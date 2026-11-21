# Schedule N checkbox fields

The yes/no questions on Schedule N, as column suffixes in the raw header
tables (`SN_01_ORG_...` for Part I, `SN_02_ORG_...` for Part II). Lines
2a-2d appear in both parts; the rest only in Part I.

## Usage

``` r
sn_checkboxes()
```

## Value

A named character vector: output column name = raw suffix.

## Examples

``` r
sn_checkboxes()
#>          DIR_SUCCESSOR_X         EMPL_SUCCESSOR_X          OWN_SUCCESSOR_X 
#>    "DTK_DIR_SUCCESSOR_X"   "DTK_EMPL_SUCCESSOR_X"    "DTK_OWN_SUCCESSOR_X" 
#>               REC_COMP_X        ASSET_DIST_GVRN_X    REQ_NOTIFY_ATTORNEY_X 
#>         "DTK_REC_COMP_X"      "ASSET_DIST_GVRN_X"  "REQ_NOTIFY_ATTORNEY_X" 
#>      ATTORNEY_NOTIFIED_X              LIAB_PAID_X       BOND_OUTSTANDING_X 
#>    "ATTORNEY_NOTIFIED_X"            "LIAB_PAID_X"     "BOND_OUTSTANDING_X" 
#>   BOND_LIAB_DISCHARGED_X 
#> "BOND_LIAB_DISCHARGED_X" 
```
