# Donor and recipient roles for each merger

A long table with one row per organization per merger: `MERGER_ID`,
`MERGER_GROUP_ID`, `ROLE` (`"donor"` or `"recipient"`), `EIN2`, and
`EVENT_YEAR` (time 0 on that organization's own fiscal calendar).

## Usage

``` r
merger_roles(cases)
```

## Arguments

- cases:

  Output of
  [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md).

## Value

A data.table.
