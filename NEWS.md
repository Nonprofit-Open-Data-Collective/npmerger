# npmerger 0.0.0.9000

* Merger evidence: `get_evidence_tables()` reads the 990 header, Part VII,
  Part VI, Schedule O, Schedule R, Schedule A, and mission tables for the
  donors and recipients in a set of filings. `merger_features()` adds:
  Part VII leadership overlap (`leader_overlap()`), counts of dissolving
  donors sharing a successor (`add_donor_counts()`), donor and recipient
  filing history and new-entity detection (`add_filing_history()`),
  corroborating disclosures (`add_corroboration()`), affiliation
  (`add_affiliation()`), and mission similarity (`add_mission_similarity()`).
* `classify_transactions()` promotes an asset transfer to a merger when at
  least two corroborating signals agree, and records `BASIS` and
  `N_CORROBORATE`.
* pkgdown site using the NODC `pkgstyle` template, and an overview vignette.
* Initial package skeleton: Schedule N retrieval, flag/EIN/IRC-section
  parsers, transaction-level stacking of Schedule N Parts I and II, merger ID
  helpers, and default classification rules.
