suppressMessages({library(duckdb); library(data.table)})
con <- dbConnect(duckdb()); S <- gsub("\\\\", "/", Sys.getenv("S"))
q <- function(sql) as.data.table(dbGetQuery(con, sql))
pq <- function(t, yrs = "*") sprintf("read_parquet('%s/data/%s/%s-*.parquet', union_by_name=true)", S, yrs, t)
fx <- function(x) tolower(trimws(x)) %in% c("1", "true", "x", "y", "yes")
d <- readRDS(file.path(S, "stage2.rds")); ov <- readRDS(file.path(S, "p7overlap.rds"))
d <- merge(d, ov[, .(EIN2, RECIP_EIN2, TAX_YEAR, N_SHARED)], by = c("EIN2", "RECIP_EIN2", "TAX_YEAR"), all.x = TRUE)
d[, LEADER_P7 := N_SHARED > 0]
# revised label using flags OR Part VII
d[, TYPE2 := TYPE]
d[TYPE == "asset_transfer" & LEADER_P7 %in% TRUE, TYPE2 := fifelse(N_DONORS >= 2, "mergerN", "merger2")]
d[TYPE2 %like% "mergerN", TYPE2 := "mergerN"]
cat("Revised labels (flags OR Part VII):\n"); print(d[, .N, by = TYPE2][order(-N)][, pct := round(100 * N / sum(N), 1)][])
lab <- d[TAX_YEAR <= 2021, .(EIN2, RECIP_EIN2, TAX_YEAR, OBJECTID, TYPE2)]
dbWriteTable(con, "lab", lab, overwrite = TRUE)

# ---- A. Part IV says closed/disposed but no Schedule N in data
p4 <- q(sprintf("select OBJECTID, EIN2, cast(TAX_YEAR as int) TAX_YEAR, F9_04_LTD_X LTD, F9_04_DOA_X DOA from %s where cast(TAX_YEAR as int) between 2019 and 2021", pq("F9-P04-T00-REQUIRED-SCHEDULES")))
p4[, `:=`(LTD = fx(LTD), DOA = fx(DOA))]
p4[, HAS_SN := OBJECTID %in% d$OBJECTID]
cat("\nA. Part IV line 31/32 vs Schedule N present (990 filers, 2019-21):\n")
print(p4[LTD | DOA, .(n = .N, has_sn = round(mean(HAS_SN), 3)), by = .(LTD, DOA)])
hd <- q(sprintf("select OBJECTID, EIN2, cast(TAX_YEAR as int) TAX_YEAR, RETURN_TYPE, F9_00_RETURN_FINAL_X FINAL from %s where cast(TAX_YEAR as int) between 2019 and 2021", pq("F9-P00-T00-HEADER")))
hd[, FINAL := fx(FINAL)]
cat("Final returns 2019-21:", hd[FINAL == TRUE, .N], "| with Schedule N:", hd[FINAL == TRUE, round(mean(OBJECTID %in% d$OBJECTID), 3)], "\n")
print(hd[FINAL == TRUE, .(n = .N, has_sn = round(mean(OBJECTID %in% d$OBJECTID), 3)), by = RETURN_TYPE])

# ---- recipient-side signals: year t and t+1 vs t-2..t-1 baseline
recip_sig <- function(tab, cols, nm) {
  x <- q(sprintf("select EIN2, cast(TAX_YEAR as int) TAX_YEAR, %s from %s", cols, pq(tab)))
  x <- x[, lapply(.SD, function(v) v[1]), by = .(EIN2, TAX_YEAR)]
  x
}
p6 <- recip_sig("F9-P06-T00-GOVERNANCE", "F9_06_GVRN_CHANGE_DOC_X CHG_DOC, cast(F9_06_GVRN_NUM_VOTING_MEMB as double) NVOTE, F9_06_POLICY_CHPTR_AFFIL_X CHAPTERS, F9_06_GVRN_DECISION_APPROV_X OUTSIDE_APPROV")
p3 <- recip_sig("F9-P03-T00-MISSION", "F9_03_PROG_NEW_X PROG_NEW, F9_03_PROG_CHANGE_X PROG_CHG, F9_03_ORG_MISSION_PURPOSE MISSION")
p11 <- recip_sig("F9-P11-T00-ASSETS", "cast(F9_11_RECO_OTH_CHANGE_NAFB as double) OTH_CHG")
p12 <- recip_sig("F9-P12-T00-FINANCIAL-REPORTING", "F9_12_FINSTAT_AUDIT_CONSOL_X CONSOL")
for (v in c("CHG_DOC", "CHAPTERS", "OUTSIDE_APPROV")) set(p6, j = v, value = fx(p6[[v]]))
for (v in c("PROG_NEW", "PROG_CHG")) set(p3, j = v, value = fx(p3[[v]]))
p12[, CONSOL := fx(CONSOL)]
R <- lab[!is.na(RECIP_EIN2)]
at <- function(tab, k) merge(R[, .(RECIP_EIN2, TAX_YEAR, TYPE2, K = TAX_YEAR + k)], tab, by.x = c("RECIP_EIN2", "K"), by.y = c("EIN2", "TAX_YEAR"))
cat("\nB. Recipient signals in merger year (t) vs two years before (t-2):\n")
b <- merge(at(p6, 0), at(p6, -2)[, .(RECIP_EIN2, TAX_YEAR, NVOTE_PRE = NVOTE, CHG_DOC_PRE = CHG_DOC)], by = c("RECIP_EIN2", "TAX_YEAR"))
b1 <- merge(at(p6, 1)[, .(RECIP_EIN2, TAX_YEAR, NVOTE_POST = NVOTE)], b, by = c("RECIP_EIN2", "TAX_YEAR"))
print(b1[, .(n = .N, chg_doc_t = round(mean(CHG_DOC), 3), chg_doc_tm2 = round(mean(CHG_DOC_PRE), 3),
            board_grew_t1 = round(mean(NVOTE_POST > NVOTE_PRE, na.rm = TRUE), 3), med_board_delta = as.numeric(median(NVOTE_POST - NVOTE_PRE, na.rm = TRUE)),
            chapters = round(mean(CHAPTERS), 3), outside_approv = round(mean(OUTSIDE_APPROV), 3)), by = TYPE2][order(-n)])
b3 <- merge(at(p3, 0), at(p3, -2)[, .(RECIP_EIN2, TAX_YEAR, PROG_NEW_PRE = PROG_NEW)], by = c("RECIP_EIN2", "TAX_YEAR"))
print(b3[, .(n = .N, prog_new_t = round(mean(PROG_NEW), 3), prog_new_tm2 = round(mean(PROG_NEW_PRE), 3), prog_chg_t = round(mean(PROG_CHG), 3)), by = TYPE2][order(-n)])
b11 <- merge(at(p11, 0), d[, .(EIN2, RECIP_EIN2, TAX_YEAR, FMV_NP)], by = c("RECIP_EIN2", "TAX_YEAR"))
b11 <- merge(b11, at(p11, -2)[, .(RECIP_EIN2, TAX_YEAR, OTH_PRE = OTH_CHG)], by = c("RECIP_EIN2", "TAX_YEAR"), all.x = TRUE)
cat("Part XI line 9 'other changes in net assets' at recipient:\n")
print(b11[, .(n = .N, nonzero_t = round(mean(abs(OTH_CHG) > 0, na.rm = TRUE), 3), nonzero_tm2 = round(mean(abs(OTH_PRE) > 0, na.rm = TRUE), 3),
              within_50pct_of_fmv = round(mean(FMV_NP > 0 & abs(OTH_CHG - FMV_NP) / FMV_NP < 0.5, na.rm = TRUE), 3)), by = TYPE2][order(-n)])
b12 <- at(p12, 0); cat("Recipient consolidated audit (t):\n"); print(b12[, .(n = .N, consol = round(mean(CONSOL), 3)), by = TYPE2])

# ---- C. Schedule R: donor and recipient related before merger
sr <- q(sprintf("select EIN2, cast(TAX_YEAR as int) TAX_YEAR, SR_02_RLTD_ORG_EIN REIN from %s", pq("SR-P02-T01-ID-RLTD-TAX-EXEMPED-ORGS")))
sr[, REIN2 := sprintf("EIN-%s-%s", substr(REIN, 1, 2), substr(REIN, 3, 9))]
c1 <- R[, .(EIN2, RECIP_EIN2, TAX_YEAR, TYPE2)]
c1[, R_LISTS_D := paste(RECIP_EIN2, EIN2) %in% sr[, paste(EIN2, REIN2)]]
c1[, D_LISTS_R := paste(EIN2, RECIP_EIN2) %in% sr[, paste(EIN2, REIN2)]]
cat("\nC. Schedule R Part II relationship (any year 2019-22), by label:\n")
print(c1[, .(n = .N, related = round(mean(R_LISTS_D | D_LISTS_R), 3)), by = TYPE2][order(-n)])
sa <- q(sprintf("select EIN2, cast(TAX_YEAR as int) TAX_YEAR, SA_01_PCSTAT_SUPPORT_ORG_X SUPP from %s", pq("SA-P01-T00-PUBLIC-CHARITY-STATUS")))
sa[, SUPP := fx(SUPP)]
c2 <- merge(lab, sa[, .(SUPP = any(SUPP)), by = EIN2], by = "EIN2")
cat("Donor is a 509(a)(3) supporting org:\n"); print(c2[, .(n = .N, supporting = round(mean(SUPP), 3)), by = TYPE2][order(-n)])

# ---- D. mission similarity donor vs recipient
tok <- function(x) { w <- unique(strsplit(tolower(gsub("[^a-z ]", " ", tolower(x))), " +")[[1]]); w[nchar(w) > 3] }
jac <- function(a, b) { if (is.na(a) || is.na(b)) return(NA_real_); A <- tok(a); B <- tok(b); if (!length(A) || !length(B)) NA_real_ else length(intersect(A, B)) / length(union(A, B)) }
mi <- p3[, .(MISSION = MISSION[!is.na(MISSION)][1]), by = EIN2]
m <- merge(merge(R, mi, by = "EIN2"), mi[, .(RECIP_EIN2 = EIN2, RMISSION = MISSION)], by = "RECIP_EIN2")
m[, SIM := mapply(jac, MISSION, RMISSION)]
set.seed(1); m[, SIM_RAND := mapply(jac, MISSION, sample(RMISSION))]
cat("\nD. Mission text Jaccard similarity donor vs recipient (random pairing as baseline):\n")
print(m[, .(n = .N, med_sim = round(median(SIM, na.rm = TRUE), 3), med_rand = round(median(SIM_RAND, na.rm = TRUE), 3)), by = TYPE2][order(-n)])

# ---- E. Schedule O text mentioning merger (2021 filings)
so <- q(sprintf("select OBJECTID, EIN2, cast(TAX_YEAR as int) TAX_YEAR, SO_00_EXPLANATION_TEXT TXT from %s", pq("SO-P00-T99-SUPPLEMENTAL-INFO", "2021")))
mg <- so[grepl("merge|merger|consolidat|combin|acquir|affiliat", TXT, ignore.case = TRUE), .(SO_MERG = TRUE), by = .(EIN2, TAX_YEAR)]
e <- merge(lab[TAX_YEAR == 2021], mg, by = c("EIN2", "TAX_YEAR"), all.x = TRUE); e[is.na(SO_MERG), SO_MERG := FALSE]
er <- merge(lab[TAX_YEAR == 2021], mg[, .(RECIP_EIN2 = EIN2, TAX_YEAR, R_SO_MERG = SO_MERG)], by = c("RECIP_EIN2", "TAX_YEAR"), all.x = TRUE); er[is.na(R_SO_MERG), R_SO_MERG := FALSE]
cat("\nE. Schedule O mentions merger/consolidat/acquir/affiliat (2021): donor and recipient, by label\n")
print(merge(e[, .(n = .N, donor_so = round(mean(SO_MERG), 3)), by = TYPE2], er[, .(recip_so = round(mean(R_SO_MERG), 3)), by = TYPE2], by = "TYPE2")[order(-n)])
cat("Baseline: share of all 2021 SO filers mentioning these words:", round(uniqueN(mg$EIN2) / uniqueN(so$EIN2), 3), "\n")
saveRDS(d, file.path(S, "stage3.rds"))
