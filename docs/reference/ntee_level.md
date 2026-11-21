# Clean NTEE code to a given number of characters

Clean NTEE code to a given number of characters

## Usage

``` r
ntee_level(x, n = 2L)
```

## Arguments

- x:

  NTEE codes.

- n:

  Characters to keep: 1 = major group (letter), 2 = letter and first
  digit (e.g. `"E2"`), 3 = full common code (e.g. `"E21"`).

## Value

Character vector (`NA` when the code is missing, too short, or a
placeholder such as `"UNDEFINED"`).

## Examples

``` r
ntee_level(c("E21", "b82z", "", NA, "X"), 2)
#> [1] "E2" "B8" NA   NA   NA  
```
