# Part VII panel around each merger

Everyone listed on Part VII for the donor and the recipient in the years
`EVENT_YEAR + window`, with time from the merger on each organization's
own fiscal calendar. When an organization filed more than one return for
a year, only the latest is used.

## Usage

``` r
merger_part7(cases, p7, window = -2:2)
```

## Arguments

- cases:

  Output of
  [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md).

- p7:

  Part VII rows (the `p7` element of
  [`get_core()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_core.md)).

- window:

  Integer offsets from the merger year.

## Value

A data.table with `MERGER_ID`, `MERGER_GROUP_ID`, `ROLE`, `EIN2`,
`TAX_YEAR`, `TIME_FROM_MERGER`, `PERSON_NAME`, `PERSON_KEY`, `TITLE`,
`HOURS`, `COMP_ORG`, `COMP_RELATED`, `COMP_OTHER`, position flags
(`TRUSTEE`, `OFFICER`, `KEY_EMPLOYEE`, `HIGH_COMP`, `FORMER`), and
`IN_BOTH` (the person appears on both the donor's and the recipient's
Part VII within the window).
