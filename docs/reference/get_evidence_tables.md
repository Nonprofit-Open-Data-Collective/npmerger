# Retrieve the evidence tables for a set of Schedule N filings

Downloads (or reuses cached) evidence tables for the years around the
filings, then reads only the rows for the donors and recipients involved
and only the columns in
[`evidence_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/evidence_tables.md).
The EIN filter and column projection are pushed into the parquet scan.

## Usage

``` r
get_evidence_tables(
  fl,
  years = NULL,
  which = names(evidence_tables()),
  path = "PANEL990",
  source = panel990::data_source(),
  verbose = TRUE,
  ...
)
```

## Arguments

- fl:

  Filing table from
  [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md).

- years:

  Tax years to read. Default: one year before the earliest filing to one
  year after the latest.

- which:

  Names of
  [`evidence_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/evidence_tables.md)
  to retrieve.

- path, source, verbose:

  Passed to
  [`panel990::download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.html).

- ...:

  Further arguments to
  [`panel990::download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.html).

## Value

A named list of data.tables (one per element of `which`).

## Details

These tables are large (Schedule O is about 150 MB per year, Part VII
about 100 MB), so the first run downloads several hundred MB per year;
later runs reuse the cache at `path`.
