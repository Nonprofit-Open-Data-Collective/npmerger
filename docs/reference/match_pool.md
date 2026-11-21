# Pool of potential comparison organization-years

Every organization-year `YEAR` in the panel for which the organization
filed a return in each year `YEAR - pre` to `YEAR + post` and has a
baseline (the same `years_back` average used for merger recipients). An
organization-year is dropped when the organization was involved in a
Schedule N event (as filer or named recipient) within `exclude_window`
years of `YEAR`.

## Usage

``` r
match_pool(
  panel,
  events = NULL,
  pre = 2L,
  post = 2L,
  years_back = 2:3,
  exclude_window = -3:2
)
```

## Arguments

- panel:

  Full 990 panel
  ([`get_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_panel.md)).

- events:

  Schedule N involvement: a table with `EIN2` and `TAX_YEAR` (filers
  from `sched_n`, plus recipient EINs from `transactions`). See
  [`schedule_n_events()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/schedule_n_events.md).

- pre, post, years_back:

  As in
  [`merger_sample()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_sample.md).

- exclude_window:

  Offsets around `YEAR` in which an event disqualifies an
  organization-year.

## Value

A data.table: `EIN2`, `YEAR`, baseline measures, `NTEE`, `NTEE2`.
