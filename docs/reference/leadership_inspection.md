# Leadership inspection file

A tidy, one-row-per-person table for checking by hand how Part VII names
are matched across a merger. For each sampled case it lists:

## Usage

``` r
leadership_inspection(
  merger_data,
  n = 100L,
  types = c("merger2", "mergerN", "consolidation"),
  pre = -2:0,
  post = 1:2,
  seed = 1L,
  file = NULL
)
```

## Arguments

- merger_data:

  The list from
  [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)
  (uses `part7`, and `leadership`, `donors`, `recipients` when present),
  or a project from
  [`merger_project()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_project.md).

- n:

  Number of cases to sample.

- types:

  Merger types to sample from.

- pre, post:

  Event years for the rosters before and after the merger.

- seed:

  Random seed for the sample.

- file:

  CSV path to write, or `NULL` to only return the table.

## Value

A data.table, invisibly when `file` is given: `MERGER_ID`, `TYPE`,
`RETENTION` (group), `SHARE_A_RETAINED`, `CEO_CAT`, `BOARD_CAT`, `CASE`,
`ORG_EIN2`, `ORG_NAME`, `PERSON_KEY`, `NAME`, `TITLE`, `PAY`
(compensation from the organization), `HOURS`, `POSITION`, `PERIODS`,
and flags `IN_ORG_A`, `IN_ORG_B`, `IN_MERGED`, `RETAINED_FROM_A` (in ORG
A and in MERGED), and `GOVERNING` (trustee or officer, or a 990-EZ
listing).

## Details

- `ORG A`: everyone on the donor's Part VII in the `pre` years;

- `ORG B`: everyone on the recipient's Part VII in the `pre` years;

- `MERGED`: everyone on the recipient's Part VII in the `post` years.

A person is one name key
([`person_key()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/person_key.md),
the key the matching uses), so the file shows exactly what the matcher
treats as the same person. When a person's name, title, pay, or hours
differ across years, the values are joined with `;;`, each followed by
the years it applies to, for example `PRESIDENT {t=-2,-1};; CEO {t=0}`.

Cases are drawn in equal numbers from three groups by the share of ORG A
people who appear in MERGED: `none` (0), `some` (above 0 and below 0.5),
and `most` (0.5 or more). Only cases with an ORG A roster and a MERGED
roster are eligible.

## Examples

``` r
if (FALSE) { # \dontrun{
proj <- merger_project( "~/Documents/NPMERGER" )

leadership_inspection(
  merger_data = proj,
  n           = 100,
  file        = file.path( proj$root, "leadership-inspection.csv" )
)
} # }
```
