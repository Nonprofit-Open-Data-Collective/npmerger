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
