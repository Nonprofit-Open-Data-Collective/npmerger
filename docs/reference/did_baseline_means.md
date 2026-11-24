# Baseline means, sample funnel, and sample composition

Descriptive companions to
[`merger_did()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md)
for the same sets.

## Usage

``` r
did_baseline_means(
  data,
  k = 5L,
  spec = "margin",
  gap = 0L,
  keep = ~OTHER == FALSE,
  designs = did_designs(),
  outcomes = names(did_outcomes())
)

did_funnel(data, k = 5L, spec = "margin", gap = 0L, keep = ~OTHER == FALSE)

did_composition(
  data,
  k = 5L,
  spec = "margin",
  gap = 0L,
  keep = ~OTHER == FALSE
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

## Value

`did_baseline_means()`: mean of each outcome at `t-2`, by design and
`TREAT`. `did_funnel()`: a `step`, `n` table from merger cases to the
units and controls used. `did_composition()`: the number of treated
units in each level of each breakout variable.
