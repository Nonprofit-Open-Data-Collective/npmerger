# Example data for offline use

A small extract of 2021 Schedule N filings with the evidence, core, name
index, and BMF rows needed to run
[`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)
without downloading anything. Built by `data-raw/example.R`.

## Usage

``` r
npmerger_example()
```

## Value

A list with `sn`, `evidence`, `core`, `names`, and `bmf`.

## Examples

``` r
ex <- npmerger_example()
ex$sn
#> <sn_raw> Schedule N tables, tax years 2021-2021 
#>   p1_header       26 rows
#>   p1_assets       40 rows
#>   p2_header        4 rows
#>   p2_assets        4 rows
#>   p3_text         19 rows
```
