#' npmerger: Build Nonprofit Merger Datasets from IRS 990 Efile Data
#'
#' Pipeline stages, each a separate function so users can enter at any point:
#'
#' 1. **Retrieve**: [get_schedule_n()] downloads Schedule N tables through
#'    'panel990'.
#' 2. **Transactions**: [sn_transactions()] stacks Part I and Part II asset
#'    lines into one long table, and [sn_filings()] builds one row per
#'    Schedule N filing.
#' 3. **Classify**: [classify_transactions()] labels each filing (merger2,
#'    mergerN, consolidation, asset_transfer, closure, asset_disposition,
#'    reorganization, other) using rules from [merger_rules()].
#' 4. **Cases and tables**: merger IDs ([merger_id()]) plus the donor,
#'    recipient, Part VII and fiscal panels (in development).
#'
#' @keywords internal
"_PACKAGE"

#' @importFrom data.table := .N .SD .BY .I %between% data.table as.data.table setDT fcase fifelse fcoalesce rbindlist uniqueN
NULL

utils::globalVariables(c(
  "OBJECTID", "EIN2", "TAX_YEAR", "PART", "RECIP_EIN", "RECIP_NAME", "RECIP_TYPE",
  "IRC_SECTION", "FMV", "SELF_TRANSFER", "RECIP_KEY", "HAS_P1", "HAS_P2",
  "LEADER_SN", "LEADER_P7", "LEADER", "N_RECIP", "N_NP_RECIP", "TOP_SHARE",
  "N_DONORS", "R_NEW", "TYPE", "FMV_TOTAL", "FMV_NP", "DIR", "EMP", "OWN", "COMP",
  "TOP_RECIP_EIN", "DONOR_FILES_LATER", "V1", "RK"
))
