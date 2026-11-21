# Build merger cases (donor-recipient pairs)

Turns classified filings into one row per donor-recipient pair.

## Usage

``` r
build_merger_cases(
  classified,
  tx,
  header = NULL,
  types = c("merger2", "mergerN", "consolidation"),
  group_window = 1L
)
```

## Arguments

- classified:

  Output of
  [`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md).

- tx:

  Output of
  [`sn_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_transactions.md).

- header:

  Optional 990 header rows for recipients (with `EIN2`, `TAX_YEAR`,
  `TAX_PERIOD_BEGIN_DATE`, `TAX_PERIOD_END_DATE`), used to place the
  distribution date on the recipient's fiscal calendar.

- types:

  Transaction types to keep.

- group_window:

  Years between donors that still count as one group.

## Value

A data.table of class `merger_cases`, one row per `MERGER_ID`.

## Details

- `MERGER_ID` is `YEAR-FROMEIN-TOEIN`, using the donor's Schedule N
  year.

- `MERGER_GROUP_ID` is `YEAR-TOEIN`. It links donors that fold into the
  same recipient within `group_window` years of each other, and uses the
  earliest donor year in the group.

- `MERGER_YEAR` is the donor's Schedule N tax year (time 0 for the
  donor).

- `RECIP_MERGER_YEAR` is the recipient's tax year whose filing period
  contains the asset distribution date (time 0 for the recipient). It
  falls back to `MERGER_YEAR` when the recipient's filing period is
  unknown.
