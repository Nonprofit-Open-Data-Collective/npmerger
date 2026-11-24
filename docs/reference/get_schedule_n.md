# Retrieve Schedule N tables

Downloads (or reuses cached) Schedule N tables for the requested tax
years through
[`panel990::download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.html)
and stacks each table across years. Schedule N files are small (about 1
MB per year in total).

## Usage

``` r
get_schedule_n(
  years,
  path = "PANEL990",
  source = panel990::data_source(),
  verbose = TRUE,
  ...
)
```

## Arguments

- years:

  Integer tax years.

- path:

  Cache directory passed to
  [`panel990::download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.html).

- source:

  A
  [`panel990::data_source()`](https://nonprofit-open-data-collective.github.io/panel990/reference/data_source.html)
  configuration.

- verbose:

  Print progress.

- ...:

  Further arguments to
  [`panel990::download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.html).

## Value

A list of class `sn_raw` with data.tables `p1_header`, `p1_assets`,
`p2_header`, `p2_assets`, `p3_text`, plus `years` and the download
`manifest`.

## Examples

``` r
if (FALSE) { # \dontrun{
sn <- get_schedule_n( 2019:2021 )
} # }
```
