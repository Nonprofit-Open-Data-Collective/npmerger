# Part VII leadership overlap between donor and recipient

Matches the people listed on the donor's Part VII in years
`t + donor_window` against those on the recipient's Part VII in years
`t + recip_window`, using
[`person_key()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/person_key.md).

## Usage

``` r
leader_overlap(
  fl,
  p7,
  donor_window = -1:0,
  recip_window = 0:1,
  min_shared = 1L,
  name_col = "F9_07_COMP_DTK_NAME_PERS"
)
```

## Arguments

- fl:

  Filing table from
  [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md)
  (needs `EIN2`, `TAX_YEAR`, and `TOP_RECIP_EIN` or `RECIP_EIN2`).

- p7:

  Part VII person rows with `EIN2`, `TAX_YEAR`, and the name column.

- donor_window, recip_window:

  Year offsets from the Schedule N year.

- min_shared:

  Shared people needed to set `LEADER_P7`.

- name_col:

  Name column in `p7`.

## Value

`fl` with `N_DONOR_P7`, `N_RECIP_P7`, `N_SHARED_P7`, and `LEADER_P7`
(`NA` when either side has no Part VII rows in the window).

## Details

On 2019-21 data, 87% of two-party pairs that checked a Schedule N line
2a-2c box shared at least one person, against 9% for closures; about 40%
of asset transfers with no box checked also shared people.
