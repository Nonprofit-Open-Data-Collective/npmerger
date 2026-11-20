# Donor and recipient attribute tables

Organization attributes for each side of a merger: merger ID, Schedule N
year, revenue/expenses/assets for the five years up to the merger,
address, organization age, and NTEE code.

## Usage

``` r
merger_attributes(cases, role = c("donor", "recipient"), ...)
```

## Arguments

- cases:

  Output of
  [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md).

- role:

  `"donor"` or `"recipient"`.

- ...:

  Retrieval options.

## Value

A data.table.
