# Build the data for the merger models

Assembles, once, everything
[`merger_did()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md)
and the other model functions need: one row per treated recipient with
its breakout variables, the candidate controls for each matching
specification (including a match on the combined recipient + donor
baseline), donor component sums for the pro forma outcomes, and the
organization-years the models read.

## Usage

``` r
build_model_data(
  merger_data,
  match_data,
  max_k = 10L,
  max_year_gap = 2L,
  event = -3:2,
  verbose = TRUE
)
```

## Arguments

- merger_data:

  The list from
  [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md).

- match_data:

  The list from
  [`build_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_match_data.md),
  with its `panel`.

- max_k:

  Most controls per treated unit any model will use.

- max_year_gap:

  Largest calendar-year gap between a recipient and its controls any
  model will use.

- event:

  Event years kept around each merger.

- verbose:

  Print progress.

## Value

A list of class `merger_model_data`: `units`, `cases`, `candidates`
(named `r_<spec>` for recipient matches and `c_margin` for the combined
match), `panel` (outcome components for the organization-years used),
`donors` (donor sums by unit and event year), `n_donors`, and `info`.
