suppressMessages({library(panel990); library(data.table)})
S <- Sys.getenv("S")
d <- readRDS(file.path(S, "stage3.rds"))
m <- d[TYPE2 %in% c("merger2", "mergerN") & !is.na(RECIP_EIN2)]
set.seed(7); m <- m[sample(.N, min(.N, 400))]
eins <- unique(c(m$EIN2, m$RECIP_EIN2)); cat("EINs:", length(eins), "\n")
t0 <- Sys.time()
p <- panelize(tables = c("P00", "P01", "P08", "P09", "P10"), years = 2018:2023,
              filters = list(EIN2 = eins), backend = "duckdb", cache = "none",
              unique_rows = FALSE, bmf = FALSE, verbose = FALSE)
cat("panelize time:", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s\n")
pd <- as.data.table(panel_data(p)); cat("panel rows:", nrow(pd), " cols:", ncol(pd), " orgs:", uniqueN(pd$EIN2), "\n")
print(table(pd$TAX_YEAR))
saveRDS(list(panel = pd, cases = m), file.path(S, "merger_panel.rds"))
