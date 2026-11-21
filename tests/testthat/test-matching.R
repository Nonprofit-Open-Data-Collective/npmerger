fake_panel <- function() {
  mk <- function(ein, years, assets, exp, rev, ntee) data.table::data.table(
    EIN2 = ein, TAX_YEAR = as.integer(years), OBJECTID = paste0(ein, years), RETURN_TYPE = "990", EZ = FALSE,
    REVENUE = rev, EXPENSES = exp, ASSETS = assets, LIABILITIES = assets / 2, NET_ASSETS = assets / 2,
    CASH = exp / 4, SURPLUS = rev - exp, EMPLOYEES = 10, NTEE = ntee)
  p <- rbind(
    mk("R1", 2010:2016, 1e6, 5e5, 5.5e5, "E21"),   # recipient: full window around 2013
    mk("D1", 2009:2012, 1e5, 9e4, 9e4, "E21"),     # donor
    mk("C1", 2015:2021, 1.1e6, 5.2e5, 5.6e5, "E22"), # good match, later years, same E2
    mk("C2", 2010:2014, 1.0e6, 5.0e5, 5.5e5, "E21"), # window too short for 2013+2? (has 2010-2014: Y=2012 ok)
    mk("C3", 2010:2016, 9e6, 5e6, 5.5e6, "E21"),     # too large
    mk("C4", 2010:2016, 1e6, 5e5, 3e5, "E21"),       # margin too low
    mk("C5", 2010:2016, 1e6, 5e5, 5.5e5, "B82"),     # wrong NTEE
    mk("C6", 2010:2016, 1e6, 5e5, 5.5e5, "E21"))     # Schedule N event in 2013
  p[, `:=`(REAL_REVENUE = real_dollars(REVENUE, TAX_YEAR), REAL_EXPENSES = real_dollars(EXPENSES, TAX_YEAR),
           REAL_ASSETS = real_dollars(ASSETS, TAX_YEAR),
           MARGIN = SURPLUS / REVENUE, EQUITY_RATIO = NET_ASSETS / ASSETS, MONTHS_CASH = CASH / (EXPENSES / 12))]
  p[, `:=`(NTEE2 = ntee_level(NTEE, 2), NTEE_MAJOR = ntee_level(NTEE, 1))]
  data.table::setkeyv(p, c("EIN2", "TAX_YEAR"))
  p
}
fake_cases <- function() data.table::data.table(
  MERGER_ID = "2012-D1-R1", MERGER_GROUP_ID = "2012-D1-R1", TYPE = "merger2", BASIS = "leader", AFFILIATED = FALSE,
  DONOR_EIN2 = "D1", RECIP_EIN2 = "R1", MERGER_YEAR = 2012L, RECIP_MERGER_YEAR = 2013L)

test_that("helpers", {
  expect_identical(ntee_level(c("E21", "b82z", "", NA, "X", "21"), 2), c("E2", "B8", NA, NA, NA, NA))
  expect_equal(real_dollars(100, 2024), 100)
  expect_gt(real_dollars(100, 2010), 100)
})

test_that("merger_sample requires the recipient window and builds baselines", {
  p <- fake_panel()
  ms <- merger_sample(fake_cases(), p)
  expect_equal(nrow(ms$sample), 1L)
  s <- ms$sample
  expect_equal(s$MATCH_YEAR, 2013L)
  expect_true(s$DONOR_PRE_OK)
  expect_equal(s$R_N_BASE, 2L)                       # 2010 and 2011
  expect_equal(s$R_MARGIN, (5.5e5 - 5e5) / 5.5e5)
  expect_identical(s$R_NTEE2, "E2")
  expect_setequal(ms$baseline$TAX_YEAR[ms$baseline$ROLE == "recipient"], c(2010L, 2011L))
  expect_equal(nrow(ms$treated), 1L)
  expect_identical(ms$treated$T_ID, "2013-R1")
  # recipient without t+2 drops out
  short <- p[!(EIN2 == "R1" & TAX_YEAR == 2015L)]
  expect_equal(nrow(merger_sample(fake_cases(), short)$sample), 0L)
})

test_that("match_pool applies the window and Schedule N exclusions", {
  p <- fake_panel()
  ev <- data.table::data.table(EIN2 = c("C6", "R1", "D1"), TAX_YEAR = c(2013L, 2013L, 2012L))
  pool <- match_pool(p, ev)
  expect_false(any(pool$EIN2 == "C6" & pool$YEAR %in% 2011:2016))   # event in 2013, window -3..+2
  expect_true(all(pool[EIN2 == "C2", YEAR] == 2012L))                # only 2012 has 2010-2014 around it
  expect_true(all(pool[EIN2 == "C1", YEAR] %in% 2017:2019))
})

test_that("match_candidates applies NTEE, size, and health calipers across years", {
  p <- fake_panel()
  ms <- merger_sample(fake_cases(), p)
  ev <- data.table::data.table(EIN2 = c("C6", "R1", "D1"), TAX_YEAR = c(2013L, 2013L, 2012L))
  pool <- match_pool(p, ev)
  m <- match_candidates(ms$treated, pool)
  expect_setequal(unique(m$C_EIN2), c("C1", "C2"))
  expect_true(all(m$C_EIN2 != "R1"))
  expect_true(any(m$YEAR_GAP > 0))                    # different calendar years allowed
  expect_equal(m[RANK == 1, C_EIN2], "C2")            # identical nominal values, nearest
  expect_true(all(diff(m$DIST) >= 0))
  m3 <- match_candidates(ms$treated, pool, ntee_chars = 3)
  expect_setequal(unique(m3$C_EIN2), "C2")
  me <- match_candidates(ms$treated, pool, health = "EQUITY_RATIO")
  expect_true("C4" %in% me$C_EIN2)                    # margin no longer binding
  b <- match_balance(ms$treated, pool, m, k = 1)
  expect_true(all(c("SMD_MATCHED", "SMD_POOL") %in% names(b)))
})
