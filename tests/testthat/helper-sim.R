# Simulated inputs for the matching and model stages: 600 organizations
# with nine years of returns, and 30 two-party mergers in 2015 in which
# organizations 1-30 absorb organizations 31-60. Recipients grow by about
# 30% after the merger.
sim_inputs <- function(seed = 1) {
  set.seed(seed)
  n <- 600L
  orgs <- data.table::data.table(
    EIN2  = sprintf("ORG-%03d", seq_len(n)),
    NTEE  = sample(c("E21", "E22", "P20", "B82"), n, TRUE),
    SIZE  = exp(stats::rnorm(n, 14, 1.2)),
    FIRST = sample(2009:2012, n, TRUE))
  panel <- orgs[, list(TAX_YEAR = FIRST:(FIRST + 8L)), by = list(EIN2, NTEE, SIZE)]
  rec <- orgs$EIN2[1:30]
  grow <- with(panel, ifelse(EIN2 %in% rec & TAX_YEAR >= 2015L, 1.3, 1))
  panel[, `:=`(
    OBJECTID      = paste0(EIN2, "-", TAX_YEAR),
    EZ            = FALSE,
    REVENUE       = grow * SIZE * exp(stats::rnorm(.N, 0, 0.1)),
    ASSETS        = grow * 1.5 * SIZE * exp(stats::rnorm(.N, 0, 0.1)),
    EMPLOYEES     = round(SIZE / 8e4),
    NTEE_SOURCE   = "bmf",
    SUBSECTION    = "3")]
  panel[, `:=`(
    EXPENSES        = REVENUE * stats::runif(.N, 0.9, 1.05),
    LIABILITIES     = ASSETS * stats::runif(.N, 0.1, 0.6),
    CASH            = ASSETS * stats::runif(.N, 0.05, 0.3),
    STAFF_EXP       = REVENUE * 0.5,
    CONTRIBUTIONS   = REVENUE * 0.6,
    PROGRAM_REVENUE = REVENUE * 0.3,
    INVEST_INCOME   = REVENUE * 0.05,
    OTHER_REVENUE   = REVENUE * 0.05)]
  panel[, `:=`(
    SURPLUS       = REVENUE - EXPENSES,
    NET_ASSETS    = ASSETS - LIABILITIES,
    FUNC_EXP      = EXPENSES,
    MGMT_EXP      = EXPENSES * 0.12,
    REAL_REVENUE  = REVENUE,
    REAL_EXPENSES = EXPENSES,
    REAL_ASSETS   = ASSETS)]
  panel[, `:=`(
    MARGIN       = SURPLUS / REVENUE,
    EQUITY_RATIO = NET_ASSETS / ASSETS,
    MONTHS_CASH  = CASH / (EXPENSES / 12),
    NTEE2        = ntee_level(NTEE, 2L))]
  data.table::setkeyv(panel, c("EIN2", "TAX_YEAR"))

  ids <- paste0("M", 1:30)
  cases <- data.table::data.table(
    MERGER_ID = ids, MERGER_GROUP_ID = ids, TYPE = "merger2", BASIS = "leader",
    AFFILIATED = rep(c(FALSE, TRUE), 15), DONOR_EIN2 = orgs$EIN2[31:60], RECIP_EIN2 = rec,
    MERGER_YEAR = 2015L, RECIP_MERGER_YEAR = 2015L)
  sched_n <- data.table::data.table(EIN2 = cases$DONOR_EIN2, TAX_YEAR = 2015L)
  transfers <- data.table::data.table(MERGER_ID = ids, FMV_ASSETS = 1e5, FLAG_OUTLIER = FALSE)
  typology <- data.table::data.table(MERGER_ID = ids,
                                     TYPOLOGY = rep(c("Merger of near-equals", "Absorption of a stable smaller organization"), 15))
  leadership <- data.table::data.table(MERGER_ID = ids, CEO_CAT = "recipient_ceo_only",
                                       BOARD_CAT = rep(c("combine_minor", "combine_major"), 15))
  md <- list(cases = cases, sched_n = sched_n, transfers = transfers, typology = typology, leadership = leadership)
  list(md = md, panel = panel)
}
