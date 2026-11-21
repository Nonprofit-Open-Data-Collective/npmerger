# data-dev

Working data for checking the package by hand. This folder is not part of the built package.

## sn-inspection-01.csv

This file is a sample of 100 Schedule N filings for checking the classifier by hand. It is built by `dev/build-inspection.R` (seed 2026) with `sn_labeled()` and `sn_inspection()`.

The sample is stratified by classifier label:

| Label | Filings |
|---|---|
| `merger2` | 17 |
| `mergerN` | 17 |
| `consolidation` | 17 |
| `asset_transfer` | 17 |
| `closure` | 16 |
| `asset_disposition` | 16 |

The file has one row per Schedule N asset line, with Part I and Part II stacked. A filing part that has a header but no asset lines gets one row with `LINE = 0`. Filing-level columns repeat on every row of the filing.

| Columns | Meaning |
|---|---|
| `TABLE`, `CASE` | Table number and case number (1–100) within the table. |
| `OBJECTID`, `EIN2`, `ORG_NAME`, `TAX_YEAR`, `TAX_PERIOD_END`, `URL` | The filing (the donor), with a link to the e-file XML. |
| `TYPE`, `BASIS` | The classifier label, and for mergers the evidence the label rests on: `leader`, `sn_text`, or `corroborated`. |
| `AFFILIATED`, `TERMINATED`, `FINAL_RETURN`, `LEADER`, `LEADER_SN`, `LEADER_P7`, `SN_MERGER_TEXT`, `N_CORROBORATE`, `N_NP_RECIP`, `TOP_SHARE`, `FMV_TOTAL`, `N_DONORS`, `R_NEW` | The evidence the classifier used. See `?classify_transactions`. |
| `MERGER_ID`, `MERGER_RECIP_EIN2` | The merger case and its recipient (merger labels only). |
| `HAS_RECIPIENT_ROW` | At least one asset line goes to the merger recipient. `NA` if the filing is not a merger. |
| `PART`, `LINE` | Schedule N part (1 = liquidation, termination or dissolution; 2 = disposition of more than 25% of net assets) and line number within that part. |
| `IS_MERGER_RECIPIENT` | This line's recipient is the merger recipient. |
| `ASSET_DESC`, `DIST_DATE`, `FMV`, `FMV_METHOD` | The asset line as reported. |
| `RECIP_EIN2`, `EIN_SOURCE` | Recipient EIN. `EIN_SOURCE` is `reported`, or `name_zip` / `name_state` when the EIN was recovered by matching the recipient's name. |
| `RECIP_NAME`, `RECIP_CITY`, `RECIP_STATE`, `RECIP_ZIP`, `IRC_SECTION`, `RECIP_TYPE`, `SELF_TRANSFER` | Recipient details. `SELF_TRANSFER` means the filer listed itself as the recipient. |
| `DIR_SUCCESSOR_X`, `EMPL_SUCCESSOR_X`, `OWN_SUCCESSOR_X`, `REC_COMP_X` | Lines 2a–2d of the row's part. Is any officer, director, trustee or key employee also a director or officer (2a), an employee (2b), or an owner (2c) of the successor, or paid by it (2d)? |
| `ASSET_DIST_GVRN_X`, `REQ_NOTIFY_ATTORNEY_X`, `ATTORNEY_NOTIFIED_X`, `LIAB_PAID_X`, `BOND_OUTSTANDING_X`, `BOND_LIAB_DISCHARGED_X` | Part I lines 3–6: distribution under governing documents, attorney general notice required and given, liabilities paid, tax-exempt bonds outstanding and discharged. These are `NA` on Part II rows. |
| `P3_TEXT` | Part III explanations, as `line reference: text`, separated by ` \| `. |
| `REVIEW_TYPE`, `REVIEW_IS_MERGER`, `REVIEW_RECIPIENT_OK`, `REVIEW_NOTE` | Blank columns for the reviewer. Fill them in on the first row of each case. |

To draw more tables, or tables of a different size, run `NUM=3 N=50 Rscript dev/build-inspection.R`. Tables never share filings.
