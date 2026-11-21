# Build the full 990 matching panel, the merger2 research sample, and the
# match candidates for merger2 recipients, and add them to the npmerger
# database (dev/build-database.R must have been run first).
#
# Env vars:
#   ROOT       database folder (default ~/Documents/NPMERGER)
#   CACHE      panel990 cache (default ROOT/PANEL990)
#   PANEL_RDS  optional saved panel (.rds) to reuse instead of rebuilding
#              (NTEE codes missing from the current BMF are filled from the
#              NCCS legacy BMF if the saved panel predates that step)
#
# Tables added to ROOT/npmerger.duckdb (and ROOT/parquet/):
#   panel_990                 every 990/990-EZ organization-year, 2009-2025
#   research_sample           merger2 cases with recipient returns t-2..t+2, baselines
#   research_baseline         donor and recipient org-years at t-3 and t-2
#   match_treated             one row per recipient and merger year
#   match_pool                eligible comparison org-years (window, no Schedule N event)
#   match_candidates_margin   candidates: NTEE2 + assets + expenses + operating margin
#   match_candidates_equity   candidates: NTEE2 + assets + expenses + equity ratio
#   match_balance             standardized differences, k = 1 and 5, both specs
#   match_settings            calipers and counts

devtools::load_all(quiet = TRUE)
library(data.table)
root  <- Sys.getenv("ROOT", file.path(Sys.getenv("USERPROFILE", path.expand("~")), "Documents", "NPMERGER"))
cache <- Sys.getenv("CACHE", file.path(root, "PANEL990"))
t0 <- Sys.time()
lap <- function(msg) cat(sprintf("[%5.1f min] %s\n", as.numeric(difftime(Sys.time(), t0, units = "mins")), msg))

prds <- Sys.getenv("PANEL_RDS")
panel <- if (nzchar(prds)) readRDS(prds) else get_panel(efile_years(), path = cache, verbose = FALSE)
if (!"NTEE_SOURCE" %in% names(panel)) {   # panel saved before the legacy NTEE fill
  panel <- fill_ntee(panel, legacy_ntee(path = cache, eins = panel$EIN2[is.na(panel$NTEE2)]))
  saveRDS(panel, file.path(root, "panel_990.rds"))
} else if (!nzchar(prds)) saveRDS(panel, file.path(root, "panel_990.rds"))
nt <- unique(panel[, list(EIN2, NTEE_SOURCE)], by = "EIN2")
lap(sprintf("NTEE source by organization: %s", paste(names(table(nt$NTEE_SOURCE, useNA = "ifany")), table(nt$NTEE_SOURCE, useNA = "ifany"), sep = " = ", collapse = ", ")))
lap(sprintf("panel: %s org-years, %s organizations", format(nrow(panel), big.mark = ","), format(uniqueN(panel$EIN2), big.mark = ",")))

md <- readRDS(file.path(root, "merger_data.rds"))
ms <- merger_sample(md$cases, panel, types = "merger2")
lap(sprintf("research sample: %d merger2 cases with recipient t-2..t+2 (of %d); %d treated units",
            nrow(ms$sample), sum(md$cases$TYPE == "merger2"), nrow(ms$treated)))

ev <- schedule_n_events(md$sched_n, md$transactions)
pool <- match_pool(panel, ev)
lap(sprintf("pool: %s org-years, %s organizations", format(nrow(pool), big.mark = ","), format(uniqueN(pool$EIN2), big.mark = ",")))

specs <- list(margin = "MARGIN", equity = "EQUITY_RATIO")
cands <- lapply(specs, function(h) match_candidates(ms$treated, pool, health = h))
for (nm in names(cands)) lap(sprintf("candidates (%s): %s pairs, %d of %d treated matched, median %s per treated",
                                     nm, format(nrow(cands[[nm]]), big.mark = ","), uniqueN(cands[[nm]]$T_ID), nrow(ms$treated),
                                     format(median(cands[[nm]][, .N, by = T_ID]$N), big.mark = ",")))
bal <- rbindlist(lapply(names(cands), function(nm) rbindlist(lapply(c(1L, 5L), function(k)
  cbind(SPEC = nm, K = k, match_balance(ms$treated, pool, cands[[nm]], k = k))))))
print(bal)

cov <- rbindlist(lapply(names(cands), function(nm) {
  n <- cands[[nm]][, .N, by = T_ID]
  data.table(SPEC = nm, TREATED = nrow(ms$treated), MATCHED = nrow(n),
             N_GE_1 = sum(n$N >= 1), N_GE_5 = sum(n$N >= 5), N_GE_25 = sum(n$N >= 25),
             MEDIAN_CANDIDATES = median(n$N), SAME_YEAR_SHARE = mean(cands[[nm]]$YEAR_GAP == 0))
}))
print(cov)
st <- attr(cands$margin, "settings")
settings <- data.table(item = c("ntee_source", "ntee_chars", "size", "size_caliper_log", "margin_caliper", "equity_caliper",
                                "window", "baseline_years", "pool_exclusion", "dollars", "built"),
                       value = c("current BMF; missing codes from NCCS legacy BMF 2022-08, then 2019-08", st$ntee_chars, paste(st$size, collapse = ", "), round(st$size_caliper, 4),
                                 attr(cands$margin, "settings")$health_caliper, attr(cands$equity, "settings")$health_caliper,
                                 "returns in every year t-2..t+2", "mean of t-3 and t-2 (t-2 required)",
                                 "any Schedule N filing or named recipient in years Y-3..Y+2",
                                 "constant 2024 dollars (CPI-U)", format(Sys.time(), "%Y-%m-%d %H:%M")))

con <- DBI::dbConnect(duckdb::duckdb(), file.path(root, "npmerger.duckdb"))
out <- list(panel_990 = panel, research_sample = ms$sample, research_baseline = ms$baseline,
            match_treated = ms$treated, match_pool = pool, match_candidates_margin = cands$margin,
            match_candidates_equity = cands$equity, match_balance = bal, match_coverage = cov, match_settings = settings)
for (nm in names(out)) {
  DBI::dbWriteTable(con, nm, as.data.frame(out[[nm]]), overwrite = TRUE)
  pq <- normalizePath(file.path(root, "parquet", paste0(nm, ".parquet")), winslash = "/", mustWork = FALSE)
  DBI::dbExecute(con, sprintf("COPY %s TO '%s' (FORMAT PARQUET, COMPRESSION ZSTD)", nm, pq))
  lap(sprintf("wrote %-24s %12s rows", nm, format(nrow(out[[nm]]), big.mark = ",")))
}
DBI::dbDisconnect(con, shutdown = TRUE)
saveRDS(list(sample = ms, pool = pool, candidates = cands, balance = bal, coverage = cov), file.path(root, "matching.rds"))
lap("done")
