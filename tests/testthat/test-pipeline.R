test_that("build_merger_data runs offline on the bundled example", {
  ex <- npmerger_example()
  expect_s3_class(ex$sn, "sn_raw")
  md <- build_merger_data(sn = ex$sn, evidence = ex$evidence, core = ex$core, names = ex$names,
                          bmf_data = ex$bmf, ratios = FALSE, verbose = FALSE)
  expect_s3_class(md, "merger_data")
  expect_true(all(c("merger2", "mergerN", "consolidation", "closure", "asset_transfer", "asset_disposition") %in% md$labels$TYPE))
  cs <- md$cases
  expect_true(nrow(cs) > 0)
  expect_false(anyDuplicated(cs$MERGER_ID) > 0)
  expect_true(all(grepl("^[0-9]{4}-[0-9]{9}-[0-9]{9}$", cs$MERGER_ID)))
  expect_setequal(md$transfers$MERGER_ID, cs$MERGER_ID)
  expect_setequal(md$donors$MERGER_ID, cs$MERGER_ID)
  expect_setequal(md$recipients$MERGER_ID, cs$MERGER_ID)
  expect_true(all(md$donors$ROLE == "donor") && all(md$recipients$ROLE == "recipient"))
  expect_true(all(c("REVENUE_T0", "REVENUE_TM4", "ASSETS_T0", "AGE", "NTEE") %in% names(md$donors)))
  expect_true(all(md$part7$TIME_FROM_MERGER %in% -2:2))
  expect_true(any(md$part7$IN_BOTH))
  fp <- md$fiscal
  expect_true(all(fp[ROLE == "donor", TIME_FROM_MERGER] <= 0L))
  expect_true(all(c("REVENUE", "ASSETS", "DEBT", "STAFF_EXP", "EXEC_COMP", "GRANTS", "OVERHEAD_RATIO") %in% names(fp)))
  # consolidation cases share a group ID with their co-donors
  cons <- cs[TYPE == "consolidation"]
  expect_true(all(cons$N_GROUP >= 2L))
})

test_that("fiscal ratios join onto the panel", {
  skip_if_not_installed("fiscal")
  ex <- npmerger_example()
  md <- build_merger_data(sn = ex$sn, evidence = ex$evidence, core = ex$core, names = ex$names,
                          bmf_data = ex$bmf, ratios = TRUE, verbose = FALSE)
  expect_true(all(c("debt_assets", "overhead", "current") %in% names(md$fiscal)))
  sm <- suppressWarnings(build_merger_data(sn = ex$sn, evidence = ex$evidence, core = ex$core, names = ex$names,
                                           bmf_data = ex$bmf, ratios = FALSE, smooth = "trailing", verbose = FALSE))
  expect_identical(attr(sm$fiscal, "smooth"), "trailing")
})
