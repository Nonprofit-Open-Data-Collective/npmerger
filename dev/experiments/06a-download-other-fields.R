library(panel990); p <- file.path(Sys.getenv("S"),"data")
t1 <- c("F9-P03-T00-MISSION","F9-P04-T00-REQUIRED-SCHEDULES","F9-P04-T00-REQUIRED-SCHEDULES-EZ","F9-P06-T00-GOVERNANCE","F9-P11-T00-ASSETS","F9-P12-T00-FINANCIAL-REPORTING","SA-P01-T00-PUBLIC-CHARITY-STATUS","SB-P01-T01-CONTRIBUTORS","SM-P01-T00-NONCASH-CONTRIBUTIONS","SR-P02-T01-ID-RLTD-TAX-EXEMPED-ORGS","SR-P05-T01-TRANSACTIONS-RLTD-ORGS")
d <- download_tables(years=2019:2022, tables=t1, path=p, verbose=FALSE); print(table(d$manifest$status))
d2 <- download_tables(years=2021, tables="SO-P00-T99-SUPPLEMENTAL-INFO", path=p, verbose=FALSE); print(table(d2$manifest$status))
