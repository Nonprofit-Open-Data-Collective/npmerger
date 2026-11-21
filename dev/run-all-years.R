# Full-years run of the npmerger pipeline.
# Env vars: CACHE (panel990 cache directory), OUT (output directory).
# Schedule N years 2010-2024 (2009 is a partial first e-file year, 2025 a
# partial current year); core tables 2009-2025.

devtools::load_all(quiet = TRUE)
library(data.table)
CACHE <- Sys.getenv("CACHE", "PANEL990"); OUT <- Sys.getenv("OUT", "npmerger-out")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
t0 <- Sys.time()
md <- build_merger_data(2010:2024, path = CACHE, ratios = TRUE, verbose = TRUE)
cat("\nrun time:", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min\n")
saveRDS(md, file.path(OUT, "merger_data.rds"))
for (nm in c("sched_n", "cases", "transfers", "donors", "recipients", "part7", "fiscal"))
  if (!is.null(md[[nm]])) fwrite(md[[nm]], file.path(OUT, paste0(nm, ".csv")))
print(md)
cat("\nManifest:\n"); print(md$manifest)

sn <- md$sched_n
cat("\nLabels by Schedule N year:\n")
print(dcast(sn[, .N, by = .(TAX_YEAR, TYPE)], TAX_YEAR ~ TYPE, value.var = "N", fill = 0))
cat("\nMerger basis and affiliation:\n")
print(sn[TYPE %in% c("merger2", "mergerN", "consolidation"), .(n = .N, corroborated = mean(BASIS == "corroborated"),
                                                                 affiliated = mean(AFFILIATED)), by = TYPE])
tx <- md$transactions
cat("\nRecipient EIN source (asset lines with a non-individual, non-business recipient):\n")
print(tx[!RECIP_TYPE %in% c("individual", "business"), .N, by = EIN_SOURCE][, pct := round(100 * N / sum(N), 1)][])
cs <- md$cases
cat("\nCases:", nrow(cs), " groups:", uniqueN(cs$MERGER_GROUP_ID),
    " recipient year differs from donor year:", round(mean(cs$RECIP_MERGER_YEAR != cs$MERGER_YEAR), 3), "\n")
tv <- md$transfers
cat("\nTransfer value: median FMV", median(tv$FMV_TOTAL, na.rm = TRUE), " sum ($bn)", round(sum(tv$FMV_TOTAL[!tv$FLAG_OUTLIER %in% TRUE], na.rm = TRUE) / 1e9, 1),
    " outliers", sum(tv$FLAG_OUTLIER, na.rm = TRUE), " median coverage", round(median(tv$COVERAGE, na.rm = TRUE), 2), "\n")
cls <- grep("^FMV_", names(tv), value = TRUE); cls <- setdiff(cls, "FMV_TOTAL")
cat("Share of transferred value by asset class:\n"); print(round(colSums(tv[!FLAG_OUTLIER %in% TRUE, ..cls], na.rm = TRUE) / sum(tv[!FLAG_OUTLIER %in% TRUE, FMV_TOTAL], na.rm = TRUE), 3))
for (side in c("donors", "recipients")) {
  a <- md[[side]]
  cat("\n", side, ": median revenue t0", median(a$REVENUE_T0, na.rm = TRUE), " median age", median(a$AGE, na.rm = TRUE),
      " NTEE coverage", round(mean(!is.na(a$NTEE)), 3), " 5-yr history complete", round(mean(a$N_YEARS_OBSERVED == 5L), 3), "\n")
}
p7 <- md$part7
cat("\nPart VII: people", nrow(p7), " mergers with any IN_BOTH person", round(p7[, any(IN_BOTH), by = MERGER_ID][, mean(V1)], 3), "\n")
fp <- md$fiscal
cat("\nFiscal panel rows by role and event time:\n"); print(dcast(fp[, .N, by = .(ROLE, TIME_FROM_MERGER)], TIME_FROM_MERGER ~ ROLE, value.var = "N"))
cat("\nRecipient median revenue by event time:\n"); print(fp[ROLE == "recipient", .(n = .N, revenue = median(REVENUE, na.rm = TRUE), assets = median(ASSETS, na.rm = TRUE)), by = TIME_FROM_MERGER][order(TIME_FROM_MERGER)])
