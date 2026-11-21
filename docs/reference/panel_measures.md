# Slim matching measures for an organization-year table

Slim matching measures for an organization-year table

## Usage

``` r
panel_measures(oy, bmf = NULL, base_year = 2024L)
```

## Arguments

- oy:

  Organization-year table from
  [`org_years()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/org_years.md)
  (with the columns in
  [`panel_columns()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_columns.md)).

- bmf:

  Optional BMF table
  ([`get_bmf()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_bmf.md))
  for NTEE codes.

- base_year:

  Year of the dollars in the `REAL_*` columns.

## Value

A data.table with `EIN2`, `TAX_YEAR`, `OBJECTID`, `RETURN_TYPE`, `EZ`,
`NAME`, `STATE`, `FORMATION_YEAR`, `FINAL_RETURN`, size measures
(`REVENUE`, `EXPENSES`, `ASSETS`, `LIABILITIES`, `NET_ASSETS`, `CASH`,
`SURPLUS`, `STAFF_EXP`, `EMPLOYEES`), their constant-dollar versions
(`REAL_REVENUE`, `REAL_EXPENSES`, `REAL_ASSETS`), profitability and
fiscal-health ratios (`MARGIN` = surplus / revenue, `EQUITY_RATIO` = net
assets / assets, `MONTHS_CASH` = cash and savings / monthly expenses),
`NTEE`, `NTEE2`, `NTEE_MAJOR`, and `SUBSECTION` (IRC 501(c) subsection,
from the BMF). Ratios are bounded to -1, 1 (months of cash to 0, 120).
