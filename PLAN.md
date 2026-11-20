# npmerger — package plan

Proposed R package for finding, classifying, and analyzing nonprofit mergers using IRS 990 e-file data
(Schedule N + core 990), built on **panel990** (retrieval/panels) and **fiscal** (fiscal-health metrics).

Background reviewed: Schedule N 2025 form + instructions, the 2018 outcomes draft (CEM + DiD design),
the 2020 IU slides, the financial-ratio sources memo, Wilder/MAP Minnesota study (merger = "integration of two or
more organizations into one legal entity in which at least one ceases to exist", plus transfer of programs and of
assets or staff), and `01-build-merger-panel.rmd` (2020 prototype on the old AWS index).

---

## 1. What the experiments found (NCCS efile v3_1, tax years 2019–2021)

Scripts are in `dev/experiments/` (they expect env var `S` = a scratch data directory).

**Data layout (panel990 tables)**

| Table | Grain | Contents |
|---|---|---|
| `SN-P01-T00-…DISSOLUTION` | 1 per filing | Part I lines 2a–2d (successor director/employee/owner/comp), 3–6 |
| `SN-P01-T01-…DISSOLUTION` | 1 per asset line | Part I line 1: desc, date, FMV, method, recipient EIN/name/address/IRC section |
| `SN-P02-T00/T01-DISPOSITION-OF-ASSETS` | same, for Part II | |
| `SN-P03-T99-SUPPLEMENTAL-INFO` | narrative | Part III text (names of people moving, line 3 explanations) |
| `SN-P99-T00` | — | empty, ignore |
| `F9-P00` header | 1 per filing | `F9_00_RETURN_FINAL_X`, `F9_00_YEAR_FORMATION`, address |
| `F9-P01` summary | 1 per filing | revenue, expenses, assets BOY/EOY, liabilities, employees |
| `F9-P07-T01-COMPENSATION` | 1 per person | name, title, position flags, comp |

**Volumes:** about 3–3.8k Part I filings and 1.2–1.4k Part II filings per year, so 14,399 Schedule N filings in 2019–21.
1,004 filings fill in **both** parts, even though the instructions say not to. 94 EINs file Schedule N in more than one year.

**Data-quality issues the package has to handle**
- Checkbox encodings are mixed: `0/1`, `true/false`, and NA.
- The T00 and T01 tables don't line up. 1,406 Part I filings have no asset rows, and 650 have asset rows but no T00 row. Build the filing universe as the union of OBJECTIDs.
- 28% of recipient rows have no usable EIN. The IRC section is free text, with around 40 spellings of 501(c)(3), plus "LLC", "INDIVIDUAL", "GOVERNMENT" and others.
- FMV has negatives and implausible outliers (max $11B). Check it against the donor's beginning-of-year assets (the "coverage" ratio).
- 225 transfers go to the donor's own EIN (reorganizations).
- 52% of Part I filers are **990-EZ** filers, so you need the EZ summary and EZ Part VII tables too, not just the F9 tables.
- Recipients: 81% of the top nonprofit recipients are in efile. 98% of those keep filing after the transfer, and 6% were formed within a year of it.

**Prototype classifier (rule-based), with validation signals that are *not* used by the rules:**

| Label | N | % | Final return | Donor files later | Median coverage (FMV/BOY assets) | Part VII person overlap* |
|---|---|---|---|---|---|---|
| closure | 5,784 | 40.2 | .95 | .04 | 0.22 | 9% |
| asset_transfer | 3,701 | 25.7 | .96 | .03 | 0.84 | **40%** |
| asset_disposition (Part II only) | 3,250 | 22.6 | .21 | .69 | 0.76 | — |
| merger2 | 1,373 | 9.5 | .96 | .02 | 0.95 | 87% |
| mergerN | 256 | 1.8 | .95 | .04 | 0.91 | 92% |
| mergerN into new entity | 35 | 0.2 | .94 | .03 | 0.99 | 100% |

\* Share of donor→recipient pairs where at least one donor Part VII person (t-1..t) appears on the recipient's Part VII (t..t+1), matched on first + last name.

Takeaways:
1. Schedule N lines 2a–2c are a good merger signal, but **under-reported**. About 40% of "asset transfers" to a continuing nonprofit with no box checked still show shared leadership on Part VII. **Part VII overlap should be a second evidence channel**, which could add roughly 1,000 mergers over three years.
2. "Recipient continues operating" is nearly always true for nonprofit recipients, so it adds little for telling cases apart. The useful signals are leadership continuity, how concentrated the transfer is (top-recipient FMV share), and coverage.
3. mergerN (2+ dissolving donors to one recipient in the same year) is real: 371 recipient-years. Many are system consolidations (hospital systems, chapters folding into a national office). 132 recipients appear as acquirers in more than one year. That is worth a **serial_acquirer / affiliate** flag.
4. Donor size is small for transfers and closures (median revenue $4k–$10k) and larger for mergers (about $87k for merger2 and $370k for mergerN). Recipients are typically 50–100× larger, which matches the 2020 slides.

---

## 2. Definitions (proposed)

**Unit of analysis:** a *transaction pair* (donor EIN → recipient EIN, Schedule N tax year), grouped into a *merger event*.

- `MERGER_ID` = `YEAR-FROMEIN-TOEIN` (9-digit EINs, YEAR = donor's Schedule N tax year), one per pair.
- `MERGER_GROUP_ID` = `YEAR-TOEIN` links all donors folding into one recipient (mergerN and consolidations).
- **Merger year (t = 0)** = the donor's Schedule N tax year. The asset distribution date gets mapped onto the recipient's fiscal calendar, so the recipient's t = 0 is the fiscal year that contains the distribution date. Both are stored.

**Transaction types** returned by `classify_transactions()`, one label per filing, plus evidence columns:

| Label | Rule sketch |
|---|---|
| `merger2` | Part I (dissolved), a dominant nonprofit recipient (≥50% of FMV), leadership continuity (2a/2b/2c **or** Part VII overlap), and the recipient has only this donor that year |
| `mergerN` | same as merger2, but the recipient has ≥2 dissolving donors in the window (t ± 1) |
| `consolidation` | mergerN where the recipient is newly formed (formation year or first filing ≥ t−1). This covers your "two orgs close and form a third" case |
| `asset_transfer` | Part I, a dominant nonprofit recipient, no leadership-continuity evidence |
| `closure` | Part I, with no assets, assets only to individuals/businesses/government/unknown, or assets spread across many charities (top share < 50%) |
| `asset_disposition` | Part II only (the org continues). Subtypes: `sale` (business or individual recipient), `transfer_np` (nonprofit recipient), `spinoff` (nonprofit recipient + leadership continuity) |
| `reorganization` | recipient EIN = donor EIN, or a disregarded entity |
| `other` / `inconsistent` | for example Part I filed but the donor keeps filing for 2+ years, or there are no usable rows |

Every threshold is an argument (`merger_rules()`), and the output keeps the evidence columns (`LEADER_SN`, `LEADER_P7`, `TOP_SHARE`, `COVERAGE`, `N_DONORS`, `R_NEW`, `FINAL_RETURN`, `DONOR_FILES_LATER`). Users can then re-label without re-running the pipeline, and run sensitivity analyses on strict vs. broad definitions.

---

## 3. Package architecture

```
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
```

Design choices:
- **data.table throughout**, matching panel990 and fiscal. Return plain data.frames/data.tables with documented columns.
- **Fetch selectively.** Schedule N is tiny (about 1 MB/yr), but header, summary and P07 are 50–100 MB/yr. Download Schedule N for all years, derive the EIN set, then read core tables with an EIN filter (duckdb parquet pushdown, `cache = "none"` option).
- **Keep the stages separate.** raw → transactions → features → labels → cases → output tables. Each stage is a function, so users can step in anywhere (for example, swap in their own classifier).
- **Get metrics from `fiscal`, not reimplement them.** One caution: `fiscal::get_panel()` defaults to efile **v2_1**, while panel990 uses **v3_1**. Field names need checking so that `compute_all_panel()` runs on panel990 output. This may need a small shim or a fix in fiscal.
- NTEE, ruling year and address come from the BMF through `panel990::bmf_merge()` / `fiscal::get_clean_ntee()`. Org age = tax year − min(formation year, ruling year).

---

## 4. Build sequence

1. **Skeleton + retrieval/cleaning** (`get_schedule_n`, `sn_transactions`, flag/IRC/EIN parsers) with tests. Package via usethis, git init.
2. **Filing features + classifier** (rules from section 2) and `sched_n_table()`. Check by hand-reading about 50 Part III narratives per label. Report a confusion matrix against the hand labels.
3. **Part VII overlap** (`leader_overlap`) added as a classifier input. Add EZ Part VII.
4. **Cases + IDs + asset values** (`build_merger_cases`, `transfer_value`).
5. **Attribute tables** (donor/recipient), with BMF NTEE + age.
6. **Part VII panel** (t-2..t+2) and **fiscal panel** using `fiscal`.
7. **Recipient EIN recovery** (fuzzy matching) to win back the 28% missing EINs.
8. Pipeline wrapper, vignettes, pkgdown site, full-years run with a manifest of counts per year and label.

---

## 5. Open questions

1. **Merger evidence.** Should leadership continuity count from Schedule N flags **or** Part VII overlap (recommended), or Schedule N flags only (strict, as in the 2018 draft)?
2. **990-EZ donors.** They are about half of Part I filers, but mostly tiny. Include them by default, with a size filter as an option?
3. **Year range.** v3_1 covers roughly 2018–2024 here. Should the old 2011–2017 e-file years (v2_x) be supported too, or only the current release?
4. **Affiliate consolidations** (chapters → national, hospital systems): keep them as mergerN, or give them their own `affiliate_consolidation` label?
