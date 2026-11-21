# Changelog

## npmerger 0.0.0.9000

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
