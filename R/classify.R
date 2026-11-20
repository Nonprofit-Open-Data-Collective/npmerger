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
#' @param promote If `TRUE` (default), a dissolution to one nonprofit successor
#'   with no leadership evidence is promoted from `asset_transfer` to a merger
#'   label when at least `min_corroborate` corroborating signals agree.
#' @param min_corroborate Number of corroborating signals required for
#'   promotion. One signal alone was too loose on 2019-21 data; two promoted
#'   about 5% of asset transfers, and those looked like mergers on measures
#'   the rule does not use.
#' @param corroborate Names of logical columns that count as corroborating
#'   signals: Schedule O merger language on the donor's and the recipient's
#'   return, and a Part VI line 4 governing-document change at the recipient
#'   in year t or t+1.
#' @return A list of class `merger_rules`.
#' @export
#' @examples
#' merger_rules()
#' merger_rules(leader = "sn", promote = FALSE)
merger_rules <- function(min_top_share = 0.5, leader = c("either", "sn", "p7"),
                         min_donors_n = 2L, new_entity_years = 1L,
                         promote = TRUE, min_corroborate = 2L,
                         corroborate = c("SO_MERGER_TEXT_DONOR", "SO_MERGER_TEXT_RECIP",
                                         "GOV_DOC_CHANGE_RECIP")) {
  structure(list(min_top_share = min_top_share, leader = match.arg(leader),
                 min_donors_n = as.integer(min_donors_n),
                 new_entity_years = as.integer(new_entity_years),
                 promote = isTRUE(promote), min_corroborate = as.integer(min_corroborate),
                 corroborate = corroborate),
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
#'   window), `R_NEW` (recipient newly formed), and the corroborating-signal
#'   columns named in `rules$corroborate`. Missing optional columns are
#'   treated as `FALSE` (or 1 donor).
#' @param rules A [merger_rules()] object.
#' @return `x` (as a data.table) with added columns `LEADER` (leadership
#'   evidence), `N_CORROBORATE` (number of corroborating signals present),
#'   `BASIS` (`"leader"`, `"corroborated"`, or `NA` for non-mergers), and
#'   `TYPE`.
#' @export
classify_transactions <- function(x, rules = merger_rules()) {
  x <- data.table::copy(as.data.table(x))
  col <- function(v, default) if (v %in% names(x)) x[[v]] else rep(default, nrow(x))
  lg <- function(v) fcoalesce(as.logical(col(v, FALSE)), FALSE)
  if (rules$leader != "sn" && !"LEADER_P7" %in% names(x))
    warning("`LEADER_P7` not found; Part VII evidence treated as absent.", call. = FALSE)
  sn <- lg("LEADER_SN"); p7 <- lg("LEADER_P7")
  x[, LEADER := switch(rules$leader, either = sn | p7, sn = sn, p7 = p7)]
  ncorr <- if (length(rules$corroborate)) Reduce(`+`, lapply(rules$corroborate, lg)) else rep(0L, nrow(x))
  x[, N_CORROBORATE := as.integer(ncorr)]
  self <- !is.na(x$TOP_RECIP_EIN) & x$TOP_RECIP_EIN == clean_ein(x$EIN2)
  one_successor <- x$N_NP_RECIP >= 1 & (x$N_NP_RECIP == 1 | fcoalesce(x$TOP_SHARE, 0) >= rules$min_top_share)
  multi <- fcoalesce(as.integer(col("N_DONORS", 1L)), 1L) >= rules$min_donors_n
  newent <- lg("R_NEW")
  promoted <- rules$promote & !x$LEADER & ncorr >= rules$min_corroborate
  merger_ev <- x$LEADER | promoted
  x[, TYPE := fcase(
    !HAS_P1 & HAS_P2, "asset_disposition",
    self, "reorganization",
    HAS_P1 & !one_successor, "closure",
    HAS_P1 & merger_ev & multi & newent, "consolidation",
    HAS_P1 & merger_ev & multi, "mergerN",
    HAS_P1 & merger_ev, "merger2",
    HAS_P1, "asset_transfer",
    default = "other")]
  x[, BASIS := fcase(!TYPE %in% c("merger2", "mergerN", "consolidation"), NA_character_,
                     LEADER, "leader", default = "corroborated")]
  x[]
}

utils::globalVariables(c("N_CORROBORATE", "BASIS"))
