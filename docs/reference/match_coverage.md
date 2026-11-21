# How many treated units have match candidates

How many treated units have match candidates

## Usage

``` r
match_coverage(treated, candidates)
```

## Arguments

- treated:

  Treated units from
  [`merger_sample()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_sample.md).

- candidates:

  A table from
  [`match_candidates()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_candidates.md).

## Value

A one-row data.table: `TREATED`, `MATCHED`, `N_GE_5`, `N_GE_25`,
`MEAN_CANDIDATES`, `MEDIAN_CANDIDATES` (both among matched units), and
`SAME_YEAR_SHARE` (share of pairs in the treated unit's calendar year).
