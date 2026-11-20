# Default transaction classification rules

Thresholds used by
[`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md).
Override any element to run stricter or broader definitions.

## Usage

``` r
merger_rules(
  min_top_share = 0.5,
  leader = c("either", "sn", "p7"),
  min_donors_n = 2L,
  new_entity_years = 1L,
  promote = TRUE,
  min_corroborate = 2L,
  corroborate = c("SO_MERGER_TEXT_DONOR", "SO_MERGER_TEXT_RECIP", "GOV_DOC_CHANGE_RECIP")
)
```

## Arguments

- min_top_share:

  Minimum share of transferred FMV going to the dominant nonprofit
  recipient for a dissolution to count as a transfer to one successor
  (rather than a dispersed closure).

- leader:

  Leadership-continuity evidence: `"either"` (Schedule N lines 2a-2c
  **or** Part VII overlap, the default), `"sn"` (Schedule N flags only),
  or `"p7"` (Part VII overlap only).

- min_donors_n:

  Number of dissolving donors to one recipient in the same window that
  makes a merger `mergerN`.

- new_entity_years:

  A recipient formed within this many years before the merger year
  counts as a new entity (consolidation).

- promote:

  If `TRUE` (default), a dissolution to one nonprofit successor with no
  leadership evidence is promoted from `asset_transfer` to a merger
  label when at least `min_corroborate` corroborating signals agree.

- min_corroborate:

  Number of corroborating signals required for promotion. One signal
  alone was too loose on 2019-21 data; two promoted about 5% of asset
  transfers, and those looked like mergers on measures the rule does not
  use.

- corroborate:

  Names of logical columns that count as corroborating signals: Schedule
  O merger language on the donor's and the recipient's return, and a
  Part VI line 4 governing-document change at the recipient in year t or
  t+1.

## Value

A list of class `merger_rules`.

## Examples

``` r
merger_rules()
#> $min_top_share
#> [1] 0.5
#> 
#> $leader
#> [1] "either"
#> 
#> $min_donors_n
#> [1] 2
#> 
#> $new_entity_years
#> [1] 1
#> 
#> $promote
#> [1] TRUE
#> 
#> $min_corroborate
#> [1] 2
#> 
#> $corroborate
#> [1] "SO_MERGER_TEXT_DONOR" "SO_MERGER_TEXT_RECIP" "GOV_DOC_CHANGE_RECIP"
#> 
#> attr(,"class")
#> [1] "merger_rules"
merger_rules(leader = "sn", promote = FALSE)
#> $min_top_share
#> [1] 0.5
#> 
#> $leader
#> [1] "sn"
#> 
#> $min_donors_n
#> [1] 2
#> 
#> $new_entity_years
#> [1] 1
#> 
#> $promote
#> [1] FALSE
#> 
#> $min_corroborate
#> [1] 2
#> 
#> $corroborate
#> [1] "SO_MERGER_TEXT_DONOR" "SO_MERGER_TEXT_RECIP" "GOV_DOC_CHANGE_RECIP"
#> 
#> attr(,"class")
#> [1] "merger_rules"
```
