library(data.table)

# two donors fold into recipient 090000009 (2020, 2021); one donor into 080000008 (2020)
lab <- data.table(
  OBJECTID = c("OID-1", "OID-2", "OID-3", "OID-4"),
  EIN2 = c("EIN-01-0000001", "EIN-01-0000002", "EIN-01-0000003", "EIN-01-0000004"),
  TAX_YEAR = c(2020L, 2021L, 2020L, 2020L),
  TYPE = c("mergerN", "mergerN", "merger2", "closure"),
  BASIS = c("leader", "leader", "corroborated", NA),
  TOP_RECIP_EIN = c("090000009", "090000009", "080000008", NA),
  N_DONORS = c(2L, 2L, 1L, NA))
tx <- data.table(
  OBJECTID = c("OID-1", "OID-1", "OID-2", "OID-3", "OID-3"),
  EIN2 = c("EIN-01-0000001", "EIN-01-0000001", "EIN-01-0000002", "EIN-01-0000003", "EIN-01-0000003"),
  TAX_YEAR = c(2020L, 2020L, 2021L, 2020L, 2020L), PART = 1L,
  ASSET_DESC = c("Cash", "Land and building", "All remaining assets", "Accounts receivable", "Furniture"),
  DIST_DATE = c("2020-06-30", "2020-09-30", "2021-03-01", "2020-12-31", "2020-12-31"),
  FMV = c(100, 900, 50, 30, -5),
  RECIP_EIN = c("090000009", "090000009", "090000009", "080000008", "080000008"))
hdr <- data.table(EIN2 = c("EIN-09-0000009", "EIN-09-0000009", "EIN-08-0000008"), TAX_YEAR = c(2020L, 2021L, 2020L),
                  TAX_PERIOD_BEGIN_DATE = c("2019-07-01", "2020-07-01", "2020-01-01"),
                  TAX_PERIOD_END_DATE = c("2020-06-30", "2021-06-30", "2020-12-31"))

test_that("build_merger_cases builds IDs, groups, and recipient merger years", {
  cs <- build_merger_cases(lab, tx, header = hdr)
  expect_s3_class(cs, "merger_cases")
  expect_setequal(cs$MERGER_ID, c("2020-010000001-090000009", "2021-010000002-090000009", "2020-010000003-080000008"))
  expect_identical(cs[DONOR_EIN2 == "EIN-01-0000002", MERGER_GROUP_ID], "2020-090000009")   # grouped with the 2020 donor
  expect_identical(cs[DONOR_EIN2 == "EIN-01-0000001", N_GROUP], 2L)
  # 2020-09-30 falls in the recipient's FY that begins 2020-07-01 (TAX_YEAR 2021)
  expect_identical(cs[DONOR_EIN2 == "EIN-01-0000001", RECIP_MERGER_YEAR], 2021L)
  expect_identical(cs[DONOR_EIN2 == "EIN-01-0000003", RECIP_MERGER_YEAR], 2020L)
  expect_equal(cs[DONOR_EIN2 == "EIN-01-0000001", FMV_TO_RECIP], 1000)
  r <- merger_roles(cs)
  expect_equal(nrow(r), 6L)
  expect_setequal(unique(r$ROLE), c("donor", "recipient"))
})

test_that("asset_class maps common descriptions", {
  expect_identical(asset_class(c("Cash & Cash Equivalents", "Accounts Receivable", "Land and building",
                                 "All remaining assets", "Furniture and equipment", "Program contracts",
                                 "Stocks and bonds", NA, "Misc", "Accounts payable & accrued expenses",
                                 "Prepaid expenses and deferred charges", "Notes and loans recievable",
                                 "Assets net of liabilities on merger of entity", "Intangible assets",
                                 "Certificates of deposit")),
                   c("cash", "receivables", "real_estate", "all_assets", "equipment", "program",
                     "investments", "unknown", "other", "liabilities", "prepaid", "receivables",
                     "all_assets", "program", "cash"))
})

oy <- merger_measures(data.table(
  EIN2 = rep(c("EIN-01-0000001", "EIN-09-0000009"), each = 3), TAX_YEAR = rep(2018:2020, 2),
  OBJECTID = paste0("O", 1:6), RETURN_TYPE = c("990EZ", "990EZ", "990EZ", "990", "990", "990"),
  ORG_NAME_L1 = rep(c("Small Org", "Big Org"), each = 3), F9_00_ORG_ADDR_STATE = rep(c("ME", "ME"), each = 3),
  F9_00_YEAR_FORMATION = c("1990", "1990", "1990", "1950", NA, NA),
  F9_01_REV_TOT_CY = c(10, 20, 30, 1000, 1100, 1200), F9_01_EXP_TOT_CY = c(9, 18, 40, 900, 1000, 1300),
  F9_10_ASSET_TOT_EOY = c(5, 6, 0, 500, 600, 700), F9_10_ASSET_TOT_BOY = c(4, 5, 1000, 450, 500, 600),
  F9_09_EXP_TOT_MGMT = c(NA, NA, NA, 90, 100, 130), F9_09_EXP_TOT_FUNDR = c(NA, NA, NA, 10, 0, 0)))

test_that("merger_measures harmonizes 990 and EZ", {
  expect_identical(oy$EZ, rep(c(TRUE, FALSE), each = 3))
  expect_equal(oy$SURPLUS[3], -10)
  expect_equal(oy$OVERHEAD_RATIO[4], 100 / 900)
  expect_true(all(is.na(oy$OVERHEAD_RATIO[1:3])))
})

test_that("transfer_value sums by class and flags outliers", {
  cs <- build_merger_cases(lab, tx, header = hdr)
  tv <- transfer_value(cs, tx, oy)
  a <- tv[MERGER_ID == "2020-010000001-090000009"]
  expect_equal(c(a$FMV_CASH, a$FMV_REAL_ESTATE, a$FMV_TOTAL), c(100, 900, 1000))
  expect_equal(a$COVERAGE, 1)                     # 1000 / donor BOY assets 1000
  expect_true(tv[MERGER_ID == "2020-010000003-080000008", ANY_NEGATIVE])
  expect_equal(a$FMV_ASSETS, 1000)
})

test_that("merger_attributes builds wide size history and age", {
  cs <- build_merger_cases(lab, tx, header = hdr)
  bmf <- data.table(EIN2 = c("EIN-01-0000001", "EIN-09-0000009"), ntee_irs = c("P20", "E22"), ruling_date = c("1985-01", "1960-05"))
  d <- merger_attributes(cs, oy, "donor", years_back = 2L, bmf = bmf)[MERGER_ID == "2020-010000001-090000009"]
  expect_identical(d$NAME, "Small Org")
  expect_equal(c(d$REVENUE_T0, d$REVENUE_TM1, d$REVENUE_TM2), c(30, 20, 10))
  expect_identical(d$NTEE, "P20"); expect_identical(d$NTEE_MAJOR, "P")
  expect_equal(d$AGE, 2020 - 1985)                # earlier of formation 1990 and ruling 1985
  rcp <- merger_attributes(cs, oy, "recipient", years_back = 2L, bmf = bmf)[MERGER_ID == "2020-010000001-090000009"]
  expect_identical(rcp$REF_YEAR, 2021L)
  expect_identical(rcp$N_YEARS_OBSERVED, 2L)      # 2019, 2020 observed; 2021 not in oy
})

test_that("merger_part7 places people in event time and flags IN_BOTH", {
  cs <- build_merger_cases(lab, tx, header = hdr)
  p7 <- data.table(EIN2 = c("EIN-01-0000001", "EIN-09-0000009", "EIN-09-0000009"), TAX_YEAR = c(2019L, 2022L, 2021L),
                   OBJECTID = c("A", "B", "C"), F9_07_COMP_DTK_NAME_PERS = c("Ann Lee", "Ann Lee", "Bo Diaz"),
                   F9_07_COMP_DTK_TITLE = c("ED", "VP", "CEO"), F9_07_COMP_DTK_POS_OFF_X = c("X", "X", "X"))
  p <- merger_part7(cs, p7)[MERGER_ID == "2020-010000001-090000009"]
  expect_identical(p[ROLE == "donor", TIME_FROM_MERGER], -1L)
  expect_setequal(p[ROLE == "recipient", TIME_FROM_MERGER], c(0L, 1L))   # recipient year 0 = 2021
  expect_identical(p[PERSON_KEY == "ANN LEE", unique(IN_BOTH)], TRUE)
  expect_identical(p[PERSON_KEY == "BO DIAZ", IN_BOTH], FALSE)
})

test_that("smooth_trailing never uses future years and respects gaps", {
  x <- data.table(EIN2 = c("A", "A", "A", "A"), TAX_YEAR = c(2018L, 2019L, 2021L, 2022L), V = c(10, 20, 60, 100))
  s <- smooth_trailing(x, "V", k = 3L)
  expect_equal(s$V, c(10, 15, 40, 80))   # 2021: mean(2019, 2021); 2022: mean(2021, 2022)
})

test_that("merger_fiscal_panel stacks donor and recipient years", {
  cs <- build_merger_cases(lab, tx, header = hdr)
  fp <- merger_fiscal_panel(cs, oy, pre = 2L, post = 1L, ratios = FALSE)
  m <- fp[MERGER_ID == "2020-010000001-090000009"]
  expect_identical(m[ROLE == "donor", TIME_FROM_MERGER], c(-2L, -1L, 0L))
  expect_identical(m[ROLE == "recipient", TIME_FROM_MERGER], c(-2L, -1L))  # recipient t0 = 2021, oy ends 2020
  expect_true(all(c("REVENUE", "ASSETS", "OVERHEAD_RATIO", "REVENUE_GROWTH", "DEFICIT_YEARS") %in% names(fp)))
  expect_equal(m[ROLE == "donor" & TIME_FROM_MERGER == -1L, REVENUE_GROWTH], (20 - 10) / 15)
  pf <- merger_proforma(fp)[MERGER_ID == "2020-010000001-090000009"]
  expect_equal(pf[TIME_FROM_MERGER == -1L, REVENUE], 20 + 1200)   # donor 2019 (its t-1) + recipient 2020 (its t-1)
})

test_that("recover_recipient_ein matches unique name + ZIP, then state", {
  t2 <- data.table(OBJECTID = "X", EIN2 = "EIN-01-0000001", TAX_YEAR = 2020L, PART = 1L,
                   RECIP_EIN = NA_character_, RECIP_NAME = c("The Arc of Maine, Inc.", "Food Bank", "Food Bank", "Jane Doe"),
                   RECIP_ZIP = c("04101", "04401", "99999", "04101"), RECIP_STATE = c("ME", "ME", "ME", "ME"),
                   RECIP_TYPE = c("501c3", "unknown", "unknown", "individual"), IRC_SECTION = NA, FMV = 1)
  nx <- data.table(EIN2 = c("EIN-11-1111111", "EIN-22-2222222", "EIN-33-3333333"), TAX_YEAR = 2020L,
                   NAME_KEY = c("ARC OF MAINE", "FOOD BANK", "FOOD BANK"), ZIP5 = c("04101", "04401", "04605"), STATE = "ME")
  out <- recover_recipient_ein(t2, nx)
  expect_identical(out$RECIP_EIN, c("111111111", "222222222", NA, NA))   # 3: two Food Banks in ME; 4: individual
  expect_identical(out$EIN_SOURCE, c("name_zip", "name_zip", NA, NA))
  expect_identical(out$RECIP_TYPE[2], "unknown_with_ein")
  expect_identical(org_name_key("The Arc of Maine, Inc."), "ARC OF MAINE")
})

test_that("org_years keeps the latest return per org-year", {
  core <- list(header = data.table(EIN2 = c("E", "E"), OBJECTID = c("a", "b"), TAX_YEAR = c(2020L, 2020L),
                                   RETURN_TYPE = "990", RETURN_TIME_STAMP = c("2021-01-01", "2021-06-01")),
               summary = data.table(EIN2 = c("E", "E"), OBJECTID = c("a", "b"), TAX_YEAR = c(2020L, 2020L),
                                    RETURN_TYPE = "990", RETURN_TIME_STAMP = c("2021-01-01", "2021-06-01"),
                                    F9_01_REV_TOT_CY = c(1, 2)))
  o <- org_years(core)
  expect_equal(nrow(o), 1L); expect_equal(o$REVENUE, 2)
})
