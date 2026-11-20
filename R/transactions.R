#' Stack Schedule N Part I and Part II asset lines
#'
#' Builds one row per asset line reported in Schedule N Part I (liquidation,
#' termination, dissolution) or Part II (disposition of more than 25% of net
#' assets), with cleaned recipient EINs and a parsed recipient type.
#'
#' @param sn An `sn_raw` object from [get_schedule_n()].
#' @return A data.table with columns `OBJECTID`, `EIN2`, `TAX_YEAR`, `PART`
#'   (1 or 2), `ASSET_DESC`, `DIST_DATE`, `FMV`, `FMV_METHOD`, `RECIP_EIN`,
#'   `RECIP_NAME`, `RECIP_STATE`, `RECIP_ZIP`, `IRC_SECTION`, `RECIP_TYPE`, and
#'   `SELF_TRANSFER`. A recipient with a blank type but a valid EIN gets the
#'   type `"unknown_with_ein"`.
#' @export
sn_transactions <- function(sn) {
  one <- function(x, part) {
    if (is.null(x) || !nrow(x)) return(NULL)
    p <- if (part == 1L) "SN_01_LTD_" else "SN_02_DOA_"
    g <- function(v) { nm <- paste0(p, v); if (nm %in% names(x)) x[[nm]] else rep(NA_character_, nrow(x)) }
    data.table(
      OBJECTID = x$OBJECTID, EIN2 = x$EIN2, TAX_YEAR = as.integer(x$TAX_YEAR), PART = part,
      ASSET_DESC = g("ASSET_DIST_DESC"), DIST_DATE = g("ASSET_DIST_DATE"),
      FMV = suppressWarnings(as.numeric(g("ASSET_DIST_FMV"))), FMV_METHOD = g("ASSET_DIST_FMV_METHOD"),
      RECIP_EIN = clean_ein(g("RECIP_EIN")),
      RECIP_NAME = fcoalesce(g("RECIP_NAME_ORG_L1"), g("RECIP_NAME_PERS")),
      RECIP_STATE = g("RECIP_ADDR_STATE"), RECIP_ZIP = substr(g("RECIP_ADDR_ZIP"), 1, 5),
      IRC_SECTION = g("RECIP_IRC_SECTION")
    )
  }
  tx <- rbindlist(list(one(sn$p1_assets, 1L), one(sn$p2_assets, 2L)))
  tx[, RECIP_TYPE := parse_irc_section(IRC_SECTION)]
  tx[RECIP_TYPE == "unknown" & !is.na(RECIP_EIN), RECIP_TYPE := "unknown_with_ein"]
  tx[, SELF_TRANSFER := !is.na(RECIP_EIN) & RECIP_EIN == clean_ein(EIN2)]
  tx[]
}

#' One row per Schedule N filing
#'
#' The Schedule N header (T00) and asset (T01) tables do not line up: some
#' filings have header rows but no asset lines, others the reverse. This
#' builds the filing universe as the union of both, and adds Part I/II
#' indicators, the line 2a-2d successor flags, and recipient summaries.
#'
#' @param sn An `sn_raw` object.
#' @param tx Optional output of [sn_transactions()] (computed if missing).
#' @return A data.table, one row per `OBJECTID`, with `EIN2`, `TAX_YEAR`,
#'   `HAS_P1`, `HAS_P2`, `DIR`, `EMP`, `OWN`, `COMP` (lines 2a-2d, either
#'   part), `LEADER_SN` (any of 2a-2c), `N_RECIP`, `N_NP_RECIP`, `FMV_TOTAL`,
#'   `FMV_NP`, `TOP_RECIP_EIN` and `TOP_SHARE` (largest nonprofit
#'   recipient's share of total FMV).
#' @export
sn_filings <- function(sn, tx = sn_transactions(sn)) {
  hdr <- function(x, p, part1) {
    if (is.null(x) || !nrow(x)) return(NULL)
    f <- function(v) sn_flag(x[[paste0(p, v)]])
    data.table(OBJECTID = x$OBJECTID, EIN2 = x$EIN2, TAX_YEAR = as.integer(x$TAX_YEAR), P1 = part1,
               DIR = f("ORG_DTK_DIR_SUCCESSOR_X"), EMP = f("ORG_DTK_EMPL_SUCCESSOR_X"),
               OWN = f("ORG_DTK_OWN_SUCCESSOR_X"), COMP = f("ORG_DTK_REC_COMP_X"))
  }
  h <- rbindlist(list(hdr(sn$p1_header, "SN_01_", TRUE), hdr(sn$p2_header, "SN_02_", FALSE)))
  anyT <- function(v) if (all(is.na(v))) NA else any(v, na.rm = TRUE)
  fl <- h[, list(EIN2 = EIN2[1], TAX_YEAR = TAX_YEAR[1],
                 DIR = anyT(DIR), EMP = anyT(EMP), OWN = anyT(OWN), COMP = anyT(COMP)), by = OBJECTID]
  ids <- unique(rbind(h[, list(OBJECTID, EIN2, TAX_YEAR)], tx[, list(OBJECTID, EIN2, TAX_YEAR)]), by = "OBJECTID")
  fl <- merge(ids, fl[, !c("EIN2", "TAX_YEAR")], by = "OBJECTID", all.x = TRUE)
  p1_ids <- union(h[h$P1, OBJECTID], tx[PART == 1L, OBJECTID])
  p2_ids <- union(h[!h$P1, OBJECTID], tx[PART == 2L, OBJECTID])
  fl[, `:=`(HAS_P1 = OBJECTID %in% p1_ids, HAS_P2 = OBJECTID %in% p2_ids)]
  fl[, LEADER_SN := fcoalesce(DIR, FALSE) | fcoalesce(EMP, FALSE) | fcoalesce(OWN, FALSE)]

  tx[, RK := fcoalesce(RECIP_EIN, toupper(trimws(RECIP_NAME)))]
  np <- tx$RECIP_TYPE %in% .np_types & !is.na(tx$RECIP_EIN) & !tx$SELF_TRANSFER
  agg <- tx[, list(N_RECIP = uniqueN(RK, na.rm = TRUE), FMV_TOTAL = sum(FMV, na.rm = TRUE)), by = OBJECTID]
  top <- tx[np, list(FMV = sum(FMV, na.rm = TRUE)), by = list(OBJECTID, RECIP_EIN)]
  top <- top[order(OBJECTID, -FMV)]
  topr <- top[, list(N_NP_RECIP = .N, FMV_NP = sum(FMV), TOP_RECIP_EIN = RECIP_EIN[1], TOP_FMV = FMV[1]), by = OBJECTID]
  agg <- merge(agg, topr, by = "OBJECTID", all.x = TRUE)
  agg[, TOP_SHARE := fifelse(FMV_TOTAL > 0, TOP_FMV / FMV_TOTAL, NA_real_)]
  agg[is.na(N_NP_RECIP), `:=`(N_NP_RECIP = 0L, FMV_NP = 0)]
  agg[, TOP_FMV := NULL]
  tx[, RK := NULL]
  fl <- merge(fl, agg, by = "OBJECTID", all.x = TRUE)
  fl[is.na(N_RECIP), `:=`(N_RECIP = 0L, N_NP_RECIP = 0L, FMV_TOTAL = 0, FMV_NP = 0)]
  fl[]
}

utils::globalVariables(c("TOP_FMV"))
