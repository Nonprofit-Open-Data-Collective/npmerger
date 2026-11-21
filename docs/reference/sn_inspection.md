# Draw inspection samples from the labeled Schedule N table

Samples labeled filings, stratified by classifier label, and returns
every row of each sampled filing. With `num` greater than 1, the tables
do not share filings, so they can go to different reviewers.

## Usage

``` r
sn_inspection(
  x,
  num = 1L,
  n = 100L,
  types = NULL,
  per_type = NULL,
  seed = 1L,
  review_cols = TRUE
)
```

## Arguments

- x:

  A table from
  [`sn_labeled()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_labeled.md).

- num:

  Number of inspection tables.

- n:

  Filings (cases) per table.

- types:

  Labels to sample. Default: every label in `x`.

- per_type:

  Optional named integer vector of filings per label in each table
  (overrides the even split of `n`).

- seed:

  Random seed, or `NULL` to leave the seed alone.

- review_cols:

  Add empty review columns (`REVIEW_TYPE`, `REVIEW_IS_MERGER`,
  `REVIEW_RECIPIENT_OK`, `REVIEW_NOTE`).

## Value

A list of `num` data.tables. Each has `TABLE` and `CASE` (1..n) in front
of the
[`sn_labeled()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/sn_labeled.md)
columns, sorted by label, case, part, and line.

## Examples

``` r
if (FALSE) { # \dontrun{
sn <- get_schedule_n(efile_years())
md <- build_merger_data(sn = sn)
lab <- sn_labeled(sn, md$sched_n, md$cases, md$transactions)
tabs <- sn_inspection(lab, num = 3, n = 100)
data.table::fwrite(tabs[[1]], "inspection-01.csv")
} # }
```
