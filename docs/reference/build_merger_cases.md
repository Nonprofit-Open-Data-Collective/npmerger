# Build merger cases (donor-recipient pairs)

Turns classified filings into donor-recipient pairs with `MERGER_ID`,
`MERGER_GROUP_ID`, the merger year on each side's fiscal calendar, and a
role table.

## Usage

``` r
build_merger_cases(
  classified,
  tx,
  types = c("merger2", "mergerN", "consolidation")
)
```

## Arguments

- classified:

  Output of
  [`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md).

- tx:

  Output of
  [`sn_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_transactions.md).

- types:

  Transaction types to keep.

## Value

A data.table of cases.
