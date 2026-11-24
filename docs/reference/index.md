# Package index

## Run the whole pipeline

Build every merger table in one call, or try it offline on the bundled
example.

- [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)
  : Build the full merger dataset
- [`npmerger_example()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/npmerger_example.md)
  : Example data for offline use
- [`efile_years()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/efile_years.md)
  : Tax years available in the e-file release

## Retrieve Schedule N

Download Schedule N tables through panel990.

- [`get_schedule_n()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_schedule_n.md)
  : Retrieve Schedule N tables
- [`sn_table_names()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_table_names.md)
  : Schedule N table names in the NCCS efile release

## Clean and stack transactions

Turn raw Schedule N tables into one row per asset line and one row per
filing, and recover missing recipient EINs.

- [`sn_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_transactions.md)
  : Stack Schedule N Part I and Part II asset lines
- [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md)
  : One row per Schedule N filing
- [`recover_recipient_ein()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/recover_recipient_ein.md)
  : Recover missing recipient EINs by name and location
- [`get_name_index()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_name_index.md)
  [`name_index()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_name_index.md)
  : Name index of 990 filers
- [`org_name_key()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/org_name_key.md)
  : Normalize organization names for matching
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
- [`sn_merger_pattern()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_merger_pattern.md)
  : Merger language in Schedule N's own text

## Classify transactions

Label each filing as a merger, asset transfer, closure, disposition, or
reorganization, using rules you can change.

- [`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md)
  : Classify Schedule N filings into transaction types
- [`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md)
  : Default transaction classification rules
- [`transaction_types()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/transaction_types.md)
  : Transaction type labels
- [`sched_n_table()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sched_n_table.md)
  : Schedule N transaction table

## Inspect the classifier

A tidy, labeled table of every Schedule N asset line with its
checkboxes, and stratified samples of it for review by hand.

- [`sn_labeled()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_labeled.md)
  : Labeled Schedule N table for inspection
- [`sn_inspection()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_inspection.md)
  : Draw inspection samples from the labeled Schedule N table
- [`sn_checkboxes()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_checkboxes.md)
  : Schedule N checkbox fields

## Build merger cases

Donor-recipient pairs with merger IDs, each organization’s merger year,
and the value of assets transferred.

- [`build_merger_cases()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_cases.md)
  : Build merger cases (donor-recipient pairs)
- [`merger_id()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_id.md)
  [`merger_group_id()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_id.md)
  : Build merger identifiers
- [`merger_roles()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_roles.md)
  : Donor and recipient roles for each merger
- [`transfer_value()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/transfer_value.md)
  : Value of assets transferred in each merger
- [`asset_class()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/asset_class.md)
  : Classify Schedule N asset descriptions

## Core financial data

Read core 990 tables for merger organizations and build harmonized 990 /
990-EZ organization-years.

- [`get_core()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_core.md)
  : Retrieve core 990 tables for a set of organizations
- [`core_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/core_tables.md)
  : Core 990 tables read for merger organizations
- [`org_years()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/org_years.md)
  : One row per organization-year from core tables
- [`merger_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_measures.md)
  : Harmonized financial measures for 990 and 990-EZ filers
- [`get_bmf()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_bmf.md)
  : Retrieve BMF organization traits for merger organizations

## Analysis tables

Donor and recipient attributes, the Part VII panel, and the
fiscal-health panel around each merger.

- [`merger_attributes()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_attributes.md)
  : Donor and recipient attribute tables
- [`merger_part7()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_part7.md)
  : Part VII panel around each merger
- [`merger_fiscal_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_fiscal_panel.md)
  : Fiscal-health panel around each merger
- [`smooth_trailing()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/smooth_trailing.md)
  : Smooth panel variables using only current and past years

## Outcome measures

Measures from the merger and financial-vulnerability literatures beyond
the ‘fiscal’ ratios, such as revenue concentration, growth, volatility,
deficit history, Tuckman-Chang flags, and a combined donor + recipient
pre-merger baseline.

- [`revenue_hhi()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/revenue_hhi.md)
  : Revenue concentration (Herfindahl-Hirschman index)
- [`trend_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/trend_measures.md)
  : Growth, volatility, and deficit history within each organization
- [`tuckman_chang()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/tuckman_chang.md)
  : Tuckman-Chang financial vulnerability flags
- [`merger_proforma()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_proforma.md)
  : Combined donor + recipient (pro forma) series

## Matched comparison samples

Build the full 990 panel, a research sample of mergers with a full
observation window, and candidate comparison organizations for merger
recipients.

- [`build_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_match_data.md)
  : Build the matched comparison data in one call
- [`match_coverage()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_coverage.md)
  : How many treated units have match candidates
- [`get_panel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_panel.md)
  : Build the full 990 organization-year panel
- [`panel_columns()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_columns.md)
  : Columns read for the full 990 matching panel
- [`panel_measures()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/panel_measures.md)
  : Slim matching measures for an organization-year table
- [`merger_sample()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_sample.md)
  : Research sample of mergers with a full observation window
- [`schedule_n_events()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/schedule_n_events.md)
  : Schedule N involvement by organization and year
- [`match_pool()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_pool.md)
  : Pool of potential comparison organization-years
- [`match_candidates()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_candidates.md)
  : Find match candidates for merger recipients
- [`match_balance()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/match_balance.md)
  : Covariate balance of a matched sample
- [`ntee_level()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/ntee_level.md)
  : Clean NTEE code to a given number of characters
- [`legacy_ntee()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/legacy_ntee.md)
  : NTEE codes from NCCS legacy BMF files
- [`fill_ntee()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/fill_ntee.md)
  : Fill missing NTEE codes from another source
- [`real_dollars()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/real_dollars.md)
  : Convert nominal dollars to constant dollars
- [`cpi_u()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/cpi_u.md)
  : Consumer price index (CPI-U, annual average)

## Merger characteristics

Leadership and board outcomes, a typology of merger cases, and a file
for checking leadership matches by hand.

- [`merger_leadership()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_leadership.md)
  : Leadership and board outcomes for each merger case
- [`leadership_inspection()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/leadership_inspection.md)
  : Leadership inspection file
- [`merger_typology()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_typology.md)
  [`typology_levels()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_typology.md)
  : Merger typology

## Models

Matched difference-in-differences for merger recipients. Build the model
data once, then run the main estimates, breakouts, sensitivity variants,
and event study from it.

- [`build_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_model_data.md)
  : Build the data for the merger models
- [`merger_did()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md)
  [`did_breakouts()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md)
  [`did_sensitivity()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md)
  : Matched difference-in-differences for merger recipients
- [`did_event_study()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_event_study.md)
  : Event-study estimates for merger recipients
- [`did_baseline_means()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_baseline_means.md)
  [`did_funnel()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_baseline_means.md)
  [`did_composition()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_baseline_means.md)
  : Baseline means, sample funnel, and sample composition
- [`did_outcomes()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_outcomes.md)
  : Outcomes for the merger models
- [`did_designs()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_designs.md)
  : Designs for the merger models
- [`did_variants()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_variants.md)
  : Sensitivity variants used in the paper
- [`did_breakout_vars()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/did_breakout_vars.md)
  : Unit-level breakout variables

## Project folder and database

Run the whole workflow into one project folder, with one DuckDB
database, a log for each stage, and a README.

- [`merger_project()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_project.md)
  : Create or open an npmerger project folder
- [`build_merger_database()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_database.md)
  : Build a project database stage by stage
- [`load_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/load_merger_data.md)
  [`load_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/load_merger_data.md)
  [`load_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/load_merger_data.md)
  : Load stage outputs from a project database
- [`db_tables()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/db_tables.md)
  [`db_read()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/db_tables.md)
  [`db_write()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/db_tables.md)
  : Tables in a project database
- [`write_project_readme()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/write_project_readme.md)
  : Write the project README

## Package

- [`npmerger`](https://nonprofit-open-data-collective.github.io/npmerger/reference/npmerger-package.md)
  [`npmerger-package`](https://nonprofit-open-data-collective.github.io/npmerger/reference/npmerger-package.md)
  : npmerger: Build Nonprofit Merger Datasets from IRS 990 Efile Data
