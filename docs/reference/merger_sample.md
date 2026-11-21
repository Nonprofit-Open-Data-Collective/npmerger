# Research sample of mergers with a full observation window

Keeps merger cases of the given types whose **recipient** filed a return
in every year from `-pre` to `+post` around its merger year (on its own
fiscal calendar), and adds baseline measures for both organizations,
averaged over the years `years_back` before the merger (years present
only; the year `-min(years_back)` is required for the baseline to
count). Donors cannot be observed after the merger, so the donor window
is reported (`DONOR_PRE_OK`: returns in every year `-pre` to `-1`) but
not required.

## Usage

``` r
merger_sample(
  cases,
  panel,
  types = "merger2",
  pre = 2L,
  post = 2L,
  years_back = 2:3
)
```

## Arguments

- cases:

  Merger cases
  ([`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md),
  the `cases` element of
  [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)).

- panel:

  Full 990 panel
  ([`get_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_panel.md)).

- types:

  Merger types to keep.

- pre, post:

  Years required before and after the recipient's merger year.

- years_back:

  Years before the merger used for the baseline.

## Value

A list with:

- `sample`: one row per case, with `R_*` (recipient) and `D_*` (donor)
  baseline measures, `R_NTEE`, `R_NTEE2`, `DONOR_PRE_OK`, and
  `R_OTHER_EVENTS` (other merger cases involving the recipient within
  the window);

- `baseline`: the underlying organization-years (donor and recipient at
  each of `years_back`), long format;

- `treated`: one row per recipient and merger year, the units to match.
