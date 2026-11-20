#' Schedule N transaction table
#'
#' One row per Schedule N filing: `TAX_YEAR`, `OBJECTID`, `EIN2`, `TYPE`, and
#' the evidence columns behind the label.
#'
#' @param classified Output of [classify_transactions()].
#' @return A data.table.
#' @export
sched_n_table <- function(classified) {
  x <- as.data.table(classified)
  keep <- c("TAX_YEAR", "OBJECTID", "EIN2", "TYPE", "BASIS", "AFFILIATED", "HAS_P1", "HAS_P2",
            "LEADER_SN", "LEADER_P7", "N_SHARED_P7", "LEADER", "SO_MERGER_TEXT_DONOR",
            "SO_MERGER_TEXT_RECIP", "GOV_DOC_CHANGE_RECIP", "N_CORROBORATE", "N_RECIP", "N_NP_RECIP",
            "TOP_RECIP_EIN", "TOP_SHARE", "FMV_TOTAL", "FMV_NP", "N_DONORS", "R_NEW", "R_FORMED",
            "FINAL_RETURN", "DONOR_FILES_LATER", "AFF_SCHED_R", "AFF_SUPPORT_ORG", "AFF_GROUP", "MISSION_SIM")
  x[, intersect(keep, names(x)), with = FALSE][order(TAX_YEAR, EIN2)]
}

#' Donor and recipient attribute tables
#'
#' Organization attributes for each side of a merger: merger ID, Schedule N
#' year, revenue/expenses/assets for the five years up to the merger, address,
#' organization age, and NTEE code.
#'
#' @param cases Output of [build_merger_cases()].
#' @param role `"donor"` or `"recipient"`.
#' @param ... Retrieval options.
#' @return A data.table.
#' @export
merger_attributes <- function(cases, role = c("donor", "recipient"), ...) {
  .not_yet("merger_attributes", "Plan step 5")
}

#' Part VII panel around each merger
#'
#' People listed on Part VII for the donor and recipient from t-2 to t+2,
#' with `MERGER_ID`, `TAX_YEAR`, `TIME_FROM_MERGER`, `ROLE`, and an
#' `IN_BOTH` flag for people who appear on both organizations.
#'
#' @param cases Output of [build_merger_cases()].
#' @param window Integer offsets from the merger year.
#' @param ... Retrieval options.
#' @return A data.table.
#' @export
merger_part7 <- function(cases, window = -2:2, ...) {
  .not_yet("merger_part7", "Plan step 6")
}

#' Fiscal-health panel around each merger
#'
#' Donor years up to the merger and recipient years before and after it,
#' with 'fiscal' metrics plus staff expenses, executive pay, grants,
#' overhead, and debt.
#'
#' @param cases Output of [build_merger_cases()].
#' @param pre,post Years before and after the merger year.
#' @param ... Retrieval options.
#' @return A data.table.
#' @export
merger_fiscal_panel <- function(cases, pre = 5L, post = 5L, ...) {
  .not_yet("merger_fiscal_panel", "Plan step 6")
}
