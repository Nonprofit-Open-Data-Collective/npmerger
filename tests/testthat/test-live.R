# Live end-to-end test: downloads real IRS efile data through panel990 and
# runs build_merger_database() on one Schedule N year. Off by default.
#
#   NPMERGER_LIVE=merger   merger stage only (a few minutes with a warm cache)
#   NPMERGER_LIVE=full     merger, match, and model stages, then merger_did()
#   NPMERGER_LIVE_CACHE    an existing PANEL990 download cache to reuse
#                          (otherwise a temporary one is filled)
#
# Run from the package root, e.g. in PowerShell:
#   $env:NPMERGER_LIVE = "full"; Rscript -e "devtools::test(filter = 'live')"

live <- Sys.getenv("NPMERGER_LIVE")
skip_if_not(live %in% c("merger", "full"), "set NPMERGER_LIVE=merger or full to run the live test")
skip_if_not_installed("duckdb")

proj <- merger_project(file.path(tempdir(), paste0("npmerger-live-", Sys.getpid())))
cache <- Sys.getenv("NPMERGER_LIVE_CACHE")
if (nzchar(cache)) proj$cache <- normalizePath(cache, winslash = "/", mustWork = TRUE)
withr::defer(unlink(proj$root, recursive = TRUE), teardown_env())

test_that("the merger stage runs on real 2021 Schedule N filings", {
  build_merger_database(proj, stages = "merger", years = 2021L, verbose = FALSE)
  md <- load_merger_data(proj)

  # one Schedule N year has about 4-5k filings (PLAN.md section 1)
  sn <- md$sched_n
  expect_gt(nrow(sn), 3000L)
  expect_lt(nrow(sn), 8000L)
  lab <- md$labels
  expect_true(all(c("closure", "asset_transfer", "asset_disposition", "merger2") %in% lab$TYPE))
  share <- stats::setNames(lab$N / sum(lab$N), lab$TYPE)
  expect_gt(share[["merger2"]], 0.03)
  expect_lt(share[["merger2"]], 0.30)

  cs <- md$cases
  expect_gt(nrow(cs), 300L)
  expect_false(anyDuplicated(cs$MERGER_ID) > 0)
  expect_true(all(grepl("^[0-9]{4}-[0-9]{9}-[0-9]{9}$", cs$MERGER_ID)))
  expect_true(all(cs$MERGER_YEAR == 2021L))
  expect_setequal(md$donors$MERGER_ID, cs$MERGER_ID)
  expect_gt(mean(!is.na(md$recipients$REVENUE_T0)), 0.7)
  expect_gt(nrow(md$leadership), 0.4 * nrow(cs))
  expect_true("debt_assets" %in% names(md$fiscal))
})

test_that("the match and model stages run on the full 990 panel", {
  skip_if_not(live == "full", "set NPMERGER_LIVE=full for the match and model stages")
  skip_if_not_installed("fixest")
  build_merger_database(proj, stages = c("match", "model"), verbose = FALSE)
  mm <- load_match_data(proj, panel = FALSE)
  expect_gt(nrow(mm$treated), 100L)
  expect_gt(nrow(mm$pool), 1e5)
  dd <- load_model_data(proj)
  fit <- merger_did(dd, outcomes = "LOG_REVENUE")
  expect_true(all(is.finite(fit$estimate)))
  expect_setequal(unique(fit$design), did_designs())
  expect_identical(db_read(proj, "build_log")$stage, c("merger", "match", "model"))
})
