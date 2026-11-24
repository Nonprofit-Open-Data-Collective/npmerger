# Descriptive tables for the paper: Schedule N labels, merger counts and
# rates, the merger typology, and case characteristics.
#
# Input:  the project folder (ROOT, default ~/Documents/NPMERGER), built
#         with dev/build-project.R (merger tables, and panel_990 for filer
#         counts)
# Output: paper/data/*.csv
#
# Run from the repository root:  Rscript paper/analysis/01-descriptives.R

devtools::load_all(quiet = TRUE)
suppressMessages({library(data.table); library(DBI)})
root <- Sys.getenv("ROOT", file.path(Sys.getenv("USERPROFILE", path.expand("~")), "Documents", "NPMERGER"))
proj <- merger_project(root)
out  <- file.path("paper", "data"); dir.create(out, showWarnings = FALSE, recursive = TRUE)
YEARS <- 2010:2024

md <- load_merger_data(proj)
sn <- as.data.table(md$sched_n); cs <- as.data.table(md$cases)
dn <- as.data.table(md$donors);  rc <- as.data.table(md$recipients)
tv <- as.data.table(md$transfers); tx <- as.data.table(md$transactions)
lead <- md$leadership

# ---- 1. Schedule N filings by label ------------------------------------------------
lab_levels <- c("merger2", "mergerN", "consolidation", "asset_transfer", "closure", "asset_disposition", "reorganization", "other")
s <- sn[TAX_YEAR %in% YEARS]
labels <- s[, list(N = .N, final_return = mean(FINAL_RETURN %in% TRUE), files_later = mean(DONOR_FILES_LATER %in% TRUE),
                   leader_sn = mean(LEADER_SN %in% TRUE), leader_p7 = mean(LEADER_P7 %in% TRUE),
                   affiliated = mean(AFFILIATED %in% TRUE), top_share = median(TOP_SHARE, na.rm = TRUE),
                   med_fmv = median(FMV_TOTAL, na.rm = TRUE)), by = TYPE]
labels[, pct := N / sum(N)]
labels[, TYPE := factor(TYPE, intersect(lab_levels, TYPE))]
setorder(labels, TYPE)
fwrite(labels, file.path(out, "sn_labels.csv"))
fwrite(s[, .N, by = list(TAX_YEAR, TYPE)][order(TAX_YEAR, TYPE)], file.path(out, "sn_labels_by_year.csv"))
fwrite(s[TYPE %in% c("merger2", "mergerN", "consolidation"), .N, by = BASIS], file.path(out, "merger_basis.csv"))

# recipient EIN coverage on asset lines
tl <- tx[TAX_YEAR %in% YEARS]
fwrite(data.table(lines = nrow(tl), has_ein = mean(!is.na(tl$RECIP_EIN)),
                  recovered = sum(tl$EIN_SOURCE %in% c("name_zip", "name_state")),
                  part1 = mean(tl$PART == 1L), n_filings = uniqueN(tl$OBJECTID)),
       file.path(out, "asset_lines.csv"))

# ---- 2. Filer counts (denominators) and merger rates ---------------------------------
con <- dbConnect(duckdb::duckdb(), file.path(root, "npmerger.duckdb"), read_only = TRUE)
filers_y <- as.data.table(dbGetQuery(con, "SELECT TAX_YEAR, COUNT(*) AS FILERS, SUM(CASE WHEN EZ THEN 0 ELSE 1 END) AS FULL990
                                           FROM panel_990 GROUP BY TAX_YEAR"))
filers_n <- as.data.table(dbGetQuery(con, "SELECT TAX_YEAR, NTEE_MAJOR, COUNT(*) AS FILERS FROM panel_990 GROUP BY TAX_YEAR, NTEE_MAJOR"))
# one NTEE code per organization from the panel (current BMF, legacy BMF where missing)
org_ntee <- as.data.table(dbGetQuery(con, "SELECT EIN2, ANY_VALUE(NTEE_MAJOR) AS NTEE_MAJOR, ANY_VALUE(SUBSECTION) AS SUBSECTION
                                           FROM panel_990 GROUP BY EIN2"))
dbDisconnect(con, shutdown = TRUE)

c2 <- cs[MERGER_YEAR %in% YEARS]
yr <- c2[, list(cases = .N, events = uniqueN(MERGER_GROUP_ID),
                merger2 = sum(TYPE == "merger2"), mergerN = sum(TYPE == "mergerN"), consolidation = sum(TYPE == "consolidation"),
                affiliated = mean(AFFILIATED %in% TRUE)), by = list(TAX_YEAR = MERGER_YEAR)]
yr <- merge(yr, filers_y, by = "TAX_YEAR")
yr[, rate_per_1000 := 1000 * cases / FILERS]
yr <- merge(yr, s[, list(closures = sum(TYPE == "closure"), transfers = sum(TYPE == "asset_transfer"),
                         dispositions = sum(TYPE == "asset_disposition")), by = TAX_YEAR], by = "TAX_YEAR")
fwrite(yr[order(TAX_YEAR)], file.path(out, "mergers_by_year.csv"))

# by subsector (donor's NTEE major group), pooled 2010-2024
grp10 <- function(m) fcase(m == "A", "Arts, culture, humanities", m == "B", "Education",
                           m %in% c("C", "D"), "Environment and animals", m %in% c("E", "F", "G", "H"), "Health",
                           m %in% LETTERS[9:16], "Human services", m == "Q", "International",
                           m %in% LETTERS[18:23], "Public and societal benefit", m == "X", "Religion",
                           m == "Y", "Mutual and membership benefit", default = "Unknown")
filers_n[, NTEE_MAJOR := grp10(NTEE_MAJOR)]
filers_n <- filers_n[, list(FILERS = sum(FILERS)), by = list(TAX_YEAR, NTEE_MAJOR)]
org_ntee[, GROUP := grp10(NTEE_MAJOR)]
dmaj <- dn[, list(MERGER_ID, D_EIN2 = EIN2, D_NTEE = NTEE, D_STATE = STATE, D_AGE = AGE, D_EZ = RETURN_TYPE == "990EZ")]
dmaj[org_ntee, on = c(D_EIN2 = "EIN2"), `:=`(D_MAJ = i.GROUP, D_C3 = i.SUBSECTION == "3")]
rmaj <- rc[, list(MERGER_ID, R_EIN2 = EIN2, R_NTEE = NTEE, R_STATE = STATE, R_AGE = AGE)]
rmaj[org_ntee, on = c(R_EIN2 = "EIN2"), `:=`(R_MAJ = i.GROUP, R_C3 = i.SUBSECTION == "3")]
c2 <- merge(merge(c2, dmaj, by = "MERGER_ID", all.x = TRUE), rmaj, by = "MERGER_ID", all.x = TRUE)
sec <- c2[, list(cases = .N), by = list(NTEE_MAJOR = D_MAJ)]
den <- filers_n[TAX_YEAR %in% YEARS, list(filer_years = sum(FILERS)), by = NTEE_MAJOR]
sec <- merge(sec, den, by = "NTEE_MAJOR", all = TRUE)
sec[, `:=`(share_cases = cases / sum(cases, na.rm = TRUE), share_filers = filer_years / sum(filer_years, na.rm = TRUE),
           rate_per_1000 = 1000 * cases / filer_years)]
fwrite(sec[order(-cases)], file.path(out, "mergers_by_sector.csv"))

# ---- 3. Typology ------------------------------------------------------------------------
pick <- function(a, b) fifelse(!is.na(a), a, b)
sz <- merge(dn[, list(MERGER_ID, D_REV = pick(REVENUE_TM1, REVENUE_TM2), D_AST = pick(ASSETS_TM1, ASSETS_TM2),
                      D_EXP = pick(EXPENSES_TM1, EXPENSES_TM2), D_REV3 = pick(REVENUE_TM3, REVENUE_TM4))],
            rc[, list(MERGER_ID, R_REV = pick(REVENUE_TM1, REVENUE_TM2), R_AST = pick(ASSETS_TM1, ASSETS_TM2))], by = "MERGER_ID")
c2 <- merge(c2, sz, by = "MERGER_ID", all.x = TRUE)
c2 <- merge(c2, tv[, list(MERGER_ID, FMV = fifelse(FLAG_OUTLIER %in% TRUE, NA_real_, FMV_ASSETS), FLAG_OUTLIER,
                          FMV_CASH, FMV_REAL_ESTATE, FMV_INVESTMENTS, FMV_RECEIVABLES, FMV_PROGRAM, FMV_EQUIPMENT)],
            by = "MERGER_ID", all.x = TRUE)
c2 <- merge(c2, lead[, list(MERGER_ID, CEO_CAT, BOARD_CAT, D_CEO_JOINS, DONOR_JOINERS, DONOR_SEAT_SHARE, BOARD_RETAIN)],
            by = "MERGER_ID", all.x = TRUE)

# donor budget relative to recipient: the larger of revenue and expenses (programs
# can run on expenses funded by an earlier year's revenue)
c2[, D_SIZE := pmax(D_REV, D_EXP, 0, na.rm = TRUE)]
c2[, R_SIZE := pmax(R_REV, 0, na.rm = TRUE)]
c2[, RATIO := fifelse(R_SIZE > 0, D_SIZE / R_SIZE, NA_real_)]
c2[, DISTRESS := (D_EXP > D_REV & D_REV > 0) | (D_REV3 > 0 & D_REV < 0.75 * D_REV3)]
c2[, ASSET_LIGHT := (is.na(FMV) | FMV < 25000) & (is.na(D_AST) | D_AST < 50000)]

TYP <- c("Consolidation into a new entity", "Multi-party absorption", "Related-entity restructuring",
         "Program or asset-light transfer", "Absorption of a struggling organization",
         "Absorption of a stable smaller organization", "Merger of near-equals", "Larger donor into smaller successor",
         "Recipient not observed before the merger")
c2[, TYPOLOGY := fcase(
  TYPE == "consolidation", TYP[1],
  TYPE == "mergerN", TYP[2],
  AFFILIATED %in% TRUE, TYP[3],
  is.na(RATIO), TYP[9],
  ASSET_LIGHT & RATIO < 0.5, TYP[4],
  RATIO < 0.5 & DISTRESS %in% TRUE, TYP[5],
  RATIO < 0.5, TYP[6],
  RATIO <= 2, TYP[7],
  default = TYP[8])]
c2[, TYPOLOGY := factor(TYPOLOGY, TYP)]
fwrite(c2[, list(MERGER_ID, MERGER_GROUP_ID, TYPE, TYPOLOGY, AFFILIATED, RATIO, DISTRESS, ASSET_LIGHT)],
       file.path(out, "case_typology.csv"))

med <- function(x) as.numeric(median(x, na.rm = TRUE))
typ <- c2[, list(N = .N, donor_rev = med(D_SIZE), recip_rev = med(R_SIZE), ratio = med(RATIO), fmv = med(FMV),
                 fmv_share_recip = med(fifelse(R_AST > 0, FMV / R_AST, NA_real_)),
                 distress = mean(DISTRESS %in% TRUE), same_ntee = mean(D_MAJ == R_MAJ, na.rm = TRUE), c3 = mean(D_C3 %in% TRUE),
                 same_state = mean(D_STATE == R_STATE, na.rm = TRUE), donor_ez = mean(D_EZ %in% TRUE),
                 ceo_joins = mean(D_CEO_JOINS[!is.na(D_CEO_JOINS)]), mission_sim = med(MISSION_SIM)),
          by = TYPOLOGY][order(TYPOLOGY)]
typ[, pct := N / sum(N)]
fwrite(typ, file.path(out, "typology.csv"))

# size-ratio distribution (for a figure), two-party mergers
fwrite(c2[TYPE == "merger2" & RATIO > 0, list(RATIO, AFFILIATED, TYPOLOGY)], file.path(out, "size_ratio.csv"))

# overall case descriptives
sumq <- function(x) { x <- x[is.finite(x)]; list(n = length(x), mean = mean(x), trim5 = mean(x, trim = 0.05),
                                                 p25 = quantile(x, .25, names = FALSE), p50 = median(x),
                                                 p75 = quantile(x, .75, names = FALSE)) }
d <- rbind(cbind(org = "donor", measure = "revenue", as.data.table(sumq(c2$D_REV))),
           cbind(org = "donor", measure = "assets", as.data.table(sumq(c2$D_AST))),
           cbind(org = "recipient", measure = "revenue", as.data.table(sumq(c2$R_REV))),
           cbind(org = "recipient", measure = "assets", as.data.table(sumq(c2$R_AST))),
           cbind(org = "transfer", measure = "fmv", as.data.table(sumq(c2[FMV > 0, FMV]))))
fwrite(d, file.path(out, "case_sizes.csv"))
fwrite(data.table(
  cases = nrow(c2), events = uniqueN(c2$MERGER_GROUP_ID), recipients = uniqueN(c2$RECIP_EIN2),
  multi_event_share = c2[, list(n = N_GROUP[1]), by = MERGER_GROUP_ID][, mean(n >= 2)],
  multi_case_share = mean(c2$N_GROUP >= 2),
  serial_recipients = c2[, uniqueN(MERGER_YEAR), by = RECIP_EIN2][, sum(V1 >= 2)],
  affiliated = mean(c2$AFFILIATED %in% TRUE), recip_larger = mean(c2$RATIO < 1, na.rm = TRUE),
  recip_10x = mean(c2$RATIO < 0.1, na.rm = TRUE), recip_100x = mean(c2$RATIO < 0.01, na.rm = TRUE),
  med_ratio_inv = median(1 / c2[RATIO > 0, RATIO]), coverage = median(tv[FMV_ASSETS > 0 & !FLAG_OUTLIER %in% TRUE, COVERAGE], na.rm = TRUE),
  total_fmv_bn = sum(c2[FMV > 0, FMV]) / 1e9, n_outliers = sum(c2$FLAG_OUTLIER %in% TRUE),
  ceo_identified = sum(!is.na(c2$D_CEO_JOINS)), ceo_joins = mean(c2$D_CEO_JOINS[!is.na(c2$D_CEO_JOINS)]),
  same_ntee = mean(c2$D_MAJ == c2$R_MAJ, na.rm = TRUE), c3 = mean(c2$D_C3 %in% TRUE), same_state = mean(c2$D_STATE == c2$R_STATE, na.rm = TRUE),
  donor_ez = mean(c2$D_EZ %in% TRUE)), file.path(out, "case_summary.csv"))

# leadership categories
fwrite(c2[TYPE == "merger2" & !is.na(CEO_CAT), .N, by = CEO_CAT][, pct := N / sum(N)][], file.path(out, "ceo_cat.csv"))
fwrite(c2[TYPE == "merger2" & !is.na(BOARD_CAT), .N, by = BOARD_CAT][, pct := N / sum(N)][], file.path(out, "board_cat.csv"))

# composition of transferred assets (positive, unflagged)
ac <- c2[FMV > 0, lapply(.SD, function(v) sum(pmax(v, 0), na.rm = TRUE)),
         .SDcols = c("FMV_CASH", "FMV_INVESTMENTS", "FMV_REAL_ESTATE", "FMV_RECEIVABLES", "FMV_PROGRAM", "FMV_EQUIPMENT")]
fwrite(melt(ac, measure.vars = names(ac))[, share := value / sum(c2[FMV > 0, FMV])][], file.path(out, "asset_classes.csv"))

# illustrative cases: the two largest recipients (by revenue) in each typology
ex <- merge(c2[, list(MERGER_ID, TYPOLOGY, MERGER_YEAR, D_SIZE, R_SIZE, FMV, D_NTEE, R_NTEE)],
            dn[, list(MERGER_ID, DONOR = NAME, D_CITY = CITY, D_ST = STATE)], by = "MERGER_ID")
ex <- merge(ex, rc[, list(MERGER_ID, RECIPIENT = NAME, R_ST = STATE)], by = "MERGER_ID")
set.seed(2026)
ex <- ex[R_SIZE > 0 & D_SIZE > 0][, .SD[sample(.N, min(.N, 6L))], by = TYPOLOGY]
fwrite(ex[order(TYPOLOGY)], file.path(out, "typology_examples.csv"))

print(labels); print(yr); print(typ); print(sec[order(-cases)])
cat("wrote", out, "\n")
