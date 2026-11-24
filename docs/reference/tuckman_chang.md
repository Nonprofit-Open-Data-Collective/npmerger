# Tuckman-Chang financial vulnerability flags

Tuckman and Chang (1991) call an organization financially vulnerable
when it is in the most vulnerable quintile on any of four indicators:
equity (net assets / revenue), revenue concentration (`REVENUE_HHI`),
administrative costs (management and general / total expenses), and
operating margin (surplus / revenue). Low equity, low administrative
costs (little to cut), low margins, and high concentration are
vulnerable. Greenlee and Trussel (2000) and Hager (2001) use the same
four.

## Usage

``` r
tuckman_chang(x, reference = x, by = "TAX_YEAR", q = 0.2)
```

## Arguments

- x:

  Organization-year table with `REVENUE`, `SURPLUS`, `NET_ASSETS`,
  `REVENUE_HHI`, and `ADMIN_RATIO` (from
  [`merger_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_measures.md)
  or
  [`panel_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_measures.md)).

- reference:

  Table used for the cutoffs (default `x`).

- by:

  Grouping columns for the cutoffs (e.g. `c("TAX_YEAR", "NTEE_MAJOR")`).

- q:

  Quantile that defines the vulnerable tail.

## Value

`x` with indicators `TC_EQUITY`, `TC_HHI`, `TC_ADMIN`, `TC_MARGIN`;
flags `TC_LOW_EQUITY`, `TC_HIGH_HHI`, `TC_LOW_ADMIN`, `TC_LOW_MARGIN`;
`TC_N_OBS` (indicators available), `TC_N_FLAGS`, `TC_ANY` (at least one
flag), and `TC_ALL` (all four flagged; `NA` unless all four are
available). The cutoffs are in `attr(, "cutoffs")`.

## Details

Cutoffs are quantiles computed within `by` groups of `reference`. Pass
the full 990 panel
([`get_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_panel.md))
as `reference`, so merger organizations are ranked against all filers
rather than against each other. The admin and concentration indicators
need the full Form 990, so 990-EZ filers are flagged on equity and
margin only.

## References

Tuckman, H. P., & Chang, C. F. (1991). *Nonprofit and Voluntary Sector
Quarterly*, 20(4), 445-460. Greenlee, J. S., & Trussel, J. M. (2000).
*Nonprofit Management and Leadership*, 11(2), 199-210.
