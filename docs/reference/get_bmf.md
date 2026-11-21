# Retrieve BMF organization traits for merger organizations

Thin wrapper around
[`panel990::bmf_retrieve()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_retrieve.html)
for a set of EINs. The BMF supplies NTEE codes and IRS ruling dates for
[`merger_attributes()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_attributes.md).

## Usage

``` r
get_bmf(eins, path = "PANEL990", verbose = TRUE, ...)
```

## Arguments

- eins:

  EINs (any format).

- path, verbose:

  Passed to
  [`panel990::bmf_retrieve()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_retrieve.html).

- ...:

  Further arguments to
  [`panel990::bmf_retrieve()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_retrieve.html).

## Value

A data.table with one row per `EIN2`.
