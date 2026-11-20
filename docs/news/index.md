# Changelog

## npmerger 0.0.0.9000

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
  promotes an asset transfer to a merger when at least two corroborating
  signals agree, and records `BASIS` and `N_CORROBORATE`.
- pkgdown site using the NODC `pkgstyle` template, and an overview
  vignette.
- Initial package skeleton: Schedule N retrieval, flag/EIN/IRC-section
  parsers, transaction-level stacking of Schedule N Parts I and II,
  merger ID helpers, and default classification rules.
