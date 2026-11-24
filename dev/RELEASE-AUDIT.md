# npmerger release audit

November 23, 2026. Package version 0.0.0.9000, branch `main`.

## Status after the fixes (later the same day)

The workflow was rebuilt from scratch in a fresh `~/Documents/NPMERGER`
with the new `build_merger_database()`:

| Stage | Time | Result |
|---|---|---|
| merger | 54 min cold (42 cached) | 63,706 filings, 12,684 cases, leadership for 8,307, typology for all |
| match | 7 min | 6.2M org-years, 2.98M pool, 4,507 treated units |
| model | 25 s | 4,507 units, trimmed candidates, 629k outcome org-years |

Checks against the old scripts on the same data:

- `merger_leadership()` matches `dev/analysis/leadership-measures.R`
  exactly (8,307 cases).
- `merger_typology()` matches the typology code in `01-descriptives.R` on
  all 12,684 cases.
- `merger_did()` and the other model functions reproduce
  `02-models-legacy.R` with zero difference: all 1,712 long-difference
  rows, 240 event-study rows, baseline means, funnel, and composition.
- Against the paper's current results (built November 21), the descriptive
  tables and the sample funnel are identical, and so are all estimates
  except log program revenue (56 of 1,712 rows, 2,975 sets instead of
  2,971). The legacy script gives the same new numbers, so the cause is
  the fresh download of Part I program revenue, not the code.

Blockers 1-3 and findings 4-9 below are fixed. The remaining items are
minor (10 and 11), the version bump, and `R CMD check`.

Problems the fresh build found:

- `fiscal` adds a ratio named `invest_income`, which collides with
  npmerger's `INVEST_INCOME` in a case-insensitive database. The old build
  script would also have failed. Fixed: colliding ratios get a `_ratio`
  suffix, and `db_write()` names any such column.
- Passing `keep = quote(...)` through `do.call()` evaluated it too early.
  Variants now use one-sided formulas (`~ OTHER == FALSE`).
- The funnel step "merger2 cases (2010-2024)" counts merger2 cases from
  every year (9,984), not just 2010-2024. The label is in the paper; the
  number is unchanged from before.

## Verdict (before the fixes)

**Not ready for release yet.** Stages 1 and 2 (finding mergers, building
the matched comparison data) are well organized package functions. Stage 3
(the models behind the paper) lives only in scripts. One of those scripts
is gitignored, and it no longer matches the objects the package builds.
The default pipeline also fails with the current `fiscal` package.

## The workflow as it stands

| Stage | Entry point | Where it lives | Saved output |
|---|---|---|---|
| 1. Identify mergers | `build_merger_data()` | package (`R/pipeline.R`) | `merger_data.rds`, `npmerger.duckdb`, `parquet/` (via `dev/build-database.R`) |
| 2. Matching data | `build_match_data()` | package (`R/match-pipeline.R`) | `matching.rds`, `panel_990.rds`, DuckDB tables (via `dev/build-matching.R`) |
| 2b. Leadership measures | none | `dev/analysis/leadership-measures.R` | `analysis/leadership.rds` |
| 2c. Merger typology | none | `paper/analysis/01-descriptives.R` (gitignored) | `paper/data/case_typology.csv` |
| 3. Models (DiD, event study, breakouts, sensitivity) | none | `paper/analysis/02-models.R` (gitignored); older copy in `dev/analysis/did-recipients.R` | `paper/data/did_*.csv` |

Every script finds its data through the `ROOT` environment variable
(default `~/Documents/NPMERGER`). Every script also calls
`devtools::load_all()`, so it only runs from a source checkout.

## Findings

### Blockers

1. **The default pipeline fails with the installed `fiscal`.**
   `devtools::test()` has one failure, `test-pipeline.R:30`.
   `build_merger_data(ratios = TRUE)` is the default, and it errors inside
   `fiscal::compute_all_panel()` (`some columns are not in the data.table:
   [.row_order.]`). The installed versions are fiscal 0.0.2.0 (commit
   `f29d9ad`) and data.table 1.18.2.1. The two GitHub dependencies are
   unpinned (`Remotes:` has no ref), so a fresh install can't be expected
   to work.
2. **The paper's results can't be reproduced from the repository.**
   `paper/` is in `.gitignore`, so `01-descriptives.R` and `02-models.R`
   aren't version controlled. The tracked `dev/analysis/did-recipients.R`
   is an earlier version without the outcome set, typology, or variants
   the paper reports.
3. **The model scripts expect an older matching object.** Both
   `02-models.R:41` and `did-recipients.R:68` read `mm$sample$sample` and
   `mm$sample$treated`. `build_match_data()` returns `mm$sample` as a
   table and `mm$treated` at the top level. Rerunning
   `dev/build-matching.R` and then `02-models.R` would fail, so the saved
   `matching.rds` the paper used predates the current function.

### Major

4. **Hidden dependencies between stages.** `02-models.R` reads
   `case_typology.csv`, which `01-descriptives.R` writes into the paper
   folder, and `leadership.rds`, which a dev script writes. The model
   stage therefore depends on a descriptive-tables script and a manual
   step. Run order isn't recorded anywhere except in comments.
5. **Outcome construction is duplicated.** `02-models.R` defines its own
   `make_y()`: logged real dollars, margin, equity, debt, months of cash,
   contribution share, revenue HHI, and admin ratio. It also extracts
   Part I and Part IX fields straight from the parquet cache. The package
   already has `revenue_hhi()`, `trend_measures()`, `merger_proforma()`,
   and `panel_measures()`. Two definitions of the same outcome will drift
   apart.
6. **There's no project folder or logging convention in the package.**
   The folder layout (cache, `.rds` objects, DuckDB, parquet, README) is
   defined only in `dev/build-*.R`. Logs exist only if the user redirects
   output (`> build.log 2>&1`). `build_info` (versions, git commit, rules)
   and `manifest` (row counts) are good foundations. The matching and model
   steps record neither, and no step saves `sessionInfo()`.
7. **Undeclared dependencies.** The workflow needs `fixest`, `DBI`, and
   `devtools`, none of which is in `DESCRIPTION`. `fixest` isn't installed
   on this machine, so the model stage can't run here.
8. **The docs stop at stage 2.** The site has Overview, Classifier, and
   Matching pages. Nothing describes the models, the run order, run times,
   disk use, or what gets saved where.

### Minor

9. The README said the classifier had not been validated. Fixed: it now
   cites the 300-filing check.
10. `dev/analysis/*.html` (about 6,000 lines of rendered reports) are
    committed. Consider dropping them or moving them to the site.
11. Version is still `0.0.0.9000`. NEWS.md should get a release entry.

## Answers to the questions

**Is it an organized workflow?** Stages 1 and 2 are: one wrapper each,
every step exported, an offline example, and tests. Stage 3 isn't.

**Does it create a project folder with meaningful logs?** Only by
convention in the dev scripts. Recommendation: a small project helper
that every stage writes through:

```r
proj <- merger_project( "~/Documents/NPMERGER" )

md <- build_merger_data( years = efile_years(), project = proj )
mm <- build_match_data( md, project = proj )
```

```
NPMERGER/
  cache/PANEL990/        panel990 downloads (reused)
  build/                 merger_data.rds, matching.rds, model_data.rds
  db/                    npmerger.duckdb, parquet/
  results/               model estimates, one file per run
  logs/                  <stage>-<timestamp>.log
  project.json           settings, rules, package versions, git commit,
                         sessionInfo for each stage run
```

**Add renv?** Yes, for the analysis project rather than the package. The
package's dependencies belong in `DESCRIPTION`. The paper and database
build should carry an `renv.lock` so the exact `panel990`, `fiscal`,
`data.table`, and `fixest` versions are recorded (blocker 1 is exactly
this failure). For the release, also pin the GitHub remotes to tagged
versions or commits.

**Can each sensitivity analysis and breakout be a follow-up function?**
Yes. Everything `02-models.R` does is a function of three things: the
merger data, the matching data, and a list of overrides. A design that
keeps the paper's results one call each:

```r
# stage 3 data: treated units with breakout variables, candidate sets,
# donor sums, and the outcome panel (Part I and IX columns included)
dd <- build_model_data( md, mm, project = proj )

# main estimates: long differences for all outcomes, three designs
fit <- merger_did( dd )

# event study for the same design
es <- did_event_study( dd )

# breakouts by any unit-level variable
did_breakouts(
  fit,
  by = c( "SIZE_BAND", "AFFILIATED", "TYPOLOGY",
          "CEO_CAT", "BOARD_CAT", "DOSE_BIN" )
)

# the paper's ten sensitivity variants, or your own
did_sensitivity( dd, variants = did_variants() )
```

`did_variants()` would return the named list now hard-coded in
`02-models.R` (`k1`, `k10`, `equity`, `gap2`, `through2021`,
`keep_other`, `ntee_current`, `unaffiliated`, `full990`, `post1`). Each
variant is a set of overrides of `merger_did()` arguments, so a user can
add one without editing package code. Typology and leadership categories
would become package functions (`merger_typology()`,
`merger_leadership()`) so `build_model_data()` doesn't depend on files
from other scripts. `fixest` goes in `Suggests`.

**Add a workflow vignette?** Yes, written after the stage 3 functions
exist, so it documents functions rather than scripts. It would cover the
whole life cycle: project setup, Schedule N to `build_merger_data()`,
`build_match_data()`, `build_model_data()`, `merger_did()`, breakouts,
and sensitivity. It would also give run times, disk use, and what is
saved where. The eval'd chunks can run on `npmerger_example()` plus the
simulated panel from the matching vignette.

## Done in this pass

- Code in all three vignettes, the README, and every `@examples` block
  now uses the narrow, one-argument-per-line style. Each step is
  separated, and the object it returns is shown.
- README status line corrected.
- Rd files regenerated, examples run, all three vignettes knit, site
  rebuilt.

## Suggested order for the rest

1. Pin `fiscal` and `panel990`, and fix or work around the
   `compute_all_panel()` failure.
2. Add `merger_project()` and the `project =` argument to both builders.
3. Move typology, leadership, outcome construction, and the DiD code into
   the package (`build_model_data()`, `merger_did()`,
   `did_event_study()`, `did_breakouts()`, `did_sensitivity()`,
   `did_variants()`), with tests on simulated data.
4. Reduce `paper/analysis/02-models.R` to calls of those functions,
   commit it (or a replication folder) with an `renv.lock`, and rerun the
   paper end to end.
5. Write the workflow vignette and add it to the navbar.
6. Bump the version, write NEWS, and run `R CMD check`.
