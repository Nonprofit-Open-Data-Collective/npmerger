# Revenue concentration (Herfindahl-Hirschman index)

Sum of squared shares of revenue sources. Negative amounts count as zero
and missing amounts as zero when at least one source is reported.

## Usage

``` r
revenue_hhi(..., ok = TRUE)
```

## Arguments

- ...:

  Numeric vectors of revenue by source (same length).

- ok:

  Logical vector; rows where it is `FALSE` return `NA` (for example
  990-EZ returns, which lack the full breakdown).

## Value

Numeric vector in 1/n..1, or `NA` when no source is positive.

## Examples

``` r
contrib <- c( 100, 50 )
program <- c(   0, 50 )
invest  <- c(   0,  0 )
other   <- c(   0, NA )

# 1 (one source) and 0.5 (two equal sources)
revenue_hhi( contrib, program, invest, other )
#> [1] 1.0 0.5
```
