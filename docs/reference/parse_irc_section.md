# Classify the free-text IRC section / entity type of a Schedule N recipient

Schedule N column (g) is free text: dozens of spellings of 501(c)(3),
entity types (LLC, corporation), "individual", "government", and so on.
This maps it to a small set of recipient types.

## Usage

``` r
parse_irc_section(x)
```

## Arguments

- x:

  Character vector from `SN_01_LTD_RECIP_IRC_SECTION` or
  `SN_02_DOA_RECIP_IRC_SECTION`.

## Value

A character vector with values `"501c3"`, `"other_exempt"`,
`"government"`, `"individual"`, `"business"`, `"other"`, or `"unknown"`.

## Examples

``` r
irc <- c( "501(c)(3)", "501 C 3", "501(c)(6)", "LLC",
          "Individual", "City of Portland", NA )

parse_irc_section( irc )
#> [1] "501c3"        "501c3"        "other_exempt" "business"     "individual"  
#> [6] "government"   "unknown"     
```
