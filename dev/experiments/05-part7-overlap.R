suppressMessages({library(duckdb); library(data.table)})
con <- dbConnect(duckdb()); S <- gsub("\\\\", "/", Sys.getenv("S"))
d <- readRDS(file.path(S, "stage2.rds"))
cases <- d[TYPE %in% c("merger2", "mergerN", "mergerN_new_entity", "asset_transfer", "closure") & !is.na(RECIP_EIN2) & R_IN_EFILE %in% TRUE & TAX_YEAR <= 2021]
eins <- unique(c(cases$EIN2, cases$RECIP_EIN2))
dbWriteTable(con, "eins", data.frame(EIN2 = eins))
p7 <- as.data.table(dbGetQuery(con, sprintf("select p.EIN2, cast(p.TAX_YEAR as int) TAX_YEAR, p.F9_07_COMP_DTK_NAME_PERS NM, p.F9_07_COMP_DTK_TITLE TITLE,
   p.F9_07_COMP_DTK_COMP_ORG COMP, p.F9_07_COMP_DTK_POS_OFF_X IS_OFF, p.F9_07_COMP_DTK_POS_KEY_EMPL_X IS_KEY, p.F9_07_COMP_DTK_POS_INDIV_TRUST_X TRUSTEE
   from read_parquet('%s/data/*/F9-P07-T01-COMPENSATION-*.parquet') p join eins using (EIN2)", S)))
cat("P07 rows for case EINs:", nrow(p7), "\n")
norm <- function(x) { x <- toupper(gsub("[^A-Za-z ]", " ", x)); x <- gsub("\\b(MR|MRS|MS|DR|JR|SR|II|III|IV|MD|PHD|ESQ|CPA|REV)\\b", " ", x)
  w <- strsplit(trimws(gsub(" +", " ", x)), " "); vapply(w, function(z) if (length(z) < 2) NA_character_ else paste(z[1], z[length(z)]), "") }
p7[, KEYNM := norm(NM)]
p7 <- p7[!is.na(KEYNM)]
res <- cases[, {
  dn <- p7[EIN2 == .BY$EIN2 & TAX_YEAR %in% (.BY$TAX_YEAR - 1):.BY$TAX_YEAR, unique(KEYNM)]
  rn <- p7[EIN2 == .BY$RECIP_EIN2 & TAX_YEAR %in% .BY$TAX_YEAR:(.BY$TAX_YEAR + 1), unique(KEYNM)]
  .(N_DONOR_P7 = length(dn), N_RECIP_P7 = length(rn), N_SHARED = length(intersect(dn, rn)))
}, by = .(EIN2, RECIP_EIN2, TAX_YEAR, TYPE, LEADER)]
cat("\nPart VII overlap (donor t-1..t vs recipient t..t+1), cases with both sides observed:\n")
print(res[N_DONOR_P7 > 0 & N_RECIP_P7 > 0, .(n = .N, any_shared = round(mean(N_SHARED > 0), 3), med_shared = as.numeric(median(N_SHARED))), by = .(TYPE, LEADER)][order(TYPE)])
cat("\nObservability: share of cases with donor P07 / recipient P07 present:\n")
print(res[, .(n = .N, donor_p7 = round(mean(N_DONOR_P7 > 0), 2), recip_p7 = round(mean(N_RECIP_P7 > 0), 2)), by = TYPE])
saveRDS(res, file.path(S, "p7overlap.rds"))
