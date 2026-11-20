# Affiliation between donor and recipient

Records whether the donor and recipient belong to one family of
organizations. This is kept separate from the transaction label: about a
third of two-party mergers and two-thirds of multi-party mergers in
2019-21 were between affiliated organizations.

## Usage

``` r
add_affiliation(fl, sr = NULL, sa = NULL, header = NULL)
```

## Arguments

- fl:

  Filing table from
  [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md).

- sr:

  Schedule R Part II rows (`SR-P02-T01-ID-RLTD-TAX-EXEMPED-ORGS`) with
  `EIN2` and `SR_02_RLTD_ORG_EIN`.

- sa:

  Schedule A Part I rows with `EIN2` and `SA_01_PCSTAT_SUPPORT_ORG_X`.

- header:

  Header rows with `EIN2` and `F9_00_GROUP_EXEMPT_NUM`.

## Value

`fl` with `AFF_SCHED_R`, `AFF_SUPPORT_ORG`, `AFF_GROUP`, and
`AFFILIATED` (any of the three).
