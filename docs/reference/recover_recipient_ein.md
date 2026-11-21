# Recover missing recipient EINs by name and location

About 28% of Schedule N recipient lines have no usable EIN. For lines
whose recipient is not an individual or business, this looks the
recipient's name up in an index of 990 filers. It accepts a match only
when exactly one EIN carries that normalized name in the same ZIP code,
or failing that, in the same state.

## Usage

``` r
recover_recipient_ein(
  tx,
  names,
  types = c("501c3", "other_exempt", "unknown", "other", "government")
)
```

## Arguments

- tx:

  Output of
  [`sn_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_transactions.md).

- names:

  A name index from
  [`get_name_index()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_name_index.md)
  or
  [`name_index()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_name_index.md).

- types:

  Recipient types eligible for recovery.

## Value

`tx` with recovered `RECIP_EIN` values and an `EIN_SOURCE` column
(`"reported"`, `"name_zip"`, `"name_state"`, or `NA`). Recovered lines
with an unknown type become `"unknown_with_ein"`.
