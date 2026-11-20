# Parse efile checkbox values

Schedule N (and most efile checkboxes) mix `0/1`, `true/false`, and `X`
encodings across schema versions. This normalizes them to logical.

## Usage

``` r
sn_flag(x, na_value = NA)
```

## Arguments

- x:

  A character (or numeric/logical) vector.

- na_value:

  Value to return for blanks and unrecognized codes. Defaults to `NA`;
  use `FALSE` when a blank box means "No".

## Value

A logical vector the same length as `x`.

## Examples

``` r
sn_flag(c("1", "true", "X", "0", "false", NA, ""))
#> [1]  TRUE  TRUE  TRUE FALSE FALSE    NA    NA
```
