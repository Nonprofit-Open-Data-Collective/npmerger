# One row per organization-year from core tables

Joins the header, summary, revenue, expenses, and balance-sheet tables
by `OBJECTID` and keeps one return per organization and tax year (the
most recently filed, so amended returns replace originals). Adds the
harmonized measures from
[`merger_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_measures.md).

## Usage

``` r
org_years(core)
```

## Arguments

- core:

  A `merger_core` list from
  [`get_core()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_core.md).

## Value

A data.table keyed by `EIN2`, `TAX_YEAR`.
