# npmerger 0.0.0.9000

* Part VII names are now matched on the **canonical first name** plus the
  surname. `name_keys()` parses each name with peopleparser, which strips
  titles and credentials and orders the name parts, and resolves nicknames
  and spelling variants (BOB → ROBERT, STEVEN → STEPHEN). `leader_overlap()`,
  `merger_part7()`, and so `LEADER_P7`, the leadership outcomes, and
  `IN_BOTH` all use it. `merger_rules(name_key = "simple")` restores the old
  first-and-last-token key (`person_key()`). Parsed names are cached for the
  session and saved in the project database (`name_keys`), so rebuilds do
  not parse them again. peopleparser (>= 0.2.3) is now an import.
  `name_keys( workers = n )` passes `workers` to
  `peopleparser::parse_names()`; with 8 workers all 1.77 million Part VII
  names parse in about 4 minutes.
* `name_match_basis()` (and `md$name_matches`) records why each person on
  both rosters matched: `exact`, a reviewed pair (`nickname`, `spelling`,
  `cognate`, `compound`), an unreviewed pair (`misspelling`, `sound_alike`),
  or `indirect` (linked only through the canonical form). `REVIEW` flags the
  last three. `leadership_inspection()` shows it as `MATCH_BASIS`.
* The whole workflow now runs inside the package, into one project folder:
  - `merger_project()` creates a folder with the download cache, one DuckDB
    database, a `logs/` folder, and a README. `build_merger_database()`
    runs the three stages (`"merger"`, `"match"`, `"model"`) into it. Each
    stage writes its tables to the database, a log with package versions,
    git commit, settings, and `sessionInfo()`, and a row in `build_log`.
    `load_merger_data()`, `load_match_data()`, and `load_model_data()`
    rebuild each stage's object from the database. `db_tables()`,
    `db_read()`, and `db_write()` give direct access. `dev/build-project.R`
    replaces `dev/build-database.R` and `dev/build-matching.R`.
  - `merger_leadership()` (CEO and board outcomes from the Part VII panel)
    and `merger_typology()` (deal structure, affiliation, relative size,
    and donor distress) were scripts; `build_merger_data()` now returns
    both as `leadership` and `typology`.
  - Models: `build_model_data()` assembles the treated units, control sets
    (including a match on the combined recipient + donor baseline), donor
    sums, and outcome panel once. `merger_did()` (long differences for
    every outcome and design), `did_breakouts()`, `did_sensitivity()` with
    `did_variants()`, `did_event_study()`, `did_baseline_means()`,
    `did_funnel()`, and `did_composition()` run from it. These replace the
    paper's model script.
  - `panel_measures()` keeps the Part I revenue sources and Part IX
    functional and management expenses, so the models no longer re-read
    the e-file cache.
  - New vignette, "Workflow: from Schedule N to merger estimates".
* `merger_fiscal_panel()` no longer fails with current `fiscal` versions,
  whose `compute_all_panel(append_to_df = FALSE)` errors when re-sorting
  rows.
* `panel990` and `fiscal` are pinned to tested commits in `Remotes`.
  `fixest` and `DBI` are suggested.
* Vignettes, the README, and examples use a narrower code style: one
  argument per line and each step's result shown.

* Outcome measures from the merger and financial-vulnerability literatures:
  - `merger_measures()` adds investment and other revenue, `REVENUE_HHI`
    (Part I revenue concentration, via `revenue_hhi()`), `ADMIN_RATIO`,
    revenue, expenses, and compensation per employee, and `DEFICIT` /
    `NEG_NET_ASSETS` flags. `panel_measures()` carries `ADMIN_RATIO` and
    `REVENUE_HHI`, and `panel_columns()` now reads Part I investment and
    other revenue.
  - `trend_measures()`: symmetric year-over-year growth (revenue,
    expenses, contributions, program revenue, net assets), trailing revenue
    coefficient of variation, and deficit-year counts. Windows never use
    future years or bridge filing gaps. `merger_fiscal_panel(trends = TRUE)`
    adds them by default.
  - `tuckman_chang()`: Tuckman-Chang (1991) vulnerability flags (bottom
    quintile on equity, margin, and admin costs, top quintile on revenue
    concentration), with cutoffs from a reference panel.
  - `merger_proforma()`: combined donor + recipient series that sums the
    organizations before the merger and uses the recipient alone after it,
    with ratios recomputed.

* Classifier inspection tables: `sn_labeled()` stacks Schedule N Part I and
  Part II asset lines into one tidy table, with each part's checkbox answers
  (`sn_checkboxes()`), the Part III text, the filing's label and evidence,
  and `IS_MERGER_RECIPIENT` on lines to the merger recipient.
  `sn_inspection()` draws `num` non-overlapping samples stratified by label,
  with blank review columns. `dev/build-inspection.R` saves one 100-case
  table to `data-dev/`.

* Matched comparison samples (`vignette("matching")`):
  - `build_match_data()` runs every matching step in one call and returns
    the sample, pool, candidates for each specification, balance, and
    coverage (`match_coverage()`).
  - `get_panel()` builds the full 990 / 990-EZ organization-year panel for
    every filer, with constant-dollar size, margin, equity ratio, months of
    cash, NTEE, and subsection (`panel_measures()`, `real_dollars()`,
    `cpi_u()`, `ntee_level()`).
  - `merger_sample()` keeps merger cases whose recipient filed in every
    year t-2..t+2, with t-3/t-2 baselines for donor and recipient.
  - `match_pool()` builds eligible comparison org-years: a full t-2..t+2
    window around any year, and no Schedule N involvement nearby
    (`schedule_n_events()`).
  - `match_candidates()` finds every candidate in the same NTEE group within
    size and profitability (or fiscal-health) calipers, across any years,
    ranked by distance. `match_balance()` reports standardized differences.
  - `dev/build-matching.R` adds these tables to the database.
  - NTEE codes the current BMF lacks (`"UNDEFINED"`, about a quarter of
    filers) are filled from the NCCS legacy BMF (`legacy_ntee()`,
    `fill_ntee()`, `get_panel(ntee_legacy = TRUE)`). `NTEE_SOURCE` records
    where each code came from.

* Classifier rules revised after hand validation on 300 filings
  (`dev/validation/`; PLAN.md section 9). Agreement with hand labels rose
  from 62% to 70%, and merger recall from 51% to 71%.
  - `merger_rules(min_top_share = 0.75)`: the default was 0.5. The share
    test now always applies, not only when there are several nonprofit
    recipients.
  - `merger_rules(final_as_termination = TRUE)`: Part-II-only filings with
    the final-return box are treated as terminations. New `TERMINATED`
    column.
  - `merger_rules(sn_text = TRUE)`: merger language in Schedule N's own text
    (`SN_MERGER_TEXT` from `sn_filings()`, pattern `sn_merger_pattern()`)
    is merger evidence on its own, with `BASIS = "sn_text"`.
  - `merger_rules(promote = FALSE)` is now the default. Only 1 of 13
    promoted filings read as a merger. Set `promote = TRUE` for a broad
    definition.

* `build_merger_data()` runs the whole pipeline and returns every table. It
  accepts pre-fetched inputs, so `npmerger_example()` runs offline.
* Merger cases: `build_merger_cases()` (merger IDs, groups, and the merger
  year on each organization's fiscal calendar), `merger_roles()`,
  `transfer_value()` (FMV by asset class, coverage of the donor's assets,
  outlier flags), and `asset_class()`.
* Core data: `get_core()`, `org_years()` (one return per organization-year),
  and `merger_measures()` (harmonized 990 / 990-EZ revenue, expenses,
  assets, debt, staff costs, executive pay, grants, and overhead).
  `get_bmf()` adds NTEE codes and ruling years.
* Analysis tables: `merger_attributes()` (donor and recipient attributes
  with five years of size history), `merger_part7()` (Part VII rosters from
  t-2 to t+2 with `IN_BOTH`), and `merger_fiscal_panel()` (measures,
  'fiscal' ratios, an optional fixed-calibration index, and optional
  trailing smoothing via `smooth_trailing()`).
* `recover_recipient_ein()` recovers missing recipient EINs by unique name
  and ZIP or state match against 990 filers (`get_name_index()`).

* Merger evidence: `get_evidence_tables()` reads the 990 header, Part VII,
  Part VI, Schedule O, Schedule R, Schedule A, and mission tables for the
  donors and recipients in a set of filings. `merger_features()` adds:
  Part VII leadership overlap (`leader_overlap()`), counts of dissolving
  donors sharing a successor (`add_donor_counts()`), donor and recipient
  filing history and new-entity detection (`add_filing_history()`),
  corroborating disclosures (`add_corroboration()`), affiliation
  (`add_affiliation()`), and mission similarity (`add_mission_similarity()`).
* `classify_transactions()` can promote an asset transfer to a merger when at
  least two corroborating signals agree, and records `BASIS` and
  `N_CORROBORATE`.
* pkgdown site using the NODC `pkgstyle` template, and an overview vignette.
* Initial package skeleton: Schedule N retrieval, flag/EIN/IRC-section
  parsers, transaction-level stacking of Schedule N Parts I and II, merger ID
  helpers, and default classification rules.
