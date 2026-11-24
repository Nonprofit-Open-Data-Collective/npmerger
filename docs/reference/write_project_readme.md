# Write the project README

Lists every table in the project database with its row count, and the
build log.
[`build_merger_database()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_database.md)
calls it after each run.

## Usage

``` r
write_project_readme(project)
```

## Arguments

- project:

  A
  [`merger_project()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_project.md).

## Value

The README path, invisibly.
