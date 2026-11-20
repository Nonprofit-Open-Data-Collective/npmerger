# Schedule N transaction table

One row per Schedule N filing: `TAX_YEAR`, `OBJECTID`, `EIN2`, `TYPE`,
and the evidence columns behind the label.

## Usage

``` r
sched_n_table(classified)
```

## Arguments

- classified:

  Output of
  [`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md).

## Value

A data.table.
