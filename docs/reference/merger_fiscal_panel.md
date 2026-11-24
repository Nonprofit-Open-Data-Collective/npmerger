# Fiscal-health panel around each merger

Stacks the donor's years up to its merger year and the recipient's years
before and after its merger year, with harmonized measures from
[`merger_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_measures.md)
and, optionally, fiscal-health ratios and a composite index from the
'fiscal' package.

## Usage

``` r
merger_fiscal_panel(
  cases,
  oy,
  pre = 5L,
  post = 5L,
  ratios = TRUE,
  fit = NULL,
  weights = NULL,
  smooth = c("none", "trailing"),
  k = 3L,
  trends = TRUE
)
```

## Arguments

- cases:

  Output of
  [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md).

- oy:

  Organization-year table from
  [`org_years()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/org_years.md).

- pre, post:

  Years before and after the merger year. Donors are kept only through
  their merger year.

- ratios:

  Compute 'fiscal' ratios (requires the 'fiscal' package).

- fit, weights:

  Optional fitted 'fiscal' model and weights; adds `fh_*` dimension
  scores and the `fiscal_health` index.

- smooth:

  `"none"` or `"trailing"`.

- k:

  Trailing window length in years.

- trends:

  Add
  [`trend_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/trend_measures.md)
  columns.

## Value

A data.table, one row per merger, role, and year, with `MERGER_ID`,
`MERGER_GROUP_ID`, `ROLE`, `EIN2`, `TAX_YEAR`, `TIME_FROM_MERGER`,
measure columns, and (if requested) ratio and index columns.

## Comparability over time

Ratios come from
[`fiscal::compute_all_panel()`](https://rdrr.io/pkg/fiscal/man/compute_all_panel.html).
Its winsorized, standardized, and percentile variants are re-estimated
within each tax year, so they rank organizations within a year rather
than measure change. To track change, pass a `fit` (a fitted
`fiscal::fiscal_health_fit()` model calibrated once on a reference
sample) and `weights` (`fiscal::fiscal_weights()`). Every
organization-year is then scored with the same fixed parameters.

## Smoothing

`smooth = "trailing"` replaces the financial fields with trailing
`k`-year averages
([`smooth_trailing()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/smooth_trailing.md))
before measures and ratios are computed. Use smoothed values for
matching and baselines. Use raw values (`smooth = "none"`) for
event-time outcome estimates, because a trailing window spreads a real
post-merger change over `k` years.

## Trends

With `trends = TRUE`, growth, revenue volatility, and deficit-year
columns from
[`trend_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/trend_measures.md)
are computed on the full (unsmoothed) organization-year history before
the window is cut, so the first window year still has its prior-year
growth. Use
[`merger_proforma()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_proforma.md)
on the result for a combined donor + recipient pre-merger baseline, and
[`tuckman_chang()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/tuckman_chang.md)
for vulnerability flags.
