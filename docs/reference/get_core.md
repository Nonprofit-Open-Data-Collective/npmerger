# Retrieve core 990 tables for a set of organizations

Downloads (or reuses cached) core tables and reads only the rows for the
requested organizations, pushing the EIN filter into the parquet scan.
990-EZ filers are included: their revenue and expenses are in the
summary table and their balance sheet in the Part X table.

## Usage

``` r
get_core(
  eins,
  years,
  which = names(core_tables()),
  path = "PANEL990",
  source = panel990::data_source(),
  verbose = TRUE,
  ...
)
```

## Arguments

- eins:

  EINs (any format accepted by
  [`clean_ein()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/clean_ein.md)).

- years:

  Tax years.

- which:

  Names of
  [`core_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/core_tables.md)
  to read.

- path, source, verbose:

  Passed to
  [`panel990::download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.html).

- ...:

  Further arguments to
  [`panel990::download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.html).

## Value

A list of class `merger_core` holding one data.table per table.
