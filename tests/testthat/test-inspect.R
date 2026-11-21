fake_sn <- function() {
  base <- function(oid, ein) data.table::data.table(OBJECTID = oid, EIN2 = ein, TAX_YEAR = "2015",
    ORG_NAME_L1 = paste("Org", oid), TAX_PERIOD_END_DATE = "2015-12-31", URL = paste0("https://x/", oid))
  p1h <- cbind(base(c("A", "B"), c("EIN-11-1111111", "EIN-22-2222222")),
               SN_01_ORG_DTK_DIR_SUCCESSOR_X = c("1", "0"), SN_01_ORG_LIAB_PAID_X = c("1", "1"))
  p1a <- cbind(base(c("A", "A", "B"), c("EIN-11-1111111", "EIN-11-1111111", "EIN-22-2222222")),
               SN_01_LTD_ASSET_DIST_DESC = c("Cash", "Building", "Furniture"),
               SN_01_LTD_ASSET_DIST_FMV = c("100", "900", "50"),
               SN_01_LTD_RECIP_EIN = c("333333333", "333333333", "444444444"),
               SN_01_LTD_RECIP_NAME_ORG_L1 = c("Successor", "Successor", "Thrift"),
               SN_01_LTD_RECIP_ADDR_CITY = c("Town", "Town", "City"),
               SN_01_LTD_RECIP_IRC_SECTION = "501(c)(3)")
  p2h <- cbind(base("C", "EIN-55-5555555"), SN_02_ORG_DTK_DIR_SUCCESSOR_X = "0")   # header only
  p3 <- cbind(base("A", "EIN-11-1111111"), SN_03_FORM_LINE_REFERENCE = "Part I", SN_03_EXPLANATION_TEXT = "Merged into Successor")
  structure(list(p1_header = p1h, p1_assets = p1a, p2_header = p2h, p2_assets = NULL, p3_text = p3), class = c("sn_raw", "list"))
}
fake_labels <- function() data.table::data.table(OBJECTID = c("A", "B", "C"), TYPE = c("merger2", "closure", "asset_disposition"),
                                                 BASIS = c("leader", NA, NA))
fake_cases <- function() data.table::data.table(MERGER_ID = "M1", DONOR_OBJECTID = "A", RECIP_EIN2 = "EIN-33-3333333")

test_that("sn_labeled stacks lines, adds checkboxes, labels, and the recipient flag", {
  x <- sn_labeled(fake_sn(), fake_labels(), fake_cases())
  expect_equal(nrow(x), 4L)                                  # 2 + 1 lines, plus 1 header-only row
  expect_setequal(unique(x$OBJECTID), c("A", "B", "C"))
  a <- x[OBJECTID == "A"]
  expect_true(all(a$IS_MERGER_RECIPIENT))
  expect_true(all(a$HAS_RECIPIENT_ROW))
  expect_true(all(a$DIR_SUCCESSOR_X))
  expect_true(all(a$LIAB_PAID_X))
  expect_identical(unique(a$P3_TEXT), "Part I: Merged into Successor")
  expect_identical(a$RECIP_CITY, c("Town", "Town"))
  b <- x[OBJECTID == "B"]
  expect_false(b$IS_MERGER_RECIPIENT)
  expect_true(is.na(b$HAS_RECIPIENT_ROW))
  expect_identical(b$TYPE, "closure")
  c <- x[OBJECTID == "C"]
  expect_equal(c$LINE, 0L)
  expect_equal(c$PART, 2L)
  expect_false(c$DIR_SUCCESSOR_X)
  expect_true(is.na(c$LIAB_PAID_X))                          # Part I-only question
  expect_identical(x$TYPE[1], "merger2")                     # sorted by label order
})

test_that("sn_inspection draws non-overlapping stratified tables", {
  x <- sn_labeled(fake_sn(), fake_labels(), fake_cases())
  t1 <- sn_inspection(x, num = 1, n = 3)
  expect_length(t1, 1L)
  expect_setequal(unique(t1[[1]]$OBJECTID), c("A", "B", "C"))
  expect_equal(max(t1[[1]]$CASE), 3L)
  expect_true(all(c("REVIEW_TYPE", "REVIEW_NOTE") %in% names(t1[[1]])))
  expect_warning(sn_inspection(x, num = 2, per_type = c(merger2 = 1L)), "Only 1")
  t2 <- suppressWarnings(sn_inspection(x, num = 2, n = 3))
  expect_length(intersect(t2[[1]]$OBJECTID, t2[[2]]$OBJECTID), 0L)
  t3 <- sn_inspection(x, per_type = c(merger2 = 1L), review_cols = FALSE)
  expect_identical(unique(t3[[1]]$OBJECTID), "A")
  expect_false("REVIEW_TYPE" %in% names(t3[[1]]))
})
