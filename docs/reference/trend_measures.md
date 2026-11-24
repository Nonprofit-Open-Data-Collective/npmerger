# Growth, volatility, and deficit history within each organization

Year-over-year growth, revenue volatility, and the count of deficit
years over a trailing window. Windows are defined on calendar years and
never use future years. Growth needs a return in the prior calendar
year, so filing gaps give `NA` rather than a multi-year change.

## Usage

``` r
trend_measures(
  x,
  vars = c("REVENUE", "EXPENSES", "CONTRIBUTIONS", "PROGRAM_REVENUE", "NET_ASSETS"),
  k = 3L,
  min_obs = k,
  id = "EIN2",
  time = "TAX_YEAR"
)
```

## Arguments

- x:

  An organization-year table with
  [`merger_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_measures.md)
  columns.

- vars:

  Columns to compute growth for; each adds `<var>_GROWTH`.

- k:

  Trailing window length in years for volatility and deficits.

- min_obs:

  Minimum returns in the window for `REVENUE_CV` and `DEFICIT_YEARS`
  (otherwise `NA`).

- id, time:

  Organization and year columns.

## Value

`x` with `<var>_GROWTH` columns, `REVENUE_CV` (coefficient of variation
of revenue over the window), `DEFICIT_YEARS` (returns in the window with
expenses above revenue), and `N_TRAIL_YEARS` (returns in the window).

## Details

Growth is the symmetric (Davis-Haltiwanger-Schuh) rate
`(v[t] - v[t-1]) / ((|v[t]| + |v[t-1]|) / 2)`, bounded to -2..2. Unlike
a log change it is defined for zero and negative values (net assets),
and it is close to the percentage change for small changes.

## References

Mayer, W. J. (2023). Simmer or boil: Revenue volatility and nonprofit
dissolution. *Nonprofit and Voluntary Sector Quarterly*.

## Examples

``` r
x <-
  data.frame(
    EIN2     = "A",
    TAX_YEAR = 2018:2021,
    REVENUE  = c( 100, 120, 90, 90 ),
    SURPLUS  = c(   5,  -2, -8,  1 )
  )

trend_measures( x, vars = "REVENUE" )
#>      EIN2 TAX_YEAR REVENUE SURPLUS REVENUE_GROWTH REVENUE_CV DEFICIT_YEARS
#>    <char>    <int>   <num>   <num>          <num>      <num>         <int>
#> 1:      A     2018     100       5             NA         NA            NA
#> 2:      A     2019     120      -2      0.1818182         NA            NA
#> 3:      A     2020      90      -8     -0.2857143  0.1478250             2
#> 4:      A     2021      90       1      0.0000000  0.1732051             2
#>    N_TRAIL_YEARS
#>            <int>
#> 1:             1
#> 2:             2
#> 3:             3
#> 4:             3
```
