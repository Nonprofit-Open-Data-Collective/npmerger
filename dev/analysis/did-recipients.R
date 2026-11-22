# Are merger recipients better or worse off after a merger?
#
# Stacked, matched difference-in-differences for merger2 recipients, t-2 vs
# t+2, with an event study (t-3..t+2), transfer-size dose bins, and
# recipient-size bands.
#
# Design
#   * Unit: a recipient in its merger year (match_treated) and its k nearest
#     comparison organizations. Each recipient and its controls form one
#     matched set.
#   * Two matches:
#       recipient  controls matched on the recipient's own baseline
#                  (match_candidates_margin from dev/build-matching.R: same
#                  NTEE2, assets and expenses within 2x, operating margin
#                  within 0.10, baseline = mean of t-3 and t-2);
#       combined   controls re-matched, with the same rules, on the combined
#                  baseline of recipient + donor(s): summed assets and
#                  expenses, revenue-weighted margin.
#   * Two estimands:
#       naive      recipient alone before and after;
#       proforma   before = recipient + donor(s) (each on its own fiscal
#                  calendar), after = recipient. Nets out the mechanical jump
#                  from absorbing the donor's books.
#     Designs run: naive x recipient match, proforma x recipient match,
#     proforma x combined match.
#   * Calendar time: controls share the recipient's pseudo-merger year
#     (MAX_GAP = 0), so set x event-time fixed effects absorb year effects.
#     With MAX_GAP > 0, calendar-year fixed effects are added.
#   * Weights: treated 1, each control 1/k within its set. Transfer size
#     enters as dose bins (FMV of assets transferred / recipient assets at
#     t-2), not as weights. Recipient size enters as bands of baseline real
#     assets (<$10m, $10-100m, >=$100m).
#   * Outcomes: log real revenue, log real assets, operating margin, log
#     (expenses / assets), log(1 + employees) (full 990 only; a 990-EZ donor
#     counts as 0 employees in the pro forma).
#   * Inference: two-way clustering by matched set and organization.
#
# Env vars: ROOT (default ~/Documents/NPMERGER), K (controls per set, 5),
#   MAX_GAP (0), DROP_OTHER (drop recipients with other merger events in the
#   window, TRUE), MAX_YEAR (latest merger year kept; default all), OUT_SUBDIR
#   (write results to ROOT/analysis/OUT_SUBDIR; default the analysis folder).
# Output: ROOT/analysis/did_*.csv and event_study.png

devtools::load_all(quiet = TRUE)   # match_candidates()
library(data.table)
library(fixest)
root    <- Sys.getenv("ROOT", file.path(Sys.getenv("USERPROFILE", path.expand("~")), "Documents", "NPMERGER"))
K       <- as.integer(Sys.getenv("K", "5"))
MAX_GAP <- as.integer(Sys.getenv("MAX_GAP", "0"))
DROP_OTHER <- as.logical(Sys.getenv("DROP_OTHER", "TRUE"))
MAX_YEAR <- as.integer(Sys.getenv("MAX_YEAR", NA))
base_dir <- file.path(root, "analysis")
out_dir <- if (nzchar(Sys.getenv("OUT_SUBDIR"))) file.path(base_dir, Sys.getenv("OUT_SUBDIR")) else base_dir
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
EVENT <- -3:2
Y <- c("LOG_REVENUE", "LOG_ASSETS", "MARGIN", "LOG_EXP_ASSETS", "LOG_EMPLOYEES")
t0 <- Sys.time()
lap <- function(msg) cat(sprintf("[%4.1f min] %s\n", as.numeric(difftime(Sys.time(), t0, units = "mins")), msg))

mm    <- readRDS(file.path(root, "matching.rds"))
md    <- readRDS(file.path(root, "merger_data.rds"))
panel <- readRDS(file.path(root, "panel_990.rds"))
panel <- panel[, list(EIN2, TAX_YEAR, EZ, REVENUE, EXPENSES, ASSETS, SURPLUS, EMPLOYEES,
                      REAL_REVENUE, REAL_EXPENSES, REAL_ASSETS)]
setkey(panel, EIN2, TAX_YEAR)

# ---- treated units, donors, dose, size ------------------------------------------
smp <- mm$sample$sample
tr  <- mm$sample$treated
cases_u <- smp[, list(T_ID = paste(MATCH_YEAR, RECIP_EIN2, sep = "-"), MERGER_ID, DONOR_EIN2, MERGER_YEAR,
                      AFFILIATED, R_OTHER_EVENTS, D_HAS_FIRST, D_REAL_ASSETS, D_REAL_EXPENSES, D_REAL_REVENUE,
                      D_MARGIN, D_EMPLOYEES)]
cases_u <- cases_u[T_ID %in% tr$T_ID]
unit <- cases_u[, list(AFFILIATED = any(AFFILIATED %in% TRUE), OTHER = any(R_OTHER_EVENTS > 0),
                       D_OK = all(D_HAS_FIRST %in% TRUE),
                       D_REAL_ASSETS = sum(D_REAL_ASSETS), D_REAL_EXPENSES = sum(D_REAL_EXPENSES),
                       D_REAL_REVENUE = sum(D_REAL_REVENUE),
                       D_SURPLUS_R = sum(D_MARGIN * pmax(D_REAL_REVENUE, 0)),
                       D_EMPLOYEES = sum(fcoalesce(D_EMPLOYEES, 0))), by = T_ID]
unit <- merge(tr[, list(T_ID, EIN2, YEAR, R_REAL_ASSETS = REAL_ASSETS, R_REAL_EXPENSES = REAL_EXPENSES,
                        R_REAL_REVENUE = REAL_REVENUE, R_MARGIN = MARGIN, R_EMPLOYEES = EMPLOYEES)], unit, by = "T_ID")

xf <- as.data.table(md$transfers)[, list(MERGER_ID, FMV = fifelse(FLAG_OUTLIER %in% TRUE, NA_real_, FMV_ASSETS))]
fmv <- merge(cases_u[, list(T_ID, MERGER_ID)], xf, by = "MERGER_ID", all.x = TRUE)[
  , list(FMV = if (all(is.na(FMV))) NA_real_ else sum(FMV, na.rm = TRUE)), by = T_ID]
unit <- merge(unit, fmv, by = "T_ID", all.x = TRUE)
ra <- panel[unit[, list(EIN2, TAX_YEAR = YEAR - 2L)], on = c("EIN2", "TAX_YEAR"), ASSETS]
unit[, DOSE := fifelse(ra > 0 & FMV >= 0, FMV / ra, NA_real_)]
unit[, DOSE_BIN := cut(DOSE, c(-Inf, 0.01, 0.10, 0.50, Inf), right = FALSE,
                       labels = c("<1%", "1-10%", "10-50%", ">=50%"))]
unit[, DOSE_BIN := factor(fifelse(is.na(DOSE_BIN), "unknown", as.character(DOSE_BIN)),
                          levels = c("<1%", "1-10%", "10-50%", ">=50%", "unknown"))]
unit[, SIZE_BAND := cut(R_REAL_ASSETS, c(-Inf, 1e7, 1e8, Inf), right = FALSE, labels = c("<$10m", "$10-100m", ">=$100m"))]
unit <- merge(unit, tr[, list(T_ID, NTEE, NTEE2, SUBSECTION)], by = "T_ID")

# CEO and board outcomes (dev/analysis/leadership-measures.R); single-donor units only
lf <- file.path(base_dir, "leadership.rds")
unit[, `:=`(CEO_CAT = NA_character_, BOARD_CAT = NA_character_)]
if (file.exists(lf)) {
  lead <- readRDS(lf)
  one <- cases_u[, if (.N == 1L) list(MERGER_ID = MERGER_ID), by = T_ID]
  one <- merge(one, lead[, list(MERGER_ID, CEO_CAT, BOARD_CAT, BOARD_RETAIN, DONOR_JOINERS, DONOR_SEAT_SHARE,
                                R_CEO_STILL_CEO)], by = "MERGER_ID")
  unit[one, on = "T_ID", `:=`(CEO_CAT = i.CEO_CAT, BOARD_CAT = i.BOARD_CAT, BOARD_RETAIN = i.BOARD_RETAIN,
                              DONOR_JOINERS = i.DONOR_JOINERS, DONOR_SEAT_SHARE = i.DONOR_SEAT_SHARE,
                              R_CEO_STILL_CEO = i.R_CEO_STILL_CEO)]
} else message("leadership.rds not found; run dev/analysis/leadership-measures.R for the CEO and board splits")
unit[, CEO_CAT := factor(CEO_CAT, levels = c("recipient_ceo_only", "both_ceos", "donor_ceo_only", "neither", "shared_ceo"))]
unit[, BOARD_CAT := factor(BOARD_CAT, levels = c("intact_donor_dissolves", "combine_minor", "combine_major", "recipient_turnover"))]

funnel <- data.table(step = c("merger2 cases (2010-2024)", "cases with recipient returns t-2..t+2",
                              "recipient units with a t-2 baseline", "units without other mergers in the window"),
                     n = c(md$cases[TYPE == "merger2", .N], nrow(smp), nrow(tr), unit[OTHER == FALSE, .N]))
if (DROP_OTHER) unit <- unit[OTHER == FALSE]
if (!is.na(MAX_YEAR)) {
  funnel <- rbind(funnel, data.table(step = sprintf("units with merger year <= %d", MAX_YEAR), n = unit[YEAR <= MAX_YEAR, .N]))
  unit <- unit[YEAR <= MAX_YEAR]
}

# ---- combined (recipient + donor) baseline and re-match ---------------------------------
comb <- unit[D_OK == TRUE & !is.na(R_MARGIN) & !is.na(D_SURPLUS_R)]
comb <- merge(tr[T_ID %in% comb$T_ID], comb[, list(T_ID, D_REAL_ASSETS, D_REAL_EXPENSES, D_REAL_REVENUE, D_SURPLUS_R, D_EMPLOYEES)],
              by = "T_ID")
comb[, `:=`(MARGIN = {
              rv <- pmax(REAL_REVENUE, 0) + pmax(D_REAL_REVENUE, 0)
              fifelse(rv > 0, pmin(pmax((MARGIN * pmax(REAL_REVENUE, 0) + D_SURPLUS_R) / rv, -1), 1), MARGIN)
            },
            REAL_ASSETS = REAL_ASSETS + D_REAL_ASSETS, REAL_EXPENSES = REAL_EXPENSES + D_REAL_EXPENSES,
            REAL_REVENUE = REAL_REVENUE + D_REAL_REVENUE)]
cand_r <- mm$candidates$margin[T_ID %in% unit$T_ID & abs(YEAR_GAP) <= MAX_GAP]
cand_c <- match_candidates(comb, mm$pool, max_year_gap = MAX_GAP)
lap(sprintf("re-matched on combined baseline: %d of %d recipients have candidates", uniqueN(cand_c$T_ID), nrow(comb)))

# covariate balance of the sets actually used (k nearest, same year), and of the
# whole same-year pool in the same NTEE2 groups
BAL_VARS <- c("REAL_ASSETS", "REAL_EXPENSES", "REAL_REVENUE", "MARGIN", "EQUITY_RATIO", "MONTHS_CASH", "EMPLOYEES")
LOG_VARS <- c("REAL_ASSETS", "REAL_EXPENSES", "REAL_REVENUE", "EMPLOYEES")
tx <- function(d) { d <- copy(d); for (v in intersect(LOG_VARS, names(d))) set(d, j = v, value = log1p(pmax(d[[v]], 0))); d }
pool_b <- tx(mm$pool[, c("EIN2", "YEAR", "NTEE2", BAL_VARS), with = FALSE])
balance <- function(treated, cand, label) {
  t <- tx(treated[T_ID %in% cand$T_ID, c("T_ID", "YEAR", "NTEE2", BAL_VARS), with = FALSE])
  setorder(cand, T_ID, DIST)
  ct <- cand[, head(.SD, K), by = T_ID, .SDcols = c("C_EIN2", "C_YEAR")][, W := 1 / .N, by = T_ID]
  c <- pool_b[ct, on = c(EIN2 = "C_EIN2", YEAR = "C_YEAR")]
  pl <- pool_b[unique(t[, list(YEAR, NTEE2)]), on = c("YEAR", "NTEE2"), nomatch = NULL]
  rbindlist(lapply(BAL_VARS, function(v) {
    tv <- t[[v]]; cv <- c[[v]]; w <- c$W; ok <- !is.na(cv)
    mt <- mean(tv, na.rm = TRUE); mc <- weighted.mean(cv[ok], w[ok]); mp <- mean(pl[[v]], na.rm = TRUE)
    sd_p <- sqrt((stats::var(tv, na.rm = TRUE) + stats::var(pl[[v]], na.rm = TRUE)) / 2)
    data.table(match = label, variable = v, scale = fifelse(v %in% LOG_VARS, "log(1 + x)", "level"),
               treated = mt, matched_controls = mc, pool_same_year_ntee2 = mp,
               smd_matched = (mt - mc) / sd_p, smd_pool = (mt - mp) / sd_p,
               n_treated = sum(!is.na(tv)), n_controls = sum(ok))
  }))
}
tr_b <- merge(tr, unit[, list(T_ID)], by = "T_ID")
bal <- rbind(balance(tr_b, copy(cand_r), "recipient match"),
             balance(comb[, c("T_ID", "YEAR", "NTEE2", BAL_VARS, "D_EMPLOYEES"), with = FALSE][
               , EMPLOYEES := EMPLOYEES + D_EMPLOYEES], copy(cand_c), "combined match"))
pool_n <- nrow(mm$pool); pool_orgs <- uniqueN(mm$pool$EIN2)
rm(mm, pool_b); invisible(gc())

# ---- matched sets ---------------------------------------------------------------------
make_sets <- function(cand) {
  setorder(cand, T_ID, DIST)
  ctrl <- cand[, head(.SD, K), by = T_ID, .SDcols = c("C_EIN2", "C_YEAR", "D_L_REAL_ASSETS")]
  ctrl[, W := 1 / .N, by = T_ID]
  u <- unit[T_ID %in% ctrl$T_ID]
  s <- rbind(u[, list(SET = T_ID, ORG = EIN2, YEAR, TREAT = 1L, W = 1)],
             ctrl[, list(SET = T_ID, ORG = C_EIN2, YEAR = C_YEAR, TREAT = 0L, W)])
  s <- merge(s, u[, list(SET = T_ID, AFFILIATED, DOSE_BIN, SIZE_BAND, CEO_CAT, BOARD_CAT)], by = "SET")
  list(sets = s, ctrl = ctrl)
}
sets_r <- make_sets(cand_r)
sets_c <- make_sets(cand_c)

# ---- outcomes by event time -------------------------------------------------------------
don <- cases_u[T_ID %in% unit$T_ID, list(SET = T_ID, D = DONOR_EIN2, MY = MERGER_YEAR)]
don <- don[, list(E = EVENT[EVENT < 0]), by = list(SET, D, MY)][, TAX_YEAR := MY + E]
don <- panel[don, on = c(EIN2 = "D", "TAX_YEAR"), nomatch = NULL]
don <- don[, list(D_N = .N, D_REVENUE = sum(REVENUE), D_EXPENSES = sum(EXPENSES), D_ASSETS = sum(ASSETS),
                  D_SURPLUS = sum(SURPLUS), D_REAL_REVENUE = sum(REAL_REVENUE),
                  D_REAL_ASSETS = sum(REAL_ASSETS), D_EMPLOYEES = sum(fcoalesce(EMPLOYEES, 0))), by = list(SET, E)]
n_don <- cases_u[, list(N_DON = uniqueN(DONOR_EIN2)), by = list(SET = T_ID)]

outcomes <- function(rev, exp, ast, sur, rrev, rast, emp, ez) suppressWarnings({
  list(LOG_REVENUE = fifelse(rrev > 0, log(rrev), NA_real_),
       LOG_ASSETS  = fifelse(rast > 0, log(rast), NA_real_),
       MARGIN      = fifelse(rev > 0, pmin(pmax(sur / rev, -1), 1), NA_real_),
       LOG_EXP_ASSETS = fifelse(exp > 0 & ast > 0, log(exp / ast), NA_real_),
       LOG_EMPLOYEES  = fifelse(ez %in% FALSE, log1p(emp), NA_real_))
})
trim <- function(v) { q <- quantile(v, c(.01, .99), na.rm = TRUE); pmin(pmax(v, q[1]), q[2]) }

outcome_data <- function(sets, proforma) {
  d <- sets[, list(E = EVENT), by = list(SET, ORG, YEAR, TREAT, W, AFFILIATED, DOSE_BIN, SIZE_BAND, CEO_CAT, BOARD_CAT)]
  d[, TAX_YEAR := YEAR + E]
  d <- panel[d, on = c(EIN2 = "ORG", "TAX_YEAR")]
  setnames(d, "EIN2", "ORG")
  if (proforma) {
    d <- merge(d, don, by = c("SET", "E"), all.x = TRUE)
    d <- merge(d, n_don, by = "SET", all.x = TRUE)
    pre <- d$TREAT == 1L & d$E < 0
    d[pre & (is.na(D_N) | D_N < N_DON), c("REVENUE", "EXPENSES", "ASSETS") := NA_real_]
    d[pre, `:=`(REVENUE = REVENUE + D_REVENUE, EXPENSES = EXPENSES + D_EXPENSES, ASSETS = ASSETS + D_ASSETS,
                SURPLUS = SURPLUS + D_SURPLUS, REAL_REVENUE = REAL_REVENUE + D_REAL_REVENUE,
                REAL_ASSETS = REAL_ASSETS + D_REAL_ASSETS, EMPLOYEES = fcoalesce(EMPLOYEES, 0) + D_EMPLOYEES)]
  }
  d[, (Y) := outcomes(REVENUE, EXPENSES, ASSETS, SURPLUS, REAL_REVENUE, REAL_ASSETS, EMPLOYEES, EZ)]
  d[, LOG_EXP_ASSETS := trim(LOG_EXP_ASSETS)]
  d[]
}

# ---- models --------------------------------------------------------------------------------
yfe <- if (MAX_GAP > 0) "+ TAX_YEAR" else ""
coefs <- function(m, design, y, spec) {
  ct <- coeftable(m)
  data.table(design = design, outcome = y, spec = spec, term = rownames(ct), estimate = ct[, 1], se = ct[, 2],
             p = ct[, 4], n_obs = nobs(m), n_sets = length(unique(m$fixef_id$SET)))
}

long_diff <- function(d, design) {
  w <- dcast(d[E %in% c(-2L, 2L)], SET + ORG + TREAT + W + AFFILIATED + DOSE_BIN + SIZE_BAND + CEO_CAT + BOARD_CAT + YEAR ~ E,
             value.var = Y)
  res <- list()
  for (y in Y) {
    w[, DY := get(paste0(y, "_2")) - get(paste0(y, "_-2"))]
    w[, TAX_YEAR := YEAR]
    dd <- w[!is.na(DY)]
    dd <- dd[SET %in% dd[TREAT == 1L, SET] & SET %in% dd[TREAT == 0L, SET]]   # complete sets only
    dd[TREAT == 0L, W := 1 / .N, by = SET]
    fit <- function(rhs) feols(as.formula(paste("DY ~", rhs, "| SET", yfe)), dd, weights = ~W, cluster = ~ SET + ORG)
    res <- c(res, list(coefs(fit("TREAT"), design, y, "pooled"),
                       coefs(fit("TREAT:DOSE_BIN"), design, y, "dose"),
                       coefs(fit("TREAT:AFFILIATED"), design, y, "affiliated"),
                       coefs(fit("TREAT:SIZE_BAND"), design, y, "size")))
    if (any(!is.na(dd$CEO_CAT))) res <- c(res, list(coefs(fit("TREAT:CEO_CAT"), design, y, "ceo"),
                                                    coefs(fit("TREAT:BOARD_CAT"), design, y, "board")))
  }
  rbindlist(res)
}

event_study <- function(d, design) {
  rbindlist(lapply(Y, function(y) {
    dd <- d[!is.na(get(y))]
    dd[, UNIT := paste(SET, ORG, YEAR)]
    m <- feols(as.formula(paste(y, "~ i(E, TREAT, ref = -2) | UNIT + SET^E", yfe)), dd, weights = ~W, cluster = ~ SET + ORG)
    coefs(m, design, y, "event")
  }))
}

designs <- list(
  "naive | recipient match"      = list(sets = sets_r$sets, proforma = FALSE),
  "proforma | recipient match"   = list(sets = sets_r$sets, proforma = TRUE),
  "proforma | combined match"    = list(sets = sets_c$sets, proforma = TRUE)
)
ld <- list(); es <- list()
for (nm in names(designs)) {
  d <- outcome_data(designs[[nm]]$sets, designs[[nm]]$proforma)
  ld[[nm]] <- long_diff(d, nm); es[[nm]] <- event_study(d, nm)
  lap(paste("estimated", nm))
}
ld <- rbindlist(ld); es <- rbindlist(es)
ld[, term := sub("^TREAT:?", "", term)]
es[, E := as.integer(sub("^E::(-?[0-9]+):TREAT$", "\\1", term))]

# ---- descriptive tables -------------------------------------------------------------------
# match coverage and quality by recipient size
cov <- unit[, list(recipients = .N), by = SIZE_BAND]
cov <- merge(cov, sets_r$ctrl[unit, on = "T_ID", nomatch = NULL][
  , list(matched_recipient = uniqueN(T_ID), med_ctrl_r = as.numeric(median(.SD[, .N, by = T_ID]$N)),
         med_abs_logassets_gap_r = median(abs(D_L_REAL_ASSETS))), by = SIZE_BAND], by = "SIZE_BAND", all.x = TRUE)
cov <- merge(cov, sets_c$ctrl[unit, on = "T_ID", nomatch = NULL][
  , list(matched_combined = uniqueN(T_ID), med_abs_logassets_gap_c = median(abs(D_L_REAL_ASSETS))), by = SIZE_BAND],
  by = "SIZE_BAND", all.x = TRUE)
cov[, eligible_combined := unit[T_ID %in% comb$T_ID, .N, by = SIZE_BAND][cov, on = "SIZE_BAND", N]]
setorder(cov, SIZE_BAND)

# recipient (and combined) size at baseline, among matched recipients
an <- unit[T_ID %in% sets_r$sets$SET]
pct <- function(v) as.list(quantile(v, c(.25, .5, .75), na.rm = TRUE, names = FALSE))
size_tab <- rbind(
  an[, c(list(base = "recipient", measure = "revenue"), pct(R_REAL_REVENUE))],
  an[, c(list(base = "recipient", measure = "assets"), pct(R_REAL_ASSETS))],
  an[!is.na(R_EMPLOYEES), c(list(base = "recipient", measure = "employees"), pct(R_EMPLOYEES))],
  an[D_OK == TRUE, c(list(base = "combined", measure = "revenue"), pct(R_REAL_REVENUE + D_REAL_REVENUE))],
  an[D_OK == TRUE, c(list(base = "combined", measure = "assets"), pct(R_REAL_ASSETS + D_REAL_ASSETS))],
  an[D_OK == TRUE & !is.na(R_EMPLOYEES), c(list(base = "combined", measure = "employees"), pct(R_EMPLOYEES + D_EMPLOYEES))])
names(size_tab)[3:5] <- c("p25", "p50", "p75")

# implied changes at the size percentiles (pooled long difference)
pooled <- ld[spec == "pooled" & outcome %in% c("LOG_REVENUE", "LOG_ASSETS", "LOG_EMPLOYEES")]
pooled[, measure := c(LOG_REVENUE = "revenue", LOG_ASSETS = "assets", LOG_EMPLOYEES = "employees")[outcome]]
pooled[, base := fifelse(grepl("^naive", design), "recipient", "combined")]
impl <- merge(pooled[, list(design, measure, base, estimate, pct_change = exp(estimate) - 1)], size_tab,
              by = c("base", "measure"))
impl[, `:=`(chg_p25 = fifelse(measure == "employees", (1 + p25), p25) * pct_change,
            chg_p50 = fifelse(measure == "employees", (1 + p50), p50) * pct_change,
            chg_p75 = fifelse(measure == "employees", (1 + p75), p75) * pct_change)]

fwrite(ld, file.path(out_dir, "did_long_difference.csv"))
fwrite(es, file.path(out_dir, "did_event_study.csv"))
fwrite(cov, file.path(out_dir, "did_match_coverage_by_size.csv"))
fwrite(size_tab, file.path(out_dir, "did_size_percentiles.csv"))
fwrite(impl, file.path(out_dir, "did_implied_changes.csv"))
fwrite(bal, file.path(out_dir, "did_balance.csv"))
funnel <- rbind(funnel, data.table(
  step = c("units with >= 1 same-year control (recipient match)", "units eligible for the combined match",
           "units with >= 1 same-year control (combined match)"),
  n = c(uniqueN(sets_r$sets$SET), nrow(comb), uniqueN(sets_c$sets$SET))))
fwrite(funnel, file.path(out_dir, "did_funnel.csv"))
saveRDS(list(unit = unit, sets_r = sets_r$sets, sets_c = sets_c$sets, pool_n = pool_n, pool_orgs = pool_orgs,
             settings = list(K = K, MAX_GAP = MAX_GAP, DROP_OTHER = DROP_OTHER, MAX_YEAR = MAX_YEAR)),
        file.path(out_dir, "did_sample.rds"))

# ---- report ---------------------------------------------------------------------------------
options(width = 220)
star <- function(p) fcase(p < .01, "***", p < .05, "**", p < .1, "*", default = "")
wide <- function(x) dcast(x[, list(outcome, term, design, v = sprintf("%6.3f%-3s (%.3f)", estimate, star(p), se))],
                          outcome + term ~ design, value.var = "v")
cat(sprintf("\nmatched sets: recipient match %d, combined match %d (k <= %d, |year gap| <= %d)\n",
            uniqueN(sets_r$sets$SET), uniqueN(sets_c$sets$SET), K, MAX_GAP))
cat("\nLong difference t-2 -> t+2, pooled:\n"); print(wide(ld[spec == "pooled"]))
cat("\nBy recipient size (baseline real assets):\n"); print(wide(ld[spec == "size"]))
cat("\nBy dose:\n"); print(wide(ld[spec == "dose"]))
cat("\nBy affiliation:\n"); print(wide(ld[spec == "affiliated"]))
cat("\nBy CEO outcome:\n"); print(wide(ld[spec == "ceo"]))
cat("\nBy board outcome:\n"); print(wide(ld[spec == "board"]))
cat("\nBalance:\n"); print(bal[, list(match, variable, smd_matched = round(smd_matched, 3), smd_pool = round(smd_pool, 3))])
cat("\nMatch coverage by recipient size:\n"); print(cov)
cat("\nBaseline size percentiles (2024 dollars; employees full 990 only):\n"); print(size_tab)
cat("\nImplied changes at those percentiles:\n")
print(impl[, list(design, measure, pct = sprintf("%+.1f%%", 100 * pct_change),
                  p25 = round(chg_p25), p50 = round(chg_p50), p75 = round(chg_p75))][order(measure, design)])
cat("\nEvent study (ref = t-2):\n")
print(dcast(es[, list(design, outcome, E, v = round(estimate, 3))], design + outcome ~ E, value.var = "v"))

cols <- c("naive | recipient match" = "grey55", "proforma | recipient match" = "#1f5fa8", "proforma | combined match" = "#d0661c")
png(file.path(out_dir, "event_study.png"), width = 1500, height = 900, res = 150)
op <- par(mfrow = c(2, 3), mar = c(4, 4, 3, 1))
for (y in Y) {
  ylim <- range(es[outcome == y, c(estimate - 1.96 * se, estimate + 1.96 * se)], 0, na.rm = TRUE)
  plot(NA, xlim = c(-3.3, 2.3), ylim = ylim, xlab = "Years from merger", ylab = "Difference vs. controls", main = y,
       bty = "n")
  abline(h = 0, col = "grey50", lty = 2); abline(v = -0.5, lty = 3, col = "grey70")
  for (k in seq_along(cols)) {
    e <- es[outcome == y & design == names(cols)[k]]
    e <- rbind(e[, list(E, estimate, se)], data.table(E = -2L, estimate = 0, se = 0))[order(E)]
    x <- e$E + c(-0.12, 0, 0.12)[k]
    segments(x, e$estimate - 1.96 * e$se, x, e$estimate + 1.96 * e$se, col = cols[k])
    lines(x, e$estimate, col = cols[k], type = "b", pch = 19, cex = 1.4)
  }
}
plot.new(); legend("center", c("recipient alone, recipient match", "pro forma, recipient match", "pro forma, combined match"),
                   col = cols, pch = 19, pt.cex = 1.4, lty = 1, bty = "n")
par(op); invisible(dev.off())
lap(paste("wrote", out_dir))
