# Matched difference-in-differences for merger recipients

Long-difference estimates, from `t-2` to `t+post`, of the change in each
outcome for merger recipients against their matched controls, for each
design in
[`did_designs()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_designs.md).
Each treated unit and its `k` closest controls form a set; models have
set fixed effects, control weights of `1/k`, and standard errors
clustered by set and organization.

## Usage

``` r
merger_did(
  data,
  k = 5L,
  spec = "margin",
  gap = 0L,
  keep = ~OTHER == FALSE,
  post = 2L,
  designs = did_designs(),
  outcomes = names(did_outcomes()),
  het = NULL,
  label = "base"
)

did_breakouts(data, by = did_breakout_vars(), ...)

did_sensitivity(data, variants = did_variants(), ...)
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

- post:

  Last event year of the long difference.

- designs:

  Designs to run, from
  [`did_designs()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_designs.md).

- outcomes:

  Outcome codes, from `names(did_outcomes())`.

- het:

  Unit-level variables to interact with treatment (see
  `did_breakouts()`).

- label:

  Value of the `variant` column.

- by:

  Breakout variables, from
  [`did_breakout_vars()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_breakout_vars.md).

- ...:

  Further arguments to `merger_did()`.

- variants:

  A named list of argument lists, as from
  [`did_variants()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_variants.md).

## Value

A data.table: `variant`, `design`, `outcome`, `spec` (`"pooled"` or the
breakout variable), `term`, `estimate`, `se`, `p`, `n_obs`, `n_sets`.
Log outcomes are log points; ratios and shares are proportions.

## Functions

- `did_breakouts()`: Breakouts: the treatment effect within each level
  of each variable in `by` (one model per variable), alongside the
  pooled estimate.

- `did_sensitivity()`: Sensitivity: `merger_did()` once per variant,
  with the variant's name in `variant`.
