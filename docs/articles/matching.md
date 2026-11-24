# Matched comparison samples for merger recipients

To ask what a merger does to the organization that absorbs another one,
we need to know how that recipient would have done without the merger.
This page builds a comparison group for that purpose. For each merger
recipient, it finds every other nonprofit that looked similar a few
years before the merger: the same field, about the same size, and
similar finances. It also requires that both the recipient and its
comparison organizations have returns for two years before and two years
after.

``` r
library(npmerger)
library(data.table)
```

## The design in brief

| Step | Function | What it does |
|----|----|----|
| Panel | [`get_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_panel.md) | One row per organization and year for every 990 and 990-EZ filer, with size in constant 2024 dollars and profitability and fiscal-health ratios. |
| Research sample | [`merger_sample()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_sample.md) | Keeps `merger2` cases (one donor, one recipient) whose recipient filed in every year from t-2 to t+2. Baselines are the mean of t-3 and t-2. |
| Exclusions | [`schedule_n_events()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/schedule_n_events.md) | Lists every organization-year that filed Schedule N or was named as a recipient. |
| Pool | [`match_pool()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_pool.md) | Every organization-year Y with returns from Y-2 to Y+2 and no Schedule N involvement in Y-3..Y+2. |
| Candidates | [`match_candidates()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_candidates.md) | Every pool organization-year in the same NTEE group, within the size and finance limits, ranked by distance. |
| Balance | [`match_balance()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_balance.md) | Standardized differences between recipients and their closest candidates. |

[`build_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_match_data.md)
runs all of these steps in one call.

**Matches can come from any year.** A recipient that merged in 2016 can
be compared with an organization observed around 2012 or 2020, as long
as that organization has its own full five-year window. Dollar amounts
are in constant 2024 dollars, so size is comparable across years.

**What a match requires** (all adjustable):

- the same NTEE code at two characters (e.g. `E2`, hospitals and primary
  care). Use `ntee_chars = 3` for the full code;
- total assets and total expenses each within a factor of 2
  (`size_caliper = log(2)`);
- operating margin within ±0.10, or, in the second specification, equity
  ratio (net assets / assets) within ±0.15 (`health_caliper`).

All candidates within the limits are kept and ranked by a standardized
distance (`RANK` 1 is the closest), so you can choose one nearest
neighbour, the closest five, or the full set with weights.

## A small worked example

The real panel has more than six million organization-years. To show the
mechanics, we simulate a small panel of 400 organizations in four NTEE
groups and ten merger recipients.

First, 400 organizations, each with an NTEE code, a typical size, and
the year it first files:

``` r
set.seed(1)

EIN2  <- sprintf( "ORG-%03d", 1:400 )
NTEE  <- sample( c("E21", "E22", "P20", "B82"), 400, TRUE )
SIZE  <- exp( rnorm(400, 14, 1.5) )
FIRST <- sample( 2009:2014, 400, TRUE )

orgs <- data.table( EIN2, NTEE, SIZE, FIRST )
```

Next, a panel with nine years of returns for each one. `by =` runs the
expression once per organization, so each row of `orgs` becomes nine
organization-years:

``` r
panel <-
  orgs[ , .( TAX_YEAR = FIRST:(FIRST + 8L) ),
        by = .( EIN2, NTEE, SIZE ) ]
```

Then the financial measures that matching uses. Size varies a little
around each organization’s typical value from year to year:

``` r
panel[ , `:=`(
  REAL_ASSETS   = SIZE * exp( rnorm(.N, 0, 0.1) ),
  REAL_EXPENSES = 0.6 * SIZE * exp( rnorm(.N, 0, 0.1) ),
  MARGIN        = rnorm( .N, 0.03, 0.08 ),
  EQUITY_RATIO  = runif( .N, 0.2, 0.9 )
) ]

panel[ , `:=`(
  REAL_REVENUE = REAL_EXPENSES / (1 - MARGIN),
  MONTHS_CASH  = runif( .N, 0, 12 ),
  EMPLOYEES    = round( REAL_EXPENSES / 8e4 ),
  NTEE2        = ntee_level( NTEE, 2L )
) ]

setkey( panel, EIN2, TAX_YEAR )
```

Last, the mergers. Organizations 1-10 absorb organizations 11-20 in
2015, and the ten donors file Schedule N that year:

``` r
DONOR_EIN2 <- orgs$EIN2[ 11:20 ]
RECIP_EIN2 <- orgs$EIN2[ 1:10 ]
MERGER_ID  <- paste0( "M", 1:10 )

cases <-
  data.table(
    MERGER_ID,
    MERGER_GROUP_ID   = MERGER_ID,
    TYPE              = "merger2",
    DONOR_EIN2,
    RECIP_EIN2,
    MERGER_YEAR       = 2015L,
    RECIP_MERGER_YEAR = 2015L
  )

sched_n <- data.table( EIN2 = DONOR_EIN2, TAX_YEAR = 2015L )
```

[`build_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_match_data.md)
takes the list that
[`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)
returns. Here we pass only the two tables it uses.

``` r
md <- list( cases = cases, sched_n = sched_n )

mm <-
  build_match_data(
    merger_data = md,
    panel       = panel,
    verbose     = FALSE
  )

mm
#> <merger_match_data>
#>   panel:     3,600 org-years
#>   sample:    7 cases, 7 treated units
#>   pool:      1,960 org-years
#>   margin:    7 of 7 treated matched, median 89 candidates
#>   equity:    7 of 7 treated matched, median 62 candidates
```

Recipients drop out of the research sample when they did not file in
every year from t-2 to t+2. The coverage table counts, for each
specification, how many treated units have candidates and how many they
have:

``` r
mm$coverage
#>      SPEC TREATED MATCHED N_GE_5 N_GE_25 MEAN_CANDIDATES MEDIAN_CANDIDATES
#>    <char>   <int>   <int>  <int>   <int>           <num>             <int>
#> 1: margin       7       7      7       4       121.00000                89
#> 2: equity       7       7      7       4        85.57143                62
#>    SAME_YEAR_SHARE
#>              <num>
#> 1:       0.1782763
#> 2:       0.1702838
```

Each candidate row pairs a treated unit (`T_ID`, the merger year and the
recipient’s EIN) with a comparison organization-year (`C_EIN2`,
`C_YEAR`). `YEAR_GAP` is the difference in calendar years, and the `D_*`
columns are the differences on each matching variable.

``` r
cand <- mm$candidates$margin

cand[ , .( T_ID, C_EIN2, C_YEAR, NTEE_KEY,
           YEAR_GAP, D_MARGIN, DIST, RANK ) ] |> head()
#>            T_ID  C_EIN2 C_YEAR NTEE_KEY YEAR_GAP      D_MARGIN       DIST  RANK
#>          <char>  <char>  <int>   <char>    <int>         <num>      <num> <int>
#> 1: 2015-ORG-001 ORG-052   2017       E2        2  1.363188e-03 0.06060345     1
#> 2: 2015-ORG-001 ORG-188   2017       E2        2  1.991534e-05 0.06123313     2
#> 3: 2015-ORG-001 ORG-072   2014       E2       -1  7.121334e-03 0.06564575     3
#> 4: 2015-ORG-001 ORG-318   2016       E2        1  7.000750e-03 0.07030736     4
#> 5: 2015-ORG-001 ORG-318   2015       E2        0 -4.649965e-03 0.07190711     5
#> 6: 2015-ORG-001 ORG-110   2015       E2        0  6.722586e-03 0.08012521     6
```

The same comparison organization can appear in several years (here
`ORG-318` in 2015 and 2016), because each of its organization-years is a
separate candidate. To use each organization once per treated unit, keep
its closest year:

``` r
# closest first, then drop later years of the same organization
cand <- cand[ order( T_ID, DIST ) ]
dup  <- duplicated( cand[ , .( T_ID, C_EIN2 ) ] )

one_per_org <- cand[ !dup ]

nrow( cand )
#> [1] 847
nrow( one_per_org )
#> [1] 242
```

Balance compares treated units with their closest `k` candidates, and
with the whole pool in the same NTEE groups:

``` r
bal <-
  mm$balance[ SPEC == "margin" & K == 5,
              .( VAR, TREATED, MATCHED, SMD_MATCHED, SMD_POOL ) ]

bal |> knitr::kable( digits = 3 )
```

| VAR               | TREATED | MATCHED | SMD_MATCHED | SMD_POOL |
|:------------------|--------:|--------:|------------:|---------:|
| log REAL_ASSETS   |  15.476 |  15.406 |       0.047 |    0.994 |
| log REAL_EXPENSES |  15.011 |  14.884 |       0.084 |    1.009 |
| log REAL_REVENUE  |  14.979 |  14.860 |       0.080 |    0.970 |
| MARGIN            |  -0.039 |  -0.028 |      -0.191 |   -1.249 |
| EQUITY_RATIO      |   0.488 |   0.552 |      -0.459 |   -0.413 |
| MONTHS_CASH       |   6.764 |   5.203 |       0.472 |    0.252 |

To change the design, pass different arguments. For example, require the
full three-character NTEE code, match on months of cash, and keep
candidates within four years of the merger:

``` r
alt <-
  build_match_data(
    merger_data  = md,
    panel        = panel,
    health       = c( cash = "MONTHS_CASH" ),
    ntee_chars   = 3L,
    max_year_gap = 4,
    verbose      = FALSE
  )

alt$coverage
#>      SPEC TREATED MATCHED N_GE_5 N_GE_25 MEAN_CANDIDATES MEDIAN_CANDIDATES
#>    <char>   <int>   <int>  <int>   <int>           <num>             <int>
#> 1:   cash       7       7      7       4        33.42857                25
#>    SAME_YEAR_SHARE
#>              <num>
#> 1:       0.1794872
```

## Running it on the full data

``` r
md <-
  build_merger_data(
    years = efile_years(),
    path  = "PANEL990"
  )

# builds the full 990 panel first (several minutes)
mm <- build_match_data( md, path = "PANEL990" )

# the five closest comparison org-years for each recipient
top5 <- mm$candidates$margin[ RANK <= 5 ]
```

[`build_merger_database()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_database.md)
runs this as the “match” stage of a project and writes every table to
the project’s DuckDB database. See
[`vignette("workflow")`](https://nonprofit-open-data-collective.github.io/npmerger/articles/workflow.md).

**NTEE codes.** The current IRS Business Master File has no NTEE code
for about a quarter of filers (it reports `"UNDEFINED"`), including many
large charities.
[`get_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_panel.md)
fills those from the code NCCS assigned in its legacy BMF extracts
([`legacy_ntee()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/legacy_ntee.md),
[`fill_ntee()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/fill_ntee.md)),
and records the source in `NTEE_SOURCE`. Codes the current BMF does have
are never replaced. Where both sources have a code they agree on 75% at
two characters, so you may want a sensitivity check limited to
`NTEE_SOURCE == "bmf"`.

## Results from the full run (November 2026)

The full panel has 6.2 million organization-years from 809,497
organizations (2009–2025). Of 9,984 `merger2` cases, 4,524 have a
recipient with returns from t-2 to t+2, giving 4,507 treated units. The
pool has 3.0 million organization-years from 506,514 organizations.

| Specification | NTEE match | Treated units matched | At least 25 candidates | Mean candidates | Median candidates | Largest abs. SMD, k = 5 |
|----|----|----|----|----|----|----|
| Margin | 2 characters | 4,399 (98%) | 3,954 | 1,110 | 476 | 0.03 |
| Equity ratio | 2 characters | 4,394 (97%) | 4,016 | 1,139 | 498 | 0.03 |
| Margin | 3 characters | 4,335 (96%) | 3,617 | 571 | 202 | 0.01 |
| Equity ratio | 3 characters | 4,304 (95%) | 3,661 | 615 | 210 | 0.03 |

Mean and median candidates are among matched units. Only about 9% of
candidate pairs fall in the same calendar year as the merger.

**About three-character codes.** 1,598 of the treated recipients have a
code ending in 0 (for example `E20`, “hospitals” without a more specific
type). Matching on three characters pairs those only with other
organizations coded at the same general level, not with the more
specific codes under them. That is one reason the two-character match is
the default.

The treated units left unmatched in the two-character margin
specification are mostly very large organizations with no comparison
organization within a factor of 2 on both assets and expenses (69 units,
median assets \$149 million), units missing a baseline value (25), and
units with no NTEE code from either source (14).
