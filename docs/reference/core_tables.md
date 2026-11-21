# Core 990 tables read for merger organizations

Core 990 tables read for merger organizations

## Usage

``` r
core_tables()
```

## Value

A named list; each element has `table` (canonical NCCS efile table
name). All columns are read (the financial tables feed 'fiscal').

## Examples

``` r
names(core_tables())
#> [1] "header"   "summary"  "revenue"  "expenses" "balance"  "p7"      
```
