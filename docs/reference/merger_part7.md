# Part VII panel around each merger

People listed on Part VII for the donor and recipient from t-2 to t+2,
with `MERGER_ID`, `TAX_YEAR`, `TIME_FROM_MERGER`, `ROLE`, and an
`IN_BOTH` flag for people who appear on both organizations.

## Usage

``` r
merger_part7(cases, window = -2:2, ...)
```

## Arguments

- cases:

  Output of
  [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md).

- window:

  Integer offsets from the merger year.

- ...:

  Retrieval options.

## Value

A data.table.
