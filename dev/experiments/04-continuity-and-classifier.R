suppressMessages({library(duckdb); library(data.table)})
con <- dbConnect(duckdb()); S <- Sys.getenv("S")
st <- readRDS(file.path(S, "stage1.rds")); fl <- st$fl; rr <- st$rr; md <- st$md
glob <- function(t) sprintf("%s/data/*/%s-*.parquet", gsub("\\\\", "/", S), t)
hd <- as.data.table(dbGetQuery(con, sprintf("select EIN2, OBJECTID, ORG_EIN, cast(TAX_YEAR as int) TAX_YEAR, RETURN_TYPE, RETURN_AMENDED_X,
   F9_00_RETURN_FINAL_X FINAL, F9_00_RETURN_INITIAL_X INITIAL, F9_00_YEAR_FORMATION FORMED, F9_00_ORG_ADDR_STATE ST, F9_00_ORG_ADDR_ZIP ZIP, F9_00_EXEMPT_STAT_501C3_X C3
   from read_parquet('%s')", glob("F9-P00-T00-HEADER"))))
s1 <- as.data.table(dbGetQuery(con, sprintf("select OBJECTID, F9_01_REV_TOT_CY REV, F9_01_EXP_TOT_CY EXP, F9_01_NAFB_ASSET_TOT_BOY A_BOY, F9_01_NAFB_ASSET_TOT_EOY A_EOY,
   F9_01_NAFB_LIAB_TOT_EOY L_EOY, F9_01_ACT_GVRN_EMPL_TOT EMPL from read_parquet('%s')", glob("F9-P01-T00-SUMMARY"))))
for (v in c("REV","EXP","A_BOY","A_EOY","L_EOY","EMPL")) set(s1, j = v, value = as.numeric(s1[[v]]))
hd <- merge(hd, s1, by = "OBJECTID", all.x = TRUE)
flagx <- function(x) tolower(trimws(x)) %in% c("1", "true", "x")
hd[, `:=`(FINAL = flagx(FINAL), INITIAL = flagx(INITIAL), FORMED = suppressWarnings(as.integer(FORMED)))]
cat("header rows:", nrow(hd), " years:", paste(range(hd$TAX_YEAR), collapse = "-"), "\n")
# one row per EIN-year (prefer non-amended, latest)
ey <- hd[order(EIN2, TAX_YEAR, RETURN_AMENDED_X)][, .SD[1], by = .(EIN2, TAX_YEAR)]
last_year <- ey[, .(LAST_YR = max(TAX_YEAR), FIRST_YR = min(TAX_YEAR), FORMED = max(FORMED, na.rm = TRUE)), by = EIN2]
last_year[!is.finite(FORMED), FORMED := NA]
fl[, TAX_YEAR := as.integer(TAX_YEAR)]
# --- donor side
d <- merge(fl, hd[, .(OBJECTID, FINAL, RETURN_TYPE, REV, EXP, A_BOY, A_EOY, L_EOY, EMPL)], by = "OBJECTID", all.x = TRUE)
d <- merge(d, last_year[, .(EIN2, LAST_YR)], by = "EIN2", all.x = TRUE)
d[, FILES_LATER := LAST_YR > TAX_YEAR]
d[, ASSETS_GONE := !is.na(A_EOY) & A_EOY <= pmax(1000, 0.05 * A_BOY)]
d[, COVER := fifelse(A_BOY > 0, FMV_TOTAL / A_BOY, NA_real_)]
cat("\nDonor signals by Schedule N part (only rows with header match):\n")
print(d[!is.na(FINAL), .(n = .N, final_ret = mean(FINAL), files_later = mean(FILES_LATER, na.rm = TRUE), assets_gone = mean(ASSETS_GONE),
         med_cover = median(COVER, na.rm = TRUE), ez = mean(RETURN_TYPE == "990EZ")), by = .(HAS_P1, HAS_P2)])
cat("Header match rate for SN filings:", mean(!is.na(d$FINAL)), "\n")
# --- recipient side: dominant nonprofit recipient per filing
np <- rr[RTYPE %in% c("501c3", "other_exempt", "unknown_with_ein") & !is.na(RECIP_EIN) & !(SELF %in% TRUE)]
np[, TAX_YEAR := as.integer(TAX_YEAR)]
top <- np[, .(FMV = sum(FMV, na.rm = TRUE)), by = .(OBJECTID, TAX_YEAR, RECIP_EIN)][order(OBJECTID, -FMV)][, .SD[1], by = OBJECTID]
top[, RECIP_EIN2 := sprintf("EIN-%s-%s", substr(RECIP_EIN, 1, 2), substr(RECIP_EIN, 3, 9))]
top <- merge(top, last_year, by.x = "RECIP_EIN2", by.y = "EIN2", all.x = TRUE)
top[, `:=`(R_IN_EFILE = !is.na(LAST_YR), R_CONTINUES = LAST_YR > TAX_YEAR, R_NEW = (!is.na(FORMED) & FORMED >= TAX_YEAR - 1))]
cat("\nTop NP recipient: in efile", round(mean(top$R_IN_EFILE), 3), "| files after merger year", round(mean(top$R_CONTINUES, na.rm = TRUE), 3),
    "| formed within 1yr", round(mean(top$R_NEW, na.rm = TRUE), 3), "\n")
# recipient size vs donor
rs <- ey[, .(EIN2, TAX_YEAR, R_REV = REV, R_ASSETS = A_EOY)]
top <- merge(top, rs, by.x = c("RECIP_EIN2", "TAX_YEAR"), by.y = c("EIN2", "TAX_YEAR"), all.x = TRUE)
d <- merge(d, top[, .(OBJECTID, RECIP_EIN, RECIP_EIN2, R_IN_EFILE, R_CONTINUES, R_NEW, R_REV, FORMED_R = FORMED)], by = "OBJECTID", all.x = TRUE)
d <- merge(d, md[, .(RECIP_EIN, TAX_YEAR = as.integer(TAX_YEAR), N_DONORS)], by = c("RECIP_EIN", "TAX_YEAR"), all.x = TRUE)
d[is.na(N_DONORS), N_DONORS := 0L]
# --- prototype classifier
d[, TYPE := fcase(
  !HAS_P1 & HAS_P2, "asset_disposition",
  !is.na(RECIP_EIN) & RECIP_EIN == gsub("[^0-9]", "", EIN2), "reorganization",
  HAS_P1 & is.na(RECIP_EIN) & (N_RECIP == 0 | is.na(N_RECIP)), "closure",
  HAS_P1 & is.na(RECIP_EIN), "closure",                       # distributed only to individuals/businesses/govt/unknown
  HAS_P1 & TOP_RECIP_SHARE < 0.5 & N_NP_RECIP > 1, "closure", # spread across many charities
  HAS_P1 & LEADER & N_DONORS >= 2 & R_NEW %in% TRUE, "mergerN_new_entity",
  HAS_P1 & LEADER & N_DONORS >= 2, "mergerN",
  HAS_P1 & LEADER, "merger2",
  HAS_P1, "asset_transfer",
  default = "other")]
cat("\nPrototype labels (2019-2021 Schedule N filings):\n"); print(d[, .N, by = TYPE][order(-N)][, pct := round(100 * N / sum(N), 1)][])
cat("\nValidation signals by label:\n")
print(d[, .(n = .N, final = round(mean(FINAL, na.rm = TRUE), 2), donor_files_later = round(mean(FILES_LATER, na.rm = TRUE), 2),
            assets_gone = round(mean(ASSETS_GONE, na.rm = TRUE), 2), recip_continues = round(mean(R_CONTINUES, na.rm = TRUE), 2),
            med_donor_rev = median(REV, na.rm = TRUE), med_recip_rev = median(R_REV, na.rm = TRUE),
            med_fmv = median(FMV_TOTAL, na.rm = TRUE), med_cover = round(median(COVER, na.rm = TRUE), 2)), by = TYPE][order(-n)])
cat("\nAsset transfers where recipient is in efile & continues (staff move not reported):",
    d[TYPE == "asset_transfer", round(mean(R_CONTINUES %in% TRUE), 3)], "\n")
cat("Merger2 cases where donor keeps filing later:", d[TYPE == "merger2", sum(FILES_LATER %in% TRUE)], "of", d[TYPE == "merger2", .N], "\n")
cat("Recipients ever recipient in >1 year (serial acquirers):", d[TYPE %like% "merger", uniqueN(RECIP_EIN[duplicated(RECIP_EIN)])], "\n")
saveRDS(d, file.path(S, "stage2.rds"))
ex <- d[TYPE == "mergerN"][order(RECIP_EIN)][, .(TAX_YEAR, EIN2, RECIP_EIN, N_DONORS, FMV_TOTAL, R_NEW)][1:12]
print(ex)
