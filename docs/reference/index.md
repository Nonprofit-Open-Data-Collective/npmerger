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

## Classify transactions

Label each filing as a merger, asset transfer, closure, disposition, or
reorganization, using rules you can change.

- [`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md)
  : Classify Schedule N filings into transaction types
- [`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md)
  : Default transaction classification rules
- [`transaction_types()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/transaction_types.md)
  : Transaction type labels
- [`leader_overlap()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/leader_overlap.md)
  : Part VII leadership overlap between donor and recipient

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
