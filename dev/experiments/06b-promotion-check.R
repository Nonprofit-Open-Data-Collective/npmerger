suppressMessages({library(duckdb); library(data.table)})
con <- dbConnect(duckdb()); S <- gsub("\\\\", "/", Sys.getenv("S"))
q <- function(sql) as.data.table(dbGetQuery(con, sql))
pq <- function(t, yrs = "*") sprintf("read_parquet('%s/data/%s/%s-*.parquet', union_by_name=true)", S, yrs, t)
fx <- function(x) tolower(trimws(x)) %in% c("1", "true", "x")
d <- readRDS(file.path(S, "stage3.rds"))[TAX_YEAR == 2021]   # Schedule O only downloaded for 2021
so <- q(sprintf("select EIN2, cast(TAX_YEAR as int) TAX_YEAR, SO_00_EXPLANATION_TEXT TXT from %s", pq("SO-P00-T99-SUPPLEMENTAL-INFO", "2021")))
mg <- unique(so[grepl("merge|merger|consolidat|combin|acquir|affiliat", TXT, ignore.case = TRUE), .(EIN2, TAX_YEAR)])
p6 <- q(sprintf("select EIN2, cast(TAX_YEAR as int) TAX_YEAR, F9_06_GVRN_CHANGE_DOC_X CHG from %s", pq("F9-P06-T00-GOVERNANCE")))
p6 <- p6[, .(CHG = any(fx(CHG))), by = .(EIN2, TAX_YEAR)]
d[, SO_D := paste(EIN2, TAX_YEAR) %in% mg[, paste(EIN2, TAX_YEAR)]]
d[, SO_R := paste(RECIP_EIN2, TAX_YEAR) %in% mg[, paste(EIN2, TAX_YEAR)]]
d[, GOV_R := paste(RECIP_EIN2, TAX_YEAR) %in% p6[CHG == TRUE, paste(EIN2, TAX_YEAR)] |
             paste(RECIP_EIN2, TAX_YEAR + 1) %in% p6[CHG == TRUE, paste(EIN2, TAX_YEAR)]]
d[, NCORR := SO_D + SO_R + GOV_R]
cat("2021 asset_transfer by number of corroborating signals:\n"); print(d[TYPE2 == "asset_transfer", .N, by = NCORR][order(NCORR)])
d[, GRP := fcase(TYPE2 == "asset_transfer" & NCORR >= 2, "promoted (>=2)",
                 TYPE2 == "asset_transfer" & NCORR == 1, "transfer, 1 signal",
                 TYPE2 == "asset_transfer", "transfer, 0 signals",
                 default = TYPE2)]
cat("\nValidation (signals not used by the rule):\n")
print(d[, .(n = .N, assets_gone = round(mean(ASSETS_GONE, na.rm = TRUE), 2), med_cover = round(median(COVER, na.rm = TRUE), 2),
            med_donor_rev = median(REV, na.rm = TRUE), affiliated_p7_shared = round(mean(N_SHARED > 0, na.rm = TRUE), 2)), by = GRP][order(-n)])
cat("\nIf single strong signal counted (donor SO text alone):", d[TYPE2 == "asset_transfer" & SO_D, .N], "\n")
