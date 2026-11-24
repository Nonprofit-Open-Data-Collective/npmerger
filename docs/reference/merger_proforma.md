# Combined donor + recipient (pro forma) series

Before a merger the recipient's own books exclude the donor, so
comparing the recipient before and after mixes the merger's effect with
the mechanical jump from absorbing the donor (and, in a rescue, the
donor's weak ratios). The pro forma series sums the recipient and its
donor(s) in each pre-merger year, on each organization's own fiscal
calendar, and uses the recipient alone from `pre_max + 1` on. Ratios are
recomputed from the summed amounts.

## Usage

``` r
merger_proforma(
  fp,
  level = c("merger", "group"),
  pre_max = -1L,
  require_all = TRUE
)
```

## Arguments

- fp:

  Output of
  [`merger_fiscal_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_fiscal_panel.md).

- level:

  `"merger"` (one recipient and one donor per series) or `"group"` (all
  donors in a `MERGER_GROUP_ID`, aligned on each donor's own time from
  merger, with the recipient's years from the group's first merger).

- pre_max:

  Last event year summed (default -1: the donor's final year, 0, is
  often a partial year).

- require_all:

  When `TRUE`, pre-merger years in which any donor has no return are set
  to `NA`.

## Value

A data.table with `ROLE = "combined"`, the ID column (`MERGER_ID` or
`MERGER_GROUP_ID`), `EIN2` and `TAX_YEAR` of the recipient,
`TIME_FROM_MERGER`, the summed measures, recomputed ratios, `N_DONORS`,
`N_DONORS_OBS`, `PF_EZ_MEMBERS`, and `PF_COMPLETE`.

## Details

Amounts a 990-EZ donor does not report (functional expenses, employees,
revenue breakdown) count as zero, and `PF_EZ_MEMBERS` counts those
donors. `REVENUE_HHI` is `NA` in years with an EZ member. 'fiscal' ratio
columns are not carried over: compute them from the summed amounts if
needed.
