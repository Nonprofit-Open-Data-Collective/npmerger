# Hand-labeling codebook: nonprofit Schedule N events

Each case is one IRS Form 990/990-EZ filing with Schedule N (liquidation, termination,
dissolution, or significant disposition of assets). Read the whole packet (form header, asset
distribution lines, Schedule N Part III narrative, Schedule O excerpts) and judge **what actually
happened to the filing organization**, as a careful human reader would. Do not guess what any
algorithm would say; judge from the text.

## LABEL (choose one)

- **MERGER**: the filing org combined into or with another organization that continues (or a
  newly formed one). Assets go to a successor **and** there is some sign of integration beyond a
  cash gift: words like merged, merger, consolidated, combined, became part of, absorbed,
  successor organization, programs/services/members/staff/board continue at the recipient, or a
  key employee, officer or director moves to the recipient. Union locals merging, chapters folding
  into a parent, and affiliates combining with a sister org all count.
- **ASSET_TRANSFER**: the org dissolved/terminated and gave its remaining assets mostly to **one**
  organization, with **no** sign that programs, members, or people continue there (an ordinary
  residual distribution to a charity at dissolution).
- **CLOSURE**: the org dissolved/terminated with no single successor: assets split across several
  unrelated recipients, spent down, returned, or there were essentially no assets.
- **ASSET_DISPOSITION**: the org **keeps operating** and disposed of a large part of its assets
  (sold property, spun off or transferred a program/division/facility, transferred to a
  partnership or affiliate) but did not itself go away.
- **REORGANIZATION**: the same organization continues in another legal form or under a new EIN
  (conversion to LLC/new corporation, re-incorporation, change of state, a new EIN, a
  tax-status change), with no real counterparty.
- **UNCLEAR**: the text is too thin or contradictory to decide. Use this sparingly; if you can
  make a reasonable call, make it and set CONFIDENCE to low.

Tie-breakers:
- "Final return" checked or Part I filed implies the org ended, but trust the narrative when it
  contradicts the boxes (e.g., a Part II filer whose text says it merged into another org and
  dissolved is MERGER).
- A transfer to a related parent/affiliate "as part of a merger/restructuring" is MERGER. A
  transfer to a related affiliate while the filer keeps operating is ASSET_DISPOSITION.
- A transfer with the description "transfer due to merger" counts as merger evidence even
  without a narrative.
- Generic mission text that happens to contain "combined" or "collaboration" is not merger evidence.

## Flags (TRUE/FALSE/NA when you cannot tell)

- **MULTI**: text indicates two or more organizations (besides the recipient) are combining in
  the same deal.
- **NEW_ENTITY**: the successor is a newly formed organization.
- **PEOPLE_MOVE**: text says board members, officers, key employees, or staff join the recipient.
- **CONTINUES**: text says the filer's programs, services, or members continue at the recipient.

## Output

A CSV with header exactly:
`CASE,LABEL,CONFIDENCE,MULTI,NEW_ENTITY,PEOPLE_MOVE,CONTINUES,NOTE`

CONFIDENCE is high/medium/low. NOTE: up to 15 words, quoted, with commas removed, giving
the key evidence. One row per case, every case in the batch.
