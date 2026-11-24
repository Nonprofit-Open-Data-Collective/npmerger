#' Part VII panel around each merger
#'
#' Everyone listed on Part VII for the donor and the recipient in the years
#' `EVENT_YEAR + window`, with time from the merger on each organization's
#' own fiscal calendar. When an organization filed more than one return for
#' a year, only the latest is used.
#'
#' @param cases Output of [build_merger_cases()].
#' @param p7 Part VII rows (the `p7` element of [get_core()]).
#' @param window Integer offsets from the merger year.
#' @param name_key `"canonical"` or `"simple"`; see [name_keys()].
#' @return A data.table with `MERGER_ID`, `MERGER_GROUP_ID`, `ROLE`, `EIN2`,
#'   `TAX_YEAR`, `TIME_FROM_MERGER`, `PERSON_NAME`, `PERSON_KEY` (with
#'   `FIRST_NAME`, `LAST_NAME`, `FIRST_CANONICAL`, and `CANONICAL_RULE` from
#'   the canonical key), `TITLE`,
#'   `HOURS`, `COMP_ORG`, `COMP_RELATED`, `COMP_OTHER`, position flags
#'   (`TRUSTEE`, `OFFICER`, `KEY_EMPLOYEE`, `HIGH_COMP`, `FORMER`), and
#'   `IN_BOTH` (the person appears on both the donor's and the recipient's
#'   Part VII within the window).
#' @export
merger_part7 <- function(cases, p7, window = -2:2, name_key = c("canonical", "simple")) {
  name_key <- match.arg(name_key)
  r <- merger_roles(cases)
  p <- as.data.table(p7)
  .need(p, c("EIN2", "TAX_YEAR", "OBJECTID", "F9_07_COMP_DTK_NAME_PERS"), "p7")
  p[, TAX_YEAR := as.integer(TAX_YEAR)]
  if ("RETURN_TIME_STAMP" %in% names(p)) {
    latest <- unique(p[, list(EIN2, TAX_YEAR, OBJECTID, RETURN_TIME_STAMP)])
    data.table::setorderv(latest, c("EIN2", "TAX_YEAR", "RETURN_TIME_STAMP"), c(1L, 1L, -1L))
    p <- p[OBJECTID %in% latest[!duplicated(latest, by = c("EIN2", "TAX_YEAR")), OBJECTID]]
  }
  num <- function(v) if (v %in% names(p)) suppressWarnings(as.numeric(p[[v]])) else rep(NA_real_, nrow(p))
  flg <- function(v) if (v %in% names(p)) sn_flag(p[[v]], FALSE) else rep(NA, nrow(p))
  chr <- function(v) if (v %in% names(p)) as.character(p[[v]]) else rep(NA_character_, nrow(p))
  pp <- data.table(EIN2 = p$EIN2, TAX_YEAR = p$TAX_YEAR, PERSON_NAME = chr("F9_07_COMP_DTK_NAME_PERS"),
                   TITLE = chr("F9_07_COMP_DTK_TITLE"), HOURS = num("F9_07_COMP_DTK_AVE_HOUR_WEEK"),
                   COMP_ORG = num("F9_07_COMP_DTK_COMP_ORG"), COMP_RELATED = num("F9_07_COMP_DTK_COMP_RLTD"),
                   COMP_OTHER = num("F9_07_COMP_DTK_COMP_OTH"),
                   TRUSTEE = flg("F9_07_COMP_DTK_POS_INDIV_TRUST_X") | flg("F9_07_COMP_DTK_POS_INST_TRUST_X"),
                   OFFICER = flg("F9_07_COMP_DTK_POS_OFF_X"), KEY_EMPLOYEE = flg("F9_07_COMP_DTK_POS_KEY_EMPL_X"),
                   HIGH_COMP = flg("F9_07_COMP_DTK_POS_HIGH_COMP_X"), FORMER = flg("F9_07_COMP_DTK_POS_FORMER_X"))
  nk <- name_keys(pp$PERSON_NAME, name_key)
  pp <- merge(pp, nk[, list(PERSON_NAME, PERSON_KEY, FIRST_NAME, LAST_NAME, FIRST_CANONICAL, CANONICAL_RULE)],
              by = "PERSON_NAME", all.x = TRUE, sort = FALSE)
  w <- rbindlist(lapply(window, function(o) r[, list(MERGER_ID, MERGER_GROUP_ID, ROLE, EIN2, TAX_YEAR = EVENT_YEAR + o,
                                                     TIME_FROM_MERGER = as.integer(o))]))
  out <- merge(w, pp, by = c("EIN2", "TAX_YEAR"), allow.cartesian = TRUE)
  both <- out[!is.na(PERSON_KEY), list(N_ROLES = uniqueN(ROLE)), by = list(MERGER_ID, PERSON_KEY)][N_ROLES == 2L]
  out[, IN_BOTH := paste(MERGER_ID, PERSON_KEY) %in% both[, paste(MERGER_ID, PERSON_KEY)]]
  data.table::setcolorder(out, c("MERGER_ID", "MERGER_GROUP_ID", "ROLE", "EIN2", "TAX_YEAR", "TIME_FROM_MERGER"))
  data.table::setorderv(out, c("MERGER_ID", "ROLE", "TAX_YEAR", "PERSON_KEY"))
  out[]
}

#' Smooth panel variables using only current and past years
#'
#' A trailing moving average within each organization, defined on calendar
#' years: the value for year t is the mean of the non-missing values in
#' years t-(k-1) through t. Unlike a centered window it never uses future
#' years, so pre-merger values are not contaminated by post-merger ones.
#' Filing gaps are not bridged.
#'
#' Uses `panel990::panel_smooth(align = "right")` when the installed
#' panel990 supports it, and an equivalent internal implementation
#' otherwise.
#'
#' @param x A panel with `id` and `time` columns.
#' @param vars Numeric columns to smooth.
#' @param k Window length in years.
#' @param id,time Panel identifier and time columns.
#' @return `x` with `vars` replaced by their trailing averages.
#' @export
#' @examples
#' x <-
#'   data.frame(
#'     EIN2     = "A",
#'     TAX_YEAR = c( 2018, 2019, 2021 ),
#'     REVENUE  = c(   10,   20,   60 )
#'   )
#'
#' # 2021 averages 2019 and 2021 only (2020 is missing)
#' smooth_trailing( x, "REVENUE" )
smooth_trailing <- function(x, vars, k = 3L, id = "EIN2", time = "TAX_YEAR") {
  al <- formals(panel990::panel_smooth)$align
  if (!is.null(al) && "right" %in% eval(al)) {
    out <- panel990::panel_smooth(as.data.frame(x), vars = vars, window = k, align = "right",
                                  time = time, id = id, verbose = FALSE)
    return(as.data.table(out))
  }
  dt <- data.table::copy(as.data.table(x))
  dt[, ROW_ID_ := .I]
  for (v in vars) {
    s <- dt[, list(id = get(id), t = as.integer(get(time)), val = as.numeric(get(v)))]
    lagged <- rbindlist(lapply(seq_len(k) - 1L, function(j) s[, list(id, t = t + j, val)]))
    agg <- lagged[!is.na(val), list(sm = mean(val)), by = list(id, t)]
    data.table::set(dt, j = v, value = agg[s, on = c("id", "t")]$sm)
  }
  dt[, ROW_ID_ := NULL][]
}

#' Fiscal-health panel around each merger
#'
#' Stacks the donor's years up to its merger year and the recipient's years
#' before and after its merger year, with harmonized measures from
#' [merger_measures()] and, optionally, fiscal-health ratios and a composite
#' index from the 'fiscal' package.
#'
#' @section Comparability over time:
#' Ratios come from [fiscal::compute_all_panel()]. Its winsorized,
#' standardized, and percentile variants are re-estimated within each tax
#' year, so they rank organizations within a year rather than measure
#' change. To track change, pass a `fit` (a fitted
#' `fiscal_health_fit()` model calibrated once on a reference sample) and
#' `weights` (`fiscal_weights()`). Every organization-year is then scored
#' with the same fixed parameters. Scoring needs a 'fiscal' version that
#' exports `fiscal_health_score()` and `fiscal_health_index()`. The version
#' pinned in `DESCRIPTION` does not, so with it a non-`NULL` `fit` stops
#' with an error.
#'
#' @section Smoothing:
#' `smooth = "trailing"` replaces the financial fields with trailing
#' `k`-year averages ([smooth_trailing()]) before measures and ratios are
#' computed. Use smoothed values for matching and baselines. Use raw values
#' (`smooth = "none"`) for event-time outcome estimates, because a trailing
#' window spreads a real post-merger change over `k` years.
#'
#' @param cases Output of [build_merger_cases()].
#' @param oy Organization-year table from [org_years()].
#' @param pre,post Years before and after the merger year. Donors are kept
#'   only through their merger year.
#' @section Trends:
#' With `trends = TRUE`, growth, revenue volatility, and deficit-year
#' columns from [trend_measures()] are computed on the full (unsmoothed)
#' organization-year history before the window is cut, so the first window
#' year still has its prior-year growth. Use [merger_proforma()] on the
#' result for a combined donor + recipient pre-merger baseline, and
#' [tuckman_chang()] for vulnerability flags.
#'
#' @param ratios Compute 'fiscal' ratios (requires the 'fiscal' package).
#' @param trends Add [trend_measures()] columns.
#' @param fit,weights Optional fitted 'fiscal' model and weights; adds
#'   `fh_*` dimension scores and the `fiscal_health` index.
#' @param smooth `"none"` or `"trailing"`.
#' @param k Trailing window length in years.
#' @return A data.table, one row per merger, role, and year, with
#'   `MERGER_ID`, `MERGER_GROUP_ID`, `ROLE`, `EIN2`, `TAX_YEAR`,
#'   `TIME_FROM_MERGER`, measure columns, and (if requested) ratio and index
#'   columns.
#' @export
merger_fiscal_panel <- function(cases, oy, pre = 5L, post = 5L, ratios = TRUE, fit = NULL, weights = NULL,
                                smooth = c("none", "trailing"), k = 3L, trends = TRUE) {
  smooth <- match.arg(smooth)
  oy <- as.data.table(oy)
  if (!"REVENUE_HHI" %in% names(oy)) oy <- merger_measures(oy)
  if (trends) oy <- trend_measures(oy)
  r <- merger_roles(cases)
  if (smooth == "trailing") {
    num <- names(oy)[vapply(oy, is.numeric, logical(1L))]
    fin <- setdiff(grep("^F9_(01|08|09|10)_", num, value = TRUE), "TAX_YEAR")
    oy <- smooth_trailing(oy, fin, k = k)
    oy <- merger_measures(oy)
  }
  w <- rbindlist(lapply(seq.int(-pre, post), function(o)
    r[, list(MERGER_ID, MERGER_GROUP_ID, ROLE, EIN2, TAX_YEAR = EVENT_YEAR + o, TIME_FROM_MERGER = as.integer(o))]))
  w <- w[!(ROLE == "donor" & TIME_FROM_MERGER > 0L)]
  sub <- oy[unique(w[, list(EIN2, TAX_YEAR)]), on = c("EIN2", "TAX_YEAR"), nomatch = NULL]
  keep <- c("EIN2", "TAX_YEAR", "OBJECTID", "RETURN_TYPE", "EZ", intersect(c(.measure_cols, .trend_cols), names(sub)))
  out <- merge(w, sub[, keep, with = FALSE], by = c("EIN2", "TAX_YEAR"))
  if (ratios && nrow(sub)) {
    if (!requireNamespace("fiscal", quietly = TRUE)) stop("`ratios = TRUE` needs the 'fiscal' package.", call. = FALSE)
    met <- if (is.null(fit)) "ratio" else c("ratio", "w")
    # append_to_df = TRUE, then keep the new columns: fiscal's
    # compute_all_panel(append_to_df = FALSE) fails when it re-sorts rows
    rt <- withCallingHandlers(
      suppressMessages(fiscal::compute_all_panel(as.data.frame(sub), metrics = met, append_to_df = TRUE, verbose = FALSE)),
      warning = function(w) if (grepl("normalization is zero or NA", conditionMessage(w))) invokeRestart("muffleWarning"))
    rt <- as.data.table(rt)
    mcols <- setdiff(names(rt), names(sub))
    # a ratio named like a measure column but in lower case (invest_income
    # vs INVEST_INCOME) breaks case-insensitive databases: add "_ratio"
    clash <- mcols[tolower(mcols) %in% tolower(c(names(out), names(sub)))]
    if (length(clash)) {
      data.table::setnames(rt, clash, paste0(clash, "_ratio"))
      mcols[match(clash, mcols)] <- paste0(clash, "_ratio")
    }
    if (!is.null(fit)) {
      sc <- .fiscal_fun("fiscal_health_score")(as.data.frame(rt), fit)
      if (!is.null(weights)) sc <- .fiscal_fun("fiscal_health_index")(sc, weights)
      sc <- as.data.table(sc)
      mcols <- union(mcols, grep("^fh_|^fiscal_health", names(sc), value = TRUE))
      rt <- sc
    }
    out <- merge(out, rt[, c("OBJECTID", mcols), with = FALSE], by = "OBJECTID", all.x = TRUE)
  }
  data.table::setcolorder(out, c("MERGER_ID", "MERGER_GROUP_ID", "ROLE", "EIN2", "TAX_YEAR", "TIME_FROM_MERGER"))
  data.table::setorderv(out, c("MERGER_ID", "ROLE", "TAX_YEAR"))
  attr(out, "smooth") <- smooth
  out[]
}

# Look up a 'fiscal' export at run time. Fiscal-health scoring exists only
# in newer 'fiscal' versions, so the package must not refer to it directly.
.fiscal_fun <- function(name) {
  if (!name %in% getNamespaceExports("fiscal"))
    stop("`fit` needs fiscal::", name, "(), which the installed 'fiscal' (",
         as.character(utils::packageVersion("fiscal")), ") does not export. ",
         "Install a newer 'fiscal' or leave `fit = NULL`.", call. = FALSE)
  getExportedValue("fiscal", name)
}

utils::globalVariables(c("TIME_FROM_MERGER", "PERSON_NAME", "PERSON_KEY", "N_ROLES", "IN_BOTH", "ROW_ID_", "sm", "val", "t"))
