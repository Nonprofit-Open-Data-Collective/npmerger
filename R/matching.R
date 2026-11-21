# ---- full 990 panel -----------------------------------------------------------

#' Columns read for the full 990 matching panel
#'
#' @return A named list: one character vector of columns per core table
#'   (header, summary, expenses, balance).
#' @export
panel_columns <- function() {
  base <- c("EIN2", "OBJECTID", "TAX_YEAR", "RETURN_TYPE", "RETURN_TIME_STAMP")
  list(
    header   = c(base, "ORG_NAME_L1", "F9_00_ORG_ADDR_STATE", "F9_00_YEAR_FORMATION", "F9_00_RETURN_FINAL_X"),
    summary  = c(base, "F9_01_REV_TOT_CY", "F9_01_EXP_TOT_CY", "F9_01_REV_CONTR_TOT_CY", "F9_01_REV_PROG_TOT_CY",
                 "F9_01_EXP_SAL_ETC_CY", "F9_01_ACT_GVRN_EMPL_TOT",
                 "F9_01_NAFB_ASSET_TOT_BOY", "F9_01_NAFB_ASSET_TOT_EOY", "F9_01_NAFB_LIAB_TOT_EOY", "F9_01_NAFB_TOT_EOY"),
    expenses = c(base, "F9_09_EXP_TOT_TOT", "F9_09_EXP_TOT_PROG", "F9_09_EXP_TOT_MGMT", "F9_09_EXP_TOT_FUNDR"),
    balance  = c(base, "F9_10_ASSET_TOT_BOY", "F9_10_ASSET_TOT_EOY", "F9_10_LIAB_TOT_EOY", "F9_10_NAFB_TOT_EOY",
                 "F9_10_ASSET_CASH_EOY", "F9_10_ASSET_SAVING_EOY", "F9_10_ASSET_CASH_SAVING_EOY",
                 "F9_10_LIAB_MTG_NOTE_EOY", "F9_10_LIAB_NOTE_UNSEC_EOY", "F9_10_LIAB_TAX_EXEMPT_BOND_EOY",
                 "F9_10_LIAB_LOAN_OFF_EOY")
  )
}

#' Build the full 990 organization-year panel
#'
#' Reads the header, summary, expenses, and balance-sheet tables for **every**
#' 990 and 990-EZ filer in `years` (only the columns in [panel_columns()]),
#' keeps one return per organization-year ([org_years()]), and returns the
#' slim matching panel from [panel_measures()]. This is the pool that
#' merger recipients are matched against.
#'
#' @param years Tax years.
#' @param path,source,verbose Passed to [panel990::download_tables()].
#' @param bmf Add NTEE codes from the BMF ([get_bmf()]): `TRUE`, `FALSE`, or a
#'   BMF table you already have.
#' @param base_year Year of the dollars in the `REAL_*` columns.
#' @return A data.table keyed by `EIN2`, `TAX_YEAR`; see [panel_measures()].
#' @export
get_panel <- function(years = efile_years(), path = "PANEL990", source = panel990::data_source(),
                      verbose = TRUE, bmf = TRUE, base_year = 2024L) {
  spec <- core_tables()[c("header", "summary", "expenses", "balance")]
  cols <- panel_columns()
  core <- lapply(names(spec), function(nm) {
    if (verbose) message("Panel table '", nm, "' (", spec[[nm]]$table, ")")
    dl <- panel990::download_tables(years = years, tables = spec[[nm]]$table, source = source, path = path, verbose = verbose)
    ok <- dl$manifest$status %in% c("downloaded", "reused")
    if (!any(ok)) return(data.table())
    rd <- panel990::read_tables(dl, columns = cols[[nm]], unique_rows = FALSE, verbose = FALSE)
    x <- rbindlist(lapply(rd$tables, as.data.table), fill = TRUE)
    x[, TAX_YEAR := as.integer(TAX_YEAR)]
    x
  })
  names(core) <- names(spec)
  oy <- org_years(structure(core, class = c("merger_core", "list")))
  rm(core); gc()
  b <- if (isTRUE(bmf)) get_bmf(unique(oy$EIN2), path = path, verbose = verbose) else if (is.data.frame(bmf)) bmf else NULL
  panel_measures(oy, bmf = b, base_year = base_year)
}

#' Consumer price index (CPI-U, annual average)
#'
#' Bureau of Labor Statistics CPI-U for all urban consumers, U.S. city
#' average, annual averages (1982-84 = 100). The 2025 value is provisional
#' (the 2024 value grown by 2.7%); replace it when the annual average is
#' published.
#' @return A data.table with `YEAR` and `CPI`.
#' @export
cpi_u <- function() {
  data.table(YEAR = 2005:2025,
             CPI = c(195.3, 201.6, 207.342, 215.303, 214.537, 218.056, 224.939, 229.594, 232.957, 236.736,
                     237.017, 240.007, 245.120, 251.107, 255.657, 258.811, 270.970, 292.655, 304.702, 313.689,
                     313.689 * 1.027))
}

#' Convert nominal dollars to constant dollars
#' @param x Dollar amounts.
#' @param year Year of each amount.
#' @param base_year Target year.
#' @return `x` in `base_year` dollars (`NA` where the year is outside [cpi_u()]).
#' @export
#' @examples
#' real_dollars(100, 2010)
real_dollars <- function(x, year, base_year = 2024L) {
  cpi <- cpi_u()
  x * cpi$CPI[cpi$YEAR == base_year] / cpi$CPI[match(as.integer(year), cpi$YEAR)]
}

#' Clean NTEE code to a given number of characters
#' @param x NTEE codes.
#' @param n Characters to keep: 1 = major group (letter), 2 = letter and
#'   first digit (e.g. `"E2"`), 3 = full common code (e.g. `"E21"`).
#' @return Character vector (`NA` when the code is missing, too short, or a
#'   placeholder such as `"UNDEFINED"`).
#' @export
#' @examples
#' ntee_level(c("E21", "b82z", "", NA, "X"), 2)
ntee_level <- function(x, n = 2L) {
  x <- toupper(gsub("[^A-Za-z0-9]", "", as.character(x)))
  out <- substr(x, 1L, n)
  # valid codes start with a letter and a digit; BMF placeholders such as
  # "UNDEFINED" / "UNU" are treated as missing
  out[is.na(x) | nchar(x) < n | !grepl("^[A-Z][0-9]", x)] <- NA_character_
  out
}

#' Slim matching measures for an organization-year table
#'
#' @param oy Organization-year table from [org_years()] (with the columns in
#'   [panel_columns()]).
#' @param bmf Optional BMF table ([get_bmf()]) for NTEE codes.
#' @param base_year Year of the dollars in the `REAL_*` columns.
#' @return A data.table with `EIN2`, `TAX_YEAR`, `OBJECTID`, `RETURN_TYPE`,
#'   `EZ`, `NAME`, `STATE`, `FORMATION_YEAR`, `FINAL_RETURN`, size measures
#'   (`REVENUE`, `EXPENSES`, `ASSETS`, `LIABILITIES`, `NET_ASSETS`, `CASH`,
#'   `SURPLUS`, `STAFF_EXP`, `EMPLOYEES`), their constant-dollar versions
#'   (`REAL_REVENUE`, `REAL_EXPENSES`, `REAL_ASSETS`), profitability and
#'   fiscal-health ratios (`MARGIN` = surplus / revenue, `EQUITY_RATIO` = net
#'   assets / assets, `MONTHS_CASH` = cash and savings / monthly expenses),
#'   `NTEE`, `NTEE2`, `NTEE_MAJOR`, and `SUBSECTION` (IRC 501(c) subsection,
#'   from the BMF). Ratios are bounded to [-1, 1]
#'   (months of cash to [0, 120]).
#' @export
panel_measures <- function(oy, bmf = NULL, base_year = 2024L) {
  x <- as.data.table(oy)
  if (!"REVENUE" %in% names(x)) x <- merger_measures(x)
  g <- function(v) if (v %in% names(x)) suppressWarnings(as.numeric(x[[v]])) else rep(NA_real_, nrow(x))
  chr <- function(v) if (v %in% names(x)) as.character(x[[v]]) else rep(NA_character_, nrow(x))
  cash <- fcoalesce(g("F9_10_ASSET_CASH_SAVING_EOY"),
                    fifelse(is.na(g("F9_10_ASSET_CASH_EOY")) & is.na(g("F9_10_ASSET_SAVING_EOY")), NA_real_,
                            fcoalesce(g("F9_10_ASSET_CASH_EOY"), 0) + fcoalesce(g("F9_10_ASSET_SAVING_EOY"), 0)))
  bound <- function(v, lo, hi) pmin(pmax(v, lo), hi)
  out <- data.table(EIN2 = x$EIN2, TAX_YEAR = as.integer(x$TAX_YEAR), OBJECTID = x$OBJECTID,
                    RETURN_TYPE = x$RETURN_TYPE, EZ = x$EZ, NAME = chr("ORG_NAME_L1"),
                    STATE = chr("F9_00_ORG_ADDR_STATE"),
                    FORMATION_YEAR = suppressWarnings(as.integer(chr("F9_00_YEAR_FORMATION"))),
                    FINAL_RETURN = sn_flag(chr("F9_00_RETURN_FINAL_X"), FALSE),
                    REVENUE = x$REVENUE, EXPENSES = x$EXPENSES, ASSETS = x$ASSETS, LIABILITIES = x$LIABILITIES,
                    NET_ASSETS = x$NET_ASSETS, CASH = cash, SURPLUS = x$SURPLUS, STAFF_EXP = x$STAFF_EXP,
                    EMPLOYEES = x$EMPLOYEES)
  out[, `:=`(REAL_REVENUE = real_dollars(REVENUE, TAX_YEAR, base_year),
             REAL_EXPENSES = real_dollars(EXPENSES, TAX_YEAR, base_year),
             REAL_ASSETS = real_dollars(ASSETS, TAX_YEAR, base_year),
             MARGIN = fifelse(REVENUE > 0, bound(SURPLUS / REVENUE, -1, 1), NA_real_),
             EQUITY_RATIO = fifelse(ASSETS > 0, bound(NET_ASSETS / ASSETS, -1, 1), NA_real_),
             MONTHS_CASH = fifelse(EXPENSES > 0, bound(CASH / (EXPENSES / 12), 0, 120), NA_real_))]
  tr <- .bmf_traits(bmf)
  if (!is.null(tr)) {
    out <- merge(out, tr[, list(EIN2, NTEE, SUBSECTION)], by = "EIN2", all.x = TRUE, sort = FALSE)
  } else out[, `:=`(NTEE = NA_character_, SUBSECTION = NA_character_)]
  out[, `:=`(NTEE2 = ntee_level(NTEE, 2L), NTEE_MAJOR = ntee_level(NTEE, 1L))]
  data.table::setkeyv(out, c("EIN2", "TAX_YEAR"))
  out[]
}

# ---- windows and baselines -----------------------------------------------------

# For (EIN2, YEAR) pairs, TRUE when the panel has a return in every year YEAR + offsets.
.has_window <- function(ids, panel, offsets) {
  key <- unique(panel[, list(EIN2, TAX_YEAR)])
  data.table::setkeyv(key, c("EIN2", "TAX_YEAR"))
  ok <- rep(TRUE, nrow(ids))
  for (o in offsets) {
    q <- data.table(EIN2 = ids$EIN2, TAX_YEAR = as.integer(ids$YEAR + o))
    ok <- ok & !is.na(key[q, on = c("EIN2", "TAX_YEAR"), which = TRUE, mult = "first"])
  }
  ok
}

.baseline_vars <- c("REAL_ASSETS", "REAL_EXPENSES", "REAL_REVENUE", "MARGIN", "EQUITY_RATIO", "MONTHS_CASH", "EMPLOYEES")

# Baseline: mean of each variable over YEAR - years_back (years present only),
# requiring a return in YEAR - min(years_back).
.baseline <- function(ids, panel, years_back = 2:3, vars = .baseline_vars) {
  ids <- data.table(EIN2 = ids$EIN2, YEAR = as.integer(ids$YEAR))
  ids <- unique(ids)
  long <- rbindlist(lapply(years_back, function(b) ids[, list(EIN2, YEAR, TAX_YEAR = YEAR - b, BACK = b)]))
  long <- merge(long, panel[, c("EIN2", "TAX_YEAR", vars), with = FALSE], by = c("EIN2", "TAX_YEAR"))
  out <- long[, c(list(N_BASE = .N, HAS_FIRST = any(BACK == min(years_back))),
                  lapply(.SD, function(v) if (all(is.na(v))) NA_real_ else mean(v, na.rm = TRUE))),
              by = list(EIN2, YEAR), .SDcols = vars]
  out <- merge(ids, out, by = c("EIN2", "YEAR"), all.x = TRUE)
  out[is.na(N_BASE), `:=`(N_BASE = 0L, HAS_FIRST = FALSE)]
  out[]
}

# ---- research sample -----------------------------------------------------------

#' Research sample of mergers with a full observation window
#'
#' Keeps merger cases of the given types whose **recipient** filed a return
#' in every year from `-pre` to `+post` around its merger year (on its own
#' fiscal calendar), and adds baseline measures for both organizations,
#' averaged over the years `years_back` before the merger (years present
#' only; the year `-min(years_back)` is required for the baseline to
#' count). Donors cannot be observed after the merger, so the donor window
#' is reported (`DONOR_PRE_OK`: returns in every year `-pre` to `-1`) but
#' not required.
#'
#' @param cases Merger cases ([build_merger_cases()], the `cases` element of
#'   [build_merger_data()]).
#' @param panel Full 990 panel ([get_panel()]).
#' @param types Merger types to keep.
#' @param pre,post Years required before and after the recipient's merger year.
#' @param years_back Years before the merger used for the baseline.
#' @return A list with:
#'   * `sample`: one row per case, with `R_*` (recipient) and `D_*` (donor)
#'     baseline measures, `R_NTEE`, `R_NTEE2`, `DONOR_PRE_OK`, and
#'     `R_OTHER_EVENTS` (other merger cases involving the recipient within
#'     the window);
#'   * `baseline`: the underlying organization-years (donor and recipient at
#'     each of `years_back`), long format;
#'   * `treated`: one row per recipient and merger year, the units to match.
#' @export
merger_sample <- function(cases, panel, types = "merger2", pre = 2L, post = 2L, years_back = 2:3) {
  cs <- as.data.table(cases)
  allc <- cs
  cs <- cs[TYPE %in% types & !is.na(RECIP_EIN2)]
  cs[, RY := fcoalesce(as.integer(RECIP_MERGER_YEAR), as.integer(MERGER_YEAR))]
  cs[, R_WINDOW_OK := .has_window(data.table(EIN2 = RECIP_EIN2, YEAR = RY), panel, seq.int(-pre, post))]
  cs[, DONOR_PRE_OK := .has_window(data.table(EIN2 = DONOR_EIN2, YEAR = MERGER_YEAR), panel, seq.int(-pre, -1L))]
  s <- cs[R_WINDOW_OK == TRUE]
  rb <- .baseline(data.table(EIN2 = s$RECIP_EIN2, YEAR = s$RY), panel, years_back)
  db <- .baseline(data.table(EIN2 = s$DONOR_EIN2, YEAR = s$MERGER_YEAR), panel, years_back)
  pref <- function(b, p) { data.table::setnames(b, setdiff(names(b), c("EIN2", "YEAR")), paste0(p, setdiff(names(b), c("EIN2", "YEAR")))); b }
  s <- merge(s, pref(rb, "R_"), by.x = c("RECIP_EIN2", "RY"), by.y = c("EIN2", "YEAR"), all.x = TRUE, sort = FALSE)
  s <- merge(s, pref(db, "D_"), by.x = c("DONOR_EIN2", "MERGER_YEAR"), by.y = c("EIN2", "YEAR"), all.x = TRUE, sort = FALSE)
  nt <- unique(panel[, list(EIN2, NTEE, SUBSECTION = if ("SUBSECTION" %in% names(panel)) SUBSECTION else NA_character_)], by = "EIN2")
  s[, R_NTEE := nt$NTEE[match(RECIP_EIN2, nt$EIN2)]][, R_NTEE2 := ntee_level(R_NTEE, 2L)]
  s[, R_SUBSECTION := nt$SUBSECTION[match(RECIP_EIN2, nt$EIN2)]]
  s[, D_NTEE := nt$NTEE[match(DONOR_EIN2, nt$EIN2)]]
  # other merger cases (any type) involving the recipient within its window
  ev <- unique(rbind(allc[, list(EIN2 = RECIP_EIN2, Y = as.integer(fcoalesce(as.integer(RECIP_MERGER_YEAR), as.integer(MERGER_YEAR))), MERGER_ID)],
                     allc[, list(EIN2 = DONOR_EIN2, Y = as.integer(MERGER_YEAR), MERGER_ID)]))
  oth <- merge(s[, list(MERGER_ID, EIN2 = RECIP_EIN2, RY)], ev, by = "EIN2", allow.cartesian = TRUE, suffixes = c("", "_O"))
  oth <- oth[MERGER_ID != MERGER_ID_O & Y >= RY - pre & Y <= RY + post, list(R_OTHER_EVENTS = uniqueN(MERGER_ID_O)), by = MERGER_ID]
  s[, R_OTHER_EVENTS := fcoalesce(oth$R_OTHER_EVENTS[match(MERGER_ID, oth$MERGER_ID)], 0L)]
  data.table::setnames(s, "RY", "MATCH_YEAR")
  keep <- c("MERGER_ID", "MERGER_GROUP_ID", "TYPE", "BASIS", "AFFILIATED", "DONOR_EIN2", "RECIP_EIN2", "MERGER_YEAR",
            "MATCH_YEAR", "DONOR_PRE_OK", "R_OTHER_EVENTS", "R_NTEE", "R_NTEE2", "R_SUBSECTION", "D_NTEE",
            grep("^(R|D)_(N_BASE|HAS_FIRST|REAL_|MARGIN|EQUITY|MONTHS|EMPLOYEES)", names(s), value = TRUE))
  s <- s[, intersect(keep, names(s)), with = FALSE][order(MATCH_YEAR, RECIP_EIN2)]

  bl <- rbindlist(lapply(years_back, function(b) rbind(
    s[, list(MERGER_ID, ROLE = "recipient", EIN2 = RECIP_EIN2, TAX_YEAR = MATCH_YEAR - b, TIME_FROM_MERGER = -b)],
    s[, list(MERGER_ID, ROLE = "donor", EIN2 = DONOR_EIN2, TAX_YEAR = MERGER_YEAR - b, TIME_FROM_MERGER = -b)])))
  bl <- merge(bl, panel, by = c("EIN2", "TAX_YEAR"))
  data.table::setcolorder(bl, c("MERGER_ID", "ROLE", "EIN2", "TAX_YEAR", "TIME_FROM_MERGER"))
  data.table::setorderv(bl, c("MERGER_ID", "ROLE", "TAX_YEAR"))

  tr <- s[R_HAS_FIRST == TRUE, c(list(T_ID = paste(MATCH_YEAR[1], RECIP_EIN2[1], sep = "-"), N_CASES = .N,
                                      MERGER_IDS = paste(MERGER_ID, collapse = ";")),
                                 lapply(.SD, `[`, 1L)),
          by = list(EIN2 = RECIP_EIN2, YEAR = MATCH_YEAR),
          .SDcols = c("R_NTEE", "R_NTEE2", "R_SUBSECTION", grep("^R_(REAL_|MARGIN|EQUITY|MONTHS|EMPLOYEES)", names(s), value = TRUE))]
  data.table::setnames(tr, names(tr), sub("^R_", "", names(tr)))
  list(sample = s[], baseline = bl[], treated = tr[])
}

# ---- candidate pool and matching -------------------------------------------------

#' Pool of potential comparison organization-years
#'
#' Every organization-year `YEAR` in the panel for which the organization
#' filed a return in each year `YEAR - pre` to `YEAR + post` and has a
#' baseline (the same `years_back` average used for merger recipients). An
#' organization-year is dropped when the organization was involved in a
#' Schedule N event (as filer or named recipient) within `exclude_window`
#' years of `YEAR`.
#'
#' @param panel Full 990 panel ([get_panel()]).
#' @param events Schedule N involvement: a table with `EIN2` and `TAX_YEAR`
#'   (filers from `sched_n`, plus recipient EINs from `transactions`). See
#'   [schedule_n_events()].
#' @param pre,post,years_back As in [merger_sample()].
#' @param exclude_window Offsets around `YEAR` in which an event disqualifies
#'   an organization-year.
#' @return A data.table: `EIN2`, `YEAR`, baseline measures, `NTEE`, `NTEE2`.
#' @export
match_pool <- function(panel, events = NULL, pre = 2L, post = 2L, years_back = 2:3, exclude_window = -3:2) {
  ids <- unique(panel[, list(EIN2, YEAR = TAX_YEAR)])
  ids <- ids[.has_window(ids, panel, seq.int(-pre, post))]
  if (!is.null(events) && nrow(events)) {
    ev <- unique(as.data.table(events)[, list(EIN2, TAX_YEAR = as.integer(TAX_YEAR))])
    bad <- unique(rbindlist(lapply(exclude_window, function(o) ev[, list(EIN2, YEAR = TAX_YEAR - o)])))
    ids <- ids[!bad, on = c("EIN2", "YEAR")]
  }
  b <- .baseline(ids, panel, years_back)
  b <- b[HAS_FIRST == TRUE]
  nt <- unique(panel[, list(EIN2, NTEE, SUBSECTION = if ("SUBSECTION" %in% names(panel)) SUBSECTION else NA_character_)], by = "EIN2")
  b[, NTEE := nt$NTEE[match(EIN2, nt$EIN2)]][, NTEE2 := ntee_level(NTEE, 2L)]
  b[, SUBSECTION := nt$SUBSECTION[match(EIN2, nt$EIN2)]]
  b[, HAS_FIRST := NULL]
  data.table::setkeyv(b, c("EIN2", "YEAR"))
  b[]
}

#' Schedule N involvement by organization and year
#'
#' @param sched_n The `sched_n` table (filers).
#' @param transactions The `transactions` table (named recipients).
#' @return A data.table of unique `EIN2`, `TAX_YEAR`.
#' @export
schedule_n_events <- function(sched_n, transactions = NULL) {
  a <- as.data.table(sched_n)[, list(EIN2, TAX_YEAR = as.integer(TAX_YEAR))]
  if (!is.null(transactions)) {
    tx <- as.data.table(transactions)
    b <- tx[!is.na(RECIP_EIN), list(EIN2 = as_ein2(RECIP_EIN), TAX_YEAR = as.integer(TAX_YEAR))]
    a <- rbind(a, b)
  }
  unique(a[!is.na(EIN2)])
}

#' Find match candidates for merger recipients
#'
#' For each treated unit (a merger recipient in its merger year), returns
#' every pool organization-year in the same NTEE group whose baseline size
#' and financial condition fall within the calipers, ranked by a
#' standardized distance. Calendar years need not coincide: a 2015 merger
#' can be matched to a 2019 comparison year. Dollar measures are in
#' constant dollars, and sizes are compared in logs.
#'
#' @param treated `treated` element of [merger_sample()].
#' @param pool Output of [match_pool()].
#' @param ntee_chars NTEE characters that must agree (2 = letter and first
#'   digit, e.g. `"E2"`; 3 = full code).
#' @param size Size measures (constant-dollar columns), compared as `log1p`.
#' @param health Profitability or fiscal-health measures: any of `"MARGIN"`,
#'   `"EQUITY_RATIO"`, `"MONTHS_CASH"`.
#' @param size_caliper Maximum absolute difference in log size (for each
#'   size measure); `log(2)` allows up to a factor of two.
#' @param health_caliper Maximum absolute difference for each health measure
#'   (named numeric, or one value for all).
#' @param max_year_gap Optional maximum `|YEAR - C_YEAR|`.
#' @return A data.table, one row per treated unit and candidate: `T_ID`,
#'   `T_EIN2`, `T_YEAR`, `C_EIN2`, `C_YEAR`, `YEAR_GAP`, `SAME_SUBSECTION`, the differences
#'   (`D_*`), `DIST` (root mean square of differences scaled by the pool's
#'   standard deviations), and `RANK` (1 = closest).
#' @export
match_candidates <- function(treated, pool, ntee_chars = 2L, size = c("REAL_ASSETS", "REAL_EXPENSES"),
                             health = "MARGIN", size_caliper = log(2),
                             health_caliper = c(MARGIN = 0.10, EQUITY_RATIO = 0.15, MONTHS_CASH = 3),
                             max_year_gap = Inf) {
  tr <- as.data.table(treated); pl <- as.data.table(pool)
  hc <- if (is.null(names(health_caliper))) stats::setNames(rep(health_caliper, length(health)), health) else health_caliper[health]
  if (anyNA(hc)) stop("No caliper for: ", paste(health[is.na(hc)], collapse = ", "), call. = FALSE)
  prep <- function(x) {
    x <- data.table::copy(x)
    x[, NKEY := ntee_level(NTEE, ntee_chars)]
    for (v in size) x[, (paste0("L_", v)) := log1p(pmax(get(v), 0))]
    x[!is.na(NKEY) & stats::complete.cases(x[, c(paste0("L_", size), health), with = FALSE])]
  }
  tr <- prep(tr); pl <- prep(pl)
  vars <- c(paste0("L_", size), health)
  sds <- vapply(vars, function(v) stats::sd(pl[[v]]), numeric(1))
  l1 <- paste0("L_", size[1])
  tr[, `:=`(LO_ = get(l1) - size_caliper, HI_ = get(l1) + size_caliper)]
  pl[, C1_ := get(l1)]
  out <- rbindlist(lapply(split(tr, by = "NKEY"), function(t) {
    p <- pl[NKEY == t$NKEY[1]]
    if (!nrow(p)) return(NULL)
    t[, TROW_ := .I]; p[, PROW_ := .I]
    ix <- p[t, on = list(C1_ >= LO_, C1_ <= HI_), nomatch = NULL, allow.cartesian = TRUE,
            list(ti = i.TROW_, ci = x.PROW_)]
    if (!nrow(ix)) return(NULL)
    a <- t[ix$ti]; b <- p[ix$ci]
    keep <- a$EIN2 != b$EIN2 & abs(a$YEAR - b$YEAR) <= max_year_gap
    for (v in size[-1]) keep <- keep & abs(a[[paste0("L_", v)]] - b[[paste0("L_", v)]]) <= size_caliper
    for (h in health) keep <- keep & abs(a[[h]] - b[[h]]) <= hc[[h]]
    if (!any(keep)) return(NULL)
    a <- a[keep]; b <- b[keep]
    j <- data.table(T_ID = a$T_ID, T_EIN2 = a$EIN2, T_YEAR = a$YEAR, C_EIN2 = b$EIN2, C_YEAR = b$YEAR, NTEE_KEY = a$NKEY,
                    SAME_SUBSECTION = if ("SUBSECTION" %in% names(a) && "SUBSECTION" %in% names(b)) a$SUBSECTION == b$SUBSECTION else NA)
    for (v in vars) data.table::set(j, j = paste0("D_", v), value = a[[v]] - b[[v]])
    j
  }))
  if (!nrow(out)) return(out)
  out[, YEAR_GAP := C_YEAR - T_YEAR]
  z <- Reduce(`+`, lapply(vars, function(v) (out[[paste0("D_", v)]] / sds[[v]])^2))
  out[, DIST := sqrt(z / length(vars))]
  data.table::setorderv(out, c("T_ID", "DIST"))
  out[, RANK := seq_len(.N), by = T_ID]
  attr(out, "settings") <- list(ntee_chars = ntee_chars, size = size, health = health, size_caliper = size_caliper,
                                health_caliper = hc, sd = sds)
  out[]
}

#' Covariate balance of a matched sample
#'
#' Standardized mean differences between treated units and their `k`
#' closest candidates (each candidate weighted `1 / k_i`), and between
#' treated units and the whole pool in the same NTEE groups.
#'
#' @param treated,pool,candidates As in [match_candidates()].
#' @param k Candidates per treated unit.
#' @param vars Baseline variables to compare.
#' @return A data.table with means and standardized differences.
#' @export
match_balance <- function(treated, pool, candidates, k = 1L,
                          vars = c("REAL_ASSETS", "REAL_EXPENSES", "REAL_REVENUE", "MARGIN", "EQUITY_RATIO", "MONTHS_CASH")) {
  tr <- as.data.table(treated); pl <- as.data.table(pool); cd <- as.data.table(candidates)[RANK <= k]
  lg <- function(x) { for (v in grep("^REAL_", vars, value = TRUE)) x[, (v) := log1p(pmax(get(v), 0))]; x }
  trm <- lg(data.table::copy(tr[T_ID %in% cd$T_ID]))
  mt <- merge(cd[, list(T_ID, EIN2 = C_EIN2, YEAR = C_YEAR)], pl, by = c("EIN2", "YEAR"))
  mt[, W := 1 / .N, by = T_ID]; mt <- lg(mt)
  pr <- lg(data.table::copy(pl[NTEE2 %in% tr$NTEE2]))
  rbindlist(lapply(vars, function(v) {
    sdv <- sqrt((stats::var(trm[[v]], na.rm = TRUE) + stats::var(pr[[v]], na.rm = TRUE)) / 2)
    m_t <- mean(trm[[v]], na.rm = TRUE)
    m_c <- stats::weighted.mean(mt[[v]], mt$W, na.rm = TRUE)
    m_p <- mean(pr[[v]], na.rm = TRUE)
    data.table(VAR = if (startsWith(v, "REAL_")) paste0("log ", v) else v, TREATED = m_t, MATCHED = m_c, POOL = m_p,
               SMD_MATCHED = (m_t - m_c) / sdv, SMD_POOL = (m_t - m_p) / sdv)
  }))
}

utils::globalVariables(c("NTEE", "NTEE2", "NTEE_MAJOR", "REAL_REVENUE", "REAL_EXPENSES", "REAL_ASSETS", "MARGIN",
                         "EQUITY_RATIO", "MONTHS_CASH", "CASH", "NET_ASSETS", "ASSETS", "YEAR", "BACK", "N_BASE",
                         "HAS_FIRST", "RY", "R_WINDOW_OK", "DONOR_PRE_OK", "RECIP_EIN2", "DONOR_EIN2", "MERGER_YEAR",
                         "RECIP_MERGER_YEAR", "MERGER_ID", "MERGER_ID_O", "Y", "R_OTHER_EVENTS", "R_NTEE", "R_NTEE2",
                         "D_NTEE", "MATCH_YEAR", "R_HAS_FIRST", "T_ID", "NKEY", "LO_", "HI_", "C1_", "i.T_ID", "i.EIN2",
                         "i.YEAR", "x.EIN2", "x.YEAR", "x.NKEY", "T_EIN2", "T_YEAR", "C_EIN2", "C_YEAR", "YEAR_GAP",
                         "DIST", "RANK", "W", "RECIP_EIN", "TYPE", "TROW_", "PROW_", "i.TROW_", "x.PROW_", "SUBSECTION", "R_SUBSECTION", "SAME_SUBSECTION"))
