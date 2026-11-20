# npmerger: Build Nonprofit Merger Datasets from IRS 990 Efile Data

Pipeline stages, each a separate function so users can enter at any
point:

## Details

1.  **Retrieve**:
    [`get_schedule_n()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/get_schedule_n.md)
    downloads Schedule N tables through 'panel990'.

2.  **Transactions**:
    [`sn_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_transactions.md)
    stacks Part I and Part II asset lines into one long table, and
    [`sn_filings()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_filings.md)
    builds one row per Schedule N filing.

3.  **Classify**:
    [`classify_transactions()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/classify_transactions.md)
    labels each filing (merger2, mergerN, consolidation, asset_transfer,
    closure, asset_disposition, reorganization, other) using rules from
    [`merger_rules()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_rules.md).

4.  **Cases and tables**: merger IDs
    ([`merger_id()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_id.md))
    plus the donor, recipient, Part VII and fiscal panels (in
    development).

## See also

Useful links:

- <https://nonprofit-open-data-collective.github.io/npmerger/>

- <https://github.com/Nonprofit-Open-Data-Collective/npmerger>

- Report bugs at
  <https://github.com/Nonprofit-Open-Data-Collective/npmerger/issues>

## Author

**Maintainer**: Jesse Lecy <jdlecy@gmail.com>
([ORCID](https://orcid.org/0000-0003-4974-0782))
