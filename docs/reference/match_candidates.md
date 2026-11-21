# Find match candidates for merger recipients

For each treated unit (a merger recipient in its merger year), returns
every pool organization-year in the same NTEE group whose baseline size
and financial condition fall within the calipers, ranked by a
standardized distance. Calendar years need not coincide: a 2015 merger
can be matched to a 2019 comparison year. Dollar measures are in
constant dollars, and sizes are compared in logs.

## Usage

``` r
match_candidates(
  treated,
  pool,
  ntee_chars = 2L,
  size = c("REAL_ASSETS", "REAL_EXPENSES"),
  health = "MARGIN",
  size_caliper = log(2),
  health_caliper = c(MARGIN = 0.1, EQUITY_RATIO = 0.15, MONTHS_CASH = 3),
  max_year_gap = Inf
)
```

## Arguments

- treated:

  `treated` element of
  [`merger_sample()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_sample.md).

- pool:

  Output of
  [`match_pool()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_pool.md).

- ntee_chars:

  NTEE characters that must agree (2 = letter and first digit, e.g.
  `"E2"`; 3 = full code).

- size:

  Size measures (constant-dollar columns), compared as `log1p`.

- health:

  Profitability or fiscal-health measures: any of `"MARGIN"`,
  `"EQUITY_RATIO"`, `"MONTHS_CASH"`.

- size_caliper:

  Maximum absolute difference in log size (for each size measure);
  `log(2)` allows up to a factor of two.

- health_caliper:

  Maximum absolute difference for each health measure (named numeric, or
  one value for all).

- max_year_gap:

  Optional maximum `|YEAR - C_YEAR|`.

## Value

A data.table, one row per treated unit and candidate: `T_ID`, `T_EIN2`,
`T_YEAR`, `C_EIN2`, `C_YEAR`, `YEAR_GAP`, `SAME_SUBSECTION`, the
differences (`D_*`), `DIST` (root mean square of differences scaled by
the pool's standard deviations), and `RANK` (1 = closest).
