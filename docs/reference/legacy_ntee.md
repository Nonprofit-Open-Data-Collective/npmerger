# NTEE codes from NCCS legacy BMF files

The current IRS Business Master File has no usable NTEE code for about a
quarter of 990 filers (`"UNDEFINED"`), including many large charities.
The NCCS legacy BMF extracts carry the NTEE code NCCS assigned
(`NTEEFINAL`), which covers most of them. This function downloads the
extracts (once) into `path/bmf_legacy/` and returns one code per
organization, taking the first vintage in `vintages` that has a valid
code.

## Usage

``` r
legacy_ntee(
  vintages = c("2022-08", "2019-08"),
  path = "PANEL990",
  eins = NULL,
  base_url = "https://nccsdata.s3.us-east-1.amazonaws.com/legacy/bmf",
  verbose = TRUE
)
```

## Arguments

- vintages:

  Legacy BMF vintages (`"YYYY-MM"`), most preferred first.

- path:

  panel990 cache folder.

- eins:

  Optional EINs to keep.

- base_url:

  Location of the NCCS legacy BMF files.

- verbose:

  Print progress.

## Value

A data.table with `EIN2`, `NTEE_LEGACY`, and `NTEE_LEGACY_VINTAGE`.

## See also

[`fill_ntee()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/fill_ntee.md)
