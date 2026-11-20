# Fiscal-health panel around each merger

Donor years up to the merger and recipient years before and after it,
with 'fiscal' metrics plus staff expenses, executive pay, grants,
overhead, and debt.

## Usage

``` r
merger_fiscal_panel(cases, pre = 5L, post = 5L, ...)
```

## Arguments

- cases:

  Output of
  [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md).

- pre, post:

  Years before and after the merger year.

- ...:

  Retrieval options.

## Value

A data.table.
