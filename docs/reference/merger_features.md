# Add all merger evidence to a filing table

Applies
[`leader_overlap()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/leader_overlap.md),
[`add_donor_counts()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_donor_counts.md),
[`add_filing_history()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_filing_history.md),
[`add_corroboration()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_corroboration.md),
[`add_affiliation()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_affiliation.md),
and
[`add_mission_similarity()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_mission_similarity.md)
using whichever evidence tables are present. The result is ready for
[`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md).

## Usage

``` r
merger_features(fl, evidence, rules = merger_rules(), donor_window = 1L)
```

## Arguments

- fl:

  Filing table from
  [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md).

- evidence:

  List from
  [`get_evidence_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_evidence_tables.md).

- rules:

  A
  [`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md)
  object (uses `min_top_share` and `new_entity_years`).

- donor_window:

  Years either side for counting donors to one successor.

## Value

The filing table with evidence columns added.

## Examples

``` r
if (FALSE) { # \dontrun{
sn  <- get_schedule_n(2019:2021)
fl  <- sn_filings(sn)
ev  <- get_evidence_tables(fl)
lab <- classify_transactions(merger_features(fl, ev))
} # }
```
