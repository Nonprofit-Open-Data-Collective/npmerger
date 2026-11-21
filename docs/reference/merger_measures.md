# Harmonized financial measures for 990 and 990-EZ filers

Adds plain-named measures used by the attribute tables and the fiscal
panel. Revenue, expenses, assets, liabilities, net assets, grants, and
contributions are available for both 990 and 990-EZ filers. The
functional-expense breakdown (overhead), executive compensation,
employees, and debt detail come from the full Form 990 only and are `NA`
for 990-EZ filers.

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
`CONTRIBUTIONS`, `PROGRAM_REVENUE`, `NONCASH_CONTRIB`, `GRANTS`,
`STAFF_EXP`, `EXEC_COMP`, `PROGRAM_EXP`, `MGMT_EXP`, `FUNDR_EXP`,
`OVERHEAD_RATIO`, `EMPLOYEES`, and `EZ` (990-EZ return).
