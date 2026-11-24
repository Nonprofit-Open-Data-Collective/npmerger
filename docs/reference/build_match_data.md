# Build the matched comparison data in one call

Runs the matching steps in order: the full 990 panel
([`get_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_panel.md)),
the research sample of mergers with a full observation window
([`merger_sample()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_sample.md)),
the Schedule N organizations to keep out of the pool
([`schedule_n_events()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/schedule_n_events.md)),
the comparison pool
([`match_pool()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_pool.md)),
match candidates for each matching specification
([`match_candidates()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_candidates.md)),
and balance checks
([`match_balance()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_balance.md)).

## Usage

``` r
build_match_data(
  merger_data,
  panel = NULL,
  years = efile_years(),
  path = "PANEL990",
  types = "merger2",
  pre = 2L,
  post = 2L,
  years_back = 2:3,
  exclude_window = -3:2,
  health = c(margin = "MARGIN", equity = "EQUITY_RATIO"),
  ntee_chars = 2L,
  size = c("REAL_ASSETS", "REAL_EXPENSES"),
  size_caliper = log(2),
  health_caliper = c(MARGIN = 0.1, EQUITY_RATIO = 0.15, MONTHS_CASH = 3),
  max_year_gap = Inf,
  balance_k = c(1L, 5L),
  verbose = TRUE
)
```

## Arguments

- merger_data:

  The list from
  [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)
  (needs `cases`; `sched_n` and `transactions` are used to keep merging
  organizations out of the pool).

- panel:

  A panel from
  [`get_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_panel.md).
  If `NULL`, it is built from `years` and `path`, which reads every 990
  filer and takes several minutes.

- years, path, verbose:

  Passed to
  [`get_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_panel.md)
  when `panel` is `NULL`.

- types, pre, post, years_back:

  Passed to
  [`merger_sample()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_sample.md)
  (and `pre`, `post`, `years_back` to
  [`match_pool()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_pool.md)).

- exclude_window:

  Passed to
  [`match_pool()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_pool.md).

- health:

  Named character vector of profitability or fiscal-health measures.
  Each one is a separate specification with its own candidate table,
  named after the element (default: `margin` = `"MARGIN"`, `equity` =
  `"EQUITY_RATIO"`).

- ntee_chars, size, size_caliper, health_caliper, max_year_gap:

  Passed to
  [`match_candidates()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_candidates.md).

- balance_k:

  Numbers of closest candidates to check balance for.

## Value

A list of class `merger_match_data`:

- `panel`, `sample`, `baseline`, `treated`, `events`, `pool`;

- `candidates`: a named list with one candidate table per `health`
  specification;

- `balance`:
  [`match_balance()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_balance.md)
  results for each specification and `k`;

- `coverage`: per specification, treated units, units with at least 1,
  5, and 25 candidates, the mean and median number of candidates, and
  the share of pairs in the same calendar year;

- `settings`: the arguments used.

## See also

[`vignette("matching", package = "npmerger")`](https://nonprofit-open-data-collective.github.io/npmerger/articles/matching.md)

## Examples

``` r
if (FALSE) { # \dontrun{
md <- build_merger_data( years = efile_years() )
mm <- build_match_data( md, path = "PANEL990" )

mm$coverage

# the five closest comparison org-years for each recipient
mm$candidates$margin[ RANK <= 5 ]
} # }
```
