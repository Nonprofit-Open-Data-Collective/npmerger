# Default transaction classification rules

Thresholds used by
[`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md).
Override any element to run stricter or broader definitions.

## Usage

``` r
merger_rules(
  min_top_share = 0.75,
  leader = c("either", "sn", "p7"),
  min_donors_n = 2L,
  new_entity_years = 1L,
  sn_text = TRUE,
  promote = FALSE,
  min_corroborate = 2L,
  corroborate = c("SO_MERGER_TEXT_DONOR", "SO_MERGER_TEXT_RECIP", "GOV_DOC_CHANGE_RECIP"),
  final_as_termination = TRUE
)
```

## Arguments

- min_top_share:

  Minimum share of transferred FMV going to the dominant nonprofit
  recipient for a dissolution to count as a transfer to one successor
  (rather than a dispersed closure). When FMV is missing, a single
  nonprofit recipient counts as one successor. The default of 0.75 comes
  from hand validation: every sampled dissolution with a top share
  between 0.5 and 0.75 was read as a dispersed closure.

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

- sn_text:

  If `TRUE` (default), merger language in Schedule N's own text
  (`SN_MERGER_TEXT`, see
  [`sn_merger_pattern()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_merger_pattern.md))
  counts as merger evidence on its own, like leadership continuity.

- promote:

  If `TRUE`, a dissolution to one nonprofit successor with no leadership
  evidence is promoted from `asset_transfer` to a merger label when at
  least `min_corroborate` corroborating signals agree. Off by default:
  in hand validation only 1 of 13 promoted filings read as a merger. The
  signals are still computed, so promotion can be turned on for a broad
  definition.

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

- final_as_termination:

  If `TRUE` (default), a filing with only Part II (disposition of more
  than 25% of assets) but the final-return box checked is treated as a
  termination, like a Part I filing. In hand validation none of these
  were ongoing dispositions; most were mergers or transfers at
  dissolution reported on the wrong part.

## Value

A list of class `merger_rules`.

## Examples

``` r
merger_rules()
#> $min_top_share
#> [1] 0.75
#> 
#> $leader
#> [1] "either"
#> 
#> $final_as_termination
#> [1] TRUE
#> 
#> $sn_text
#> [1] TRUE
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
merger_rules(leader = "sn", sn_text = FALSE)
#> $min_top_share
#> [1] 0.75
#> 
#> $leader
#> [1] "sn"
#> 
#> $final_as_termination
#> [1] TRUE
#> 
#> $sn_text
#> [1] FALSE
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
merger_rules(promote = TRUE)   # broad definition
#> $min_top_share
#> [1] 0.75
#> 
#> $leader
#> [1] "either"
#> 
#> $final_as_termination
#> [1] TRUE
#> 
#> $sn_text
#> [1] TRUE
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
```
