# npmerger

Build nonprofit merger datasets from IRS Form 990 e-file data.

**npmerger** finds candidate mergers in Schedule N (liquidation,
termination, dissolution, or significant disposition of assets). It
classifies each transaction and builds analysis tables around every
merger event: donor and recipient attributes, Part VII rosters, and
fiscal-health panels. Data is retrieved with
[panel990](https://github.com/Nonprofit-Open-Data-Collective/panel990),
and fiscal metrics come from
[fiscal](https://github.com/Nonprofit-Open-Data-Collective/fiscal).

> Status: early development. Retrieval, cleaning, filing-level features,
> and the rule-based classifier are working. Case building, attribute
> tables, and panels are stubs. See the
> [roadmap](https://github.com/Nonprofit-Open-Data-Collective/npmerger/blob/main/PLAN.md)
> and the
> [overview](https://nonprofit-open-data-collective.github.io/npmerger/articles/npmerger.html).

## Installation

``` r

# install.packages("remotes")
remotes::install_github("Nonprofit-Open-Data-Collective/npmerger")
```

## Usage

``` r

library(npmerger)

sn  <- get_schedule_n(2019:2021)   # Schedule N tables via panel990
tx  <- sn_transactions(sn)         # one row per asset line (Parts I + II)
fl  <- sn_filings(sn, tx)          # one row per Schedule N filing
lab <- classify_transactions(fl)   # merger2, mergerN, closure, ...
sched_n_table(lab)
```

## Transaction types

| Label | Meaning |
|----|----|
| `merger2` | Dissolved; one dominant nonprofit successor; leadership continuity |
| `mergerN` | Same, but the successor absorbs 2+ dissolving organizations |
| `consolidation` | mergerN into a newly formed entity |
| `asset_transfer` | Dissolved; one dominant nonprofit successor; no continuity evidence |
| `closure` | Dissolved; assets dispersed or not going to a nonprofit |
| `asset_disposition` | Part II only: more than 25% of net assets transferred, but the organization continues |
| `reorganization` | Assets transferred to the filer’s own EIN |

Leadership continuity uses Schedule N lines 2a–2c **or** overlap of
people listed on the donor’s and the recipient’s Part VII
(`merger_rules(leader = "either")`).

Merger IDs take the form `YEAR-FROMEIN-TOEIN`
([`merger_id()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_id.md)),
and `YEAR-TOEIN` groups multi-party mergers
([`merger_group_id()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_id.md)).
