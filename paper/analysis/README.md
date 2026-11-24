# Paper analysis scripts

These scripts write the tables the working paper reads (`paper/data/*.csv`).
The paper draft itself is kept out of the repository. Only these scripts are
tracked, so the results can be rebuilt from a checkout.

Run order, from the repository root:

1. Build the project database (`ROOT`, default `~/Documents/NPMERGER`):
   `Rscript dev/build-project.R`. It runs
   `build_merger_database()` for the merger, match, and model stages.
2. `Rscript paper/analysis/01-descriptives.R`: Schedule N labels, merger
   counts and rates, typology, and case characteristics.
3. `Rscript paper/analysis/02-models.R`: matched difference-in-differences
   estimates, event study, breakouts, sensitivity variants, funnel, and
   balance.

Both scripts call `devtools::load_all()`, so they use the package code in the
checkout. `renv.lock` at the repository root records the package versions
used for the paper.
