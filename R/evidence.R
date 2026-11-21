#' Evidence tables and the columns read from each
#'
#' The 990 tables [get_evidence_tables()] reads for the donors and recipients
#' in a set of Schedule N filings, and the columns kept from each.
#'
#' @return A named list; each element has `table` (canonical NCCS efile
#'   table name) and `columns`.
#' @export
#' @examples
#' names(evidence_tables())
evidence_tables <- function() {
  k <- c("EIN2", "OBJECTID", "TAX_YEAR")
  list(
    header  = list(table = "F9-P00-T00-HEADER",
                   columns = c(k, "RETURN_TYPE", "RETURN_TIME_STAMP", "TAX_PERIOD_BEGIN_DATE", "TAX_PERIOD_END_DATE",
                               "F9_00_RETURN_FINAL_X", "F9_00_RETURN_INITIAL_X",
                               "F9_00_YEAR_FORMATION", "F9_00_GROUP_EXEMPT_NUM")),
    p7      = list(table = "F9-P07-T01-COMPENSATION", columns = c(k, "F9_07_COMP_DTK_NAME_PERS", "F9_07_COMP_DTK_TITLE")),
    p6      = list(table = "F9-P06-T00-GOVERNANCE", columns = c(k, "F9_06_GVRN_CHANGE_DOC_X")),
    so      = list(table = "SO-P00-T99-SUPPLEMENTAL-INFO", columns = c(k, "SO_00_EXPLANATION_TEXT")),
    sr      = list(table = "SR-P02-T01-ID-RLTD-TAX-EXEMPED-ORGS", columns = c(k, "SR_02_RLTD_ORG_EIN")),
    sa      = list(table = "SA-P01-T00-PUBLIC-CHARITY-STATUS", columns = c(k, "SA_01_PCSTAT_SUPPORT_ORG_X")),
    mission = list(table = "F9-P03-T00-MISSION", columns = c(k, "F9_03_ORG_MISSION_PURPOSE"))
  )
}

#' Retrieve the evidence tables for a set of Schedule N filings
#'
#' Downloads (or reuses cached) evidence tables for the years around the
#' filings, then reads only the rows for the donors and recipients involved
#' and only the columns in [evidence_tables()]. The EIN filter and column
#' projection are pushed into the parquet scan.
#'
#' These tables are large (Schedule O is about 150 MB per year, Part VII
#' about 100 MB), so the first run downloads several hundred MB per year;
#' later runs reuse the cache at `path`.
#'
#' @param fl Filing table from [sn_filings()].
#' @param years Tax years to read. Default: one year before the earliest
#'   filing to one year after the latest.
#' @param which Names of [evidence_tables()] to retrieve.
#' @param path,source,verbose Passed to [panel990::download_tables()].
#' @param ... Further arguments to [panel990::download_tables()].
#' @return A named list of data.tables (one per element of `which`).
#' @export
get_evidence_tables <- function(fl, years = NULL, which = names(evidence_tables()),
                                path = "PANEL990", source = panel990::data_source(),
                                verbose = TRUE, ...) {
  fl <- .with_recip_ein2(fl)
  if (is.null(years)) years <- seq(min(fl$TAX_YEAR) - 1L, max(fl$TAX_YEAR) + 1L)
  eins <- unique(stats::na.omit(c(fl$EIN2, fl$RECIP_EIN2)))
  spec <- evidence_tables()[which]
  out <- lapply(names(spec), function(nm) {
    s <- spec[[nm]]
    if (verbose) message("Evidence table '", nm, "' (", s$table, ")")
    dl <- panel990::download_tables(years = years, tables = s$table, source = source,
                                    path = path, verbose = verbose, ...)
    rd <- panel990::read_tables(dl, columns = s$columns, filters = list(EIN2 = eins),
                                unique_rows = FALSE, verbose = FALSE)
    x <- rbindlist(lapply(rd$tables, as.data.table), fill = TRUE)
    if ("TAX_YEAR" %in% names(x)) x[, TAX_YEAR := as.integer(TAX_YEAR)]
    x
  })
  names(out) <- names(spec)
  out
}

#' Add all merger evidence to a filing table
#'
#' Applies [leader_overlap()], [add_donor_counts()], [add_filing_history()],
#' [add_corroboration()], [add_affiliation()], and [add_mission_similarity()]
#' using whichever evidence tables are present. The result is ready for
#' [classify_transactions()].
#'
#' @param fl Filing table from [sn_filings()].
#' @param evidence List from [get_evidence_tables()].
#' @param rules A [merger_rules()] object (uses `min_top_share` and
#'   `new_entity_years`).
#' @param donor_window Years either side for counting donors to one successor.
#' @return The filing table with evidence columns added.
#' @export
#' @examples
#' \dontrun{
#' sn  <- get_schedule_n(2019:2021)
#' fl  <- sn_filings(sn)
#' ev  <- get_evidence_tables(fl)
#' lab <- classify_transactions(merger_features(fl, ev))
#' }
merger_features <- function(fl, evidence, rules = merger_rules(), donor_window = 1L) {
  ev <- evidence
  fl <- .with_recip_ein2(fl)
  if (!is.null(ev$p7)) fl <- leader_overlap(fl, ev$p7)
  if (!is.null(ev$header)) fl <- add_filing_history(fl, ev$header, new_entity_years = rules$new_entity_years)
  fl <- add_donor_counts(fl, window = donor_window, min_top_share = rules$min_top_share,
                         final_as_termination = rules$final_as_termination %||% TRUE)
  if (!is.null(ev$so) || !is.null(ev$p6)) fl <- add_corroboration(fl, so = ev$so, p6 = ev$p6)
  fl <- add_affiliation(fl, sr = ev$sr, sa = ev$sa, header = ev$header)
  if (!is.null(ev$mission)) fl <- add_mission_similarity(fl, ev$mission)
  fl[]
}
