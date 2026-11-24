# Load stage outputs from a project database

Rebuild the objects that
[`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md),
[`build_match_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_match_data.md),
and
[`build_model_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_model_data.md)
return, from the tables
[`build_merger_database()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_database.md)
wrote.

## Usage

``` r
load_merger_data(project)

load_match_data(project, panel = TRUE)

load_model_data(project)
```

## Arguments

- project:

  A
  [`merger_project()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_project.md).

- panel:

  Load the full 990 panel too (several million rows).

## Value

A `merger_data`, `merger_match_data`, or `merger_model_data` object.
