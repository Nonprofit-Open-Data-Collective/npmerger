# Tables in a project database

Tables in a project database

## Usage

``` r
db_tables(project)

db_read(project, table = NULL, query = NULL)

db_write(project, tables)
```

## Arguments

- project:

  A
  [`merger_project()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/merger_project.md).

- table:

  Table name.

- query:

  Optional SQL instead of a whole table.

- tables:

  A named list of data frames.

## Value

`db_tables()`: table names. `db_read()`: a data.table. `db_write()`: the
row counts written, invisibly.
