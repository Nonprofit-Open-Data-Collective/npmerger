# npmerger — package plan

Proposed R package for finding, classifying, and analyzing nonprofit
mergers using IRS 990 e-file data (Schedule N + core 990), built on
**panel990** (retrieval/panels) and **fiscal** (fiscal-health metrics).

Background reviewed: Schedule N 2025 form + instructions, the 2018
outcomes draft (CEM + DiD design), the 2020 IU slides, the
financial-ratio sources memo, Wilder/MAP Minnesota study (merger =
“integration of two or more organizations into one legal entity in which
at least one ceases to exist”, plus transfer of programs and of assets
or staff), and `01-build-merger-panel.rmd` (2020 prototype on the old
AWS index).

------------------------------------------------------------------------

## 1. What the experiments found (NCCS efile v3_1, tax years 2019–2021)

Scripts are in `dev/experiments/` (they expect env var `S` = a scratch
data directory).

**Data layout (panel990 tables)**

| Table | Grain | Contents |
|----|----|----|
| `SN-P01-T00-…DISSOLUTION` | 1 per filing | Part I lines 2a–2d (successor director/employee/owner/comp), 3–6 |
| `SN-P01-T01-…DISSOLUTION` | 1 per asset line | Part I line 1: desc, date, FMV, method, recipient EIN/name/address/IRC section |
| `SN-P02-T00/T01-DISPOSITION-OF-ASSETS` | same, for Part II |  |
| `SN-P03-T99-SUPPLEMENTAL-INFO` | narrative | Part III text (names of people moving, line 3 explanations) |
| `SN-P99-T00` | — | empty, ignore |
| `F9-P00` header | 1 per filing | `F9_00_RETURN_FINAL_X`, `F9_00_YEAR_FORMATION`, address |
| `F9-P01` summary | 1 per filing | revenue, expenses, assets BOY/EOY, liabilities, employees |
| `F9-P07-T01-COMPENSATION` | 1 per person | name, title, position flags, comp |

**Volumes:** about 3–3.8k Part I filings and 1.2–1.4k Part II filings
per year, so 14,399 Schedule N filings in 2019–21. 1,004 filings fill in
**both** parts, even though the instructions say not to. 94 EINs file
Schedule N in more than one year.

**Data-quality issues the package has to handle** - Checkbox encodings
are mixed: `0/1`, `true/false`, and NA. - The T00 and T01 tables don’t
line up. 1,406 Part I filings have no asset rows, and 650 have asset
rows but no T00 row. Build the filing universe as the union of
OBJECTIDs. - 28% of recipient rows have no usable EIN. The IRC section
is free text, with around 40 spellings of 501(c)(3), plus “LLC”,
“INDIVIDUAL”, “GOVERNMENT” and others. - FMV has negatives and
implausible outliers (max \$11B). Check it against the donor’s
beginning-of-year assets (the “coverage” ratio). - 225 transfers go to
the donor’s own EIN (reorganizations). - 52% of Part I filers are
**990-EZ** filers, so you need the EZ summary and EZ Part VII tables
too, not just the F9 tables. - Recipients: 81% of the top nonprofit
recipients are in efile. 98% of those keep filing after the transfer,
and 6% were formed within a year of it.

**Prototype classifier (rule-based), with validation signals that are
*not* used by the rules:**

| Label | N | % | Final return | Donor files later | Median coverage (FMV/BOY assets) | Part VII person overlap\* |
|----|----|----|----|----|----|----|
| closure | 5,784 | 40.2 | .95 | .04 | 0.22 | 9% |
| asset_transfer | 3,701 | 25.7 | .96 | .03 | 0.84 | **40%** |
| asset_disposition (Part II only) | 3,250 | 22.6 | .21 | .69 | 0.76 | — |
| merger2 | 1,373 | 9.5 | .96 | .02 | 0.95 | 87% |
| mergerN | 256 | 1.8 | .95 | .04 | 0.91 | 92% |
| mergerN into new entity | 35 | 0.2 | .94 | .03 | 0.99 | 100% |

\* Share of donor→recipient pairs where at least one donor Part VII
person (t-1..t) appears on the recipient’s Part VII (t..t+1), matched on
first + last name.

Takeaways: 1. Schedule N lines 2a–2c are a good merger signal, but
**under-reported**. About 40% of “asset transfers” to a continuing
nonprofit with no box checked still show shared leadership on Part VII.
**Part VII overlap should be a second evidence channel**, which could
add roughly 1,000 mergers over three years. 2. “Recipient continues
operating” is nearly always true for nonprofit recipients, so it adds
little for telling cases apart. The useful signals are leadership
continuity, how concentrated the transfer is (top-recipient FMV share),
and coverage. 3. mergerN (2+ dissolving donors to one recipient in the
same year) is real: 371 recipient-years. Many are system consolidations
(hospital systems, chapters folding into a national office). 132
recipients appear as acquirers in more than one year. That is worth a
**serial_acquirer / affiliate** flag. 4. Donor size is small for
transfers and closures (median revenue \$4k–\$10k) and larger for
mergers (about \$87k for merger2 and \$370k for mergerN). Recipients are
typically 50–100× larger, which matches the 2020 slides.

------------------------------------------------------------------------

## 2. Definitions (proposed)

**Unit of analysis:** a *transaction pair* (donor EIN → recipient EIN,
Schedule N tax year), grouped into a *merger event*.

- `MERGER_ID` = `YEAR-FROMEIN-TOEIN` (9-digit EINs, YEAR = donor’s
  Schedule N tax year), one per pair.
- `MERGER_GROUP_ID` = `YEAR-TOEIN` links all donors folding into one
  recipient (mergerN and consolidations).
- **Merger year (t = 0)** = the donor’s Schedule N tax year. The asset
  distribution date gets mapped onto the recipient’s fiscal calendar, so
  the recipient’s t = 0 is the fiscal year that contains the
  distribution date. Both are stored.

**Transaction types** returned by
[`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md),
one label per filing, plus evidence columns:

| Label | Rule sketch |
|----|----|
| `merger2` | Part I (dissolved), a dominant nonprofit recipient (≥50% of FMV), leadership continuity (2a/2b/2c **or** Part VII overlap), and the recipient has only this donor that year |
| `mergerN` | same as merger2, but the recipient has ≥2 dissolving donors in the window (t ± 1) |
| `consolidation` | mergerN where the recipient is newly formed (formation year or first filing ≥ t−1). This covers your “two orgs close and form a third” case |
| `asset_transfer` | Part I, a dominant nonprofit recipient, no leadership-continuity evidence |
| `closure` | Part I, with no assets, assets only to individuals/businesses/government/unknown, or assets spread across many charities (top share \< 50%) |
| `asset_disposition` | Part II only (the org continues). Subtypes: `sale` (business or individual recipient), `transfer_np` (nonprofit recipient), `spinoff` (nonprofit recipient + leadership continuity) |
| `reorganization` | recipient EIN = donor EIN, or a disregarded entity |
| `other` / `inconsistent` | for example Part I filed but the donor keeps filing for 2+ years, or there are no usable rows |

Every threshold is an argument
([`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md)),
and the output keeps the evidence columns (`LEADER_SN`, `LEADER_P7`,
`TOP_SHARE`, `COVERAGE`, `N_DONORS`, `R_NEW`, `FINAL_RETURN`,
`DONOR_FILES_LATER`). Users can then re-label without re-running the
pipeline, and run sensitivity analyses on strict vs. broad definitions.

------------------------------------------------------------------------

## 3. Package architecture

    npmerger/
      DESCRIPTION   Imports: data.table, panel990, fiscal; Suggests: duckdb, arrow, testthat, knitr
      R/
        retrieve.R      get_schedule_n(years, ...)       -> sn_raw (6 SN tables via panel990::download_tables/read_tables)
                        get_core(eins, years, tables)    -> header, P01/EZ summary, P07 for selected EINs only (parquet pushdown)
        clean.R         sn_flag(), clean_ein(), parse_irc_section(), sn_transactions(sn_raw)
                        -> long table: 1 row per asset line, Part I + II stacked, with recipient type
        recipients.R    recover_recipient_ein(): name+ZIP/state fuzzy match vs efile header (and BMF) for the 28% missing
        features.R      sn_filings(): filing-level features (parts, flags, N recipients, top share, FMV totals, coverage)
                        leader_overlap(): Part VII person matching donor -> recipient (name normalization, window)
        classify.R      merger_rules(), classify_transactions(features, rules) -> label + evidence
        cases.R         build_merger_cases(): pairs, MERGER_ID, MERGER_GROUP_ID, merger years, role table
        assets.R        transfer_value(): FMV to the recipient, by asset class (cash / receivables / investments /
                        real estate / other) with outlier flags; book-value fallback (donor BOY assets − liabilities)
        tables.R        sched_n_table()          YEAR, OBJECTID, EIN2, TYPE (+ subtype, evidence)
                        donor_attributes()        merger ID, SN year, rev/exp/assets t-5..t (wide), address, age, NTEE
                        recipient_attributes()    same, recipient EIN
                        merger_part7()            people x year, t-2..t+2, ROLE, TIME_FROM_MERGER, IN_BOTH flag
                        merger_fiscal_panel()     donor (t-5..0) + recipient (t-5..t+5) stacked; fiscal::compute_all_panel()
                                                  plus staff exp, exec pay (P07 / Part IX), grants, overhead, debt
        pipeline.R      build_merger_data(years) -> list of all tables + manifest (row counts, drops, per step)
      inst/extdata/     small fixture (about 200 filings, all labels) for tests and examples
      tests/testthat/   flag parsing, IRC parsing, classifier truth table, ID format, panel windows
      vignettes/        01-identifying-mergers, 02-building-panels, 03-did-example (matched comparison)
      data-raw/         script to build the fixture + an IRC-section lookup table

Design choices: - **data.table throughout**, matching panel990 and
fiscal. Return plain data.frames/data.tables with documented columns. -
**Fetch selectively.** Schedule N is tiny (about 1 MB/yr), but header,
summary and P07 are 50–100 MB/yr. Download Schedule N for all years,
derive the EIN set, then read core tables with an EIN filter (duckdb
parquet pushdown, `cache = "none"` option). - **Keep the stages
separate.** raw → transactions → features → labels → cases → output
tables. Each stage is a function, so users can step in anywhere (for
example, swap in their own classifier). - **Get metrics from `fiscal`,
not reimplement them.** fiscal now defaults to the current efile release
(v3_1), the same as panel990. See section 7 for calibration and
smoothing. - NTEE, ruling year and address come from the BMF through
[`panel990::bmf_merge()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_merge.html)
/
[`fiscal::get_clean_ntee()`](https://nonprofit-open-data-collective.github.io/fiscal/reference/get_clean_ntee.html).
Org age = tax year − min(formation year, ruling year).

------------------------------------------------------------------------

## 4. Build sequence

1.  ✅ **Skeleton + retrieval/cleaning** (`get_schedule_n`,
    `sn_transactions`, flag/IRC/EIN parsers) with tests.
2.  ✅ **Filing features + classifier** (rules from section 2) and
    [`sched_n_table()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sched_n_table.md).
    Hand-validated on 300 filings, with three rule changes as a result;
    see section 9.
3.  ✅ **Merger evidence wired into the classifier**
    ([`get_evidence_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_evidence_tables.md),
    [`merger_features()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_features.md)):
    - Part VII overlap:
      [`leader_overlap()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/leader_overlap.md).
      The F9 Part VII table also covers EZ filers: 89% of merger donors
      and recipients have rows.
    - Multi-party counts:
      [`add_donor_counts()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_donor_counts.md).
    - New-entity detection and filing history:
      [`add_filing_history()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_filing_history.md).
    - Corroboration:
      [`add_corroboration()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_corroboration.md).
    - Affiliation:
      [`add_affiliation()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_affiliation.md).
    - Mission similarity:
      [`add_mission_similarity()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_mission_similarity.md).

    Real-data check on 2021 (5,167 filings; script `dev/run-2021.R`):
    closure 2,160; asset_disposition 1,090; asset_transfer 938; merger2
    858; mergerN 107; consolidation 14. Of these, 54 mergers rest on
    corroboration rather than leadership. Affiliated pairs make up 37%
    of merger2, 76% of mergerN, and 4% of closures. 98% of merger donors
    file a final return. Evidence retrieval takes about 2.5 minutes cold
    (from the parquet cache) and 0.4 minutes warm.
4.  ✅ **Cases, IDs, and asset values:**
    - [`get_core()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_core.md),
      [`org_years()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/org_years.md),
      [`merger_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_measures.md).
    - [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md),
      which places the merger year on the recipient’s fiscal calendar.
    - [`transfer_value()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/transfer_value.md)
      and
      [`asset_class()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/asset_class.md).
      Classifying transferred value moved the “other” bucket from 31% to
      3%.
5.  ✅ **Attribute tables:**
    [`merger_attributes()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_attributes.md)
    and
    [`get_bmf()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_bmf.md).
    NTEE coverage is 97–98%.
6.  ✅ **Part VII panel**
    ([`merger_part7()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_part7.md))
    and **fiscal panel**
    ([`merger_fiscal_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_fiscal_panel.md),
    [`smooth_trailing()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/smooth_trailing.md)).
7.  ✅ **Recipient EIN recovery**
    ([`recover_recipient_ein()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/recover_recipient_ein.md)),
    by unique name + ZIP, then name + state. It recovers only about
    1,200 lines (1.2%): of the lines with no EIN, about 40% have no
    recipient name, and many name churches, governments, or “various”.
    Most missing-EIN recipients do not file 990s, so the 23% that remain
    missing is largely a data limit.
8.  ✅ **Wrapper and documentation:**
    - [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md),
      plus offline example data
      ([`npmerger_example()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/npmerger_example.md),
      built by `data-raw/example.R`).
    - Vignette and site.
    - Full-years run (`dev/run-all-years.R`) and descriptives
      (`dev/descriptives.R`); see section 8.

------------------------------------------------------------------------

## 5. Other 990 fields (tested 2026-11-20, `dev/experiments/06-other-fields.R`)

**Decision:** leadership continuity = Schedule N lines 2a–2c **or** Part
VII overlap (`merger_rules(leader = "either")`). With that rule, 2019–21
counts are: closure 5,784; asset_disposition 3,250; asset_transfer
2,632; merger2 2,306; mergerN 427.

The table below shows each field’s rate by label. “Recip.” is measured
at the recipient in the merger year.

| Field | merger2 | mergerN | asset_transfer | closure | Verdict |
|----|----|----|----|----|----|
| **Schedule R Part II**: donor and recipient list each other as related orgs | .35 | .64 | .08 | .03 | **Use.** Separates intra-system consolidation from arm’s-length merger |
| **Schedule O** text mentions merg/consolidat/acquir/affiliat (donor) | .33 | .54 | .10 | .04 | **Use** as tiebreaker evidence (all-filer baseline .06) |
| Same, recipient’s Schedule O | .28 | .53 | .13 | .01 | **Use** |
| **Part VI line 4**: significant changes to governing documents (recip., t vs t-2) | .12 vs .04 | .13 vs .05 | .02 vs .09 | .04 | **Use**, about 3× lift at t |
| **Schedule A**: donor is a 509(a)(3) supporting org | .18 | .25 | .09 | .05 | **Use** as affiliation flag |
| **Part XII**: recipient’s audit is consolidated | .34 | .63 | .30 | .25 | Descriptive (systems) |
| Mission-text similarity (Jaccard, donor vs recipient; random = 0) | .07 | .09 | .03 | .00 | **Use** as relatedness measure (horizontal vs. other) |
| Part III: significant new programs (recip., t vs t-2) | .06 vs .02 | .05 vs .11 | .02 | .01 | Weak, noisy |
| Part VI line 1a: board grew t-2 → t+1 | .40 | .41 | .38 | .52 | Not useful |
| Part XI line 9: other changes in net assets ≈ FMV received (±50%) | .23 | .08 | .08 | .02 | Use only to validate [`transfer_value()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/transfer_value.md) |
| Part IV lines 31/32 or final return **without** Schedule N | — | — | — | — | No gap: 99–100% have Schedule N |

What this means for the package: - Add an **affiliation** dimension,
separate from the label:
`AFFILIATED = Schedule R link | supporting org | same group exemption number | chapters (Part VI 10a)`.
About a third of merger2 cases and two-thirds of mergerN cases are
within one family of organizations. Analyses will usually want to split
or drop them. This answers the earlier open question: keep the labels,
and add a flag. - Add **corroborating evidence** columns:
`SO_MERGER_TEXT_DONOR`, `SO_MERGER_TEXT_RECIP`, and
`GOV_DOC_CHANGE_RECIP` (Part VI line 4 at the recipient, t or t+1).
**Decision: allow promotion.** An `asset_transfer` becomes a merger
label when ≥2 of the 3 signals agree
(`merger_rules(promote = TRUE, min_corroborate = 2)`). The output
records `BASIS = "corroborated"` (vs `"leader"`) and `N_CORROBORATE`.
`MISSION_SIM` is descriptive only and does not count toward promotion. -
Tested on 2021: 54 of 999 asset transfers (5%) are promoted. They look
like mergers on measures the rule doesn’t use: 69% of donors end the
year with near-zero assets, vs 37% for unpromoted transfers (65% for
merger2), and median donor revenue is \$61k vs \$5k (\$47k for merger2).
One signal alone would promote 163 cases, which have weaker profiles
(47% assets gone, \$12k revenue), so the threshold stays at 2. - The
universe is complete from Schedule N. Use Part IV and the final-return
flag only for validation.

Not tested, but worth adding to the panels: - Part V line 2a W-3
employee count (`F9_05_NUM_EMPL`) and Part I line 5 employees. These
measure staff absorbed by the recipient. - Part VIII line 1g non-cash
contributions and Schedule M at the recipient. These are where in-kind
asset transfers show up. - Header `F9_00_GROUP_EXEMPT_NUM` / group
returns (chapters), and the name-change / DBA fields (recipients that
rename after a merger). - Schedule R Part V (transfers with related
orgs), to cross-check transfer amounts within affiliated families. -
Schedule D Part V (endowments): restricted funds that move with the
merger. - Schedule H (hospitals), for a hospital-specific subsample. -
Schedule B contributor names are redacted in public data, so it isn’t
usable.

------------------------------------------------------------------------

## 7. Fiscal health index and smoothing (tested 2026-11-20, `dev/experiments/07-fiscal-index-smoothing.R`)

**Is the index calibrated?** No. fiscal 0.0.2 has a full measurement
workflow: `fiscal_diagnostics()` → `fiscal_triage()` →
`fiscal_dimensions()` → `fiscal_health_fit()` → `fiscal_weights()` →
`fiscal_health_score()` → `fiscal_health_index()`. But no fitted model
ships with it. The only bundled data are `dat10k` (10,000 orgs, tax year
2023) and `part010810`. The docs say triage and dimension discovery
“require review and substantive judgment”, so nothing is automated. - I
fit the workflow on `dat10k` with all defaults. It runs end to end: 48
winsorized ratios, 3 PCA dimensions, and **29 standalone indicators**.
With default equal weights, the standalones dominate the composite. So
the defaults are a starting point, not a calibration. - **To do:**
calibrate once on a stated reference sample, review triage, dimensions
and weights, and save the fit. Then score every org-year with it.
Options for the reference sample: a full single-year cross-section of
all 990 filers; a pooled pre-period such as 2018–19; or `dat10k`.

**Can we get metrics for every year and track change?** Yes, but use the
right layer: - `compute_all_panel()` gives the raw ratios for every
org-year. Its `_w` / `_z` / `_p` columns are **re-estimated within each
year**: percentile and z-score are relative to that year’s
cross-section. They are good for ranking but not for tracking absolute
change over time. - `fiscal_health_score()` with a fixed fit applies the
stored centers, scales and coefficients without re-estimating. **This is
the comparable-over-time index.** I tested it on 769 merger orgs (3,142
org-years, 2018–23) scored against the 2023 calibration, and it produced
an index for every year.

**Smoothing.**
[`panel990::panel_smooth()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_smooth.html)
is **centered only** (odd window, positions `t-1, t, t+1`). It also
counts rows rather than calendar years, so filing gaps get bridged.
There is no trailing option, in the installed version or on GitHub main.
For merger panels this leaks post-merger information into pre-merger
years. I compared on recipients (k = 3), measuring partial correlation
of the t-1 index with the year-t index, controlling for t-2:

|  | raw | trailing (t-2..t) | centered (t-1..t+1) |
|----|----|----|----|
| Correlation of t-1 with year t (leakage) | .53 | .47 | **.61** |
| Mean index at t-2 (recipients) | .21 | .20 | **.38** (inflated) |
| Within-org year-to-year SD of index | .88 | .33 | .33 |

- A trailing window cuts noise as much as centered does (−63%
  volatility), with no look-ahead.
- Trailing does **lag** real changes: the post-merger rise is spread
  over k years (trailing .26 → .29 → .31 for t = 0..2).
- Plan:
  1.  Add `align = c("left", "center", "right")` to
      [`panel990::panel_smooth()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_smooth.html)
      (default `"center"`). `"right"` is the trailing window, counted by
      calendar year. This was requested in panel990. npmerger’s
      [`smooth_trailing()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/smooth_trailing.md)
      calls it when the installed panel990 supports `"right"`, and
      otherwise uses an equivalent internal version.
  2.  In
      [`merger_fiscal_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_fiscal_panel.md),
      offer `smooth = "trailing"` (default `k = 3`).
  3.  Use trailing-smoothed values for matching covariates and baselines
      (t-2), and **raw** values for event-time outcome estimates.
      Otherwise the lag smears the merger effect.

------------------------------------------------------------------------

## 8. Full-years run (Schedule N 2010–2024, e-file v3_1; 2026-11-20)

`dev/run-all-years.R` took 53 minutes on a warm cache (8.3 GB,
2009–2025).

**Scale:** - 60,235 Schedule N filings; **12,059 merger filings**:
merger2 9,405; mergerN 2,430; consolidation 224. - These become 11,943
donor→recipient cases in 10,336 merger events. - Mergers grew from about
330 a year (2010) to about 1,050 (2024). - 4% of merger2 and 9% of
mergerN rest on corroboration rather than leadership evidence. 40% of
merger2 and 65% of mergerN are between affiliated organizations.

**Descriptives** (`dev/descriptives.R`; sizes are for year t-1, the last
full year before the merger):

|  | Closing org (donor) | Recipient |
|----|----|----|
| Revenue: median (p25–p75) | \$260k (\$56k–\$1.28m) | \$6.3m (\$0.95m–\$31.8m) |
| Assets: median | \$447k | \$10.3m |
| Revenue: mean / 5%-trimmed mean | \$11.7m / \$1.24m | \$141m / \$32.6m |

- **Size gap.** The median recipient has 11.9× the donor’s revenue (p25
  2.7×, p75 82×). The recipient is larger in 89% of mergers, more than
  10× larger in 53%, and more than 100× larger in 23%. The ratio is
  smaller for consolidations (1.2–1.5×) and larger for affiliated
  mergers (19–25×).
- **Multi-organization mergers.**
  - 8.2% of merger events have two or more closing donors, and those
    events account for 20% of all closing organizations.
  - Group size: 2 donors in 5.6% of events, 3 in 1.5%, 4 or more in
    1.1%.
  - 92 consolidations into a new entity, involving 223 donors.
- **Part VII joiners** (10,871 mergers with both rosters observed).
  - On average 2.0 donor people newly appear on the recipient’s Part VII
    after the merger (median 1). 54% of mergers have at least one
    joiner.
  - About 14% of the donor’s roster joins (median donor roster: 11
    people).
  - Separately, 58% of mergers already had at least one person on both
    rosters before the merger (mean 2.8). Affiliated mergers average 5
    such people.
- **CEO / executive director.**
  - A donor CEO or ED can be identified in 4,755 mergers: 82% by title,
    the rest as the highest-paid officer. Many small donors have no paid
    executive.
  - **54% of those CEOs appear at the recipient after the merger.** Of
    those, 73% are listed as CEO or ED there, 11% as another officer or
    staff, and 8% as a board member.
  - The rate is 75% for affiliated two-party mergers, 35% for
    unaffiliated ones, and 61–64% for consolidations.
- **Asset transfers.**
  - Median \$308k; 5%-trimmed mean \$1.9m; mean \$10.9m.
  - \$116bn in total across 10,637 positive, unflagged transfers. 662
    transfers are flagged as outliers.
  - The median transfer is 91% of the donor’s beginning-of-year assets.
  - As a share of the recipient’s t-1 assets: median 5.2%. 29% of
    transfers are under 1%, 24% are 10–50%, and 17% are 50% or more.
    Consolidations are the high end (median 16–39%), since the recipient
    is new.

Section 8 figures use the v1 rules. Section 9 changes the rules, so the
full run needs re-running before these figures are quoted.

------------------------------------------------------------------------

## 9. Classifier validation (step 2; 2026-11-20, `dev/validation/`)

**Design.** - 300 Schedule N filings from 2010–2024: 50 drawn at random
from each v1 label (merger2, mergerN, consolidation, asset_transfer,
closure, asset_disposition). - Drawn only from filings with some
narrative: Schedule N Part III text, or Schedule O sentences about
dissolution, merger, or transfer. The share with narrative is 36% of
closures, 46% of asset transfers, 65% of dispositions, and 84–95% of the
merger types. - Each case is a text packet: form header, asset lines,
Part III, and Schedule O excerpts. The classifier label is not shown.
Packets are labeled blind against `codebook.md` (merger, asset transfer,
closure, asset disposition, reorganization, unclear), with flags for
multi-party, new entity, people moving, and programs continuing. -
Labeling was done by model readers, not people. A human spot-check of
`hand-labels.csv` is still worthwhile, especially the low-confidence
rows (55 of 300). - “Weighted” figures reweight each stratum to its
population size.

**v1 results.** - Agreement: 62% (60% weighted). - Precision: merger 66%
(56% weighted), asset transfer 52%, closure 66%, disposition 58%. - Main
errors: 1. **Part-II-only filers that ended.** All 12 with the
final-return box checked were terminations (7 mergers, 4 transfers, 1
closure), not dispositions. 2. **Asset transfer → closure.** 10 of the
11 dissolutions with a top-recipient share between 0.5 and 0.75 read as
dispersed closures, and none as mergers. The v1 rule also skipped the
share test whenever there was only one *nonprofit* recipient, even if
most value went to vendors or individuals. 3. **Merger language on
Schedule N itself.** Some filings say “transfer due to merger”, “plan
merger”, “lodge merged” and so on in the asset description or Part III,
but have no leadership evidence. Every such terminated filing with one
successor (51 of 51) was read as a merger. This is partly circular,
since the readers saw that text, but it is the filer’s own statement. 4.
**Promotion by corroboration.** Only 1 of 8 promoted cases read as a
merger. 5. **Leadership-based mergers read as residual transfers (43
cases).** This is the main remaining gap. It is mostly chapters, union
locals, auxiliaries, and plans sending their remaining assets to a
parent or sister organization where officers *already* sat. Schedule N
line 2 is answered yes, and Part VII shows overlap, but the overlap
predates the transfer. - Part VII joiners (people new to the recipient
after the merger) are more precise than overlap: 78% with a Schedule N
flag, 55% without. Interlock-only cases without a flag score 45%. -
Readers could not see Part VII, so this channel is not cleanly tested
here.

**Rule changes (v2, now the defaults).** 1. `min_top_share = 0.75`,
applied to the share of *total* FMV. It falls back to “one nonprofit
recipient” only when FMV is missing. 2. `final_as_termination = TRUE`: a
Part-II-only filing with the final-return box checked is treated as a
termination. The new `TERMINATED` column records this. 3.
`sn_text = TRUE`: `SN_MERGER_TEXT`
([`sn_merger_pattern()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_merger_pattern.md)
matched against asset descriptions, valuation methods, and Part III)
counts as merger evidence on its own. `BASIS = "sn_text"`.

**v2 results (same sample).**

| classifier  hand  | merger | transfer | closure | disposition | reorg |
|-------------------|--------|----------|---------|-------------|-------|
| merger            | 109    | 43       | 1       | 1           | 5     |
| asset_transfer    | 6      | 26       | 5       | 0           | 2     |
| closure           | 3      | 14       | 45      | 1           | 3     |
| asset_disposition | 4      | 1        | 2       | 29          | 0     |

- Agreement: 70% (68% weighted).
- Precision: merger 69% (62% weighted), asset transfer 67%, closure 68%,
  disposition 81%.
- Merger recall rises from 51% to 71% (weighted).
- Merger precision by basis: leader 70% (n = 149), sn_text 5/5,
  corroborated 0/5.
- Population effect on 2010–2024: mergers go from 12,059 to 12,827.
  - asset_disposition: 15,018 → 12,320.
  - asset_transfer: 10,180 → 9,067.
  - closure: 22,978 → 26,021.
  - With `promote = FALSE`: 12,346 mergers.

**Other findings.** - **Closure → asset transfer (14).** These are
mostly single recipients with no EIN or name, such as “unnamed
orphanage” or “another nonprofit”. They cannot become merger cases
either way, so this mainly affects closure vs. transfer counts. -
**mergerN.** Readers saw multi-party language in only 6% of mergerN
cases. The label comes from other donors sending assets to the same
recipient within a year. That is real, but it is usually a recipient
absorbing several affiliates, not one multi-party deal; the text of a
single filing rarely shows it. - **consolidation.** 54% of hand-read
consolidations mention a new entity. - **Reorganization.** Readers found
10 (conversions, new EINs, PTA→PTO). The self-transfer rule catches none
of them, because the new entity has a different EIN.

**Still open.** - Whether to keep promotion on by default (0 of 5 under
v2). - Whether to define the Part VII channel as joiners rather than any
overlap. - A human pass over the low-confidence labels.

------------------------------------------------------------------------

## 6. Open questions

1.  **990-EZ donors.** They are about half of Part I filers, but mostly
    tiny. Include them by default, with a size filter as an option?
2.  **Year range.** The current release (v3_1) covers 2009–2025, so the
    older v2_x releases are no longer needed. 2009 and 2025 are partial
    years.
3.  **Fiscal index reference sample.** Which reference should the
    fiscal-health model be calibrated on (section 7)?
