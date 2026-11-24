# Sensitivity variants used in the paper

Each variant is a list of arguments to
[`merger_did()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md).
`base` is the main specification; the others change one thing each. Add
your own by appending to the list.

## Usage

``` r
did_variants()
```

## Value

A named list of argument lists.

## Examples

``` r
v <- did_variants()

names( v )
#>  [1] "base"         "k1"           "k10"          "equity"       "gap2"        
#>  [6] "through2021"  "keep_other"   "ntee_current" "unaffiliated" "full990"     
#> [11] "post1"       

# add a variant: three controls instead of five
v$k3 <- modifyList( v$base, list( k = 3L ) )
```
