# Classify Schedule N asset descriptions

Maps free-text asset descriptions to broad classes.

## Usage

``` r
asset_class(x)
```

## Arguments

- x:

  Character vector of asset descriptions.

## Value

Character vector: `"all_assets"` (whole or net asset transfers),
`"liabilities"` (liabilities assumed by the recipient, usually entered
as negative values), `"cash"`, `"receivables"` (including loans, notes,
and amounts due), `"investments"`, `"real_estate"`, `"equipment"`,
`"inventory"`, `"prepaid"` (prepaid expenses and deposits), `"program"`
(contracts, programs, intangibles, records, name), `"other"`, or
`"unknown"`.

## Examples

``` r
desc <- c( "Cash & Cash Equivalents",
           "Accounts Receivable",
           "Land and building",
           "All remaining assets",
           "Furniture and equipment",
           "Program contracts",
           "Accounts payable & accrued expenses",
           "Prepaid expenses" )

asset_class( desc )
#> [1] "cash"        "receivables" "real_estate" "all_assets"  "equipment"  
#> [6] "program"     "liabilities" "prepaid"    
```
