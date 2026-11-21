# Donor and recipient attribute tables

One row per merger with the attributes of one side of it:

## Usage

``` r
merger_attributes(
  cases,
  oy,
  role = c("donor", "recipient"),
  years_back = 4L,
  bmf = NULL
)
```

## Arguments

- cases:

  Output of
  [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md).

- oy:

  Organization-year table from
  [`org_years()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/org_years.md).

- role:

  `"donor"` or `"recipient"`.

- years_back:

  Years before `REF_YEAR` to include (4 gives five years).

- bmf:

  Optional BMF table from
  [`get_bmf()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_bmf.md).

## Value

A data.table, one row per `MERGER_ID`.

## Details

- identifiers: `MERGER_ID`, `MERGER_GROUP_ID`, `ROLE`, `EIN2`;

- `SN_YEAR` (the donor's Schedule N year) and `REF_YEAR` (time 0 on this
  organization's fiscal calendar);

- name and address from the latest return filed in or before `REF_YEAR`;

- `FORMATION_YEAR` (990 header), `RULING_YEAR` (BMF), and `AGE`
  (`SN_YEAR` minus the earlier of the two);

- `NTEE`, `NTEE_MAJOR`, `NTEEV2`, `SUBSECTION` (BMF; organizations that
  have dissolved are often missing from the current BMF);

- `REVENUE`, `EXPENSES`, and `ASSETS` for `REF_YEAR - years_back`
  through `REF_YEAR`, in wide form (`REVENUE_T0`, `REVENUE_TM1`, ...),
  plus `N_YEARS_OBSERVED`.
