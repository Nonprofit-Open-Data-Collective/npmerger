#' Build merger identifiers
#'
#' `merger_id()` builds the pair identifier `YEAR-FROMEIN-TOEIN` (9-digit
#' EINs, donor first). `merger_group_id()` builds `YEAR-TOEIN`, which links
#' all donors folding into one recipient.
#'
#' @param year Merger year (the donor's Schedule N tax year).
#' @param from_ein Donor (closing organization) EIN.
#' @param to_ein Recipient (successor organization) EIN.
#' @return A character vector.
#' @export
#' @examples
#' merger_id(2020, "01-0215911", "010431680")
#' merger_group_id(2020, "010431680")
merger_id <- function(year, from_ein, to_ein) {
  f <- clean_ein(from_ein); t <- clean_ein(to_ein)
  ifelse(is.na(year) | is.na(f) | is.na(t), NA_character_, paste(as.integer(year), f, t, sep = "-"))
}

#' @rdname merger_id
#' @export
merger_group_id <- function(year, to_ein) {
  t <- clean_ein(to_ein)
  ifelse(is.na(year) | is.na(t), NA_character_, paste(as.integer(year), t, sep = "-"))
}

#' Build merger cases (donor-recipient pairs)
#'
#' Turns classified filings into one row per donor-recipient pair.
#'
#' * `MERGER_ID` is `YEAR-FROMEIN-TOEIN`, using the donor's Schedule N year.
#' * `MERGER_GROUP_ID` is `YEAR-TOEIN`. It links donors that fold into the
#'   same recipient within `group_window` years of each other, and uses the
#'   earliest donor year in the group.
#' * `MERGER_YEAR` is the donor's Schedule N tax year (time 0 for the donor).
#' * `RECIP_MERGER_YEAR` is the recipient's tax year whose filing period
#'   contains the asset distribution date (time 0 for the recipient). It
#'   falls back to `MERGER_YEAR` when the recipient's filing period is
#'   unknown.
#'
#' @param classified Output of [classify_transactions()].
#' @param tx Output of [sn_transactions()].
#' @param header Optional 990 header rows for recipients (with `EIN2`,
#'   `TAX_YEAR`, `TAX_PERIOD_BEGIN_DATE`, `TAX_PERIOD_END_DATE`), used to
#'   place the distribution date on the recipient's fiscal calendar.
#' @param types Transaction types to keep.
#' @param group_window Years between donors that still count as one group.
#' @return A data.table of class `merger_cases`, one row per `MERGER_ID`.
#' @export
build_merger_cases <- function(classified, tx, header = NULL,
                               types = c("merger2", "mergerN", "consolidation"),
                               group_window = 1L) {
  cl <- .with_recip_ein2(classified)
  cl <- cl[TYPE %in% types & !is.na(TOP_RECIP_EIN)]
  tx <- as.data.table(tx)
  lines <- tx[cl[, list(OBJECTID, RECIP_EIN = TOP_RECIP_EIN)], on = c("OBJECTID", "RECIP_EIN"), nomatch = NULL]
  dd <- lines[, list(DIST_DATE = suppressWarnings(max(as.Date(DIST_DATE), na.rm = TRUE)),
                     FMV_TO_RECIP = sum(FMV, na.rm = TRUE), N_LINES = .N), by = list(OBJECTID, RECIP_EIN)]
  dd[!is.finite(DIST_DATE), DIST_DATE := as.Date(NA)]
  keep <- intersect(c("TYPE", "BASIS", "AFFILIATED", "N_DONORS", "LEADER_SN", "LEADER_P7", "N_SHARED_P7",
                      "N_CORROBORATE", "R_NEW", "MISSION_SIM", "TOP_SHARE", "FMV_TOTAL"), names(cl))
  cs <- cl[, c("OBJECTID", "EIN2", "RECIP_EIN2", "TOP_RECIP_EIN", "TAX_YEAR", keep), with = FALSE]
  data.table::setnames(cs, c("OBJECTID", "EIN2", "TAX_YEAR"), c("DONOR_OBJECTID", "DONOR_EIN2", "MERGER_YEAR"))
  cs <- merge(cs, dd, by.x = c("DONOR_OBJECTID", "TOP_RECIP_EIN"), by.y = c("OBJECTID", "RECIP_EIN"), all.x = TRUE)
  cs[, MERGER_ID := merger_id(MERGER_YEAR, DONOR_EIN2, TOP_RECIP_EIN)]
  # amended returns: keep one row per merger ID (latest filing object)
  data.table::setorderv(cs, c("MERGER_ID", "DONOR_OBJECTID"), c(1L, -1L))
  cs <- cs[!duplicated(MERGER_ID)]
  # merger groups: donors to one recipient whose years are within group_window of the previous donor
  data.table::setorderv(cs, c("TOP_RECIP_EIN", "MERGER_YEAR"))
  cs[, GRP_BREAK_ := c(TRUE, diff(MERGER_YEAR) > group_window), by = TOP_RECIP_EIN]
  cs[, GRP_NUM_ := cumsum(GRP_BREAK_), by = TOP_RECIP_EIN]
  cs[, `:=`(GROUP_YEAR = min(MERGER_YEAR), N_GROUP = uniqueN(DONOR_EIN2)), by = list(TOP_RECIP_EIN, GRP_NUM_)]
  cs[, MERGER_GROUP_ID := merger_group_id(GROUP_YEAR, TOP_RECIP_EIN)]
  cs[, c("GRP_BREAK_", "GRP_NUM_") := NULL]
  # recipient's merger year on its own fiscal calendar
  cs[, RECIP_MERGER_YEAR := MERGER_YEAR]
  if (!is.null(header) && nrow(header) && all(c("TAX_PERIOD_BEGIN_DATE", "TAX_PERIOD_END_DATE") %in% names(header))) {
    h <- unique(as.data.table(header)[, list(EIN2, RY = as.integer(TAX_YEAR),
                                             B = as.Date(TAX_PERIOD_BEGIN_DATE), E = as.Date(TAX_PERIOD_END_DATE))])
    m <- h[cs[!is.na(DIST_DATE), list(MERGER_ID, EIN2 = RECIP_EIN2, DIST_DATE)], on = "EIN2", nomatch = NULL, allow.cartesian = TRUE]
    m <- m[DIST_DATE >= B & DIST_DATE <= E, list(RY = min(RY)), by = MERGER_ID]
    cs[m, RECIP_MERGER_YEAR := i.RY, on = "MERGER_ID"]
  }
  cs[, TOP_RECIP_EIN := NULL]
  data.table::setcolorder(cs, c("MERGER_ID", "MERGER_GROUP_ID", "TYPE", "DONOR_EIN2", "RECIP_EIN2", "MERGER_YEAR",
                                "RECIP_MERGER_YEAR", "GROUP_YEAR", "N_GROUP", "DIST_DATE", "FMV_TO_RECIP", "N_LINES"))
  data.table::setorderv(cs, c("MERGER_YEAR", "MERGER_ID"))
  structure(cs[], class = c("merger_cases", class(cs)))
}

#' Donor and recipient roles for each merger
#'
#' A long table with one row per organization per merger: `MERGER_ID`,
#' `MERGER_GROUP_ID`, `ROLE` (`"donor"` or `"recipient"`), `EIN2`, and
#' `EVENT_YEAR` (time 0 on that organization's own fiscal calendar).
#'
#' @param cases Output of [build_merger_cases()].
#' @return A data.table.
#' @export
merger_roles <- function(cases) {
  cs <- as.data.table(cases)
  rbind(cs[, list(MERGER_ID, MERGER_GROUP_ID, ROLE = "donor", EIN2 = DONOR_EIN2, EVENT_YEAR = MERGER_YEAR)],
        cs[, list(MERGER_ID, MERGER_GROUP_ID, ROLE = "recipient", EIN2 = RECIP_EIN2, EVENT_YEAR = RECIP_MERGER_YEAR)])
}

#' Classify Schedule N asset descriptions
#'
#' Maps free-text asset descriptions to broad classes.
#'
#' @param x Character vector of asset descriptions.
#' @return Character vector: `"all_assets"` (whole or net asset transfers),
#'   `"liabilities"` (liabilities assumed by the recipient, usually entered as
#'   negative values), `"cash"`, `"receivables"` (including loans, notes, and
#'   amounts due), `"investments"`, `"real_estate"`, `"equipment"`,
#'   `"inventory"`, `"prepaid"` (prepaid expenses and deposits), `"program"`
#'   (contracts, programs, intangibles, records, name), `"other"`, or
#'   `"unknown"`.
#' @export
#' @examples
#' asset_class(c("Cash & Cash Equivalents", "Accounts Receivable", "Land and building",
#'               "All remaining assets", "Furniture and equipment", "Program contracts",
#'               "Accounts payable & accrued expenses", "Prepaid expenses"))
asset_class <- function(x) {
  u <- toupper(as.character(x))
  fcase(
    is.na(u) | grepl("^\\s*(N/?A|NONE|0)?\\s*$", u), "unknown",
    grepl("ALL (REMAINING |OF ITS |OF THE )?ASSETS|NET ASSETS?\\b|ASSETS NET OF|REMAINING (ASSETS|FUNDS|BALANCE|CASH)|ENTIRE|ALL FUNDS|SUBSTANTIALLY ALL|MERGE|TRANSFER OF ASSETS|ASSETS TRANSFER|EQUITY TRANSFER|^\\s*ASSETS\\s*$|DISSOLUTION|DISSOLVED", u), "all_assets",
    grepl("PAYABLE|ACCRUED|DEFERRED REVENUE|LIABILIT|ENTRANCE FEE|REFUNDABLE|DEFERRED CHARGE|WORKER.?S COMP", u) & !grepl("PREPAID", u), "liabilities",
    grepl("RECEIVABLE|RECIEVABLE|PLEDGE|\\bLOANS?\\b|\\bNOTES?\\b|DUE FROM|ADVANCE", u), "receivables",
    grepl("INVEST|SECURIT|STOCK|BOND|MUTUAL FUND|ENDOW|BROKERAGE|ANNUIT", u), "investments",
    grepl("CASH|CHECK|BANK|SAVINGS|MONEY|FUNDS|DONATION|GRANT|CONTRIBUTION|CERTIFICATES? OF DEPOSIT|\\bCDS?\\b", u), "cash",
    grepl("LAND|BUILDING|REAL (ESTATE|PROPERTY)|PROPERT|FACILIT|HOUSE|PARCEL|ACRE|CAMP\\b|LEASEHOLD", u), "real_estate",
    grepl("EQUIP|FURNI|VEHICLE|COMPUTER|FIXED ASSET|MACHIN|TRUCK|\\bVAN\\b|\\bBUS\\b|FIXTURE", u), "equipment",
    grepl("INVENTOR|SUPPLIES|BOOKS|MERCHANDISE", u), "inventory",
    grepl("PREPAID|DEPOSIT|OTHER CURRENT", u), "prepaid",
    grepl("PROGRAM|CONTRACT|INTELLECT|INTANGIBLE|TRADEMARK|RECORDS|\\bNAME\\b|GOODWILL|WEBSITE|DOMAIN|CLIENT|LICENSE|MEMBERSHIP", u), "program",
    default = "other")
}

#' Value of assets transferred in each merger
#'
#' Sums the fair market value of the asset lines the donor reported for its
#' recipient, by asset class. With `core`, it also compares the total to the
#' donor's beginning-of-year assets (`COVERAGE`) and flags implausible
#' values.
#'
#' @param cases Output of [build_merger_cases()].
#' @param tx Output of [sn_transactions()].
#' @param core Optional organization-year table from [org_years()].
#' @param max_coverage Flag transfers above this multiple of the donor's
#'   beginning-of-year assets.
#' @return A data.table, one row per `MERGER_ID`, with:
#'   * `FMV_<class>` columns (see [asset_class()]);
#'   * `FMV_TOTAL` (all lines as reported) and `FMV_ASSETS` (excluding
#'     liabilities assumed, which filers usually enter as positive amounts);
#'   * `N_LINES`, `N_FMV_MISSING`, and `ANY_NEGATIVE`;
#'   * with `core`: `DONOR_ASSETS_BOY`, `COVERAGE` (`FMV_ASSETS` divided by
#'     the donor's beginning-of-year assets), and `FLAG_OUTLIER` (coverage
#'     above `max_coverage`, or negative `FMV_ASSETS`).
#' @export
transfer_value <- function(cases, tx, core = NULL, max_coverage = 2) {
  cs <- as.data.table(cases)
  tx <- as.data.table(tx)
  key <- cs[, list(MERGER_ID, OBJECTID = DONOR_OBJECTID, RECIP_EIN = clean_ein(RECIP_EIN2), DONOR_EIN2, MERGER_YEAR)]
  ln <- tx[key, on = c("OBJECTID", "RECIP_EIN"), nomatch = NULL]
  ln[, CLASS := asset_class(ASSET_DESC)]
  wide <- data.table::dcast(ln, MERGER_ID ~ CLASS, value.var = "FMV", fun.aggregate = function(v) sum(v, na.rm = TRUE), fill = 0)
  cls <- setdiff(names(wide), "MERGER_ID")
  data.table::setnames(wide, cls, paste0("FMV_", toupper(cls)))
  tot <- ln[, list(FMV_TOTAL = sum(FMV, na.rm = TRUE), FMV_ASSETS = sum(FMV[CLASS != "liabilities"], na.rm = TRUE),
                   N_LINES = .N, N_FMV_MISSING = sum(is.na(FMV)), ANY_NEGATIVE = any(FMV < 0, na.rm = TRUE)), by = MERGER_ID]
  out <- merge(key[, list(MERGER_ID, DONOR_EIN2, MERGER_YEAR)], merge(tot, wide, by = "MERGER_ID"), by = "MERGER_ID", all.x = TRUE)
  if (!is.null(core)) {
    co <- as.data.table(core)[, list(DONOR_EIN2 = EIN2, MERGER_YEAR = TAX_YEAR, DONOR_ASSETS_BOY = ASSETS_BOY)]
    out <- merge(out, co, by = c("DONOR_EIN2", "MERGER_YEAR"), all.x = TRUE)
    out[, COVERAGE := fifelse(DONOR_ASSETS_BOY > 0, FMV_ASSETS / DONOR_ASSETS_BOY, NA_real_)]
    out[, FLAG_OUTLIER := (!is.na(COVERAGE) & COVERAGE > max_coverage) | (FMV_ASSETS < 0) %in% TRUE]
  }
  out[, c("DONOR_EIN2", "MERGER_YEAR") := NULL]
  out[]
}

utils::globalVariables(c("MERGER_ID", "MERGER_GROUP_ID", "DONOR_OBJECTID", "DONOR_EIN2", "MERGER_YEAR",
                         "RECIP_MERGER_YEAR", "GROUP_YEAR", "N_GROUP", "DIST_DATE", "FMV_TO_RECIP", "N_LINES",
                         "GRP_BREAK_", "GRP_NUM_", "RY", "B", "E", "i.RY", "ASSET_DESC", "CLASS", "ANY_NEGATIVE",
                         "N_FMV_MISSING", "DONOR_ASSETS_BOY", "ASSETS_BOY", "COVERAGE", "FLAG_OUTLIER", "FMV_ASSETS",
                         "TAX_PERIOD_BEGIN_DATE", "TAX_PERIOD_END_DATE"))
