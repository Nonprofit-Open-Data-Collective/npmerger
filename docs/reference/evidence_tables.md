# Evidence tables and the columns read from each

The 990 tables
[`get_evidence_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_evidence_tables.md)
reads for the donors and recipients in a set of Schedule N filings, and
the columns kept from each.

## Usage

``` r
evidence_tables()
```

## Value

A named list; each element has `table` (canonical NCCS efile table name)
and `columns`.

## Examples

``` r
names(evidence_tables())
#> [1] "header"  "p7"      "p6"      "so"      "sr"      "sa"      "mission"
```
