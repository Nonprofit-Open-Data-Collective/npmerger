#' Default transaction classification rules
#'
#' Thresholds used by [classify_transactions()]. Override any element to run
#' stricter or broader definitions.
#'
#' @param min_top_share Minimum share of transferred FMV going to the dominant
#'   nonprofit recipient for a dissolution to count as a transfer to one
#'   successor (rather than a dispersed closure).
#' @param leader Leadership-continuity evidence: `"either"` (Schedule N lines
#'   2a-2c **or** Part VII overlap, the default), `"sn"` (Schedule N flags
#'   only), or `"p7"` (Part VII overlap only).
#' @param min_donors_n Number of dissolving donors to one recipient in the same
#'   window that makes a merger `mergerN`.
#' @param new_entity_years A recipient formed within this many years before the
#'   merger year counts as a new entity (consolidation).
#' @return A list of class `merger_rules`.
#' @export
#' @examples
#' merger_rules()
#' merger_rules(leader = "sn")
merger_rules <- function(min_top_share = 0.5, leader = c("either", "sn", "p7"),
                         min_donors_n = 2L, new_entity_years = 1L) {
  structure(list(min_top_share = min_top_share, leader = match.arg(leader),
                 min_donors_n = as.integer(min_donors_n),
                 new_entity_years = as.integer(new_entity_years)),
            class = "merger_rules")
}

#' Transaction type labels
#' @return Character vector of the labels [classify_transactions()] can return.
#' @export
transaction_types <- function() {
  c("merger2", "mergerN", "consolidation", "asset_transfer", "closure",
    "asset_disposition", "reorganization", "other")
}

#' Classify Schedule N filings into transaction types
#'
#' Applies rule-based labels to a filing-level feature table. The evidence
#' columns are kept, so labels can be revised without re-running the
#' pipeline.
#'
#' @param x A filing-level table, typically from [sn_filings()], with these
#'   columns: `HAS_P1`, `HAS_P2`, `LEADER_SN`, `N_NP_RECIP`, `TOP_SHARE`,
#'   `TOP_RECIP_EIN`, and `EIN2`. Optional columns: `LEADER_P7` (Part VII
#'   overlap), `N_DONORS` (dissolving donors to the same recipient in the
#'   window), and `R_NEW` (recipient newly formed). Missing optional columns
#'   are treated as `FALSE` / 1.
#' @param rules A [merger_rules()] object.
#' @return `x` (as a data.table) with added `LEADER` and `TYPE` columns.
#' @export
classify_transactions <- function(x, rules = merger_rules()) {
  x <- data.table::copy(as.data.table(x))
  col <- function(v, default) if (v %in% names(x)) x[[v]] else rep(default, nrow(x))
  if (rules$leader != "sn" && !"LEADER_P7" %in% names(x))
    warning("`LEADER_P7` not found; Part VII evidence treated as absent.", call. = FALSE)
  sn <- fcoalesce(as.logical(col("LEADER_SN", FALSE)), FALSE)
  p7 <- fcoalesce(as.logical(col("LEADER_P7", FALSE)), FALSE)
  x[, LEADER := switch(rules$leader, either = sn | p7, sn = sn, p7 = p7)]
  self <- !is.na(x$TOP_RECIP_EIN) & x$TOP_RECIP_EIN == clean_ein(x$EIN2)
  one_successor <- x$N_NP_RECIP >= 1 & (x$N_NP_RECIP == 1 | fcoalesce(x$TOP_SHARE, 0) >= rules$min_top_share)
  multi <- fcoalesce(as.integer(col("N_DONORS", 1L)), 1L) >= rules$min_donors_n
  newent <- fcoalesce(as.logical(col("R_NEW", FALSE)), FALSE)
  x[, TYPE := fcase(
    !HAS_P1 & HAS_P2, "asset_disposition",
    self, "reorganization",
    HAS_P1 & !one_successor, "closure",
    HAS_P1 & LEADER & multi & newent, "consolidation",
    HAS_P1 & LEADER & multi, "mergerN",
    HAS_P1 & LEADER, "merger2",
    HAS_P1, "asset_transfer",
    default = "other")]
  x[]
}
