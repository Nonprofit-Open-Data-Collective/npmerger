# Normalize person names for matching

Upper-cases, strips punctuation, titles and suffixes (Mr, Dr, Jr, MD,
PhD, ...), and keeps the first and last remaining tokens, so
`"Dr. Jane Q. Smith, PhD"` and `"JANE SMITH"` match.

## Usage

``` r
person_key(x)
```

## Arguments

- x:

  Character vector of names.

## Value

Character vector of keys (`NA` when fewer than two tokens remain).

## Examples

``` r
people <- c( "Dr. Jane Q. Smith, PhD", "JANE SMITH", "Smith" )

person_key( people )
#> [1] "JANE SMITH" "JANE SMITH" NA          
```
