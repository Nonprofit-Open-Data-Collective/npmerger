# Normalize organization names for matching

Upper-cases, replaces `&` with `AND`, strips punctuation, and drops
leading `THE` and legal suffixes (`INC`, `CORP`, `LLC`, ...). Program
words such as `FOUNDATION` are kept, since they distinguish
organizations.

## Usage

``` r
org_name_key(x)
```

## Arguments

- x:

  Character vector of names.

## Value

Character vector of keys (`NA` for blank names).

## Examples

``` r
orgs <- c( "The Arc of Maine, Inc.", "ARC OF MAINE",
           "Smith & Jones Co." )

org_name_key( orgs )
#> [1] "ARC OF MAINE"    "ARC OF MAINE"    "SMITH AND JONES"
```
