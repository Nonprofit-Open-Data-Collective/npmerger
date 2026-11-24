#' Default transaction classification rules
#'
#' Thresholds used by [classify_transactions()]. Override any element to run
#' stricter or broader definitions.
#'
#' @param min_top_share Minimum share of transferred FMV going to the dominant
#'   nonprofit recipient for a dissolution to count as a transfer to one
#'   successor (rather than a dispersed closure). When FMV is missing, a
#'   single nonprofit recipient counts as one successor. The default of 0.75
#'   comes from hand validation: every sampled dissolution with a top share
#'   between 0.5 and 0.75 was read as a dispersed closure.
#' @param final_as_termination If `TRUE` (default), a filing with only Part II
#'   (disposition of more than 25% of assets) but the final-return box
#'   checked is treated as a termination, like a Part I filing. In hand
#'   validation none of these were ongoing dispositions; most were mergers
#'   or transfers at dissolution reported on the wrong part.
#' @param leader Leadership-continuity evidence: `"either"` (Schedule N lines
#'   2a-2c **or** Part VII overlap, the default), `"sn"` (Schedule N flags
#'   only), or `"p7"` (Part VII overlap only).
#' @param min_donors_n Number of dissolving donors to one recipient in the same
#'   window that makes a merger `mergerN`.
#' @param new_entity_years A recipient formed within this many years before the
#'   merger year counts as a new entity (consolidation).
#' @param sn_text If `TRUE` (default), merger language in Schedule N's own
#'   text (`SN_MERGER_TEXT`, see [sn_merger_pattern()]) counts as merger
#'   evidence on its own, like leadership continuity.
#' @param promote If `TRUE`, a dissolution to one nonprofit successor
#'   with no leadership evidence is promoted from `asset_transfer` to a merger
#'   label when at least `min_corroborate` corroborating signals agree. Off
#'   by default: in hand validation only 1 of 13 promoted filings read as a
#'   merger. The signals are still computed, so promotion can be turned on
#'   for a broad definition.
#' @param min_corroborate Number of corroborating signals required for
#'   promotion. One signal alone was too loose on 2019-21 data; two promoted
#'   about 5% of asset transfers, and those looked like mergers on measures
#'   the rule does not use.
#' @param corroborate Names of logical columns that count as corroborating
#'   signals: Schedule O merger language on the donor's and the recipient's
#'   return, and a Part VI line 4 governing-document change at the recipient
#'   in year t or t+1.
#' @param name_key How Part VII names are matched between donor and recipient:
#'   `"canonical"` (default; canonical first name plus surname, via
#'   [name_keys()] and the peopleparser package) or `"simple"` (first and last
#'   token, [person_key()]).
#' @return A list of class `merger_rules`.
#' @export
#' @examples
#' merger_rules()
#'
#' # strict: Schedule N boxes only
#' merger_rules( leader = "sn", sn_text = FALSE )
#'
#' # broad: corroborating signals can promote a filing
#' merger_rules( promote = TRUE )
merger_rules <- function(min_top_share = 0.75, leader = c("either", "sn", "p7"),
                         min_donors_n = 2L, new_entity_years = 1L, sn_text = TRUE,
                         promote = FALSE, min_corroborate = 2L,
                         corroborate = c("SO_MERGER_TEXT_DONOR", "SO_MERGER_TEXT_RECIP",
                                         "GOV_DOC_CHANGE_RECIP"),
                         final_as_termination = TRUE, name_key = c("canonical", "simple")) {
  structure(list(min_top_share = min_top_share, leader = match.arg(leader),
                 final_as_termination = isTRUE(final_as_termination), sn_text = isTRUE(sn_text),
                 min_donors_n = as.integer(min_donors_n),
                 new_entity_years = as.integer(new_entity_years),
                 promote = isTRUE(promote), min_corroborate = as.integer(min_corroborate),
                 corroborate = corroborate, name_key = match.arg(name_key)),
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
#'   window), `R_NEW` (recipient newly formed), `FINAL_RETURN`, and the corroborating-signal
#'   columns named in `rules$corroborate`. Missing optional columns are
#'   treated as `FALSE` (or 1 donor).
#' @param rules A [merger_rules()] object.
#' @return `x` (as a data.table) with added columns `TERMINATED` (the filer
#'   ended; see `final_as_termination` in [merger_rules()]), `LEADER` (leadership
#'   evidence), `N_CORROBORATE` (number of corroborating signals present),
#'   `BASIS` (`"leader"`, `"sn_text"`, `"corroborated"`, or `NA` for non-mergers), and
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
  term <- .terminated(x, rules$final_as_termination)
  one_successor <- .one_successor(x, rules$min_top_share)
  multi <- fcoalesce(as.integer(col("N_DONORS", 1L)), 1L) >= rules$min_donors_n
  newent <- lg("R_NEW")
  sntext <- isTRUE(rules$sn_text) & lg("SN_MERGER_TEXT")
  promoted <- rules$promote & !x$LEADER & !sntext & ncorr >= rules$min_corroborate
  merger_ev <- x$LEADER | sntext | promoted
  x[, TERMINATED := term]
  x[, TYPE := fcase(
    !term & HAS_P2, "asset_disposition",
    self, "reorganization",
    term & !one_successor, "closure",
    term & merger_ev & multi & newent, "consolidation",
    term & merger_ev & multi, "mergerN",
    term & merger_ev, "merger2",
    term, "asset_transfer",
    default = "other")]
  x[, BASIS := fcase(!TYPE %in% c("merger2", "mergerN", "consolidation"), NA_character_,
                     LEADER, "leader", sntext, "sn_text", default = "corroborated")]
  x[]
}

# The filer ended: Part I, or (optionally) Part II with the final-return box.
.terminated <- function(x, final = TRUE) {
  p1 <- fcoalesce(as.logical(x$HAS_P1), FALSE)
  if (!final || !"FINAL_RETURN" %in% names(x)) return(p1)
  p1 | (fcoalesce(as.logical(x$HAS_P2), FALSE) & fcoalesce(as.logical(x$FINAL_RETURN), FALSE))
}

# One dominant nonprofit successor: top share of FMV at or above the
# threshold, or (when FMV is missing) a single nonprofit recipient.
.one_successor <- function(x, min_top_share) {
  n <- fcoalesce(as.integer(x$N_NP_RECIP), 0L)
  s <- as.numeric(x$TOP_SHARE)
  n >= 1L & fifelse(is.na(s), n == 1L, s >= min_top_share)
}

utils::globalVariables(c("N_CORROBORATE", "BASIS", "TERMINATED"))
