# Donor and recipient filing history

Adds the donor's final-return flag and whether it filed again later, and
the recipient's formation year, whether it is newly formed, and whether
it filed after the merger year.

## Usage

``` r
add_filing_history(fl, header, new_entity_years = 1L)
```

## Arguments

- fl:

  Filing table from
  [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md).

- header:

  990 header rows (`F9-P00-T00-HEADER`) for donors and recipients, with
  `EIN2`, `TAX_YEAR`, `OBJECTID`, `F9_00_RETURN_FINAL_X`,
  `F9_00_RETURN_INITIAL_X`, and `F9_00_YEAR_FORMATION`.

- new_entity_years:

  A recipient formed (or filing an initial return) within this many
  years before the merger year counts as new.

## Value

`fl` with `FINAL_RETURN`, `DONOR_FILES_LATER`, `R_FORMED`,
`R_INITIAL_NEAR`, `R_NEW`, `R_IN_EFILE`, and `R_FILES_LATER`.
