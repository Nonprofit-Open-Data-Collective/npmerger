# Package index

## Retrieve Schedule N

Download Schedule N tables (and, later, core 990 tables for selected
organizations) through panel990.

- [`get_schedule_n()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_schedule_n.md)
  : Retrieve Schedule N tables
- [`sn_table_names()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_table_names.md)
  : Schedule N table names in the NCCS efile release
- [`get_core()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_core.md)
  : Retrieve core 990 tables for a set of organizations

## Clean and stack transactions

Turn raw Schedule N tables into one row per asset line and one row per
filing.

- [`sn_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_transactions.md)
  : Stack Schedule N Part I and Part II asset lines
- [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md)
  : One row per Schedule N filing
- [`sn_flag()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_flag.md)
  : Parse efile checkbox values
- [`clean_ein()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/clean_ein.md)
  [`as_ein2()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/clean_ein.md)
  : Clean EINs
- [`parse_irc_section()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/parse_irc_section.md)
  : Classify the free-text IRC section / entity type of a Schedule N
  recipient

## Gather merger evidence

Read the 990 tables for the donors and recipients involved, and add
leadership, multi-party, filing-history, corroboration, and affiliation
evidence to each filing.

- [`get_evidence_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_evidence_tables.md)
  : Retrieve the evidence tables for a set of Schedule N filings
- [`evidence_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/evidence_tables.md)
  : Evidence tables and the columns read from each
- [`merger_features()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_features.md)
  : Add all merger evidence to a filing table
- [`leader_overlap()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/leader_overlap.md)
  : Part VII leadership overlap between donor and recipient
- [`add_donor_counts()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_donor_counts.md)
  : Count dissolving donors that share a successor
- [`add_filing_history()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_filing_history.md)
  : Donor and recipient filing history
- [`add_corroboration()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_corroboration.md)
  : Corroborating merger disclosures
- [`add_affiliation()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_affiliation.md)
  : Affiliation between donor and recipient
- [`add_mission_similarity()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/add_mission_similarity.md)
  : Mission-statement similarity between donor and recipient
- [`person_key()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/person_key.md)
  : Normalize person names for matching
- [`merger_text_pattern()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_text_pattern.md)
  : Pattern for merger language in narrative text

## Classify transactions

Label each filing as a merger, asset transfer, closure, disposition, or
reorganization, using rules you can change.

- [`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md)
  : Classify Schedule N filings into transaction types
- [`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md)
  : Default transaction classification rules
- [`transaction_types()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/transaction_types.md)
  : Transaction type labels

## Build merger cases and tables

Merger identifiers, donor-recipient cases, and the analysis tables built
around each merger.

- [`merger_id()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_id.md)
  [`merger_group_id()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_id.md)
  : Build merger identifiers
- [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md)
  : Build merger cases (donor-recipient pairs)
- [`transfer_value()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/transfer_value.md)
  : Value of assets transferred to each recipient
- [`sched_n_table()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sched_n_table.md)
  : Schedule N transaction table
- [`merger_attributes()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_attributes.md)
  : Donor and recipient attribute tables
- [`merger_part7()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_part7.md)
  : Part VII panel around each merger
- [`merger_fiscal_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_fiscal_panel.md)
  : Fiscal-health panel around each merger

## Package

- [`npmerger`](https://nonprofit-open-data-collective.github.io/npmerger/reference/npmerger-package.md)
  [`npmerger-package`](https://nonprofit-open-data-collective.github.io/npmerger/reference/npmerger-package.md)
  : npmerger: Build Nonprofit Merger Datasets from IRS 990 Efile Data
