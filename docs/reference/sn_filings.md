# One row per Schedule N filing

The Schedule N header (T00) and asset (T01) tables do not line up: some
filings have header rows but no asset lines, others the reverse. This
builds the filing universe as the union of both, and adds Part I/II
indicators, the line 2a-2d successor flags, and recipient summaries.

## Usage

``` r
sn_filings(sn, tx = sn_transactions(sn))
```

## Arguments

- sn:

  An `sn_raw` object.

- tx:

  Optional output of
  [`sn_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_transactions.md)
  (computed if missing).

## Value

A data.table, one row per `OBJECTID`, with `EIN2`, `TAX_YEAR`, `HAS_P1`,
`HAS_P2`, `DIR`, `EMP`, `OWN`, `COMP` (lines 2a-2d, either part),
`LEADER_SN` (any of 2a-2c), `N_RECIP`, `N_NP_RECIP`, `FMV_TOTAL`,
`FMV_NP`, `TOP_RECIP_EIN` and `TOP_SHARE` (largest nonprofit recipient's
share of total FMV), and `SN_MERGER_TEXT` (Schedule N's own text
mentions a merger; see
[`sn_merger_pattern()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_merger_pattern.md)).
