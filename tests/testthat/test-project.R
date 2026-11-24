skip_if_not_installed("duckdb")
skip_if_not_installed("DBI")

new_project <- function(name) {
  root <- file.path(tempdir(), paste0("npmerger-", name, "-", Sys.getpid()))
  unlink(root, recursive = TRUE)
  merger_project(root)
}

test_that("merger_project creates the folder layout", {
  proj <- new_project("layout")
  on.exit(unlink(proj$root, recursive = TRUE), add = TRUE)
  expect_s3_class(proj, "merger_project")
  expect_true(all(dir.exists(c(proj$root, proj$cache, proj$logs, proj$results))))
  expect_identical(db_tables(proj), character())
  expect_output(print(proj), "merger +not built")
  expect_error(load_merger_data(proj), "merger stage has not been built")
  expect_error(load_match_data(proj), "match stage has not been built")
  expect_error(load_model_data(proj), "model stage has not been built")
})

test_that("db_write refuses column names that differ only in case", {
  proj <- new_project("case")
  on.exit(unlink(proj$root, recursive = TRUE), add = TRUE)
  expect_error(db_write(proj, list(x = data.frame(a = 1, A = 2))), "differ only in case")
  n <- db_write(proj, list(x = data.frame(a = 1:3, f = factor(c("u", "v", "u")))))
  expect_identical(n, c(x = 3L))
  expect_identical(db_read(proj, "x")$f, c("u", "v", "u"))
  expect_identical(db_read(proj, query = "SELECT COUNT(*) AS n FROM x")$n, 3)
})

test_that("the merger stage builds offline into the project database", {
  ex <- npmerger_example()
  proj <- new_project("merger")
  on.exit(unlink(proj$root, recursive = TRUE), add = TRUE)
  args <- list(sn = ex$sn, evidence = ex$evidence, core = ex$core, names = ex$names, bmf_data = ex$bmf,
               ratios = FALSE)
  build_merger_database(proj, stages = "merger", years = 2019:2021, merger_args = args, verbose = FALSE)

  tabs <- db_tables(proj)
  expect_true(all(c("cases", "donors", "recipients", "part7", "typology", "name_keys",
                    "build_log", "build_settings") %in% tabs))
  md <- load_merger_data(proj)
  expect_s3_class(md, "merger_data")
  expect_s3_class(md$cases, "merger_cases")
  expect_true(is.factor(md$typology$TYPOLOGY))
  expect_setequal(md$donors$MERGER_ID, md$cases$MERGER_ID)

  # only scalar settings are recorded, never the data passed in merger_args
  st <- db_read(proj, "build_settings")
  expect_true(all(c("years", "ratios", "rules", "name_parser") %in% st$item))
  expect_false(any(c("sn", "evidence", "core", "names", "bmf_data") %in% st$item))
  expect_identical(npmerger:::.kv_read(proj, "merger")$years, 2019:2021)

  lg <- db_read(proj, "build_log")
  expect_identical(lg$stage, "merger")
  log_file <- file.path(proj$logs, lg$log)
  expect_true(file.exists(log_file))
  txt <- readLines(log_file)
  expect_true(any(grepl("^# npmerger merger stage", txt)))
  expect_true(any(grepl("^# finished", txt)))
  expect_true(any(grepl("sessionInfo|R version", txt)))
  expect_lt(length(txt), 500L)

  rd <- readLines(file.path(proj$root, "README.md"))
  expect_true(any(grepl("`cases`", rd, fixed = TRUE)))
  expect_true(any(grepl("| merger |", rd, fixed = TRUE)))

  # a rerun reuses parsed names and appends to the build log
  build_merger_database(proj, stages = "merger", years = 2019:2021, merger_args = args, verbose = FALSE)
  expect_identical(db_read(proj, "build_log")$stage, c("merger", "merger"))
  expect_identical(nrow(load_merger_data(proj)$cases), nrow(md$cases))
})

test_that("the match and model stages build and reload from the database", {
  skip_if_not_installed("fixest")
  sim <- sim_inputs()
  proj <- new_project("stages")
  on.exit(unlink(proj$root, recursive = TRUE), add = TRUE)
  db_write(proj, sim$md)
  build_merger_database(proj, stages = c("match", "model"), match_args = list(panel = sim$panel), verbose = FALSE)

  expect_output(print(proj), "model +built")
  mm <- load_match_data(proj)
  expect_s3_class(mm, "merger_match_data")
  expect_true(all(c("margin", "equity") %in% names(mm$candidates)))
  expect_identical(data.table::key(mm$panel), c("EIN2", "TAX_YEAR"))
  expect_identical(nrow(load_match_data(proj, panel = FALSE)$panel), 0L)
  expect_false("panel" %in% db_read(proj, "build_settings")$item)

  dd <- load_model_data(proj)
  expect_s3_class(dd, "merger_model_data")
  expect_true(is.factor(dd$units$SIZE_BAND))

  # the loaded objects give the same estimates as the in-memory build
  mm0 <- build_match_data(sim$md, panel = sim$panel, verbose = FALSE)
  dd0 <- build_model_data(sim$md, mm0, verbose = FALSE)
  f1 <- merger_did(dd, outcomes = "LOG_REVENUE", keep = NULL)
  f0 <- merger_did(dd0, outcomes = "LOG_REVENUE", keep = NULL)
  expect_equal(f1$estimate, f0$estimate, tolerance = 1e-8)

  lg <- db_read(proj, "build_log")
  expect_identical(lg$stage, c("match", "model"))
  expect_true(all(file.exists(file.path(proj$logs, lg$log))))
})

test_that("fiscal-health scoring fails clearly when fiscal lacks it", {
  skip_if_not_installed("fiscal")
  skip_if("fiscal_health_score" %in% getNamespaceExports("fiscal"))
  expect_error(npmerger:::.fiscal_fun("fiscal_health_score"), "does not export")
})
