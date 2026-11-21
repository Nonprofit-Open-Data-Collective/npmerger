#' Schedule N table names in the NCCS efile release
#'
#' @return A named character vector (short name = canonical table).
#' @export
#' @examples
#' sn_table_names()
sn_table_names <- function() {
  c(
    p1_header = "SN-P01-T00-LIQUIDATION-TERMINATION-DISSOLUTION",
    p1_assets = "SN-P01-T01-LIQUIDATION-TERMINATION-DISSOLUTION",
    p2_header = "SN-P02-T00-DISPOSITION-OF-ASSETS",
    p2_assets = "SN-P02-T01-DISPOSITION-OF-ASSETS",
    p3_text   = "SN-P03-T99-SUPPLEMENTAL-INFO"
  )
}

#' Retrieve Schedule N tables
#'
#' Downloads (or reuses cached) Schedule N tables for the requested tax years
#' through [panel990::download_tables()] and stacks each table across years.
#' Schedule N files are small (about 1 MB per year in total).
#'
#' @param years Integer tax years.
#' @param path Cache directory passed to [panel990::download_tables()].
#' @param source A [panel990::data_source()] configuration.
#' @param verbose Print progress.
#' @param ... Further arguments to [panel990::download_tables()].
#' @return A list of class `sn_raw` with data.tables `p1_header`,
#'   `p1_assets`, `p2_header`, `p2_assets`, `p3_text`, plus `years` and the
#'   download `manifest`.
#' @export
#' @examples
#' \dontrun{
#' sn <- get_schedule_n(2019:2021)
#' }
get_schedule_n <- function(years, path = "PANEL990", source = panel990::data_source(),
                           verbose = TRUE, ...) {
  tabs <- sn_table_names()
  dl <- panel990::download_tables(years = years, tables = unname(tabs), source = source,
                                  path = path, verbose = verbose, ...)
  rd <- panel990::read_tables(dl, verbose = verbose)
  tbl_of <- sub("::[0-9]+$", "", names(rd$tables))
  out <- lapply(tabs, function(t) {
    x <- rbindlist(lapply(rd$tables[tbl_of == t], as.data.table), fill = TRUE)
    if ("TAX_YEAR" %in% names(x)) x[, TAX_YEAR := as.integer(TAX_YEAR)]
    x
  })
  names(out) <- names(tabs)
  structure(c(out, list(years = years, manifest = rd$manifest)), class = c("sn_raw", "list"))
}

#' @export
print.sn_raw <- function(x, ...) {
  cat("<sn_raw> Schedule N tables, tax years", paste(range(x$years), collapse = "-"), "\n")
  for (nm in names(sn_table_names())) cat(sprintf("  %-10s %7d rows\n", nm, nrow(x[[nm]])))
  invisible(x)
}

