# Overview: finding nonprofit mergers in IRS 990 data

Nonprofit mergers are rare, hard to see, and easy to confuse with other
ways an organization winds down. **npmerger** builds research datasets
of mergers from IRS Form 990 e-file data:

1.  It finds candidate transactions in **Schedule N**.
2.  It decides which of them are mergers rather than closures or asset
    sales.
3.  It assembles the tables needed to study what happens to the
    organizations involved.

Data comes from the NCCS e-file release through
[panel990](https://nonprofit-open-data-collective.github.io/panel990/),
and fiscal-health metrics come from
[fiscal](https://github.com/Nonprofit-Open-Data-Collective/fiscal).

> **Status.** The full pipeline works, from Schedule N through the
> analysis tables. The classifier has been checked against 300
> hand-labeled filings; see [How the classifier separates mergers from
> other
> cases](https://nonprofit-open-data-collective.github.io/npmerger/articles/classifier.md)
> and the
> [roadmap](https://github.com/Nonprofit-Open-Data-Collective/npmerger/blob/main/PLAN.md).

## What counts as a merger

Following the Wilder Research study of Minnesota mergers, a merger is
the integration of two or more organizations into one legal entity, in
which at least one organization ceases to exist and its programs,
assets, or staff move to the successor. In 990 data that means three
things have to be visible:

- **The donor closes.** It files Schedule N Part I (liquidation,
  termination, or dissolution). Its final return usually shows assets
  near zero.
- **Its assets go to a nonprofit successor.** One nonprofit recipient
  receives most of the transferred value. Assets that are scattered
  across many charities, or go to individuals or businesses, look like a
  closure.
- **People go with them.** Officers, directors, or key employees join
  the successor.

The recipient keeps operating in almost every case, so that condition
adds little information. Leadership continuity and the concentration of
transferred assets are what separate a merger from a closure.

## Where the evidence comes from

**Schedule N.** Part I lists each asset distributed by an organization
that dissolved: a description, the date, fair market value (FMV), and
the recipient’s name, EIN, address, and IRC section. Part II lists the
same for an organization that disposed of more than 25% of its net
assets and kept operating. Lines 2a–2c ask whether any officer,
director, trustee, or key employee became a director, employee, or owner
of the successor.

**Part VII.** Those Schedule N boxes are under-reported. npmerger also
matches the people listed on the donor’s Part VII (years t-1 and t)
against the recipient’s Part VII (years t and t+1). In 2019–21 data,
87–100% of donor–recipient pairs that checked a box shared at least one
person, against 9% for closures. About 40% of asset transfers with no
box checked shared people too. Leadership continuity counts when either
source shows it.

**Schedule N’s own text.** When the asset descriptions or Part III
explanation say the transfer is part of a merger or consolidation
([`sn_merger_pattern()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_merger_pattern.md)),
that counts as merger evidence on its own. In hand validation every
terminated filing with one successor and such text read as a merger.

**Corroborating disclosures.** These are recorded for every filing. With
`merger_rules(promote = TRUE)`, a dissolution to one nonprofit successor
with no other merger evidence is promoted to a merger when at least two
of them agree. Promotion is off by default, because in hand validation
few promoted filings read as mergers. The signals are:

- merger language in the donor’s Schedule O narrative;
- merger language in the recipient’s Schedule O narrative;
- a significant change to the recipient’s governing documents (Part VI
  line 4) in the merger year or the year after.

**Affiliation** is recorded separately from the label. It covers
Schedule R links, 509(a)(3) supporting organizations, group exemptions,
and chapters. About a third of two-party mergers and two-thirds of
multi-party mergers happen inside one family of organizations, and many
analyses will want to separate them from arm’s-length mergers.

## Transaction types

``` r
library(npmerger)
transaction_types()
#> [1] "merger2"           "mergerN"           "consolidation"    
#> [4] "asset_transfer"    "closure"           "asset_disposition"
#> [7] "reorganization"    "other"
```

| Label | Meaning |
|----|----|
| `merger2` | Dissolved; one dominant nonprofit successor; leadership continuity or corroboration |
| `mergerN` | The same, where the successor absorbs two or more dissolving organizations |
| `consolidation` | A `mergerN` into a newly formed entity |
| `asset_transfer` | Dissolved; one dominant nonprofit successor; no continuity evidence |
| `closure` | Dissolved; assets dispersed, or not going to a nonprofit |
| `asset_disposition` | Part II only: more than 25% of net assets transferred, organization continues |
| `reorganization` | Assets transferred to the filer’s own EIN |

A first pass over 2019–21 filings (14,399 Schedule N returns) gave these
shares. This was before corroboration was applied, and it used Schedule
N flags or Part VII overlap as the leadership evidence:

| Label             | Filings | Share |
|-------------------|---------|-------|
| closure           | 5,784   | 40%   |
| asset_disposition | 3,250   | 23%   |
| asset_transfer    | 2,632   | 18%   |
| merger2           | 2,306   | 16%   |
| mergerN           | 427     | 3%    |

## The pipeline

[`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)
runs everything and returns every table:

``` r
md <-
  build_merger_data(
    years = 2019:2021,
    path  = "PANEL990"
  )
```

Each stage is also a separate function, so you can stop at any point,
inspect the result, or substitute your own step:

``` r
# Schedule N tables, via panel990
sn <- get_schedule_n( 2019:2021 )

# one row per asset line, Parts I and II
tx <- sn_transactions( sn )

# fill missing recipient EINs by name (index covers t-1 to t+1)
name_index <- get_name_index( 2018:2022 )
tx <- recover_recipient_ein( tx, name_index )

# one row per Schedule N filing
fl <- sn_filings( sn, tx )

# 990 tables for the donors and recipients
ev <- get_evidence_tables( fl )

# add the evidence to each filing
fe <- merger_features( fl, ev )

# labels, plus the evidence behind them
lab <- classify_transactions( fe )

# YEAR, OBJECTID, EIN2, TYPE, evidence
sched_n_table( lab )
```

[`get_schedule_n()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_schedule_n.md)
downloads about 1 MB per tax year.
[`get_evidence_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_evidence_tables.md)
is much heavier on its first run: Schedule O is about 150 MB per year
and Part VII about 100 MB. Both cache what they download, and the
evidence step then reads only the rows for the organizations involved.

[`merger_features()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_features.md)
adds one group of columns per kind of evidence:

| Function | Adds | Source |
|----|----|----|
| [`leader_overlap()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/leader_overlap.md) | `LEADER_P7`, `N_SHARED_P7` | Part VII names, donor t-1..t vs recipient t..t+1 |
| [`add_donor_counts()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_donor_counts.md) | `N_DONORS` | Other dissolving donors with the same dominant successor, t±1 |
| [`add_filing_history()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_filing_history.md) | `FINAL_RETURN`, `DONOR_FILES_LATER`, `R_FORMED`, `R_NEW` | 990 header |
| [`add_corroboration()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_corroboration.md) | `SO_MERGER_TEXT_DONOR`, `SO_MERGER_TEXT_RECIP`, `GOV_DOC_CHANGE_RECIP` | Schedule O, Part VI line 4 |
| [`add_affiliation()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_affiliation.md) | `AFF_SCHED_R`, `AFF_SUPPORT_ORG`, `AFF_GROUP`, `AFFILIATED` | Schedule R Part II, Schedule A, group exemption number |
| [`add_mission_similarity()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_mission_similarity.md) | `MISSION_SIM` | Part III mission statements |

### Cleaning

Schedule N is messy, and the low-level helpers handle the recurring
problems. Checkboxes come in several encodings:

``` r
flags <- c( "1", "true", "X", "0", "false", NA )

sn_flag( flags )
#> [1]  TRUE  TRUE  TRUE FALSE FALSE    NA
```

Recipient EINs arrive in many formats, including placeholders:

``` r
eins <- c( "01-0215911", "10215911", "000000000", "EIN-01-0215911" )

clean_ein( eins )
#> [1] "010215911" "010215911" NA          "010215911"

as_ein2( "010215911" )
#> [1] "EIN-01-0215911"
```

The recipient’s IRC section is free text, with dozens of spellings of
501(c)(3) alone:

``` r
irc <- c( "501(c)(3)", "501 C 3", "501(c)(6)", "LLC",
          "Individual", "City of Portland", NA )

parse_irc_section( irc )
#> [1] "501c3"        "501c3"        "other_exempt" "business"     "individual"  
#> [6] "government"   "unknown"
```

[`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md)
also deals with Schedule N’s header and asset tables not lining up. Some
filings have only one or the other, so the filing list is built from
both.

### Classifying

[`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md)
takes a filing-level table and adds a label, plus the evidence used to
reach it. Here is a small made-up example with one filing of each kind:

``` r
case <- c( "sale", "dispersed", "flags",
           "part7", "corroborated", "no evidence" )
recip <- "020000002"   # the one nonprofit successor

filings <-
  data.frame(
    case,
    EIN2          = paste0( "EIN-01-000000", 1:6 ),
    HAS_P1        = c( FALSE, TRUE, TRUE, TRUE, TRUE, TRUE ),
    HAS_P2        = c( TRUE, FALSE, FALSE, FALSE, FALSE, FALSE ),
    LEADER_SN     = c( FALSE, FALSE, TRUE, FALSE, FALSE, FALSE ),
    LEADER_P7     = c( FALSE, FALSE, FALSE, TRUE, FALSE, FALSE ),
    N_NP_RECIP    = c( 0L, 6L, 1L, 1L, 1L, 1L ),
    TOP_SHARE     = c( NA, 0.2, 1, 1, 1, 1 ),
    TOP_RECIP_EIN = c( NA, rep( recip, 5 ) ),
    SO_MERGER_TEXT_DONOR =
      c( FALSE, FALSE, FALSE, FALSE, TRUE, FALSE ),
    GOV_DOC_CHANGE_RECIP =
      c( FALSE, FALSE, FALSE, FALSE, TRUE, FALSE )
  )

out <- classify_transactions( filings )

cols <- c( "case", "LEADER", "N_CORROBORATE", "BASIS", "TYPE" )
out[ , ..cols ]
#>            case LEADER N_CORROBORATE  BASIS              TYPE
#>          <char> <lgcl>         <int> <char>            <char>
#> 1:         sale  FALSE             0   <NA> asset_disposition
#> 2:    dispersed  FALSE             0   <NA>           closure
#> 3:        flags   TRUE             0 leader           merger2
#> 4:        part7   TRUE             0 leader           merger2
#> 5: corroborated  FALSE             2   <NA>    asset_transfer
#> 6:  no evidence  FALSE             0   <NA>    asset_transfer
```

The rules are arguments, so you can run strict and broad definitions
side by side. For example, a strict definition counts only the Schedule
N boxes, and a broad one turns promotion on:

``` r
strict_rules <- merger_rules( leader = "sn" )
broad_rules  <- merger_rules( promote = TRUE )

strict <- classify_transactions( filings, strict_rules )
broad  <- classify_transactions( filings, broad_rules )

data.frame(
  case    = filings$case,
  strict  = strict$TYPE,
  default = out$TYPE,
  broad   = broad$TYPE
)
#>           case            strict           default             broad
#> 1         sale asset_disposition asset_disposition asset_disposition
#> 2    dispersed           closure           closure           closure
#> 3        flags           merger2           merger2           merger2
#> 4        part7    asset_transfer           merger2           merger2
#> 5 corroborated    asset_transfer    asset_transfer           merger2
#> 6  no evidence    asset_transfer    asset_transfer    asset_transfer
```

[`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md)
also sets these thresholds and switches:

- the minimum share of transferred value going to the dominant recipient
  (`min_top_share`, default 0.75);
- whether a Part-II-only filing with the final-return box counts as a
  termination (`final_as_termination`, default `TRUE`);
- how many dissolving donors make a merger multi-party (`min_donors_n`);
- how recently a recipient must have been formed to count as a new
  entity (`new_entity_years`).

## Merger identifiers

Every donor–recipient pair gets an ID of the form `YEAR-FROMEIN-TOEIN`,
where the year is the donor’s Schedule N tax year. A group ID ties
together all the donors that fold into one recipient:

``` r
merger_id( 2020, "01-0215911", "010431680" )
#> [1] "2020-010215911-010431680"

merger_group_id( 2020, "010431680" )
#> [1] "2020-010431680"
```

## Output tables

The package ships a small extract of real 2021 filings, so the whole
pipeline can run offline. Here it is run without the **fiscal** ratios,
to keep this page quick:

``` r
# bundled inputs: sn, evidence, core, names, bmf
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

### Schedule N table

`md$sched_n` has one row per Schedule N filing, with its label and the
evidence behind it:

``` r
cols <- c( "TAX_YEAR", "OBJECTID", "EIN2", "TYPE",
           "BASIS", "AFFILIATED", "N_DONORS" )

md$sched_n[ , ..cols ] |> head()
#>    TAX_YEAR               OBJECTID           EIN2           TYPE  BASIS
#>       <int>                 <char>         <char>         <char> <char>
#> 1:     2021 OID-202440449349301959 EIN-04-2305850 asset_transfer   <NA>
#> 2:     2021 OID-202222529349300142 EIN-13-2890752  consolidation leader
#> 3:     2021 OID-202213189349309256 EIN-13-6737136        closure   <NA>
#> 4:     2021 OID-202302299349200025 EIN-14-1732612        merger2 leader
#> 5:     2021 OID-202331009349300123 EIN-23-2659951        merger2 leader
#> 6:     2021 OID-202231339349309508 EIN-23-7401639        closure   <NA>
#>    AFFILIATED N_DONORS
#>        <lgcl>    <int>
#> 1:      FALSE        1
#> 2:       TRUE        4
#> 3:      FALSE       NA
#> 4:      FALSE        1
#> 5:      FALSE        1
#> 6:      FALSE       NA
```

### Merger cases

`md$cases` has one row per donor–recipient pair.

- `MERGER_YEAR` is time 0 for the donor.
- `RECIP_MERGER_YEAR` is time 0 for the recipient: the recipient’s tax
  year that contains the asset distribution date. It can differ from the
  donor’s year when the two keep different fiscal years.
- `MERGER_GROUP_ID` and `N_GROUP` tie together the donors that fold into
  the same successor.

``` r
cols <- c( "MERGER_ID", "MERGER_GROUP_ID", "TYPE",
           "MERGER_YEAR", "RECIP_MERGER_YEAR",
           "N_GROUP", "FMV_TO_RECIP" )

md$cases[ , ..cols ]
#>                    MERGER_ID MERGER_GROUP_ID          TYPE MERGER_YEAR
#>                       <char>          <char>        <char>       <int>
#>  1: 2021-132890752-861250084  2021-861250084 consolidation        2021
#>  2: 2021-141732612-141670547  2021-141670547       merger2        2021
#>  3: 2021-232659951-300994771  2021-300994771       merger2        2021
#>  4: 2021-263889207-861250084  2021-861250084 consolidation        2021
#>  5: 2021-431339285-436034533  2021-436034533       mergerN        2021
#>  6: 2021-454035038-861250084  2021-861250084 consolidation        2021
#>  7: 2021-463851186-880330858  2021-880330858       mergerN        2021
#>  8: 2021-464830921-382426175  2021-382426175       merger2        2021
#>  9: 2021-560478530-436034533  2021-436034533       mergerN        2021
#> 10: 2021-561479296-581344392  2021-581344392       merger2        2021
#> 11: 2021-742275383-840510404  2021-840510404       merger2        2021
#> 12: 2021-820603982-860858401  2021-860858401       merger2        2021
#> 13: 2021-830686168-383043861  2021-383043861       merger2        2021
#> 14: 2021-843640492-861250084  2021-861250084 consolidation        2021
#> 15: 2021-853056693-844965336  2021-844965336       merger2        2021
#> 16: 2021-880387136-880330858  2021-880330858       mergerN        2021
#>     RECIP_MERGER_YEAR N_GROUP FMV_TO_RECIP
#>                 <int>   <int>        <num>
#>  1:              2021       4       621192
#>  2:              2021       1        19876
#>  3:              2020       1      3635000
#>  4:              2021       4     28420106
#>  5:              2021       2       364976
#>  6:              2021       4      3809252
#>  7:              2021       2      2244659
#>  8:              2021       1      8462698
#>  9:              2022       2      3763351
#> 10:              2021       1       286110
#> 11:              2021       1     10262017
#> 12:              2021       1        24216
#> 13:              2021       1     13857198
#> 14:              2021       4     17392454
#> 15:              2021       1         1947
#> 16:              2021       2            0
```

### Value transferred

`md$transfers` breaks the reported fair market value down by asset class
([`asset_class()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/asset_class.md)).

- `FMV_ASSETS` excludes liabilities the recipient assumed.
- `COVERAGE` compares the transfer to the donor’s beginning-of-year
  assets. Values far above 1 are flagged in `FLAG_OUTLIER`.

``` r
cols <- c( "MERGER_ID", "FMV_TOTAL", "FMV_ASSETS", "FMV_CASH",
           "FMV_REAL_ESTATE", "COVERAGE", "FLAG_OUTLIER" )

md$transfers[ , ..cols ] |> head()
#>                   MERGER_ID FMV_TOTAL FMV_ASSETS FMV_CASH FMV_REAL_ESTATE
#>                      <char>     <num>      <num>    <num>           <num>
#> 1: 2021-132890752-861250084    621192     621192        0               0
#> 2: 2021-141732612-141670547     19876      19876    19876               0
#> 3: 2021-232659951-300994771   3635000    3635000        0         3635000
#> 4: 2021-263889207-861250084  28420106   28420106        0               0
#> 5: 2021-431339285-436034533    364976     364976        0               0
#> 6: 2021-454035038-861250084   3809252    3809252        0               0
#>      COVERAGE FLAG_OUTLIER
#>         <num>       <lgcl>
#> 1: 0.13817759        FALSE
#> 2:         NA        FALSE
#> 3: 1.35343088        FALSE
#> 4: 0.63862057        FALSE
#> 5: 0.07462893        FALSE
#> 6: 0.51346299        FALSE
```

### Donor and recipient attributes

`md$donors` and `md$recipients` share the merger ID and one layout:

- `SN_YEAR` and `REF_YEAR` (time 0 on that organization’s calendar);
- name and address;
- formation and ruling years, and age;
- NTEE code;
- revenue, expenses, and assets for the five years up to `REF_YEAR`.

``` r
cols <- c( "MERGER_ID", "NAME", "STATE", "AGE", "NTEE",
           "REVENUE_TM4", "REVENUE_TM2", "REVENUE_T0",
           "ASSETS_T0" )

md$donors[ 1:3, ..cols ]
#> Key: <MERGER_ID>
#>                   MERGER_ID                                     NAME  STATE
#>                      <char>                                   <char> <char>
#> 1: 2021-132890752-861250084       COUNCIL FOR ADULT AND EXPERIENTIAL     IN
#> 2: 2021-141732612-141670547 FRIENDS OF THE WARREN-WASHINGTON SUBSTAN     NY
#> 3: 2021-232659951-300994771              WEST-MONT CHRISTIAN ACADEMY     PA
#>      AGE      NTEE REVENUE_TM4 REVENUE_TM2 REVENUE_T0 ASSETS_T0
#>    <int>    <char>       <num>       <num>      <num>     <num>
#> 1:    42       B60    10676822     5794883    3930537         0
#> 2:    28 UNDEFINED          NA          NA         NA         0
#> 3:    39       B20     1720367     1757887      14427   2316208
```

### Part VII panel

`md$part7` lists everyone on either organization’s Part VII from t-2 to
t+2. `IN_BOTH` marks people who appear on both:

``` r
cols <- c( "MERGER_ID", "ROLE", "TIME_FROM_MERGER",
           "PERSON_NAME", "TITLE", "COMP_ORG" )

# people on both organizations' rosters
in_both <- md$part7[ IN_BOTH == TRUE ]

in_both[ 1:6, ..cols ]
#>                   MERGER_ID   ROLE TIME_FROM_MERGER       PERSON_NAME     TITLE
#>                      <char> <char>            <int>            <char>    <char>
#> 1: 2021-132890752-861250084  donor               -2         ERIN ROTH   TRUSTEE
#> 2: 2021-132890752-861250084  donor               -2        LARRY LUTZ   TRUSTEE
#> 3: 2021-132890752-861250084  donor               -2     THOMAS DAWSON     CHAIR
#> 4: 2021-132890752-861250084  donor               -2    WILLIAM HANSEN   TRUSTEE
#> 5: 2021-132890752-861250084  donor               -1 CHRISTINA L CLARK SECRETARY
#> 6: 2021-132890752-861250084  donor               -1         ERIN ROTH   TRUSTEE
#>    COMP_ORG
#>       <num>
#> 1:        0
#> 2:        0
#> 3:        0
#> 4:        0
#> 5:        0
#> 6:        0
```

### Fiscal panel

`md$fiscal` stacks the donor’s years up to the merger and the
recipient’s years before and after it, with harmonized 990 and 990-EZ
measures. Overhead, executive compensation, employees, and debt detail
come from the full Form 990 only.

``` r
cols <- c( "MERGER_ID", "TIME_FROM_MERGER", "REVENUE",
           "EXPENSES", "ASSETS", "STAFF_EXP", "OVERHEAD_RATIO" )

recips <- md$fiscal[ ROLE == "recipient" ]

recips[ 1:6, ..cols ]
#>                   MERGER_ID TIME_FROM_MERGER  REVENUE  EXPENSES   ASSETS
#>                      <char>            <int>    <num>     <num>    <num>
#> 1: 2021-132890752-861250084                0 36146755  17521070 87757237
#> 2: 2021-132890752-861250084                1 76931166  79334560 58003532
#> 3: 2021-132890752-861250084                2 74422160 127845259        0
#> 4: 2021-141732612-141670547               -5   769134    737421   144252
#> 5: 2021-141732612-141670547               -4  1052146   1082249   143189
#> 6: 2021-141732612-141670547               -3  1160369   1017077   487309
#>    STAFF_EXP OVERHEAD_RATIO
#>        <num>          <num>
#> 1:  12145865     0.33733910
#> 2:  57050443     0.38829966
#> 3:  56784484     0.19622319
#> 4:    530126     0.08916481
#> 5:    683892     0.10239511
#> 6:    589851     0.11333852
```

With `ratios = TRUE` (the default), the panel also gets the ratios from
[`fiscal::compute_all_panel()`](https://rdrr.io/pkg/fiscal/man/compute_all_panel.html).
Two choices matter when you study change over time:

- **A fixed calibration.** The ratios’ winsorized and percentile
  variants are recomputed within each year. For an index that is
  comparable across years, fit `fiscal::fiscal_health_fit()` once on a
  reference sample and pass it (and `fiscal::fiscal_weights()`) as `fit`
  and `weights`.
- **Backward-looking smoothing.** `smooth = "trailing"` averages each
  organization’s current and two previous years
  ([`smooth_trailing()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/smooth_trailing.md)).
  It never uses future years, so pre-merger values are not contaminated
  by post-merger ones. Use it for matching and baselines, and raw values
  for event-time outcomes.
