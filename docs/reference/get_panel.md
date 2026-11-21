# Build the full 990 organization-year panel

Reads the header, summary, expenses, and balance-sheet tables for
**every** 990 and 990-EZ filer in `years` (only the columns in
[`panel_columns()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_columns.md)),
keeps one return per organization-year
([`org_years()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/org_years.md)),
and returns the slim matching panel from
[`panel_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_measures.md).
This is the pool that merger recipients are matched against.

## Usage

``` r
get_panel(
  years = efile_years(),
  path = "PANEL990",
  source = panel990::data_source(),
  verbose = TRUE,
  bmf = TRUE,
  base_year = 2024L
)
```

## Arguments

- years:

  Tax years.

- path, source, verbose:

  Passed to
  [`panel990::download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.html).

- bmf:

  Add NTEE codes from the BMF
  ([`get_bmf()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_bmf.md)):
  `TRUE`, `FALSE`, or a BMF table you already have.

- base_year:

  Year of the dollars in the `REAL_*` columns.

## Value

A data.table keyed by `EIN2`, `TAX_YEAR`; see
[`panel_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_measures.md).
