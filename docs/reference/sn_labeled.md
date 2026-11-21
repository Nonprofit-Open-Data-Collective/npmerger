# Labeled Schedule N table for inspection

Stacks Schedule N Part I and Part II asset lines into one tidy table:
one row per asset line, with the part's checkbox answers as extra
columns, the filing's classifier label and key evidence, and a flag on
the line(s) that go to the merger recipient. A filing part with a header
but no asset lines gets one row with empty asset fields, so every
labeled filing appears.

## Usage

``` r
sn_labeled(
  sn,
  labeled,
  cases = NULL,
  transactions = NULL,
  label_cols = c("TYPE", "BASIS", "AFFILIATED", "TERMINATED", "FINAL_RETURN", "LEADER",
    "LEADER_SN", "LEADER_P7", "SN_MERGER_TEXT", "N_CORROBORATE", "N_NP_RECIP",
    "TOP_SHARE", "FMV_TOTAL", "N_DONORS", "R_NEW")
)
```

## Arguments

- sn:

  An `sn_raw` object from
  [`get_schedule_n()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_schedule_n.md).

- labeled:

  The labeled filing table,
  [`sched_n_table()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sched_n_table.md)
  (the `sched_n` element of
  [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)).

- cases:

  Optional merger cases from
  [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md)
  (the `cases` element). Used to name the merger recipient of each donor
  filing.

- transactions:

  Optional asset lines with recovered recipient EINs (the `transactions`
  element). Used when its rows line up with `sn_transactions(sn)`;
  otherwise only reported EINs are used.

- label_cols:

  Columns of `labeled` to carry onto every row.

## Value

A data.table with filing columns (`OBJECTID`, `EIN2`, `ORG_NAME`,
`TAX_YEAR`, `TAX_PERIOD_END`, `URL`, the `label_cols`, `MERGER_ID`,
`MERGER_RECIP_EIN2`, `HAS_RECIPIENT_ROW`, `P3_TEXT`), line columns
(`PART`, `LINE`, `ASSET_DESC`, `DIST_DATE`, `FMV`, `FMV_METHOD`,
`RECIP_EIN2`, `EIN_SOURCE`, `RECIP_NAME`, `RECIP_CITY`, `RECIP_STATE`,
`RECIP_ZIP`, `IRC_SECTION`, `RECIP_TYPE`, `SELF_TRANSFER`,
`IS_MERGER_RECIPIENT`), and the checkbox columns in
[`sn_checkboxes()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_checkboxes.md)
(`NA` where the part does not ask the question).

## See also

[`sn_inspection()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_inspection.md)
to draw review samples.
