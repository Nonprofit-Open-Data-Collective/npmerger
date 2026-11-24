skip_if_not_installed("fixest")

sim <- sim_inputs()
mm <- build_match_data(sim$md, panel = sim$panel, verbose = FALSE)
dd <- build_model_data(sim$md, mm, verbose = FALSE)

test_that("build_model_data assembles units, candidates, and the outcome panel", {
  expect_s3_class(dd, "merger_model_data")
  expect_true(all(c("r_margin", "r_equity", "c_margin") %in% names(dd$candidates)))
  expect_gt(nrow(dd$units), 20)
  expect_true(all(did_breakout_vars() %in% names(dd$units)))
  # at most max_k candidates per unit for each gap
  n0 <- dd$candidates$r_margin[YEAR_GAP == 0, .N, by = T_ID]$N
  expect_true(all(n0 <= dd$info$max_k))
  expect_true(all(c("CONTRIBUTIONS", "FUNC_EXP", "MGMT_EXP") %in% names(dd$panel)))
})

test_that("merger_did recovers recipient growth", {
  fit <- merger_did(dd, outcomes = c("LOG_REVENUE", "MARGIN"), keep = NULL)
  expect_setequal(unique(fit$design), did_designs())
  expect_named(fit, c("variant", "design", "outcome", "spec", "term", "estimate", "se", "p", "n_obs", "n_sets"))
  b <- fit[design == "naive | recipient match" & outcome == "LOG_REVENUE", estimate]
  expect_gt(b, log(1.15))
  expect_lt(b, log(1.45))
})

test_that("breakouts, sensitivity, and event study run from the same data", {
  br <- did_breakouts(dd, by = "AFFILIATED", outcomes = "LOG_REVENUE", keep = NULL,
                      designs = "naive | recipient match")
  expect_true(all(c("pooled", "AFFILIATED") %in% br$spec))
  v <- did_variants()[c("base", "k1", "gap2")]
  v <- lapply(v, function(a) { a$keep <- ~ TRUE; a })
  sens <- did_sensitivity(dd, variants = v, outcomes = "LOG_REVENUE", designs = "naive | recipient match")
  expect_setequal(unique(sens$variant), c("base", "k1", "gap2"))
  es <- did_event_study(dd, outcomes = "LOG_REVENUE", keep = NULL, designs = "naive | recipient match")
  expect_setequal(es$E, c(-3L, -1L, 0L, 1L, 2L))
  expect_error(merger_did(dd, k = 50L), "max_k")
})

test_that("funnel, composition, and baseline means", {
  expect_equal(nrow(did_funnel(dd, keep = NULL)), 9L)
  expect_true("TYPOLOGY" %in% did_composition(dd, keep = NULL)$var)
  bm <- did_baseline_means(dd, keep = NULL, outcomes = "LOG_REVENUE")
  expect_setequal(bm$TREAT, c(0L, 1L))
})

test_that("a project database round-trips every stage", {
  skip_if_not_installed("duckdb")
  proj <- merger_project(file.path(tempdir(), "npmerger-proj-test"))
  on.exit(unlink(proj$root, recursive = TRUE), add = TRUE)
  db_write(proj, list(cases = sim$md$cases, sched_n = sim$md$sched_n, transfers = sim$md$transfers,
                      typology = sim$md$typology, leadership = sim$md$leadership))
  expect_true("cases" %in% db_tables(proj))
  md2 <- load_merger_data(proj)
  expect_equal(nrow(md2$cases), 30L)
  dd2 <- build_model_data(md2, mm, verbose = FALSE)
  expect_equal(nrow(dd2$units), nrow(dd$units))
  x <- npmerger:::.with_log(proj, "test", { message("hello"); 1 }, echo = FALSE)
  expect_true(any(grepl("hello", readLines(attr(x, "log_file")))))
})
