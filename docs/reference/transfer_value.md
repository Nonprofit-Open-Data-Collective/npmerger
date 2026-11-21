# Value of assets transferred in each merger

Sums the fair market value of the asset lines the donor reported for its
recipient, by asset class. With `core`, it also compares the total to
the donor's beginning-of-year assets (`COVERAGE`) and flags implausible
values.

## Usage

``` r
transfer_value(cases, tx, core = NULL, max_coverage = 2)
```

## Arguments

- cases:

  Output of
  [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md).

- tx:

  Output of
  [`sn_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_transactions.md).

- core:

  Optional organization-year table from
  [`org_years()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/org_years.md).

- max_coverage:

  Flag transfers above this multiple of the donor's beginning-of-year
  assets.

## Value

A data.table, one row per `MERGER_ID`, with:

- `FMV_<class>` columns (see
  [`asset_class()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/asset_class.md));

- `FMV_TOTAL` (all lines as reported) and `FMV_ASSETS` (excluding
  liabilities assumed, which filers usually enter as positive amounts);

- `N_LINES`, `N_FMV_MISSING`, and `ANY_NEGATIVE`;

- with `core`: `DONOR_ASSETS_BOY`, `COVERAGE` (`FMV_ASSETS` divided by
  the donor's beginning-of-year assets), and `FLAG_OUTLIER` (coverage
  above `max_coverage`, or negative `FMV_ASSETS`).
