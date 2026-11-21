# Count dissolving donors that share a successor

For each Part I filing whose dominant nonprofit successor is
`TOP_RECIP_EIN`, counts the distinct dissolving donors with the same
dominant successor within `window` years. A count of 2 or more marks a
multi-party merger (`mergerN`) or, with a new recipient, a
consolidation.

## Usage

``` r
add_donor_counts(
  fl,
  window = 1L,
  min_top_share = 0.75,
  final_as_termination = TRUE
)
```

## Arguments

- fl:

  Filing table from
  [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md).

- window:

  Years either side of the filing's tax year.

- min_top_share:

  A donor counts only when the successor receives at least this share of
  its transferred value (or is its only nonprofit recipient). Keeps
  large charities that collect small residual gifts from many closures
  from looking like serial acquirers.

- final_as_termination:

  Count Part-II-only filings with the final-return box (`FINAL_RETURN`,
  from
  [`add_filing_history()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_filing_history.md))
  as dissolving donors. See
  [`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md).

## Value

`fl` with `N_DONORS` (`NA` for filings without a dominant successor).
