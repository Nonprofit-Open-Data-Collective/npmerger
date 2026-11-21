# Descriptives on the full-years merger data.
# Env vars: OUT (directory holding merger_data.rds from dev/run-all-years.R).
suppressMessages({devtools::load_all(quiet = TRUE); library(data.table)})
OUT <- Sys.getenv("OUT", "npmerger-out")
md <- readRDS(file.path(OUT, "merger_data.rds"))
cs <- md$cases; dn <- md$donors; rc <- md$recipients; p7 <- md$part7; tv <- md$transfers
q <- function(x, p = c(.25, .5, .75)) round(quantile(x, p, na.rm = TRUE))
summ <- function(x) { x <- x[is.finite(x)]; c(n = length(x), mean = round(mean(x)), trim5 = round(mean(x, trim = .05)), p25 = round(quantile(x, .25)),
                                             median = round(median(x)), p75 = round(quantile(x, .75))) }
res <- list()

cat("== Coverage ==\n")
cat("merger cases:", nrow(cs), " groups:", uniqueN(cs$MERGER_GROUP_ID), " years:", paste(range(cs$MERGER_YEAR), collapse = "-"), "\n")
print(cs[, .N, by = TYPE])

# --- 1-3. size of closing and recipient orgs (t-1), and the size gap
a <- merge(dn[, .(MERGER_ID, D_REV = REVENUE_TM1, D_EXP = EXPENSES_TM1, D_AST = ASSETS_TM1)],
           rc[, .(MERGER_ID, R_REV = REVENUE_TM1, R_EXP = EXPENSES_TM1, R_AST = ASSETS_TM1)], by = "MERGER_ID")
a <- merge(a, cs[, .(MERGER_ID, TYPE, AFFILIATED, N_GROUP)], by = "MERGER_ID")
cat("\n== 1. Closing (donor) org size, year t-1 ==\n")
s1 <- rbind(revenue = summ(a$D_REV), expenses = summ(a$D_EXP), assets = summ(a$D_AST)); print(s1)
cat("\n== 2. Recipient org size, year t-1 ==\n")
s2 <- rbind(revenue = summ(a$R_REV), expenses = summ(a$R_EXP), assets = summ(a$R_AST)); print(s2)
a[, `:=`(RATIO_REV = fifelse(D_REV > 0, R_REV / D_REV, NA_real_), RATIO_AST = fifelse(D_AST > 0, R_AST / D_AST, NA_real_))]
cat("\n== 3. Size gap: recipient / donor (t-1) ==\n")
gap <- rbind(revenue = round(quantile(a$RATIO_REV, c(.1, .25, .5, .75, .9), na.rm = TRUE), 1),
             assets = round(quantile(a$RATIO_AST, c(.1, .25, .5, .75, .9), na.rm = TRUE), 1)); print(gap)
cat("recipient larger by revenue:", round(mean(a$R_REV > a$D_REV, na.rm = TRUE), 3),
    "| >10x:", round(mean(a$RATIO_REV > 10, na.rm = TRUE), 3), "| >100x:", round(mean(a$RATIO_REV > 100, na.rm = TRUE), 3), "\n")
cat("by type and affiliation (median revenue ratio):\n")
print(a[, .(n = .N, donor_rev = median(D_REV, na.rm = TRUE), recip_rev = median(R_REV, na.rm = TRUE),
            ratio = round(median(RATIO_REV, na.rm = TRUE), 1)), by = .(TYPE, AFFILIATED)][order(TYPE, AFFILIATED)])

# --- 4. multi-org mergers
cat("\n== 4. Multi-organization mergers ==\n")
g <- cs[, .(N_GROUP = N_GROUP[1], TYPE = TYPE[1]), by = MERGER_GROUP_ID]
cat("share of merger cases (donors) in groups of 2+:", round(mean(cs$N_GROUP >= 2), 3),
    "| share of merger events (groups) with 2+ donors:", round(mean(g$N_GROUP >= 2), 3), "\n")
print(g[, .N, by = .(donors = pmin(N_GROUP, 6L))][order(donors)][, pct := round(100 * N / sum(N), 1)][])
cat("consolidations into a new entity: events", g[TYPE == "consolidation", .N], "| donors", cs[TYPE == "consolidation", .N], "\n")
cat("multi-org share by year:\n"); print(cs[, .(cases = .N, multi = round(mean(N_GROUP >= 2), 3)), by = MERGER_YEAR][order(MERGER_YEAR)])

# --- 5. Part VII individuals joining the recipient
cat("\n== 5. Part VII individuals joining the recipient ==\n")
p <- p7[!is.na(PERSON_KEY)]
don <- unique(p[ROLE == "donor" & TIME_FROM_MERGER <= 0, .(MERGER_ID, PERSON_KEY)])
rpre <- unique(p[ROLE == "recipient" & TIME_FROM_MERGER < 0, .(MERGER_ID, PERSON_KEY)])
rpost <- unique(p[ROLE == "recipient" & TIME_FROM_MERGER >= 0, .(MERGER_ID, PERSON_KEY)])
both_post <- merge(don, rpost, by = c("MERGER_ID", "PERSON_KEY"))
before <- merge(both_post, rpre, by = c("MERGER_ID", "PERSON_KEY"))
joiners <- fsetdiff(both_post, before)
obs <- intersect(unique(don$MERGER_ID), unique(rpost$MERGER_ID))   # both rosters observed
pj <- data.table(MERGER_ID = obs)
pj <- merge(pj, don[, .(DONOR_ROSTER = .N), by = MERGER_ID], by = "MERGER_ID", all.x = TRUE)
pj <- merge(pj, joiners[, .(JOINERS = .N), by = MERGER_ID], by = "MERGER_ID", all.x = TRUE)
pj <- merge(pj, before[, .(ALREADY_SHARED = .N), by = MERGER_ID], by = "MERGER_ID", all.x = TRUE)
for (v in c("JOINERS", "ALREADY_SHARED")) pj[is.na(get(v)), (v) := 0L]
pj <- merge(pj, cs[, .(MERGER_ID, TYPE, AFFILIATED, BASIS)], by = "MERGER_ID")
cat("mergers with both rosters observed:", nrow(pj), "of", nrow(cs), "\n")
cat("joiners per merger: mean", round(mean(pj$JOINERS), 2), "| median", median(pj$JOINERS),
    "| share with >=1 joiner", round(mean(pj$JOINERS >= 1), 3), "\n")
cat("share of donor roster that joins: mean", round(mean(pj$JOINERS / pj$DONOR_ROSTER), 3), "| median donor roster", median(pj$DONOR_ROSTER), "\n")
cat("people already on both rosters before the merger (interlocks): mean", round(mean(pj$ALREADY_SHARED), 2),
    "| share of mergers with any", round(mean(pj$ALREADY_SHARED >= 1), 3), "\n")
print(table(joiners = pmin(pj$JOINERS, 10L)))
print(pj[, .(n = .N, mean_joiners = round(mean(JOINERS), 2), any_joiner = round(mean(JOINERS >= 1), 3),
             mean_interlocks = round(mean(ALREADY_SHARED), 2)), by = .(TYPE, AFFILIATED)][order(TYPE, AFFILIATED)])

# --- 6. Does the donor's CEO join?
cat("\n== 6. Donor CEO / executive director joins the recipient ==\n")
ceo_pat <- "CEO|CHIEF EXEC|EXECUTIVE DIRECTOR|EXEC\\.? DIR|EXECUTIVE DIR|PRESIDENT\\s*(&|AND|/)\\s*C|PRES\\s*(&|/)\\s*CEO|ADMINISTRATOR|SUPERINTENDENT"
dr <- p[ROLE == "donor" & TIME_FROM_MERGER <= 0]
dr[, LAST := TIME_FROM_MERGER == max(TIME_FROM_MERGER), by = MERGER_ID]
dr <- dr[LAST == TRUE]
dr[, IS_CEO := grepl(ceo_pat, toupper(TITLE)) & !grepl("BOARD|ASSISTANT|ASSOC|DEPUTY|VICE|FORMER", toupper(TITLE)) & !FORMER %in% TRUE]
ceo <- dr[IS_CEO == TRUE][order(MERGER_ID, -fcoalesce(COMP_ORG, 0))][, .SD[1], by = MERGER_ID][, .(MERGER_ID, PERSON_KEY, TITLE, BY = "title")]
fb <- dr[!MERGER_ID %in% ceo$MERGER_ID & (OFFICER %in% TRUE | KEY_EMPLOYEE %in% TRUE) & fcoalesce(COMP_ORG, 0) > 0][
  order(MERGER_ID, -COMP_ORG)][, .SD[1], by = MERGER_ID][, .(MERGER_ID, PERSON_KEY, TITLE, BY = "highest_paid")]
ceo <- rbind(ceo, fb)
ceo <- ceo[MERGER_ID %in% obs]
post <- p[ROLE == "recipient" & TIME_FROM_MERGER >= 0, .(MERGER_ID, PERSON_KEY, R_TITLE = TITLE, TIME_FROM_MERGER)]
cj <- merge(ceo, post[order(TIME_FROM_MERGER)][, .SD[1], by = .(MERGER_ID, PERSON_KEY)], by = c("MERGER_ID", "PERSON_KEY"), all.x = TRUE)
cj[, JOINED := !is.na(R_TITLE)]
cj[, R_ROLE := fcase(!JOINED, NA_character_,
                     grepl(ceo_pat, toupper(R_TITLE)) & !grepl("BOARD|ASSISTANT|DEPUTY|VICE", toupper(R_TITLE)), "CEO/ED",
                     grepl("VICE|VP|CHIEF|DIRECTOR OF|DIRECTOR,|MANAGER|OFFICER|TREAS|SECRET|CFO|COO", toupper(R_TITLE)), "other officer/staff",
                     grepl("DIRECTOR|TRUSTEE|BOARD|MEMBER|CHAIR", toupper(R_TITLE)), "board",
                     default = "other")]
cj <- merge(cj, cs[, .(MERGER_ID, TYPE, AFFILIATED)], by = "MERGER_ID")
cat("mergers with an identifiable donor CEO/ED:", nrow(cj), "of", length(obs), "with both rosters (",
    round(100 * mean(cj$BY == "title"), 1), "% by title, rest highest-paid officer)\n")
cat("donor CEO appears at recipient after merger:", round(mean(cj$JOINED), 3), "\n")
print(cj[JOINED == TRUE, .N, by = R_ROLE][, pct := round(100 * N / sum(N), 1)][order(-N)])
print(cj[, .(n = .N, ceo_joins = round(mean(JOINED), 3)), by = .(TYPE, AFFILIATED)][order(TYPE, AFFILIATED)])

# --- 7. size of asset transfers and share of recipient assets
cat("\n== 7. Asset transfers ==\n")
t7 <- merge(tv[, .(MERGER_ID, FMV_ASSETS, FMV_TOTAL, COVERAGE, FLAG_OUTLIER)], a[, .(MERGER_ID, R_AST, D_AST, TYPE, AFFILIATED)], by = "MERGER_ID")
ok <- t7[!FLAG_OUTLIER %in% TRUE & FMV_ASSETS > 0]
cat("transfers with positive value, not flagged:", nrow(ok), "of", nrow(t7), " (flagged outliers:", sum(t7$FLAG_OUTLIER, na.rm = TRUE), ")\n")
print(rbind(FMV_ASSETS = summ(ok$FMV_ASSETS)))
cat("total transferred ($bn):", round(sum(ok$FMV_ASSETS) / 1e9, 1), "\n")
cat("transfer / donor t-1 assets (coverage) median:", round(median(ok$COVERAGE, na.rm = TRUE), 2), "\n")
ok[, SHARE_RECIP := fifelse(R_AST > 0, FMV_ASSETS / R_AST, NA_real_)]
cat("transfer as share of recipient t-1 assets: median", round(median(ok$SHARE_RECIP, na.rm = TRUE), 3),
    "| mean (trimmed 5%)", round(mean(ok$SHARE_RECIP, trim = .05, na.rm = TRUE), 3), "| n", sum(!is.na(ok$SHARE_RECIP)), "\n")
print(ok[!is.na(SHARE_RECIP), .N, by = .(share = cut(SHARE_RECIP, c(0, .01, .05, .1, .25, .5, 1, Inf), right = FALSE))][order(share)][, pct := round(100 * N / sum(N), 1)][])
print(ok[, .(n = .N, median_fmv = round(median(FMV_ASSETS)), median_share = round(median(SHARE_RECIP, na.rm = TRUE), 3)), by = .(TYPE, AFFILIATED)][order(TYPE, AFFILIATED)])

fwrite(pj, file.path(OUT, "desc_part7_joiners.csv")); fwrite(cj, file.path(OUT, "desc_ceo.csv")); fwrite(ok, file.path(OUT, "desc_transfers.csv")); fwrite(a, file.path(OUT, "desc_sizes.csv"))
