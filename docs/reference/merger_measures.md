# Harmonized financial measures for 990 and 990-EZ filers

Adds plain-named measures used by the attribute tables and the fiscal
panel. Revenue, expenses, assets, liabilities, net assets, grants, and
contributions are available for both 990 and 990-EZ filers. The
functional-expense breakdown (overhead), executive compensation,
employees, the revenue-source breakdown, and debt detail come from the
full Form 990 only and are `NA` for 990-EZ filers.

## Usage

``` r
merger_measures(x)
```

## Arguments

- x:

  An organization-year table (from
  [`org_years()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/org_years.md)).

## Value

`x` with measure columns added: `REVENUE`, `EXPENSES`, `SURPLUS`,
`ASSETS`, `ASSETS_BOY`, `LIABILITIES`, `NET_ASSETS`, `DEBT`,
`CONTRIBUTIONS`, `PROGRAM_REVENUE`, `INVEST_INCOME`, `OTHER_REVENUE`,
`NONCASH_CONTRIB`, `GRANTS`, `STAFF_EXP`, `EXEC_COMP`, `PROGRAM_EXP`,
`MGMT_EXP`, `FUNDR_EXP`, `OVERHEAD_RATIO`, `ADMIN_RATIO` (management and
general / total expenses), `REVENUE_HHI`, `EMPLOYEES`,
`REV_PER_EMPLOYEE`, `EXP_PER_EMPLOYEE`, `COMP_PER_EMPLOYEE` (salaries
and benefits / employees), `DEFICIT` (expenses exceed revenue),
`NEG_NET_ASSETS`, and `EZ` (990-EZ return).

## Details

`REVENUE_HHI` is the Herfindahl-Hirschman index of revenue concentration
across the four Part I sources (contributions, program service revenue,
investment income, other revenue), the revenue-concentration indicator
of Tuckman and Chang (1991). Negative sources count as zero. It ranges
from 0.25 (equal shares) to 1 (one source). Per-employee measures are
`NA` when the return reports no employees.

## References

Tuckman, H. P., & Chang, C. F. (1991). A methodology for measuring the
financial vulnerability of charitable nonprofit organizations.
*Nonprofit and Voluntary Sector Quarterly*, 20(4), 445-460.
