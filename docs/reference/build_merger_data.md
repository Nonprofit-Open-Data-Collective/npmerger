# Build the full merger dataset

Runs the whole pipeline: Schedule N retrieval, EIN recovery,
filing-level features, merger evidence, classification, merger cases,
transfer values, donor and recipient attributes, the Part VII panel, and
the fiscal panel. Every stage is also available as its own function.

## Usage

``` r
build_merger_data(
  years = NULL,
  path = "PANEL990",
  rules = merger_rules(),
  types = c("merger2", "mergerN", "consolidation"),
  recover_eins = TRUE,
  pre = 5L,
  post = 5L,
  years_back = 4L,
  ratios = TRUE,
  fit = NULL,
  weights = NULL,
  smooth = c("none", "trailing"),
  k = 3L,
  bmf = TRUE,
  sn = NULL,
  evidence = NULL,
  core = NULL,
  names = NULL,
  bmf_data = NULL,
  verbose = TRUE
)
```

## Arguments

- years:

  Schedule N tax years. Ignored when `sn` is supplied.

- path:

  Cache directory for all downloads.

- rules:

  A
  [`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md)
  object.

- types:

  Transaction types that become merger cases.

- recover_eins:

  Recover missing recipient EINs by name
  ([`recover_recipient_ein()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/recover_recipient_ein.md)).

- pre, post:

  Years before and after the merger in the fiscal panel.

- years_back:

  Years before the merger in the attribute tables.

- ratios, fit, weights, smooth, k:

  Passed to
  [`merger_fiscal_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_fiscal_panel.md).

- bmf:

  Retrieve BMF traits (NTEE, ruling year) for attributes.

- sn, evidence, core, names, bmf_data:

  Optional pre-fetched inputs.

- verbose:

  Print progress.

## Value

A list of class `merger_data` with `sched_n` (one row per Schedule N
filing), `cases`, `transfers`, `donors`, `recipients`, `part7`,
`fiscal`, `transactions` (asset lines), and `manifest` (row counts per
stage).

## Details

Pre-fetched inputs (`sn`, `evidence`, `core`, `names`, `bmf_data`) are
used instead of retrieving them, which makes it possible to run the
pipeline offline, for example on
[`npmerger_example()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/npmerger_example.md).

## Examples

``` r
ex <- npmerger_example()
md <- build_merger_data(sn = ex$sn, evidence = ex$evidence, core = ex$core,
                        names = ex$names, bmf_data = ex$bmf, ratios = FALSE)
md
#> <merger_data>
#> Schedule N filings by type:
#>   merger2                  9
#>   asset_transfer           5
#>   mergerN                  4
#>   closure                  4
#>   consolidation            4
#>   asset_disposition        3
#> Tables:
#>   cases            17 rows
#>   transfers        17 rows
#>   donors           17 rows
#>   recipients       17 rows
#>   part7          1786 rows
#>   fiscal          181 rows
```
