# Build Schedule N inspection tables for checking the classifier by hand,
# and save one 100-case table to data-dev/.
#
# Env vars:
#   ROOT   database folder with merger_data.rds (default ~/Documents/NPMERGER)
#   CACHE  panel990 cache (default ROOT/PANEL990)
#   NUM    number of tables (default 1)
#   N      cases per table (default 100)
#   SEED   random seed (default 2026)

devtools::load_all(quiet = TRUE)
library(data.table)
root  <- Sys.getenv("ROOT", file.path(Sys.getenv("USERPROFILE", path.expand("~")), "Documents", "NPMERGER"))
cache <- Sys.getenv("CACHE", file.path(root, "PANEL990"))
num   <- as.integer(Sys.getenv("NUM", "1"))
n     <- as.integer(Sys.getenv("N", "100"))
seed  <- as.integer(Sys.getenv("SEED", "2026"))

md  <- readRDS(file.path(root, "merger_data.rds"))
sn  <- get_schedule_n(efile_years(), path = cache, verbose = FALSE)
lab <- sn_labeled(sn, md$sched_n, md$cases, md$transactions)
tabs <- sn_inspection(lab, num = num, n = n, seed = seed)

dir.create("data-dev", showWarnings = FALSE)
for (i in seq_along(tabs)) {
  f <- file.path("data-dev", sprintf("sn-inspection-%02d.csv", i))
  fwrite(tabs[[i]], f)
  cat(sprintf("%s: %d cases, %d rows\n", f, uniqueN(tabs[[i]]$OBJECTID), nrow(tabs[[i]])))
  print(unique(tabs[[i]][, list(CASE, TYPE)])[, .N, by = TYPE])
}
