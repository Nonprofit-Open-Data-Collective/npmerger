#' Merger typology
#'
#' Sorts merger cases into types by deal structure, affiliation, and the
#' relative size and condition of the two organizations in the years before
#' the merger. Rules are applied in order; the first that matches wins:
#'
#' 1. `consolidation` cases: "Consolidation into a new entity";
#' 2. `mergerN` cases: "Multi-party absorption";
#' 3. affiliated organizations: "Related-entity restructuring";
#' 4. no recipient size before the merger: "Recipient not observed before
#'    the merger";
#' 5. little transferred (FMV under $25,000, or not reported) by a donor
#'    with under $50,000 in assets, and donor less than half the
#'    recipient's size: "Program or asset-light transfer";
#' 6. donor less than half the recipient's size and in distress:
#'    "Absorption of a struggling organization";
#' 7. donor less than half the recipient's size: "Absorption of a stable
#'    smaller organization";
#' 8. donor between half and twice the recipient's size: "Merger of
#'    near-equals";
#' 9. otherwise: "Larger donor into smaller successor".
#'
#' Size is the donor's budget (the larger of revenue and expenses) over the
#' recipient's revenue, in t-1 (else t-2). The donor is in distress when
#' expenses exceed revenue, or revenue fell 25% or more from t-3 (else t-4).
#'
#' @param cases,donors,recipients,transfers Tables from
#'   [build_merger_data()].
#' @return A data.table, one row per `MERGER_ID`: `MERGER_GROUP_ID`, `TYPE`,
#'   `TYPOLOGY` (a factor in the order above), `AFFILIATED`, `RATIO`,
#'   `DISTRESS`, `ASSET_LIGHT`, `D_SIZE`, `R_SIZE`, and `FMV` (assets
#'   transferred, `NA` for outliers).
#' @export
merger_typology <- function(cases, donors, recipients, transfers) {
  cs <- as.data.table(cases); dn <- as.data.table(donors); rc <- as.data.table(recipients)
  tv <- as.data.table(transfers)
  pick <- function(a, b) fifelse(!is.na(a), a, b)
  sz <- merge(dn[, list(MERGER_ID, D_REV = pick(REVENUE_TM1, REVENUE_TM2), D_AST = pick(ASSETS_TM1, ASSETS_TM2),
                        D_EXP = pick(EXPENSES_TM1, EXPENSES_TM2), D_REV3 = pick(REVENUE_TM3, REVENUE_TM4))],
              rc[, list(MERGER_ID, R_REV = pick(REVENUE_TM1, REVENUE_TM2))], by = "MERGER_ID")
  x <- merge(cs[, list(MERGER_ID, MERGER_GROUP_ID, TYPE, AFFILIATED)], sz, by = "MERGER_ID", all.x = TRUE)
  x <- merge(x, tv[, list(MERGER_ID, FMV = fifelse(FLAG_OUTLIER %in% TRUE, NA_real_, FMV_ASSETS))],
             by = "MERGER_ID", all.x = TRUE)
  # donor budget: the larger of revenue and expenses (programs can run on
  # expenses funded by an earlier year's revenue)
  x[, D_SIZE := pmax(D_REV, D_EXP, 0, na.rm = TRUE)]
  x[, R_SIZE := pmax(R_REV, 0, na.rm = TRUE)]
  x[, RATIO := fifelse(R_SIZE > 0, D_SIZE / R_SIZE, NA_real_)]
  x[, DISTRESS := (D_EXP > D_REV & D_REV > 0) | (D_REV3 > 0 & D_REV < 0.75 * D_REV3)]
  x[, ASSET_LIGHT := (is.na(FMV) | FMV < 25000) & (is.na(D_AST) | D_AST < 50000)]
  typ <- typology_levels()
  x[, TYPOLOGY := fcase(
    TYPE == "consolidation", typ[1],
    TYPE == "mergerN", typ[2],
    AFFILIATED %in% TRUE, typ[3],
    is.na(RATIO), typ[9],
    ASSET_LIGHT & RATIO < 0.5, typ[4],
    RATIO < 0.5 & DISTRESS %in% TRUE, typ[5],
    RATIO < 0.5, typ[6],
    RATIO <= 2, typ[7],
    default = typ[8])]
  x[, TYPOLOGY := factor(TYPOLOGY, typ)]
  x[, list(MERGER_ID, MERGER_GROUP_ID, TYPE, TYPOLOGY, AFFILIATED, RATIO, DISTRESS, ASSET_LIGHT, D_SIZE, R_SIZE, FMV)]
}

#' @rdname merger_typology
#' @export
typology_levels <- function() {
  c("Consolidation into a new entity", "Multi-party absorption", "Related-entity restructuring",
    "Program or asset-light transfer", "Absorption of a struggling organization",
    "Absorption of a stable smaller organization", "Merger of near-equals",
    "Larger donor into smaller successor", "Recipient not observed before the merger")
}

utils::globalVariables(c("D_REV", "D_AST", "D_EXP", "D_REV3", "R_REV", "REVENUE_TM1", "REVENUE_TM2", "REVENUE_TM3",
                         "REVENUE_TM4", "ASSETS_TM1", "ASSETS_TM2", "EXPENSES_TM1", "EXPENSES_TM2", "FMV", "FLAG_OUTLIER",
                         "FMV_ASSETS", "D_SIZE", "R_SIZE", "RATIO", "DISTRESS", "ASSET_LIGHT", "TYPOLOGY", "AFFILIATED"))
