# Build inst/extdata/npmerger-example.rds: a small extract of real 2021
# Schedule N filings, with the evidence, core, name-index, and BMF rows
# needed to run build_merger_data() offline.
#
# Usage: set CACHE to a panel990 cache that holds Schedule N 2021, evidence
# tables 2020-2022, core tables 2016-2025, the 2020-2022 headers, and the BMF,
# then run from the package root:  Rscript data-raw/example.R

devtools::load_all(quiet = TRUE)
library(data.table)
CACHE <- Sys.getenv("CACHE", "PANEL990")
set.seed(2021)

sn <- get_schedule_n(2021, path = CACHE, verbose = FALSE)
tx <- sn_transactions(sn)
names_all <- get_name_index(2020:2022, path = CACHE, verbose = FALSE)
tx <- recover_recipient_ein(tx, names_all)
fl <- sn_filings(sn, tx)
ev <- get_evidence_tables(fl, path = CACHE, verbose = FALSE)
lab <- classify_transactions(merger_features(fl, ev))

# pick filings: every donor of a few multi-party groups, plus a sample of each label
grp <- c(lab[TYPE == "mergerN", .(n = .N), by = TOP_RECIP_EIN][n >= 2][sample(.N, 2), TOP_RECIP_EIN],
         lab[TYPE == "consolidation", .(n = .N), by = TOP_RECIP_EIN][n >= 2][sample(.N, 1), TOP_RECIP_EIN])
pick <- unique(c(
  lab[TOP_RECIP_EIN %in% grp & TYPE %in% c("mergerN", "consolidation"), OBJECTID],
  lab[TYPE == "merger2" & BASIS == "leader"][sample(.N, 8), OBJECTID],
  lab[TYPE == "merger2" & BASIS == "corroborated"][sample(.N, 2), OBJECTID],
  lab[TYPE == "asset_transfer"][sample(.N, 4), OBJECTID],
  lab[TYPE == "closure"][sample(.N, 4), OBJECTID],
  lab[TYPE == "asset_disposition"][sample(.N, 3), OBJECTID]))
sel <- lab[OBJECTID %in% pick]
eins <- unique(na.omit(c(sel$EIN2, sel$RECIP_EIN2)))
cat("filings:", length(pick), " organizations:", length(eins), "\n")

sub_sn <- sn
for (nm in names(sn_table_names())) sub_sn[[nm]] <- sn[[nm]][OBJECTID %in% pick]
sub_ev <- lapply(ev, function(x) x[EIN2 %in% eins])
sub_ev$so <- sub_ev$so[, SO_00_EXPLANATION_TEXT := substr(SO_00_EXPLANATION_TEXT, 1, 400)]

core <- get_core(eins, 2016:2025, path = CACHE, verbose = FALSE)
keep_cols <- unique(c(.base_cols, "F9_00_ORG_ADDR_L1", "F9_00_ORG_ADDR_CITY", "F9_00_ORG_ADDR_STATE", "F9_00_ORG_ADDR_ZIP",
                      "F9_00_YEAR_FORMATION", "F9_00_RETURN_FINAL_X", "F9_00_RETURN_INITIAL_X",
                      fiscal::get_pc_fields(), fiscal::get_pz_fields(),
                      grep("^F9_(01|09|10)_", unlist(lapply(core[c("summary", "expenses", "balance")], names)), value = TRUE),
                      "F9_08_REV_CONTR_NONCSH", "F9_08_REV_CONTR_TOT",
                      grep("^F9_07_COMP_DTK_(NAME_PERS|TITLE|AVE_HOUR_WEEK|COMP_ORG|COMP_RLTD|COMP_OTH|POS_)", names(core$p7), value = TRUE)))
sub_core <- structure(lapply(core, function(x) x[, intersect(names(x), keep_cols), with = FALSE]), class = c("merger_core", "list"))

cand <- org_name_key(tx[OBJECTID %in% pick & is.na(RECIP_EIN) | EIN_SOURCE %in% c("name_zip", "name_state"), RECIP_NAME])
sub_names <- names_all[NAME_KEY %in% cand]
bmf <- get_bmf(eins, path = CACHE, verbose = FALSE)
bmf_cols <- intersect(names(bmf), c("EIN2", grep("ntee|ruling|subsection", names(bmf), value = TRUE, ignore.case = TRUE)))
sub_bmf <- bmf[, bmf_cols, with = FALSE]

ex <- list(sn = sub_sn, evidence = sub_ev, core = sub_core, names = sub_names, bmf = sub_bmf)
dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(ex, "inst/extdata/npmerger-example.rds", compress = "xz")
cat("size:", round(file.size("inst/extdata/npmerger-example.rds") / 1024), "KB\n")
print(sel[, .N, by = TYPE])
