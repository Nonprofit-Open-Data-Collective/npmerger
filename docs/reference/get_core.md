# Retrieve core 990 tables for a set of organizations

Reads header, summary (990 and 990-EZ), Part VII and other core tables
for a selected set of EINs only, pushing the EIN filter into the parquet
scan.

## Usage

``` r
get_core(eins, years, tables = c("P00", "P01", "F9-P01-T00-SUMMARY-EZ"), ...)
```

## Arguments

- eins:

  EINs (any format accepted by
  [`clean_ein()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/clean_ein.md)).

- years:

  Tax years.

- tables:

  Table names or 'panel990' aliases.

- ...:

  Passed to 'panel990' retrieval functions.

## Value

A named list of data.tables.
