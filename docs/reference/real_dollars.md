# Convert nominal dollars to constant dollars

Convert nominal dollars to constant dollars

## Usage

``` r
real_dollars(x, year, base_year = 2024L)
```

## Arguments

- x:

  Dollar amounts.

- year:

  Year of each amount.

- base_year:

  Target year.

## Value

`x` in `base_year` dollars (`NA` where the year is outside
[`cpi_u()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/cpi_u.md)).

## Examples

``` r
real_dollars(100, 2010)
#> [1] 143.8571
```
