# Score the classifier against the hand labels (plan step 2).
#
# Reads dev/validation/hand-labels.csv and OUT/merger_data.rds, re-runs the
# current classify_transactions() on the stored filing features, and prints
# confusion matrices, per-label precision, and merger recall. "Weighted"
# figures reweight each sampled stratum (the v1 label) to its population
# size, so they estimate accuracy over all Schedule N filings with text.
#
# Env: OUT = folder holding merger_data.rds. Run from the package root.

devtools::load_all(quiet = TRUE)
library(data.table)
out <- Sys.getenv("OUT")
md <- readRDS(file.path(out, "merger_data.rds"))
sn <- as.data.table(md$sched_n)
hl <- fread("dev/validation/hand-labels.csv", colClasses = list(character = "OBJECTID"))

# merger_data from before v2 lacks SN_MERGER_TEXT; rebuild it from the transactions
# and Schedule N Part III (if a cached sched_n raw object is available) or
# fall back to the stored classifier output.
if (!"SN_MERGER_TEXT" %in% names(sn)) {
  tx <- as.data.table(md$transactions)
  hit <- function(v) !is.na(v) & grepl(sn_merger_pattern(), v, ignore.case = TRUE, perl = TRUE)
  ids <- tx[hit(ASSET_DESC) | hit(FMV_METHOD), OBJECTID]
  p3f <- Sys.getenv("P3_RDS")
  if (nzchar(p3f)) { p3 <- readRDS(p3f); ids <- c(ids, p3$OBJECTID[hit(p3$TXT)]) }
  sn[, SN_MERGER_TEXT := OBJECTID %in% ids]
}
x <- add_donor_counts(sn[, !intersect(c("TYPE", "BASIS", "LEADER", "N_CORROBORATE", "N_DONORS", "TERMINATED"), names(sn)), with = FALSE])
cl <- classify_transactions(x)

lv <- c("merger2", "mergerN", "consolidation")
coll <- function(t) fcase(t %in% lv, "MERGER", t == "asset_transfer", "ASSET_TRANSFER", t == "closure", "CLOSURE",
                          t == "asset_disposition", "ASSET_DISPOSITION", t == "reorganization", "REORGANIZATION", default = "OTHER")
d <- merge(hl, cl[, list(OBJECTID, TYPE_NOW = TYPE, BASIS_NOW = BASIS)], by = "OBJECTID")
d[, `:=`(P_V1 = coll(TYPE_V1), P_NOW = coll(TYPE_NOW))]
pop <- sn[, .N, by = TYPE]
d[, wt := pop$N[match(TYPE_V1, pop$TYPE)] / .N, by = TYPE_V1]
h <- c("MERGER", "ASSET_TRANSFER", "CLOSURE", "ASSET_DISPOSITION", "REORGANIZATION")

cat("Fine type (current rules) x hand label\n")
print(table(classifier = d$TYPE_NOW, hand = factor(d$HAND_LABEL, h)))
cat("\nCollapsed, v1 rules\n"); print(table(classifier = factor(d$P_V1, h), hand = factor(d$HAND_LABEL, h)))
cat("\nCollapsed, current rules\n"); print(table(classifier = factor(d$P_NOW, h), hand = factor(d$HAND_LABEL, h)))
acc <- function(p) c(raw = mean(d[[p]] == d$HAND_LABEL), weighted = weighted.mean(d[[p]] == d$HAND_LABEL, d$wt))
cat("\nAgreement v1:", round(100 * acc("P_V1"), 1), " current:", round(100 * acc("P_NOW"), 1), "\n")
for (p in c("P_V1", "P_NOW")) {
  cat("\nPrecision,", p, "\n")
  print(d[, list(n = .N, precision = round(mean(HAND_LABEL == get(p)), 2),
                 weighted = round(weighted.mean(HAND_LABEL == get(p), wt), 2)), keyby = c(p)])
  cat("Merger recall:", round(d[HAND_LABEL == "MERGER", c(mean(get(p) == "MERGER"), weighted.mean(get(p) == "MERGER", wt))], 2), "\n")
}
cat("\nMerger precision by basis (current)\n")
print(d[P_NOW == "MERGER", list(n = .N, precision = round(mean(HAND_LABEL == "MERGER"), 2)), by = BASIS_NOW])
