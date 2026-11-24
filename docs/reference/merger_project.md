# Create or open an npmerger project folder

A project keeps one build together:

## Usage

``` r
merger_project(root = file.path(path.expand("~"), "NPMERGER"))
```

## Arguments

- root:

  Project folder. Created if it does not exist.

## Value

A list of class `merger_project` with `root`, `cache`, `db`, `logs`, and
`results` paths.

## Details

    <root>/
      PANEL990/          panel990 download cache (reused by later builds)
      npmerger.duckdb    every table, plus build_info and build_log
      logs/              one log per stage run, <stage>-<time>.log
      results/           model estimates
      README.md          tables, row counts, and build settings

## Examples

``` r
proj <- merger_project( file.path( tempdir(), "NPMERGER" ) )

proj
#> <merger_project> C:/Users/jlecy/AppData/Local/Temp/RtmpsNzdq9/NPMERGER 
#>   merger  not built
#>   match   not built
#>   model   not built
```
