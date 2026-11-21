# Merger language in Schedule N's own text

Regular expression matched against the asset descriptions, valuation
methods, and Part III explanations on Schedule N to set `SN_MERGER_TEXT`
in
[`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md).
Narrower than
[`merger_text_pattern()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_text_pattern.md),
which is used on the much longer Schedule O: in hand validation every
terminated filing with one successor and a match was read as a merger.

## Usage

``` r
sn_merger_pattern()
```

## Value

A character string (a Perl-compatible regex, case-insensitive).
