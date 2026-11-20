# Part VII leadership overlap between donor and recipient

Matches normalized person names on the donor's Part VII (t-1, t) against
the recipient's Part VII (t, t+1).

## Usage

``` r
leader_overlap(pairs, p7)
```

## Arguments

- pairs:

  A table with `EIN2`, `RECIP_EIN2`, `TAX_YEAR`.

- p7:

  Part VII person rows with `EIN2`, `TAX_YEAR`, and the person name
  column `F9_07_COMP_DTK_NAME_PERS`.

## Value

`pairs` with `N_DONOR_P7`, `N_RECIP_P7`, `N_SHARED`, `LEADER_P7`.
