# Build the blind hand-labeling sample for classifier validation (plan step 2).
#
# Draws 50 Schedule N filings per classifier label from the filings that have
# narrative text (Schedule N Part III, or Schedule O sentences about
# dissolution/merger/transfer), and writes one text packet per case without
# the classifier's label. Labelers follow codebook.md.
#
# Env: CACHE = panel990 data cache (the year folders), OUT = folder holding
# merger_data.rds from dev/run-all-years.R. Writes to OUT/val/.

library(data.table)
cache <- Sys.getenv("CACHE"); out <- Sys.getenv("OUT")
val <- file.path(out, "val"); dir.create(val, showWarnings = FALSE)
con <- DBI::dbConnect(duckdb::duckdb())
q <- function(s) as.data.table(DBI::dbGetQuery(con, s))
pq <- function(t) sprintf("read_parquet('%s/*/%s-*.parquet', union_by_name=true)", cache, t)

md <- readRDS(file.path(out, "merger_data.rds"))
sn <- as.data.table(md$sched_n); tx <- as.data.table(md$transactions)
duckdb::duckdb_register(con, "ids", sn[, list(OBJECTID)])

p3 <- q(sprintf("select OBJECTID, SN_03_EXPLANATION_TEXT as TXT, SN_03_FORM_LINE_REFERENCE as REF from %s",
                pq("SN-P03-T99-SUPPLEMENTAL-INFO")))
p3 <- p3[!is.na(TXT) & nchar(TXT) > 20]
pat <- "(?i)(dissol|merg|consolidat|terminat|liquidat|wind|ceas|transfer|successor|acqui|combin|absorb|affiliat|sold|sale of)"
so <- q(sprintf("select s.OBJECTID, s.SO_00_EXPLANATION_TEXT as TXT from %s s join ids using (OBJECTID) where regexp_matches(s.SO_00_EXPLANATION_TEXT, '%s')",
                pq("SO-P00-T99-SUPPLEMENTAL-INFO"), pat))

sn[, HAS_TEXT := OBJECTID %in% p3$OBJECTID | OBJECTID %in% so$OBJECTID]
print(sn[, list(N = .N, with_text = round(100 * mean(HAS_TEXT))), by = TYPE])

set.seed(20261120)
smp <- sn[HAS_TEXT == TRUE, .SD[sample(.N, min(.N, 50L))], by = TYPE][sample(.N)]
smp[, CASE := sprintf("C%03d", .I)][, BATCH := rep(1:6, length.out = .N)]
duckdb::duckdb_register(con, "smp", smp[, list(OBJECTID)])
nm <- q(sprintf("select distinct OBJECTID, ORG_NAME_L1, RETURN_TYPE from read_parquet(['%1$s/*/SN-P01-T0*-*.parquet','%1$s/*/SN-P02-T0*-*.parquet'], union_by_name=true) join smp using (OBJECTID)", cache))
smp <- merge(smp, nm[!duplicated(OBJECTID)], by = "OBJECTID", all.x = TRUE, sort = FALSE)

or_ <- function(a, b) ifelse(is.na(a), b, a)
cut <- function(x, n) ifelse(nchar(x) > n, paste0(substr(x, 1, n), " [...]"), x)
fmt <- function(v) ifelse(is.na(v), "NA", format(round(v), big.mark = ",", scientific = FALSE))
packet <- function(r) {
  l <- tx[OBJECTID == r$OBJECTID]
  lines <- if (nrow(l)) sprintf("  - Part %s | to: %s | EIN %s | %s | IRC: %s | FMV %s | desc: %s",
                                ifelse(l$PART == 1, "I", "II"), or_(l$RECIP_NAME, ""), ifelse(is.na(l$RECIP_EIN), "missing", "given"),
                                l$RECIP_STATE, l$IRC_SECTION, fmt(l$FMV), cut(l$ASSET_DESC, 160)) else "  (none)"
  if (length(lines) > 12) lines <- c(lines[1:12], sprintf("  ... and %d more lines", length(lines) - 12))
  t3 <- p3[OBJECTID == r$OBJECTID]
  t3 <- if (nrow(t3)) cut(paste(paste0("[", or_(t3$REF, ""), "] ", t3$TXT), collapse = " | "), 1800) else "(none)"
  ts <- so[OBJECTID == r$OBJECTID]$TXT
  ts <- if (length(ts)) {
    seg <- unlist(strsplit(ts, "(?<=[.;])\\s+", perl = TRUE))
    cut(paste(cut(unique(seg[grepl(pat, seg, perl = TRUE)]), 350), collapse = " ... "), 1200)
  } else "(none)"
  sprintf(paste0("=== %s ===\nOrganization: %s | Form %s | Tax year %s | Final return box: %s\n",
                 "Schedule N filed: Part I (liquidation/termination) = %s; Part II (disposition of >25%% of assets, org continues) = %s\n",
                 "Asset distribution lines:\n%s\nSchedule N Part III text: %s\nSchedule O excerpts (keyword sentences): %s\n"),
          r$CASE, r$ORG_NAME_L1, r$RETURN_TYPE, r$TAX_YEAR, r$FINAL_RETURN, r$HAS_P1, r$HAS_P2,
          paste(lines, collapse = "\n"), t3, ts)
}
for (b in 1:6) {
  rows <- smp[BATCH == b][order(CASE)]
  writeLines(vapply(seq_len(nrow(rows)), function(i) packet(rows[i]), ""), file.path(val, sprintf("batch%d.txt", b)), useBytes = TRUE)
}
fwrite(smp[, list(CASE, BATCH, OBJECTID, EIN2, TAX_YEAR, TYPE, BASIS)], file.path(val, "key.csv"))
