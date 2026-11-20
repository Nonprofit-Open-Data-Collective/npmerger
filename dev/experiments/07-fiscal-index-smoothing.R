suppressMessages({library(fiscal); library(data.table)})
e <- new.env(); data("dat10k", package = "fiscal", envir = e); ref <- e$dat10k
cat("dat10k:", dim(ref), " TAX_YEAR:", paste(unique(ref$TAX_YEAR), collapse = ","), "\n")
m <- compute_all(ref, verbose = FALSE)
reg <- as.data.table(fiscal_metrics()); cat("\nmetric registry:", nrow(reg), "rows; columns:", paste(names(reg), collapse = ", "), "\n")
print(head(reg, 5))
ratio_cols <- grep("_w$", names(m), value = TRUE)
cat("\nwinsorized ratio columns:", length(ratio_cols), "\n")
dg <- fiscal_diagnostics(m, variables = ratio_cols)
tr <- fiscal_triage(dg)
print(tr)
dm <- fiscal_dimensions(m, triage = tr, seed = 1)
print(dm)
fit <- fiscal_health_fit(m, dimensions = dm)
print(fit)
w <- fiscal_weights(fit)
sc <- fiscal_health_score(m, fit)
ix <- fiscal_health_index(sc, w)
cat("\nindex summary:\n"); print(summary(ix$fiscal_health)); cat("coverage:\n"); print(summary(ix$fiscal_health_coverage))
saveRDS(list(fit = fit, weights = w, dims = dm, triage = tr), file.path(Sys.getenv("S"), "fh_fit_dat10k.rds"))

# ---- panel for merger orgs (dev/experiments/07a) then scoring + smoothing comparison
suppressMessages({library(fiscal); library(panel990); library(data.table)})
S <- Sys.getenv("S")
x <- readRDS(file.path(S, "merger_panel.rds")); pd <- x$panel; cases <- x$cases
cal <- readRDS(file.path(S, "fh_fit_dat10k.rds"))
pd[, TAX_YEAR := as.integer(TAX_YEAR)]
pd <- pd[order(EIN2, TAX_YEAR, -as.character(RETURN_TIME_STAMP))][, .SD[1], by = .(EIN2, TAX_YEAR)]   # one return per org-year
cat("org-years:", nrow(pd), "\n")

# trailing smoother: mean over calendar years [t-(k-1), t] within EIN2 (handles gaps; never uses future years)
smooth_trailing <- function(dt, vars, k = 3L, id = "EIN2", time = "TAX_YEAR") {
  out <- copy(dt)
  for (v in vars) {
    s <- dt[, c(id, time, v), with = FALSE]; setnames(s, c("id", "t", "val"))
    lag <- rbindlist(lapply(0:(k - 1L), function(j) s[, .(id, t = t + j, val)]))
    agg <- lag[!is.na(val), .(sm = mean(val)), by = .(id, t)]
    m <- agg[s, on = .(id, t)]$sm
    set(out, j = v, value = m)
  }
  out
}
num <- names(pd)[vapply(pd, is.numeric, logical(1))]
fin <- setdiff(intersect(num, fiscal::get_pc_fields()), c("TAX_YEAR"))
fin <- fin[vapply(fin, function(v) mean(!is.na(pd[[v]])) > 0.05, logical(1))]
cat("financial fields smoothed:", length(fin), "\n")

score_panel <- function(dt) {
  r <- as.data.frame(compute_all_panel(as.data.frame(dt), verbose = FALSE))
  s <- fiscal_health_score(r, cal$fit)
  as.data.table(fiscal_health_index(s, cal$weights))
}
raw   <- suppressMessages(score_panel(pd))
trail <- suppressMessages(score_panel(smooth_trailing(pd, fin, 3L)))
cent  <- suppressMessages(score_panel(as.data.table(panel990::panel_smooth(as.data.frame(pd), vars = fin, window = 3, verbose = FALSE))))
key <- c("EIN2", "TAX_YEAR")
z <- Reduce(function(a, b) merge(a, b, by = key),
            list(raw[, c(key, "fiscal_health"), with = FALSE][, .(EIN2, TAX_YEAR, FH_RAW = fiscal_health)],
                 trail[, .(EIN2, TAX_YEAR, FH_TRAIL = fiscal_health)],
                 cent[, .(EIN2, TAX_YEAR, FH_CENT = fiscal_health)]))
cat("\nIndex available by year (raw):\n"); print(z[, .(n = .N, mean_raw = round(mean(FH_RAW, na.rm = TRUE), 3)), by = TAX_YEAR][order(TAX_YEAR)])

# event time for recipients
rc <- unique(cases[, .(EIN2 = RECIP_EIN2, MERGER_YEAR = TAX_YEAR)])[, .SD[1], by = EIN2]
zr <- merge(z, rc, by = "EIN2"); zr[, ET := TAX_YEAR - MERGER_YEAR]
cat("\nRecipient index by event time (fixed 2023 calibration):\n")
print(zr[ET %between% c(-3, 2), .(n = .N, raw = round(mean(FH_RAW, na.rm = TRUE), 3), trailing = round(mean(FH_TRAIL, na.rm = TRUE), 3),
                                    centered = round(mean(FH_CENT, na.rm = TRUE), 3)), by = ET][order(ET)])
# leakage test: does the smoothed t-1 value contain information from t+1?
lk <- merge(zr[ET == -1, .(EIN2, PRE_RAW = FH_RAW, PRE_TRAIL = FH_TRAIL, PRE_CENT = FH_CENT)], zr[ET == 0, .(EIN2, POST = FH_RAW)], by = "EIN2")
lk <- merge(lk, zr[ET == -2, .(EIN2, PRE2 = FH_RAW)], by = "EIN2")
cat("\nLeakage check (recipients): partial correlation with year-t raw index, controlling for t-2 raw:\n")
pc <- function(a) { ok <- complete.cases(lk[, .(get(a), POST, PRE2)]); cor(resid(lm(lk[[a]][ok] ~ lk$PRE2[ok])), resid(lm(lk$POST[ok] ~ lk$PRE2[ok]))) }
print(round(c(raw_tm1 = pc("PRE_RAW"), trailing_tm1 = pc("PRE_TRAIL"), centered_tm1 = pc("PRE_CENT")), 3))
cat("\nYear-to-year volatility of index within org (sd of first differences):\n")
v <- z[order(EIN2, TAX_YEAR)][, .(d_raw = diff(FH_RAW), d_trail = diff(FH_TRAIL), d_cent = diff(FH_CENT)), by = EIN2]
print(round(sapply(v[, -1], sd, na.rm = TRUE), 3))
