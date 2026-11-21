# Smooth panel variables using only current and past years

A trailing moving average within each organization, defined on calendar
years: the value for year t is the mean of the non-missing values in
years t-(k-1) through t. Unlike a centered window it never uses future
years, so pre-merger values are not contaminated by post-merger ones.
Filing gaps are not bridged.

## Usage

``` r
smooth_trailing(x, vars, k = 3L, id = "EIN2", time = "TAX_YEAR")
```

## Arguments

- x:

  A panel with `id` and `time` columns.

- vars:

  Numeric columns to smooth.

- k:

  Window length in years.

- id, time:

  Panel identifier and time columns.

## Value

`x` with `vars` replaced by their trailing averages.

## Details

Uses `panel990::panel_smooth(align = "right")` when the installed
panel990 supports it, and an equivalent internal implementation
otherwise.

## Examples

``` r
x <- data.frame(EIN2 = "A", TAX_YEAR = c(2018, 2019, 2021), REVENUE = c(10, 20, 60))
smooth_trailing(x, "REVENUE")   # 2021 uses 2019 and 2021 only (2020 missing)
#>      EIN2 TAX_YEAR REVENUE
#>    <char>    <num>   <num>
#> 1:      A     2018      10
#> 2:      A     2019      15
#> 3:      A     2021      40
```
