# Covariate balance of a matched sample

Standardized mean differences between treated units and their `k`
closest candidates (each candidate weighted `1 / k_i`), and between
treated units and the whole pool in the same NTEE groups.

## Usage

``` r
match_balance(
  treated,
  pool,
  candidates,
  k = 1L,
  vars = c("REAL_ASSETS", "REAL_EXPENSES", "REAL_REVENUE", "MARGIN", "EQUITY_RATIO",
    "MONTHS_CASH")
)
```

## Arguments

- treated, pool, candidates:

  As in
  [`match_candidates()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_candidates.md).

- k:

  Candidates per treated unit.

- vars:

  Baseline variables to compare.

## Value

A data.table with means and standardized differences.
