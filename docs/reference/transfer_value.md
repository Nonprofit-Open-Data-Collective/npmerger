# Value of assets transferred to each recipient

Value of assets transferred to each recipient

## Usage

``` r
transfer_value(tx, cases)
```

## Arguments

- tx:

  Output of
  [`sn_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_transactions.md).

- cases:

  Output of
  [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md).

## Value

A data.table of FMV by merger and asset class, with outlier flags.
