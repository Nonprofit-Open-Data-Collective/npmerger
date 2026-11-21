# Classify Schedule N filings into transaction types

Applies rule-based labels to a filing-level feature table. The evidence
columns are kept, so labels can be revised without re-running the
pipeline.

## Usage

``` r
classify_transactions(x, rules = merger_rules())
```

## Arguments

- x:

  A filing-level table, typically from
  [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md),
  with these columns: `HAS_P1`, `HAS_P2`, `LEADER_SN`, `N_NP_RECIP`,
  `TOP_SHARE`, `TOP_RECIP_EIN`, and `EIN2`. Optional columns:
  `LEADER_P7` (Part VII overlap), `N_DONORS` (dissolving donors to the
  same recipient in the window), `R_NEW` (recipient newly formed),
  `FINAL_RETURN`, and the corroborating-signal columns named in
  `rules$corroborate`. Missing optional columns are treated as `FALSE`
  (or 1 donor).

- rules:

  A
  [`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md)
  object.

## Value

`x` (as a data.table) with added columns `TERMINATED` (the filer ended;
see `final_as_termination` in
[`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md)),
`LEADER` (leadership evidence), `N_CORROBORATE` (number of corroborating
signals present), `BASIS` (`"leader"`, `"sn_text"`, `"corroborated"`, or
`NA` for non-mergers), and `TYPE`.
