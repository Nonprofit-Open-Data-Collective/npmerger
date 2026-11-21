# npmerger

Build nonprofit merger datasets from IRS Form 990 e-file data.

**npmerger** finds candidate mergers in Schedule N (liquidation, termination,
dissolution, or significant disposition of assets). It classifies each
transaction and builds analysis tables around every merger event: donor and
recipient attributes, Part VII rosters, and fiscal-health panels. Data is
retrieved with [panel990](https://github.com/Nonprofit-Open-Data-Collective/panel990),
and fiscal metrics come from [fiscal](https://github.com/Nonprofit-Open-Data-Collective/fiscal).

> Status: early development. The full pipeline works, from Schedule N
> through the analysis tables. The classifier has not yet been validated
> against hand-labeled cases. See the
> [roadmap](https://github.com/Nonprofit-Open-Data-Collective/npmerger/blob/main/PLAN.md)
> and the [overview](https://nonprofit-open-data-collective.github.io/npmerger/articles/npmerger.html).

## Installation

```r
# install.packages("remotes")
remotes::install_github("Nonprofit-Open-Data-Collective/npmerger")
```

## Usage

```r
library(npmerger)

# everything in one call: Schedule N, evidence, classification, cases,
# transfers, donor/recipient attributes, Part VII panel, fiscal panel
md <- build_merger_data(2019:2021, path = "PANEL990")
md$cases; md$donors; md$recipients; md$part7; md$fiscal

# offline, on the bundled example
ex <- npmerger_example()
build_merger_data(sn = ex$sn, evidence = ex$evidence, core = ex$core,
                  names = ex$names, bmf_data = ex$bmf)

# or stage by stage
sn  <- get_schedule_n(2019:2021)   # Schedule N tables via panel990
tx  <- sn_transactions(sn)         # one row per asset line (Parts I + II)
fl  <- sn_filings(sn, tx)          # one row per Schedule N filing
ev  <- get_evidence_tables(fl)     # header, Part VII, VI, Sched O/R/A for these orgs
fe  <- merger_features(fl, ev)     # leadership, donor counts, corroboration, affiliation
lab <- classify_transactions(fe)   # merger2, mergerN, consolidation, closure, ...
sched_n_table(lab)
```

## Transaction types

| Label | Meaning |
|---|---|
| `merger2` | Dissolved; one dominant nonprofit successor; leadership continuity |
| `mergerN` | Same, but the successor absorbs 2+ dissolving organizations |
| `consolidation` | mergerN into a newly formed entity |
| `asset_transfer` | Dissolved; one dominant nonprofit successor; no continuity evidence |
| `closure` | Dissolved; assets dispersed or not going to a nonprofit |
| `asset_disposition` | Part II only: more than 25% of net assets transferred, but the organization continues |
| `reorganization` | Assets transferred to the filer's own EIN |

Leadership continuity uses Schedule N lines 2a–2c **or** overlap of people
listed on the donor's and the recipient's Part VII (`merger_rules(leader = "either")`).

Merger IDs take the form `YEAR-FROMEIN-TOEIN` (`merger_id()`), and
`YEAR-TOEIN` groups multi-party mergers (`merger_group_id()`).
