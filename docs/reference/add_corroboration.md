# Corroborating merger disclosures

Flags Schedule O merger language on the donor's and the recipient's
returns, and a significant change to the recipient's governing documents
(Part VI line 4).
[`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md)
promotes an asset transfer to a merger when at least two of these agree
(see
[`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md)).

## Usage

``` r
add_corroboration(
  fl,
  so = NULL,
  p6 = NULL,
  pattern = merger_text_pattern(),
  so_recip_window = 0L,
  gov_window = 0:1
)
```

## Arguments

- fl:

  Filing table from
  [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md).

- so:

  Schedule O rows with `EIN2`, `TAX_YEAR`, `SO_00_EXPLANATION_TEXT`.

- p6:

  Part VI rows with `EIN2`, `TAX_YEAR`, `F9_06_GVRN_CHANGE_DOC_X`.

- pattern:

  Regular expression for merger language.

- so_recip_window, gov_window:

  Year offsets for the recipient checks.

## Value

`fl` with `SO_MERGER_TEXT_DONOR`, `SO_MERGER_TEXT_RECIP`, and
`GOV_DOC_CHANGE_RECIP`.
