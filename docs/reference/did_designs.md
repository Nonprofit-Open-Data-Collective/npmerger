# Designs for the merger models

- `"naive | recipient match"`: the recipient alone, against controls
  matched to the recipient;

- `"proforma | recipient match"`: before the merger, recipient plus
  donor(s); after, the recipient; same controls;

- `"proforma | combined match"`: the same outcome, against controls
  matched to the combined recipient + donor baseline.

## Usage

``` r
did_designs()
```

## Value

A character vector of design names.
