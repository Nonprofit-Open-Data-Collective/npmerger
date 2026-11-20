# Clean EINs

`clean_ein()` returns a 9-digit character EIN, or `NA` for blanks and
placeholder values (all zeros, all nines, wrong length). `as_ein2()`
converts to the `EIN-XX-XXXXXXX` key used by the NCCS efile tables.

## Usage

``` r
clean_ein(x)

as_ein2(x)
```

## Arguments

- x:

  A vector of EINs in any common format (with or without dashes, numeric
  with dropped leading zeros, or `EIN-XX-XXXXXXX`).

## Value

A character vector.

## Examples

``` r
clean_ein(c("01-0215911", "10215911", "000000000", "EIN-01-0215911", NA))
#> [1] "010215911" "010215911" NA          "010215911" NA         
as_ein2("010215911")
#> [1] "EIN-01-0215911"
```
