library(data.table)

test_that("revenue_hhi handles shares, negatives, EZ and empty rows", {
  h <- revenue_hhi(c(100, 50, -10, NA, 10), c(0, 50, 10, NA, 10), c(0, 0, 0, NA, 10), c(0, 0, 0, NA, 10),
                   ok = c(TRUE, TRUE, TRUE, TRUE, FALSE))
  expect_equal(h, c(1, 0.5, 1, NA, NA))
})

test_that("merger_measures adds HHI, admin ratio, per-employee measures and flags", {
  x <- merger_measures(data.table(
    EIN2 = c("A", "B"), TAX_YEAR = 2020L, OBJECTID = c("o1", "o2"), RETURN_TYPE = c("990", "990EZ"),
    F9_01_REV_TOT_CY = c(200, 50), F9_01_EXP_TOT_CY = c(220, 40),
    F9_01_REV_CONTR_TOT_CY = c(100, 30), F9_01_REV_PROG_TOT_CY = c(100, 20),
    F9_01_REV_INVEST_TOT_CY = c(0, NA), F9_01_REV_OTH_CY = c(0, NA),
    F9_10_NAFB_TOT_EOY = c(-5, 10), F9_09_EXP_TOT_MGMT = c(22, NA),
    F9_01_EXP_SAL_ETC_CY = c(110, NA), F9_01_ACT_GVRN_EMPL_TOT = c(2, NA)))
  expect_equal(x$REVENUE_HHI, c(0.5, NA))
  expect_equal(x$ADMIN_RATIO, c(0.1, NA))
  expect_equal(c(x$REV_PER_EMPLOYEE[1], x$COMP_PER_EMPLOYEE[1]), c(100, 55))
  expect_identical(x$DEFICIT, c(TRUE, FALSE))
  expect_identical(x$NEG_NET_ASSETS, c(TRUE, FALSE))
})

test_that("trend_measures uses prior calendar year only and trailing windows", {
  x <- data.table(EIN2 = "A", TAX_YEAR = c(2018L, 2019L, 2021L, 2022L, 2023L),
                  REVENUE = c(100, 300, 90, 90, 120), SURPLUS = c(5, -2, -8, 1, -1))
  t <- trend_measures(x, vars = "REVENUE", k = 3L, min_obs = 2L)
  expect_equal(t$REVENUE_GROWTH, c(NA, 1, NA, 0, 30 / 105))   # 2021 has no 2020 return
  expect_identical(t$N_TRAIL_YEARS, c(1L, 2L, 2L, 2L, 3L))      # 2021 window = 2019, 2021
  expect_identical(t$DEFICIT_YEARS, c(NA, 1L, 2L, 1L, 2L))
  expect_equal(t$REVENUE_CV[5], sd(c(90, 90, 120)) / 100)
})

test_that("tuckman_chang flags the vulnerable tail against a reference", {
  ref <- data.table(TAX_YEAR = 2020L, REVENUE = 100, SURPLUS = seq(-40, 50, 10), NET_ASSETS = seq(0, 90, 10),
                    REVENUE_HHI = seq(0.3, 1, length.out = 10), ADMIN_RATIO = seq(0.01, 0.2, length.out = 10))
  x <- data.table(TAX_YEAR = 2020L, REVENUE = c(100, 100, 100), SURPLUS = c(-40, 50, 0), NET_ASSETS = c(0, 90, 50),
                  REVENUE_HHI = c(1, 0.3, NA), ADMIN_RATIO = c(0.01, 0.2, NA))
  tc <- tuckman_chang(x, reference = ref)
  expect_identical(tc$TC_N_FLAGS, c(4L, 0L, 0L))
  expect_identical(tc$TC_ALL, c(TRUE, FALSE, NA))
  expect_identical(tc$TC_N_OBS, c(4L, 4L, 2L))
  expect_identical(tc$TC_ANY, c(TRUE, FALSE, FALSE))
  expect_s3_class(attr(tc, "cutoffs"), "data.table")
})

test_that("merger_proforma sums donor and recipient before the merger", {
  fp <- data.table(MERGER_ID = "M1", MERGER_GROUP_ID = "G1",
                   ROLE = c("donor", "donor", "recipient", "recipient", "recipient"),
                   EIN2 = c("D", "D", "R", "R", "R"), TAX_YEAR = c(2019L, 2020L, 2020L, 2021L, 2022L),
                   TIME_FROM_MERGER = c(-1L, 0L, -1L, 0L, 1L), EZ = c(TRUE, TRUE, FALSE, FALSE, FALSE),
                   REVENUE = c(10, 5, 100, 120, 130), EXPENSES = c(12, 6, 90, 110, 125),
                   SURPLUS = c(-2, -1, 10, 10, 5), NET_ASSETS = c(1, 0, 50, 55, 60),
                   MGMT_EXP = c(NA, NA, 9, 11, 12), EMPLOYEES = c(NA, NA, 3, 4, 4))
  pf <- merger_proforma(fp)
  expect_identical(pf$TIME_FROM_MERGER, c(-1L, 0L, 1L))
  expect_equal(pf$REVENUE, c(110, 120, 130))       # t = -1 summed; t >= 0 recipient alone
  expect_equal(pf$MGMT_EXP[1], 9)                  # EZ donor's missing functional expenses count as 0
  expect_equal(pf$ADMIN_RATIO[1], 9 / 102)
  expect_identical(pf$PF_EZ_MEMBERS[1], 1L)
  expect_true(all(pf$PF_COMPLETE))
  expect_true(all(pf$ROLE == "combined"))
})
