#' Core 990 tables read for merger organizations
#'
#' @return A named list; each element has `table` (canonical NCCS efile table
#'   name). All columns are read (the financial tables feed 'fiscal').
#' @export
#' @examples
#' names(core_tables())
core_tables <- function() {
  list(
    header   = list(table = "F9-P00-T00-HEADER"),
    summary  = list(table = "F9-P01-T00-SUMMARY"),
    revenue  = list(table = "F9-P08-T00-REVENUE"),
    expenses = list(table = "F9-P09-T00-EXPENSES"),
    balance  = list(table = "F9-P10-T00-BALANCE-SHEET"),
    p7       = list(table = "F9-P07-T01-COMPENSATION")
  )
}

#' Retrieve core 990 tables for a set of organizations
#'
#' Downloads (or reuses cached) core tables and reads only the rows for the
#' requested organizations, pushing the EIN filter into the parquet scan.
#' 990-EZ filers are included: their revenue and expenses are in the summary
#' table and their balance sheet in the Part X table.
#'
#' @param eins EINs (any format accepted by [clean_ein()]).
#' @param years Tax years.
#' @param which Names of [core_tables()] to read.
#' @param path,source,verbose Passed to [panel990::download_tables()].
#' @param ... Further arguments to [panel990::download_tables()].
#' @return A list of class `merger_core` holding one data.table per table.
#' @export
get_core <- function(eins, years, which = names(core_tables()), path = "PANEL990",
                     source = panel990::data_source(), verbose = TRUE, ...) {
  eins <- unique(stats::na.omit(as_ein2(eins)))
  spec <- core_tables()[which]
  out <- lapply(names(spec), function(nm) {
    if (verbose) message("Core table '", nm, "' (", spec[[nm]]$table, ")")
    dl <- panel990::download_tables(years = years, tables = spec[[nm]]$table, source = source,
                                    path = path, verbose = verbose, ...)
    ok <- dl$manifest$status %in% c("downloaded", "reused")
    if (!any(ok)) return(data.table())
    rd <- panel990::read_tables(dl, filters = list(EIN2 = eins), unique_rows = FALSE, verbose = FALSE)
    x <- rbindlist(lapply(rd$tables, as.data.table), fill = TRUE)
    if ("TAX_YEAR" %in% names(x)) x[, TAX_YEAR := as.integer(TAX_YEAR)]
    x
  })
  names(out) <- names(spec)
  structure(out, class = c("merger_core", "list"))
}

.base_cols <- c("EIN2", "OBJECTID", "ORG_EIN", "ORG_NAME_L1", "ORG_NAME_L2", "RETURN_AMENDED_X",
                "RETURN_GROUP_X", "RETURN_PARTIAL_X", "RETURN_TAXPER_DAYS", "RETURN_TIME_STAMP",
                "RETURN_TYPE", "TAX_PERIOD_BEGIN_DATE", "TAX_PERIOD_END_DATE", "TAX_YEAR", "URL", "VERSION")

#' One row per organization-year from core tables
#'
#' Joins the header, summary, revenue, expenses, and balance-sheet tables by
#' `OBJECTID` and keeps one return per organization and tax year (the most
#' recently filed, so amended returns replace originals). Adds the
#' harmonized measures from [merger_measures()].
#'
#' @param core A `merger_core` list from [get_core()].
#' @return A data.table keyed by `EIN2`, `TAX_YEAR`.
#' @export
org_years <- function(core) {
  parts <- Filter(function(x) !is.null(x) && nrow(x) > 0, core[intersect(c("header", "summary", "revenue", "expenses", "balance"), names(core))])
  if (!length(parts)) stop("`core` has no financial tables.", call. = FALSE)
  first <- as.data.table(parts[[1]])
  oy <- Reduce(function(a, b) {
    b <- as.data.table(b)
    b <- b[, c("OBJECTID", setdiff(names(b), c(.base_cols, names(a)))), with = FALSE]
    merge(a, b, by = "OBJECTID", all = TRUE)
  }, parts[-1], first)
  oy[, TAX_YEAR := as.integer(TAX_YEAR)]
  oy <- oy[!is.na(EIN2) & !is.na(TAX_YEAR)]
  data.table::setorderv(oy, c("EIN2", "TAX_YEAR", "RETURN_TIME_STAMP"), c(1L, 1L, -1L))
  oy <- oy[!duplicated(oy, by = c("EIN2", "TAX_YEAR"))]
  oy <- merger_measures(oy)
  data.table::setkeyv(oy, c("EIN2", "TAX_YEAR"))
  oy[]
}

#' Harmonized financial measures for 990 and 990-EZ filers
#'
#' Adds plain-named measures used by the attribute tables and the fiscal
#' panel. Revenue, expenses, assets, liabilities, net assets, grants, and
#' contributions are available for both 990 and 990-EZ filers. The
#' functional-expense breakdown (overhead), executive compensation,
#' employees, and debt detail come from the full Form 990 only and are `NA`
#' for 990-EZ filers.
#'
#' @param x An organization-year table (from [org_years()]).
#' @return `x` with measure columns added: `REVENUE`, `EXPENSES`, `SURPLUS`,
#'   `ASSETS`, `ASSETS_BOY`, `LIABILITIES`, `NET_ASSETS`, `DEBT`,
#'   `CONTRIBUTIONS`, `PROGRAM_REVENUE`, `NONCASH_CONTRIB`, `GRANTS`,
#'   `STAFF_EXP`, `EXEC_COMP`, `PROGRAM_EXP`, `MGMT_EXP`, `FUNDR_EXP`,
#'   `OVERHEAD_RATIO`, `EMPLOYEES`, and `EZ` (990-EZ return).
#' @export
merger_measures <- function(x) {
  x <- as.data.table(x)
  g <- function(...) { for (v in c(...)) if (v %in% names(x)) return(suppressWarnings(as.numeric(x[[v]]))); rep(NA_real_, nrow(x)) }
  s <- function(...) { m <- do.call(cbind, lapply(c(...), function(v) g(v))); out <- rowSums(m, na.rm = TRUE); out[rowSums(!is.na(m)) == 0] <- NA_real_; out }
  x[, `:=`(
    EZ              = RETURN_TYPE == "990EZ",
    REVENUE         = g("F9_01_REV_TOT_CY"),
    EXPENSES        = g("F9_01_EXP_TOT_CY", "F9_09_EXP_TOT_TOT"),
    ASSETS          = g("F9_10_ASSET_TOT_EOY", "F9_01_NAFB_ASSET_TOT_EOY"),
    ASSETS_BOY      = g("F9_10_ASSET_TOT_BOY", "F9_01_NAFB_ASSET_TOT_BOY"),
    LIABILITIES     = g("F9_10_LIAB_TOT_EOY", "F9_01_NAFB_LIAB_TOT_EOY"),
    NET_ASSETS      = g("F9_10_NAFB_TOT_EOY", "F9_01_NAFB_TOT_EOY"),
    DEBT            = s("F9_10_LIAB_MTG_NOTE_EOY", "F9_10_LIAB_NOTE_UNSEC_EOY", "F9_10_LIAB_TAX_EXEMPT_BOND_EOY", "F9_10_LIAB_LOAN_OFF_EOY"),
    CONTRIBUTIONS   = g("F9_01_REV_CONTR_TOT_CY", "F9_08_REV_CONTR_TOT"),
    PROGRAM_REVENUE = g("F9_01_REV_PROG_TOT_CY"),
    NONCASH_CONTRIB = g("F9_08_REV_CONTR_NONCSH"),
    GRANTS          = g("F9_01_EXP_GRANT_SIMILAR_CY"),
    STAFF_EXP       = g("F9_01_EXP_SAL_ETC_CY"),
    EXEC_COMP       = g("F9_09_EXP_COMP_DTK_TOT"),
    PROGRAM_EXP     = g("F9_09_EXP_TOT_PROG"),
    MGMT_EXP        = g("F9_09_EXP_TOT_MGMT"),
    FUNDR_EXP       = g("F9_09_EXP_TOT_FUNDR"),
    EMPLOYEES       = g("F9_01_ACT_GVRN_EMPL_TOT")
  )]
  x[, SURPLUS := REVENUE - EXPENSES]
  x[, OVERHEAD_RATIO := fifelse(!is.na(MGMT_EXP) & EXPENSES > 0, (MGMT_EXP + fcoalesce(FUNDR_EXP, 0)) / EXPENSES, NA_real_)]
  x[]
}

#' @export
print.merger_core <- function(x, ...) {
  cat("<merger_core>\n")
  for (nm in names(x)) cat(sprintf("  %-9s %8d rows  %4d cols\n", nm, nrow(x[[nm]]), ncol(x[[nm]])))
  invisible(x)
}

.measure_cols <- c("REVENUE", "EXPENSES", "SURPLUS", "ASSETS", "ASSETS_BOY", "LIABILITIES", "NET_ASSETS",
                   "DEBT", "CONTRIBUTIONS", "PROGRAM_REVENUE", "NONCASH_CONTRIB", "GRANTS", "STAFF_EXP",
                   "EXEC_COMP", "PROGRAM_EXP", "MGMT_EXP", "FUNDR_EXP", "OVERHEAD_RATIO", "EMPLOYEES")

utils::globalVariables(c("RETURN_TYPE", "RETURN_TIME_STAMP", "EZ", "REVENUE", "EXPENSES", "SURPLUS",
                         "MGMT_EXP", "FUNDR_EXP", "OVERHEAD_RATIO"))
