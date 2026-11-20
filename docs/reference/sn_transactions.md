# Stack Schedule N Part I and Part II asset lines

Builds one row per asset line reported in Schedule N Part I
(liquidation, termination, dissolution) or Part II (disposition of more
than 25% of net assets), with cleaned recipient EINs and a parsed
recipient type.

## Usage

``` r
sn_transactions(sn)
```

## Arguments

- sn:

  An `sn_raw` object from
  [`get_schedule_n()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_schedule_n.md).

## Value

A data.table with columns `OBJECTID`, `EIN2`, `TAX_YEAR`, `PART` (1 or
2), `ASSET_DESC`, `DIST_DATE`, `FMV`, `FMV_METHOD`, `RECIP_EIN`,
`RECIP_NAME`, `RECIP_STATE`, `RECIP_ZIP`, `IRC_SECTION`, `RECIP_TYPE`,
and `SELF_TRANSFER`. A recipient with a blank type but a valid EIN gets
the type `"unknown_with_ein"`.
