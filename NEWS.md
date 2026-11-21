# npmerger 0.0.0.9000

* Matched comparison samples:
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
