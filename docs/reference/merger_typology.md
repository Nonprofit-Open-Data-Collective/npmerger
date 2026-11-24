# Merger typology

Sorts merger cases into types by deal structure, affiliation, and the
relative size and condition of the two organizations in the years before
the merger. Rules are applied in order; the first that matches wins:

## Usage

``` r
merger_typology(cases, donors, recipients, transfers)

typology_levels()
```

## Arguments

- cases, donors, recipients, transfers:

  Tables from
  [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md).

## Value

A data.table, one row per `MERGER_ID`: `MERGER_GROUP_ID`, `TYPE`,
`TYPOLOGY` (a factor in the order above), `AFFILIATED`, `RATIO`,
`DISTRESS`, `ASSET_LIGHT`, `D_SIZE`, `R_SIZE`, and `FMV` (assets
transferred, `NA` for outliers).

## Details

1.  `consolidation` cases: "Consolidation into a new entity";

2.  `mergerN` cases: "Multi-party absorption";

3.  affiliated organizations: "Related-entity restructuring";

4.  no recipient size before the merger: "Recipient not observed before
    the merger";

5.  little transferred (FMV under \$25,000, or not reported) by a donor
    with under \$50,000 in assets, and donor less than half the
    recipient's size: "Program or asset-light transfer";

6.  donor less than half the recipient's size and in distress:
    "Absorption of a struggling organization";

7.  donor less than half the recipient's size: "Absorption of a stable
    smaller organization";

8.  donor between half and twice the recipient's size: "Merger of
    near-equals";

9.  otherwise: "Larger donor into smaller successor".

Size is the donor's budget (the larger of revenue and expenses) over the
recipient's revenue, in t-1 (else t-2). The donor is in distress when
expenses exceed revenue, or revenue fell 25% or more from t-3 (else
t-4).
