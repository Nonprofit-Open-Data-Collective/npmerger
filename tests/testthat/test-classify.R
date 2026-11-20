truth <- data.table::data.table(
  case = c("disposition", "self", "no_np", "dispersed", "merger2_sn", "merger2_p7",
           "mergerN", "consolidation", "transfer"),
  EIN2 = "EIN-01-0000001",
  HAS_P1 = c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE),
  HAS_P2 = c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
  LEADER_SN = c(FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE),
  LEADER_P7 = c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE),
  N_NP_RECIP = c(1L, 1L, 0L, 6L, 1L, 1L, 1L, 1L, 1L),
  TOP_SHARE = c(1, 1, NA, 0.2, 1, 1, 0.9, 1, 1),
  TOP_RECIP_EIN = c("020000002", "010000001", NA, "020000002", "020000002", "020000002",
                    "020000002", "020000002", "020000002"),
  N_DONORS = c(1L, 1L, 0L, 1L, 1L, 1L, 3L, 2L, 1L),
  R_NEW = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE)
)

test_that("classifier truth table", {
  out <- classify_transactions(truth)
  expect_identical(out$TYPE, c("asset_disposition", "reorganization", "closure", "closure",
                               "merger2", "merger2", "mergerN", "consolidation", "asset_transfer"))
  expect_true(all(out$TYPE %in% transaction_types()))
})

test_that("leader rule switches evidence channel", {
  out <- classify_transactions(truth, merger_rules(leader = "sn"))
  expect_identical(out$TYPE[truth$case == "merger2_p7"], "asset_transfer")
  out <- classify_transactions(truth, merger_rules(leader = "p7"))
  expect_identical(out$TYPE[truth$case == "merger2_sn"], "asset_transfer")
})

test_that("optional columns default sensibly", {
  expect_warning(out <- classify_transactions(truth[, !c("LEADER_P7", "N_DONORS", "R_NEW")]), "LEADER_P7")
  expect_identical(out$TYPE[truth$case == "mergerN"], "merger2")
  expect_false(any(c("LEADER_P7", "N_DONORS", "R_NEW") %in% names(out)))
})
