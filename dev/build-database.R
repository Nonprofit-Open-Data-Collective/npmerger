# Build the full npmerger database: every Schedule N year in the e-file
# release, all output tables, written as a DuckDB database plus one Parquet
# file per table, with a README listing the tables.
#
# Env vars:
#   ROOT   database folder (default ~/Documents/NPMERGER)
#   CACHE  panel990 data cache (default ROOT/PANEL990; downloaded if missing)
#   YEARS  Schedule N years, e.g. "2009:2025" (default efile_years())
#   MD_RDS optional saved merger_data .rds to write out instead of rebuilding
#
# Layout written under ROOT:
#   npmerger.duckdb        one table per output, plus build_info
#   parquet/<table>.parquet
#   merger_data.rds        the merger_data object from build_merger_data()
#   README.md              tables, row counts, and build settings
#   build.log              (when run with output redirected)

devtools::load_all(quiet = TRUE)
library(data.table)
root  <- Sys.getenv("ROOT", file.path(Sys.getenv("USERPROFILE", path.expand("~")), "Documents", "NPMERGER"))
cache <- Sys.getenv("CACHE", file.path(root, "PANEL990"))
yrs   <- Sys.getenv("YEARS", "")
years <- if (nzchar(yrs)) eval(parse(text = yrs)) else efile_years()
dir.create(file.path(root, "parquet"), showWarnings = FALSE, recursive = TRUE)

t0 <- Sys.time()
# MD_RDS: reuse a saved merger_data object instead of running the pipeline.
md <- if (nzchar(Sys.getenv("MD_RDS"))) readRDS(Sys.getenv("MD_RDS")) else
  build_merger_data(years, path = cache, ratios = TRUE, verbose = TRUE)
mins <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
cat("\nrun time:", mins, "min\n"); print(md)
saveRDS(md, file.path(root, "merger_data.rds"))

tables <- c(
  sched_n      = "One row per Schedule N filing: label (TYPE), evidence basis, and every evidence column.",
  transactions = "One row per Schedule N asset line (Parts I and II), cleaned, with recipient type and EIN source.",
  cases        = "One row per donor-recipient merger pair: MERGER_ID (YEAR-FROMEIN-TOEIN), group ID, type, evidence.",
  transfers    = "Value transferred per merger case, by asset class, with coverage of donor assets and outlier flags.",
  donors       = "Donor attributes: name, address, age, NTEE, and revenue/expenses/assets for t0 and the four prior years.",
  recipients   = "Recipient attributes, same layout as donors.",
  part7        = "Part VII people for donor and recipient, years t-2..t+2, with IN_BOTH.",
  fiscal       = "Fiscal panel: donor years up to the merger, recipient years before and after, measures and 'fiscal' ratios.",
  labels       = "Label definitions.",
  manifest     = "Inputs used: tables, years, and row counts."
)
git <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_)
rules <- unclass(merger_rules())
info <- data.table(item = c("built", "schedule_n_years", "npmerger_version", "git_commit", "panel990_version", "fiscal_version",
                           "run_minutes", names(rules)),
                   value = c(format(Sys.time(), "%Y-%m-%d %H:%M"), paste(range(years), collapse = "-"),
                             as.character(utils::packageVersion("npmerger")), git[1],
                             as.character(utils::packageVersion("panel990")), as.character(utils::packageVersion("fiscal")),
                             mins, vapply(rules, function(v) paste(v, collapse = ", "), "")))

dbf <- file.path(root, "npmerger.duckdb")
if (file.exists(dbf)) file.remove(dbf)
con <- DBI::dbConnect(duckdb::duckdb(), dbf)
counts <- integer()
for (nm in names(tables)) {
  x <- md[[nm]]
  if (is.null(x)) next
  x <- as.data.table(x)
  DBI::dbWriteTable(con, nm, as.data.frame(x), overwrite = TRUE)
  pq <- normalizePath(file.path(root, "parquet", paste0(nm, ".parquet")), winslash = "/", mustWork = FALSE)
  DBI::dbExecute(con, sprintf("COPY %s TO '%s' (FORMAT PARQUET, COMPRESSION ZSTD)", nm, pq))
  counts[nm] <- nrow(x)
  cat(sprintf("%-13s %10s rows %4d cols\n", nm, format(nrow(x), big.mark = ","), ncol(x)))
}
DBI::dbWriteTable(con, "build_info", as.data.frame(info), overwrite = TRUE)
DBI::dbDisconnect(con, shutdown = TRUE)

sn <- as.data.table(md$sched_n)
by_type <- sn[, .N, by = TYPE][order(-N)]
readme <- c(
  "# npmerger database", "",
  sprintf("Nonprofit mergers, asset transfers, and closures from IRS Form 990 Schedule N, tax years %s (NCCS e-file release).",
          paste(range(years), collapse = "-")),
  sprintf("Built %s with npmerger %s (commit %s), default `merger_rules()`. Run time %s minutes.",
          info[item == "built", value], info[item == "npmerger_version", value], git[1], mins), "",
  "2009 and the latest year are partial e-file years; filter on `TAX_YEAR` if you need complete years.", "",
  "## Files", "",
  "- `npmerger.duckdb`: every table below plus `build_info`. Open with `DBI::dbConnect(duckdb::duckdb(), \"npmerger.duckdb\", read_only = TRUE)`.",
  "- `parquet/`: the same tables, one Parquet file each.",
  "- `merger_data.rds`: the full `merger_data` object (`readRDS()`).",
  "- `PANEL990/`: the panel990 cache of e-file tables used to build it. Rebuilds reuse it.", "",
  "## Tables", "",
  "| table | rows | contents |", "|---|---|---|",
  sprintf("| `%s` | %s | %s |", names(counts), format(counts, big.mark = ","), tables[names(counts)]), "",
  "## Schedule N filings by type", "",
  "| type | filings |", "|---|---|",
  sprintf("| %s | %s |", by_type$TYPE, format(by_type$N, big.mark = ",")), "",
  "## Rebuild", "",
  "From the npmerger repository root:", "",
  "```", "Rscript dev/build-database.R > build.log 2>&1", "```", "",
  "Definitions and validation: PLAN.md in https://github.com/Nonprofit-Open-Data-Collective/npmerger")
writeLines(readme, file.path(root, "README.md"))
cat("\nWrote", root, "\n")
