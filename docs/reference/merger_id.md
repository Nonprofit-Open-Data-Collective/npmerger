# Build merger identifiers

`merger_id()` builds the pair identifier `YEAR-FROMEIN-TOEIN` (9-digit
EINs, donor first). `merger_group_id()` builds `YEAR-TOEIN`, which links
all donors folding into one recipient.

## Usage

``` r
merger_id(year, from_ein, to_ein)

merger_group_id(year, to_ein)
```

## Arguments

- year:

  Merger year (the donor's Schedule N tax year).

- from_ein:

  Donor (closing organization) EIN.

- to_ein:

  Recipient (successor organization) EIN.

## Value

A character vector.

## Examples

``` r
merger_id( 2020, "01-0215911", "010431680" )
#> [1] "2020-010215911-010431680"

merger_group_id( 2020, "010431680" )
#> [1] "2020-010431680"
```
