# Fill missing NTEE codes from another source

Replaces `NTEE` where the panel has no valid two-character code, and
records where each code came from in `NTEE_SOURCE` (`"bmf"`,
`"legacy_bmf_<vintage>"`, or `NA`). Codes the current BMF does have are
never replaced.

## Usage

``` r
fill_ntee(panel, legacy)
```

## Arguments

- panel:

  A panel from
  [`panel_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_measures.md)
  or
  [`get_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_panel.md).

- legacy:

  A table from
  [`legacy_ntee()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/legacy_ntee.md).

## Value

`panel` with `NTEE`, `NTEE2`, `NTEE_MAJOR` updated and `NTEE_SOURCE`.
