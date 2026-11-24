#' Build the matched comparison data in one call
#'
#' Runs the matching steps in order: the full 990 panel ([get_panel()]), the
#' research sample of mergers with a full observation window
#' ([merger_sample()]), the Schedule N organizations to keep out of the pool
#' ([schedule_n_events()]), the comparison pool ([match_pool()]), match
#' candidates for each matching specification ([match_candidates()]), and
#' balance checks ([match_balance()]).
#'
#' @param merger_data The list from [build_merger_data()] (needs `cases`;
#'   `sched_n` and `transactions` are used to keep merging organizations out
#'   of the pool).
#' @param panel A panel from [get_panel()]. If `NULL`, it is built from
#'   `years` and `path`, which reads every 990 filer and takes several
#'   minutes.
#' @param years,path,verbose Passed to [get_panel()] when `panel` is `NULL`.
#' @param types,pre,post,years_back Passed to [merger_sample()] (and
#'   `pre`, `post`, `years_back` to [match_pool()]).
#' @param exclude_window Passed to [match_pool()].
#' @param health Named character vector of profitability or fiscal-health
#'   measures. Each one is a separate specification with its own candidate
#'   table, named after the element (default: `margin` = `"MARGIN"`,
#'   `equity` = `"EQUITY_RATIO"`).
#' @param ntee_chars,size,size_caliper,health_caliper,max_year_gap Passed to
#'   [match_candidates()].
#' @param balance_k Numbers of closest candidates to check balance for.
#' @return A list of class `merger_match_data`:
#'   * `panel`, `sample`, `baseline`, `treated`, `events`, `pool`;
#'   * `candidates`: a named list with one candidate table per `health`
#'     specification;
#'   * `balance`: [match_balance()] results for each specification and `k`;
#'   * `coverage`: per specification, treated units, units with at least 1,
#'     5, and 25 candidates, the mean and median number of candidates, and
#'     the share of pairs in the same calendar year;
#'   * `settings`: the arguments used.
#' @seealso `vignette("matching", package = "npmerger")`
#' @export
#' @examples
#' \dontrun{
#' md <- build_merger_data( years = efile_years() )
#' mm <- build_match_data( md, path = "PANEL990" )
#'
#' mm$coverage
#'
#' # the five closest comparison org-years for each recipient
#' mm$candidates$margin[ RANK <= 5 ]
#' }
build_match_data <- function(merger_data, panel = NULL, years = efile_years(), path = "PANEL990",
                             types = "merger2", pre = 2L, post = 2L, years_back = 2:3, exclude_window = -3:2,
                             health = c(margin = "MARGIN", equity = "EQUITY_RATIO"), ntee_chars = 2L,
                             size = c("REAL_ASSETS", "REAL_EXPENSES"), size_caliper = log(2),
                             health_caliper = c(MARGIN = 0.10, EQUITY_RATIO = 0.15, MONTHS_CASH = 3),
                             max_year_gap = Inf, balance_k = c(1L, 5L), verbose = TRUE) {
  say <- function(...) if (verbose) message(...)
  if (is.null(merger_data$cases)) stop("`merger_data` needs a `cases` table (see build_merger_data()).", call. = FALSE)
  if (is.null(names(health))) names(health) <- tolower(health)
  if (is.null(panel)) { say("Full 990 panel"); panel <- get_panel(years, path = path, verbose = verbose) }

  say("Research sample")
  ms <- merger_sample(merger_data$cases, panel, types = types, pre = pre, post = post, years_back = years_back)
  events <- if (!is.null(merger_data$sched_n)) schedule_n_events(merger_data$sched_n, merger_data$transactions) else {
    warning("`merger_data$sched_n` is missing, so Schedule N organizations are not kept out of the pool.", call. = FALSE)
    NULL
  }
  say("Comparison pool")
  pool <- match_pool(panel, events, pre = pre, post = post, years_back = years_back, exclude_window = exclude_window)

  cands <- lapply(health, function(h) {
    say("Candidates: ", h)
    match_candidates(ms$treated, pool, ntee_chars = ntee_chars, size = size, health = h,
                     size_caliper = size_caliper, health_caliper = health_caliper, max_year_gap = max_year_gap)
  })
  names(cands) <- names(health)

  bal <- rbindlist(lapply(names(cands), function(nm) rbindlist(lapply(balance_k, function(k)
    cbind(SPEC = nm, K = as.integer(k), match_balance(ms$treated, pool, cands[[nm]], k = k))))))
  cov <- rbindlist(lapply(names(cands), function(nm) match_coverage(ms$treated, cands[[nm]])[, SPEC := nm]))
  data.table::setcolorder(cov, "SPEC")

  settings <- list(types = types, pre = pre, post = post, years_back = years_back, exclude_window = exclude_window,
                   health = health, ntee_chars = ntee_chars, size = size, size_caliper = size_caliper,
                   health_caliper = health_caliper[intersect(names(health_caliper), health)],
                   max_year_gap = max_year_gap, balance_k = balance_k)
  structure(list(panel = panel, sample = ms$sample, baseline = ms$baseline, treated = ms$treated,
                 events = events, pool = pool, candidates = cands, balance = bal, coverage = cov,
                 settings = settings),
            class = c("merger_match_data", "list"))
}

#' How many treated units have match candidates
#'
#' @param treated Treated units from [merger_sample()].
#' @param candidates A table from [match_candidates()].
#' @return A one-row data.table: `TREATED`, `MATCHED`, `N_GE_5`, `N_GE_25`,
#'   `MEAN_CANDIDATES`, `MEDIAN_CANDIDATES` (both among matched units), and
#'   `SAME_YEAR_SHARE` (share of pairs in the treated unit's calendar year).
#' @export
match_coverage <- function(treated, candidates) {
  n <- as.data.table(candidates)[, .N, by = T_ID]$N
  data.table(TREATED = nrow(treated), MATCHED = length(n), N_GE_5 = sum(n >= 5), N_GE_25 = sum(n >= 25),
             MEAN_CANDIDATES = if (length(n)) mean(n) else NA_real_,
             MEDIAN_CANDIDATES = if (length(n)) stats::median(n) else NA_real_,
             SAME_YEAR_SHARE = if (nrow(candidates)) mean(candidates$YEAR_GAP == 0) else NA_real_)
}

#' @export
print.merger_match_data <- function(x, ...) {
  cat("<merger_match_data>\n")
  cat(sprintf("  panel:     %s org-years\n", format(nrow(x$panel), big.mark = ",")))
  cat(sprintf("  sample:    %s cases, %s treated units\n", format(nrow(x$sample), big.mark = ","), format(nrow(x$treated), big.mark = ",")))
  cat(sprintf("  pool:      %s org-years\n", format(nrow(x$pool), big.mark = ",")))
  for (i in seq_len(nrow(x$coverage))) with(x$coverage[i], cat(sprintf(
    "  %-10s %s of %s treated matched, median %s candidates\n", paste0(SPEC, ":"),
    format(MATCHED, big.mark = ","), format(TREATED, big.mark = ","), format(MEDIAN_CANDIDATES, big.mark = ","))))
  invisible(x)
}

utils::globalVariables(c("SPEC"))
