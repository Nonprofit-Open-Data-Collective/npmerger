# Mission-statement similarity between donor and recipient

Jaccard similarity of the word sets (words longer than three letters) in
the donor's and recipient's mission statements. Descriptive only: it
does not count toward promotion. Median similarity in 2019-21 was .07
for two-party mergers and .03 for asset transfers; random pairs score 0.

## Usage

``` r
add_mission_similarity(fl, mission, text_col = "F9_03_ORG_MISSION_PURPOSE")
```

## Arguments

- fl:

  Filing table from
  [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md).

- mission:

  Rows with `EIN2` and a mission text column.

- text_col:

  Mission text column.

## Value

`fl` with `MISSION_SIM`.
