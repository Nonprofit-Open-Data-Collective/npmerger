# Build a project database stage by stage

Runs the npmerger workflow into one project folder
([`merger_project()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_project.md)),
writing every table to one DuckDB database and a log for each stage:

## Usage

``` r
build_merger_database(
  project,
  stages = c("merger", "match", "model"),
  years = efile_years(),
  merger_args = list(),
  match_args = list(),
  model_args = list(),
  verbose = TRUE
)
```

## Arguments

- project:

  A
  [`merger_project()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_project.md).

- stages:

  Stages to run, in order.

- years:

  Schedule N tax years for the merger stage.

- merger_args, match_args, model_args:

  Lists of further arguments to
  [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md),
  [`build_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_match_data.md),
  [`build_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_model_data.md).

- verbose:

  Print progress (it is always logged).

## Value

The project, invisibly.

## Details

1.  `"merger"`:
    [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md).
    Schedule N, the classifier, and tables about the organizations
    involved, including
    [`merger_leadership()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_leadership.md)
    and
    [`merger_typology()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_typology.md).
    Stands alone: it reads only the returns of the organizations that
    filed Schedule N or received assets.

2.  `"match"`:
    [`build_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_match_data.md).
    The full 990 panel, the research sample, the comparison pool,
    candidates, and balance.

3.  `"model"`:
    [`build_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_model_data.md).
    Treated units, trimmed candidate sets, donor sums, and the
    organization-years the models read.

Each stage reads what it needs from the database, so stages can be run
separately and later ones rerun without repeating earlier ones. Results
of the models themselves are not stored; run
[`merger_did()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_did.md)
and friends on
[`load_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/load_merger_data.md).

## Examples

``` r
if (FALSE) { # \dontrun{
proj <- merger_project( "~/NPMERGER" )

build_merger_database( proj, years = efile_years() )

dd  <- load_model_data( proj )
fit <- merger_did( dd )
} # }
```
