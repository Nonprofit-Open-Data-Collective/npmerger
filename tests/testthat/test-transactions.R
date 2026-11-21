fake_sn <- function() {
  base <- function(oid, ein) data.table::data.table(OBJECTID = oid, EIN2 = ein, TAX_YEAR = "2020")
  p1h <- cbind(base(c("OID-1", "OID-2"), c("EIN-01-0000001", "EIN-01-0000002")),
               SN_01_ORG_DTK_DIR_SUCCESSOR_X = c("1", "false"), SN_01_ORG_DTK_EMPL_SUCCESSOR_X = c("0", "false"),
               SN_01_ORG_DTK_OWN_SUCCESSOR_X = c("0", "false"), SN_01_ORG_DTK_REC_COMP_X = c("0", "false"))
  p1a <- cbind(base(c("OID-1", "OID-1", "OID-3"), c("EIN-01-0000001", "EIN-01-0000001", "EIN-01-0000003")),
               SN_01_LTD_ASSET_DIST_FMV = c("900", "100", "50"), SN_01_LTD_RECIP_EIN = c("020000002", "030000003", NA),
               SN_01_LTD_RECIP_NAME_ORG_L1 = c("A", "B", NA), SN_01_LTD_RECIP_NAME_PERS = c(NA, NA, "Jane Doe"),
               SN_01_LTD_RECIP_IRC_SECTION = c("501(c)(3)", "", "Individual"))
  p2h <- cbind(base("OID-4", "EIN-01-0000004"), SN_02_ORG_DTK_DIR_SUCCESSOR_X = "0",
               SN_02_ORG_DTK_EMPL_SUCCESSOR_X = "0", SN_02_ORG_DTK_OWN_SUCCESSOR_X = "0", SN_02_ORG_DTK_REC_COMP_X = "0")
  p2a <- cbind(base("OID-4", "EIN-01-0000004"), SN_02_DOA_ASSET_DIST_FMV = "5000",
               SN_02_DOA_RECIP_EIN = "040000004", SN_02_DOA_RECIP_NAME_ORG_L1 = "Buyer LLC",
               SN_02_DOA_RECIP_IRC_SECTION = "LLC")
  structure(list(p1_header = p1h, p1_assets = p1a, p2_header = p2h, p2_assets = p2a,
                 p3_text = data.table::data.table(), years = 2020L), class = c("sn_raw", "list"))
}

test_that("sn_transactions stacks both parts", {
  tx <- sn_transactions(fake_sn())
  expect_equal(nrow(tx), 4L)
  expect_identical(tx$RECIP_TYPE, c("501c3", "unknown_with_ein", "individual", "business"))
  expect_identical(tx$PART, c(1L, 1L, 1L, 2L))
})

test_that("sn_filings unions header and asset tables", {
  fl <- sn_filings(fake_sn())
  expect_setequal(fl$OBJECTID, c("OID-1", "OID-2", "OID-3", "OID-4"))
  f1 <- fl[OBJECTID == "OID-1"]
  expect_true(f1$HAS_P1 && f1$LEADER_SN)
  expect_equal(f1$N_NP_RECIP, 2L)
  expect_equal(f1$TOP_SHARE, 0.9)
  expect_identical(f1$TOP_RECIP_EIN, "020000002")
  expect_true(fl[OBJECTID == "OID-3"]$HAS_P1)          # asset rows only
  expect_equal(fl[OBJECTID == "OID-2"]$N_RECIP, 0L)    # header only
  expect_true(fl[OBJECTID == "OID-4"]$HAS_P2 && !fl[OBJECTID == "OID-4"]$HAS_P1)
  cl <- classify_transactions(fl, merger_rules(leader = "sn"))
  expect_identical(cl[order(OBJECTID)]$TYPE, c("merger2", "closure", "closure", "asset_disposition"))
})

test_that("sn_filings flags merger language in Schedule N text", {
  sn <- fake_sn()
  sn$p3_text <- data.table::data.table(OBJECTID = "OID-3", SN_03_EXPLANATION_TEXT = "Assets transferred due to the MERGER")
  sn$p2_assets[, SN_02_DOA_ASSET_DIST_DESC := "Consolidation of programs"]
  fl <- sn_filings(sn)
  expect_identical(fl[order(OBJECTID)]$SN_MERGER_TEXT, c(FALSE, FALSE, TRUE, TRUE))
  expect_false(any(sn_filings(fake_sn())$SN_MERGER_TEXT))
})
