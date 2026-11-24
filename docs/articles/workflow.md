# Workflow: from Schedule N to merger estimates

A study of nonprofit mergers with **npmerger** has three stages. Each
one is a single function, and each writes its tables to one project
database.

| Stage | Function | What it builds | Reads |
|----|----|----|----|
| 1\. Mergers | [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md) | Schedule N labels, merger cases, donor and recipient tables, Part VII rosters, leadership outcomes, typology | Schedule N, plus the returns of the organizations involved |
| 2\. Matching | [`build_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_match_data.md) | The full 990 panel, the research sample, the comparison pool, candidates, balance | Every 990 and 990-EZ return |
| 3\. Model data | [`build_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_model_data.md) | Treated units, control sets, donor sums, the outcome panel | Stages 1 and 2 |

The models then run from the stage 3 data:
[`merger_did()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md)
for the main estimates,
[`did_breakouts()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md),
[`did_sensitivity()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md),
and
[`did_event_study()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_event_study.md).

**Stage 1 stands on its own.** Finding mergers needs only Schedule N and
the returns of the organizations that filed it or received assets. If
you only want a list of mergers, stop there. Stages 2 and 3 are for
comparing merger recipients with organizations that did not merge.

``` r
library( npmerger )
library( data.table )
```

## The project folder

[`merger_project()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_project.md)
creates a folder that holds one build:

``` r
proj <- merger_project( "~/Documents/NPMERGER" )
```

    NPMERGER/
      PANEL990/          panel990 download cache (reused by later builds)
      npmerger.duckdb    every table, plus build_log and build_settings
      logs/              one log per stage run, <stage>-<time>.log
      results/           model estimates
      README.md          tables, row counts, and the build log

[`build_merger_database()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_database.md)
runs the stages into that folder:

``` r
build_merger_database(
  project = proj,
  stages  = c( "merger", "match", "model" ),
  years   = efile_years()
)
```

Each stage reads what it needs from the database, so you can rerun a
later stage, for example with different matching calipers, without
repeating the earlier ones:

``` r
build_merger_database(
  project    = proj,
  stages     = c( "match", "model" ),
  match_args = list( ntee_chars = 3L )
)
```

Every stage run writes a log with the package versions, git commit,
settings, a timestamped line for each step, and
[`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html). It also
adds a row to the `build_log` table.

## Stage 1: find the mergers

[`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)
downloads Schedule N, classifies every filing, and builds the tables
about each merger. Here it runs offline on the bundled extract of 2021
filings:

``` r
ex <- npmerger_example()

md <-
  build_merger_data(
    sn       = ex$sn,
    evidence = ex$evidence,
    core     = ex$core,
    names    = ex$names,
    bmf_data = ex$bmf,
    ratios   = FALSE,
    verbose  = FALSE
  )

md
#> <merger_data>
#> Schedule N filings by type:
#>   merger2                  8
#>   asset_transfer           6
#>   closure                  6
#>   mergerN                  4
#>   consolidation            4
#>   asset_disposition        1
#> Tables:
#>   cases            16 rows
#>   transfers        16 rows
#>   donors           16 rows
#>   recipients       16 rows
#>   part7          1618 rows
#>   fiscal          166 rows
#>   leadership       11 rows
#>   typology         16 rows
```

On the full data, the same call takes `years` and a cache folder instead
of the pre-fetched tables:

``` r
md <-
  build_merger_data(
    years = efile_years(),
    path  = proj$cache
  )
```

Two of the tables describe the merger itself rather than the filings:

``` r
md$typology[ , .( MERGER_ID, TYPE, TYPOLOGY, RATIO ) ] |> head()
#> Key: <MERGER_ID>
#>                   MERGER_ID          TYPE                        TYPOLOGY
#>                      <char>        <char>                          <fctr>
#> 1: 2021-132890752-861250084 consolidation Consolidation into a new entity
#> 2: 2021-141732612-141670547       merger2 Program or asset-light transfer
#> 3: 2021-232659951-300994771       merger2           Merger of near-equals
#> 4: 2021-263889207-861250084 consolidation Consolidation into a new entity
#> 5: 2021-431339285-436034533       mergerN          Multi-party absorption
#> 6: 2021-454035038-861250084 consolidation Consolidation into a new entity
#>        RATIO
#>        <num>
#> 1:        NA
#> 2: 0.0000000
#> 3: 0.7784352
#> 4:        NA
#> 5: 0.5011514
#> 6:        NA
```

`md$leadership` records what happened to the two chief executives and
the two boards
([`merger_leadership()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_leadership.md)).
It needs rosters on both sides of the merger, so it is empty for this
one-year extract.

## Stage 2: build the comparison data

[`build_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_match_data.md)
reads every 990 filer into one panel and finds comparison organizations
for each merger recipient. See
[`vignette("matching")`](https://nonprofit-open-data-collective.github.io/npmerger/articles/matching.md)
for the design. The rest of this page uses a simulated panel of 600
organizations, 30 of which absorb another organization in 2015 and grow
by about 30% afterwards.

``` r
mm <-
  build_match_data(
    merger_data = sim,
    panel       = panel,
    verbose     = FALSE
  )

mm
#> <merger_match_data>
#>   panel:     5,400 org-years
#>   sample:    30 cases, 30 treated units
#>   pool:      2,862 org-years
#>   margin:    30 of 30 treated matched, median 394 candidates
#>   equity:    30 of 30 treated matched, median 229.5 candidates
```

On the full data, leave out `panel` and give the cache folder. The panel
is built from the same files stage 1 downloaded:

``` r
mm <- build_match_data( md, path = proj$cache )
```

## Stage 3: assemble the model data

[`build_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_model_data.md)
does the slow joins once. It keeps one row per treated recipient with
its breakout variables, the closest candidate controls for every
matching specification (plus a match on the combined recipient and donor
baseline), donor sums for the pro forma outcomes, and only the
organization-years the models read.

``` r
dd <- build_model_data( sim, mm, verbose = FALSE )

dd
#> <merger_model_data>
#>   units:      30 treated recipients (30 without other mergers in the window)
#>   r_margin:   584 candidate rows
#>   r_equity:   587 candidate rows
#>   c_margin:   575 candidate rows
#>   panel:      3,029 org-years
#>   limits:     k <= 10, year gap <= 2
```

`max_k` and `max_year_gap` set the largest control sets and
calendar-year gaps any later model can ask for (10 and 2 by default).

## Run the models

Every model reads only `dd`.
[`merger_did()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md)
gives long-difference estimates, from two years before the merger to two
years after, for each design:

``` r
fit <-
  merger_did(
    data     = dd,
    outcomes = c( "LOG_REVENUE", "MARGIN" ),
    keep     = NULL
  )

fit[ , .( design, outcome, estimate, se, n_sets ) ] |>
  knitr::kable( digits = 3 )
```

| design                      | outcome     | estimate |    se | n_sets |
|:----------------------------|:------------|---------:|------:|-------:|
| naive \| recipient match    | LOG_REVENUE |    0.261 | 0.030 |     30 |
| naive \| recipient match    | MARGIN      |    0.021 | 0.009 |     30 |
| proforma \| recipient match | LOG_REVENUE |   -0.527 | 0.134 |     30 |
| proforma \| recipient match | MARGIN      |    0.018 | 0.011 |     30 |
| proforma \| combined match  | LOG_REVENUE |   -0.548 | 0.137 |     30 |
| proforma \| combined match  | MARGIN      |    0.009 | 0.011 |     30 |

`keep = NULL` uses every treated unit. The default, `~ OTHER == FALSE`,
drops recipients involved in other mergers in the window.

The three designs are listed by
[`did_designs()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_designs.md).
The recipient alone grows by about the simulated 30% (0.26 log points).
The pro forma designs compare the merged organization with the recipient
and donor combined before the merger. In this simulation the donors are
about as large as their recipients, but the recipients grow by only 30%,
so the merged organization ends up smaller than the two were apart and
the pro forma estimates are negative.

### Breakouts

Interact treatment with any unit-level variable from
[`did_breakout_vars()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_breakout_vars.md):

``` r
br <-
  did_breakouts(
    data     = dd,
    by       = "AFFILIATED",
    outcomes = "LOG_REVENUE",
    designs  = "naive | recipient match",
    keep     = NULL
  )

br[ , .( spec, term, estimate, se ) ] |>
  knitr::kable( digits = 3 )
```

| spec       | term            | estimate |    se |
|:-----------|:----------------|---------:|------:|
| pooled     |                 |    0.261 | 0.030 |
| AFFILIATED | AFFILIATEDFALSE |    0.228 | 0.043 |
| AFFILIATED | AFFILIATEDTRUE  |    0.295 | 0.038 |

### Sensitivity

[`did_variants()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_variants.md)
lists the paper’s variants. Each is a set of
[`merger_did()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md)
arguments, so adding one is a single line:

``` r
v <- did_variants()[ c( "base", "k1", "gap2" ) ]

# use every unit in this small example
v <- lapply( v, modifyList, list( keep = ~ TRUE ) )

# one more: three controls per recipient
v$k3 <- modifyList( v$base, list( k = 3L ) )

sens <-
  did_sensitivity(
    data     = dd,
    variants = v,
    outcomes = "LOG_REVENUE",
    designs  = "naive | recipient match"
  )

sens[ , .( variant, estimate, se, n_sets ) ] |>
  knitr::kable( digits = 3 )
```

| variant | estimate |    se | n_sets |
|:--------|---------:|------:|-------:|
| base    |    0.261 | 0.030 |     30 |
| k1      |    0.241 | 0.042 |     30 |
| gap2    |    0.248 | 0.046 |     30 |
| k3      |    0.251 | 0.031 |     30 |

### Event study

``` r
es <-
  did_event_study(
    data     = dd,
    outcomes = "LOG_REVENUE",
    designs  = "naive | recipient match",
    keep     = NULL
  )

es[ , .( E, estimate, se ) ] |>
  knitr::kable( digits = 3 )
```

|   E | estimate |    se |
|----:|---------:|------:|
|  -3 |    0.002 | 0.027 |
|  -1 |    0.049 | 0.035 |
|   0 |    0.286 | 0.034 |
|   1 |    0.272 | 0.031 |
|   2 |    0.261 | 0.030 |

[`did_baseline_means()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_baseline_means.md),
[`did_funnel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_baseline_means.md),
and
[`did_composition()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_baseline_means.md)
describe the same samples: outcome means at `t-2`, the counts from
merger cases to the units and controls used, and the treated units in
each breakout group.

## Coming back to a project

Everything is in the database, so a later session starts from
[`load_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/load_merger_data.md)
instead of rebuilding:

``` r
proj <- merger_project( "~/Documents/NPMERGER" )

dd  <- load_model_data( proj )
fit <- merger_did( dd )
```

[`load_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/load_merger_data.md)
and
[`load_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/load_merger_data.md)
return the stage 1 and stage 2 objects, and
[`db_read()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/db_tables.md)
reads any single table:

``` r
db_tables( proj )

db_read( proj, "match_balance" )
```
