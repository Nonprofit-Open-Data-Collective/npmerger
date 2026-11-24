# Event-study estimates for merger recipients

Difference between recipients and their matched controls in each event
year, relative to `t-2`, with unit and set-by-event-year fixed effects.

## Usage

``` r
did_event_study(
  data,
  k = 5L,
  spec = "margin",
  gap = 0L,
  keep = ~OTHER == FALSE,
  designs = did_designs(),
  outcomes = names(did_outcomes()),
  label = "base"
)
```

## Arguments

- data:

  A
  [`build_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_model_data.md)
  object.

- k:

  Controls per treated unit.

- spec:

  Matching specification: `"margin"` or `"equity"` (the names of
  `health` in
  [`build_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_match_data.md)).

- gap:

  Largest calendar-year gap between a recipient and its controls (with a
  gap above 0, the models add tax-year fixed effects).

- keep:

  A one-sided formula (or quoted expression or string), evaluated in
  `data$units`, that selects the treated units (e.g.
  `~ OTHER == FALSE & YEAR <= 2021L`), or `NULL` for all.

- designs:

  Designs to run, from
  [`did_designs()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_designs.md).

- outcomes:

  Outcome codes, from `names(did_outcomes())`.

- label:

  Value of the `variant` column.

## Value

A data.table as from
[`merger_did()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md),
with `spec = "event"` and an event-year column `E`.
