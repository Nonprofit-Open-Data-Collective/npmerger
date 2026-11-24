# Changelog

## npmerger 0.0.0.9000

- The whole workflow now runs inside the package, into one project
  folder:

  - [`merger_project()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_project.md)
    creates a folder with the download cache, one DuckDB database, a
    `logs/` folder, and a README.
    [`build_merger_database()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_database.md)
    runs the three stages (`"merger"`, `"match"`, `"model"`) into it.
    Each stage writes its tables to the database, a log with package
    versions, git commit, settings, and
    [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html), and a
    row in `build_log`.
    [`load_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/load_merger_data.md),
    [`load_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/load_merger_data.md),
    and
    [`load_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/load_merger_data.md)
    rebuild each stage’s object from the database.
    [`db_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/db_tables.md),
    [`db_read()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/db_tables.md),
    and
    [`db_write()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/db_tables.md)
    give direct access. `dev/build-project.R` replaces
    `dev/build-database.R` and `dev/build-matching.R`.
  - [`merger_leadership()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_leadership.md)
    (CEO and board outcomes from the Part VII panel) and
    [`merger_typology()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_typology.md)
    (deal structure, affiliation, relative size, and donor distress)
    were scripts;
    [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)
    now returns both as `leadership` and `typology`.
  - Models:
    [`build_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_model_data.md)
    assembles the treated units, control sets (including a match on the
    combined recipient + donor baseline), donor sums, and outcome panel
    once.
    [`merger_did()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md)
    (long differences for every outcome and design),
    [`did_breakouts()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md),
    [`did_sensitivity()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md)
    with
    [`did_variants()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_variants.md),
    [`did_event_study()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_event_study.md),
    [`did_baseline_means()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_baseline_means.md),
    [`did_funnel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_baseline_means.md),
    and
    [`did_composition()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_baseline_means.md)
    run from it. These replace the paper’s model script.
  - [`panel_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_measures.md)
    keeps the Part I revenue sources and Part IX functional and
    management expenses, so the models no longer re-read the e-file
    cache.
  - New vignette, “Workflow: from Schedule N to merger estimates”.

- [`merger_fiscal_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_fiscal_panel.md)
  no longer fails with current `fiscal` versions, whose
  `compute_all_panel(append_to_df = FALSE)` errors when re-sorting rows.

- `panel990` and `fiscal` are pinned to tested commits in `Remotes`.
  `fixest` and `DBI` are suggested.

- Vignettes, the README, and examples use a narrower code style: one
  argument per line and each step’s result shown.

- Outcome measures from the merger and financial-vulnerability
  literatures:

  - [`merger_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_measures.md)
    adds investment and other revenue, `REVENUE_HHI` (Part I revenue
    concentration, via
    [`revenue_hhi()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/revenue_hhi.md)),
    `ADMIN_RATIO`, revenue, expenses, and compensation per employee, and
    `DEFICIT` / `NEG_NET_ASSETS` flags.
    [`panel_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_measures.md)
    carries `ADMIN_RATIO` and `REVENUE_HHI`, and
    [`panel_columns()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_columns.md)
    now reads Part I investment and other revenue.
  - [`trend_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/trend_measures.md):
    symmetric year-over-year growth (revenue, expenses, contributions,
    program revenue, net assets), trailing revenue coefficient of
    variation, and deficit-year counts. Windows never use future years
    or bridge filing gaps. `merger_fiscal_panel(trends = TRUE)` adds
    them by default.
  - [`tuckman_chang()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/tuckman_chang.md):
    Tuckman-Chang (1991) vulnerability flags (bottom quintile on equity,
    margin, and admin costs, top quintile on revenue concentration),
    with cutoffs from a reference panel.
  - [`merger_proforma()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_proforma.md):
    combined donor + recipient series that sums the organizations before
    the merger and uses the recipient alone after it, with ratios
    recomputed.

- Classifier inspection tables:
  [`sn_labeled()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_labeled.md)
  stacks Schedule N Part I and Part II asset lines into one tidy table,
  with each part’s checkbox answers
  ([`sn_checkboxes()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_checkboxes.md)),
  the Part III text, the filing’s label and evidence, and
  `IS_MERGER_RECIPIENT` on lines to the merger recipient.
  [`sn_inspection()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_inspection.md)
  draws `num` non-overlapping samples stratified by label, with blank
  review columns. `dev/build-inspection.R` saves one 100-case table to
  `data-dev/`.

- Matched comparison samples
  ([`vignette("matching")`](https://nonprofit-open-data-collective.github.io/npmerger/articles/matching.md)):

  - [`build_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_match_data.md)
    runs every matching step in one call and returns the sample, pool,
    candidates for each specification, balance, and coverage
    ([`match_coverage()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_coverage.md)).
  - [`get_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_panel.md)
    builds the full 990 / 990-EZ organization-year panel for every
    filer, with constant-dollar size, margin, equity ratio, months of
    cash, NTEE, and subsection
    ([`panel_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_measures.md),
    [`real_dollars()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/real_dollars.md),
    [`cpi_u()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/cpi_u.md),
    [`ntee_level()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/ntee_level.md)).
  - [`merger_sample()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_sample.md)
    keeps merger cases whose recipient filed in every year t-2..t+2,
    with t-3/t-2 baselines for donor and recipient.
  - [`match_pool()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_pool.md)
    builds eligible comparison org-years: a full t-2..t+2 window around
    any year, and no Schedule N involvement nearby
    ([`schedule_n_events()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/schedule_n_events.md)).
  - [`match_candidates()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_candidates.md)
    finds every candidate in the same NTEE group within size and
    profitability (or fiscal-health) calipers, across any years, ranked
    by distance.
    [`match_balance()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_balance.md)
    reports standardized differences.
  - `dev/build-matching.R` adds these tables to the database.
  - NTEE codes the current BMF lacks (`"UNDEFINED"`, about a quarter of
    filers) are filled from the NCCS legacy BMF
    ([`legacy_ntee()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/legacy_ntee.md),
    [`fill_ntee()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/fill_ntee.md),
    `get_panel(ntee_legacy = TRUE)`). `NTEE_SOURCE` records where each
    code came from.

- Classifier rules revised after hand validation on 300 filings
  (`dev/validation/`; PLAN.md section 9). Agreement with hand labels
  rose from 62% to 70%, and merger recall from 51% to 71%.

  - `merger_rules(min_top_share = 0.75)`: the default was 0.5. The share
    test now always applies, not only when there are several nonprofit
    recipients.
  - `merger_rules(final_as_termination = TRUE)`: Part-II-only filings
    with the final-return box are treated as terminations. New
    `TERMINATED` column.
  - `merger_rules(sn_text = TRUE)`: merger language in Schedule N’s own
    text (`SN_MERGER_TEXT` from
    [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md),
    pattern
    [`sn_merger_pattern()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_merger_pattern.md))
    is merger evidence on its own, with `BASIS = "sn_text"`.
  - `merger_rules(promote = FALSE)` is now the default. Only 1 of 13
    promoted filings read as a merger. Set `promote = TRUE` for a broad
    definition.

- [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)
  runs the whole pipeline and returns every table. It accepts
  pre-fetched inputs, so
  [`npmerger_example()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/npmerger_example.md)
  runs offline.

- Merger cases:
  [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md)
  (merger IDs, groups, and the merger year on each organization’s fiscal
  calendar),
  [`merger_roles()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_roles.md),
  [`transfer_value()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/transfer_value.md)
  (FMV by asset class, coverage of the donor’s assets, outlier flags),
  and
  [`asset_class()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/asset_class.md).

- Core data:
  [`get_core()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_core.md),
  [`org_years()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/org_years.md)
  (one return per organization-year), and
  [`merger_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_measures.md)
  (harmonized 990 / 990-EZ revenue, expenses, assets, debt, staff costs,
  executive pay, grants, and overhead).
  [`get_bmf()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_bmf.md)
  adds NTEE codes and ruling years.

- Analysis tables:
  [`merger_attributes()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_attributes.md)
  (donor and recipient attributes with five years of size history),
  [`merger_part7()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_part7.md)
  (Part VII rosters from t-2 to t+2 with `IN_BOTH`), and
  [`merger_fiscal_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_fiscal_panel.md)
  (measures, ‘fiscal’ ratios, an optional fixed-calibration index, and
  optional trailing smoothing via
  [`smooth_trailing()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/smooth_trailing.md)).

- [`recover_recipient_ein()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/recover_recipient_ein.md)
  recovers missing recipient EINs by unique name and ZIP or state match
  against 990 filers
  ([`get_name_index()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_name_index.md)).

- Merger evidence:
  [`get_evidence_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_evidence_tables.md)
  reads the 990 header, Part VII, Part VI, Schedule O, Schedule R,
  Schedule A, and mission tables for the donors and recipients in a set
  of filings.
  [`merger_features()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_features.md)
  adds: Part VII leadership overlap
  ([`leader_overlap()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/leader_overlap.md)),
  counts of dissolving donors sharing a successor
  ([`add_donor_counts()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_donor_counts.md)),
  donor and recipient filing history and new-entity detection
  ([`add_filing_history()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_filing_history.md)),
  corroborating disclosures
  ([`add_corroboration()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_corroboration.md)),
  affiliation
  ([`add_affiliation()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_affiliation.md)),
  and mission similarity
  ([`add_mission_similarity()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_mission_similarity.md)).

- [`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md)
  can promote an asset transfer to a merger when at least two
  corroborating signals agree, and records `BASIS` and `N_CORROBORATE`.

- pkgdown site using the NODC `pkgstyle` template, and an overview
  vignette.

- Initial package skeleton: Schedule N retrieval, flag/EIN/IRC-section
  parsers, transaction-level stacking of Schedule N Parts I and II,
  merger ID helpers, and default classification rules.
