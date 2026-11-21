# Name index of 990 filers

Reads name and address fields from the 990 header for the given years
(no EIN filter) to support
[`recover_recipient_ein()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/recover_recipient_ein.md).

## Usage

``` r
get_name_index(
  years,
  path = "PANEL990",
  source = panel990::data_source(),
  verbose = TRUE
)

name_index(header)
```

## Arguments

- years:

  Tax years.

- path, source, verbose:

  Passed to
  [`panel990::download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.html).

- header:

  Header rows with `EIN2`, `TAX_YEAR`, `ORG_NAME_L1`,
  `F9_00_ORG_ADDR_ZIP`, `F9_00_ORG_ADDR_STATE`.

## Value

A data.table with `EIN2`, `TAX_YEAR`, `NAME_KEY`, `ZIP5`, `STATE`, one
row per distinct combination.
