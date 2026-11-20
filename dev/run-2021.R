# Real-data check of the full classification pipeline on 2021 Schedule N filings.
# Set env var S to a scratch directory; data are cached under $S/data.
suppressMessages({devtools::load_all("C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmerger", quiet = TRUE); library(data.table)})
path <- file.path(Sys.getenv("S"), "data")
t0 <- Sys.time()
sn <- get_schedule_n(2021, path = path, verbose = FALSE)
fl <- sn_filings(sn)
ev <- get_evidence_tables(fl, path = path, verbose = FALSE)
cat("evidence rows:", paste(names(ev), sapply(ev, nrow), sep = "=", collapse = "  "), "\n")
cat("retrieval:", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min\n")
fe <- merger_features(fl, ev)
lab <- classify_transactions(fe)
saveRDS(list(fe = fe, lab = lab), file.path(Sys.getenv("S"), "real2021.rds"))
cat("\nLabels (2021):\n"); print(lab[, .N, by = .(TYPE)][order(-N)][, pct := round(100 * N / sum(N), 1)][])
cat("\nMerger basis:\n"); print(lab[!is.na(BASIS), .N, by = .(TYPE, BASIS)][order(TYPE, BASIS)])
cat("\nEvidence and validation by label:\n")
print(lab[, .(n = .N, leader_sn = round(mean(LEADER_SN), 2), p7_obs = round(mean(!is.na(LEADER_P7)), 2),
              p7 = round(mean(LEADER_P7, na.rm = TRUE), 2), corr2 = round(mean(N_CORROBORATE >= 2), 3),
              affiliated = round(mean(AFFILIATED), 2), r_new = round(mean(R_NEW, na.rm = TRUE), 3),
              final = round(mean(FINAL_RETURN), 2), files_later = round(mean(DONOR_FILES_LATER, na.rm = TRUE), 2),
              mission = round(median(MISSION_SIM, na.rm = TRUE), 3)), by = TYPE][order(-n)])
cat("\nN_DONORS distribution among mergers:\n"); print(lab[TYPE %in% c("merger2", "mergerN", "consolidation"), table(pmin(N_DONORS, 5L), useNA = "ifany")])
cat("\nExample consolidations:\n"); print(head(lab[TYPE == "consolidation", .(EIN2, TOP_RECIP_EIN, N_DONORS, R_FORMED, R_INITIAL_NEAR, AFFILIATED)], 8))
