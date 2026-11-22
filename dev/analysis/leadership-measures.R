# Leadership and board outcomes for each merger case, from the Part VII
# panel (md$part7: donor and recipient rosters, t-2..t+2 on each
# organization's own calendar).
#
# CEO (one per organization):
#   * Title matches CEO / executive director / president & CEO /
#     administrator / superintendent (not deputy, vice, assistant, board, or
#     former); the highest-paid such person if several.
#   * Otherwise the highest-paid officer or key employee with pay > 0.
#   * Donor CEO: on the donor's last roster at or before t0.
#   * Recipient CEO: on the recipient's last roster before t0 (t-1, else t-2).
#   * "Remains" = the person appears anywhere on the recipient's roster at
#     t+1 or t+2. R_CEO_STILL_CEO records whether the recipient's CEO still
#     holds a CEO title there.
#   CEO_CAT:
#     recipient_ceo_only  recipient CEO remains; donor CEO does not join
#     both_ceos           both remain at the recipient
#     donor_ceo_only      donor CEO joins; recipient CEO leaves
#     neither             both gone
#     shared_ceo          the same person led both before the merger, or the
#                         donor CEO was already on the recipient's roster
#
# Board (governing roster = trustees and officers, plus 990-EZ listings,
# which have no position flags; excludes key employees and highest-paid
# staff who are not trustees or officers, and former officers):
#   * R_PRE: recipient roster at t-1 (else t-2); R_POST: at t+1 (else t+2);
#     D_PRE: donor's last roster at or before t0.
#   * BOARD_RETAIN   share of R_PRE still on R_POST.
#   * DONOR_JOINERS  donor members on R_POST who were not on R_PRE
#                    (pre-merger interlocks do not count).
#   * DONOR_SEAT_SHARE  DONOR_JOINERS / size of R_POST.
#   BOARD_CAT:
#     intact_donor_dissolves  BOARD_RETAIN >= 0.5 and no donor joiners
#     combine_minor           BOARD_RETAIN >= 0.5, joiners hold < 20% of seats
#     combine_major           BOARD_RETAIN >= 0.5, joiners hold >= 20% of seats
#     recipient_turnover      BOARD_RETAIN < 0.5
#
# Output: ROOT/analysis/leadership.rds (one row per MERGER_ID)

library(data.table)
root <- Sys.getenv("ROOT", file.path(Sys.getenv("USERPROFILE", path.expand("~")), "Documents", "NPMERGER"))
out_dir <- file.path(root, "analysis"); dir.create(out_dir, showWarnings = FALSE)
md <- readRDS(file.path(root, "merger_data.rds"))
p  <- as.data.table(md$part7)[!is.na(PERSON_KEY)]
p[, UT := toupper(fcoalesce(TITLE, ""))]
f <- function(v) v %in% TRUE

ceo_pat <- "CEO|CHIEF EXEC|EXECUTIVE DIRECTOR|EXEC\\.? DIR|EXECUTIVE DIR|PRESIDENT\\s*(&|AND|/)\\s*C|PRES\\s*(&|/)\\s*CEO|ADMINISTRATOR|SUPERINTENDENT"
not_ceo <- "BOARD|ASSISTANT|ASSOC|DEPUTY|VICE|FORMER"
p[, IS_CEO_TITLE := grepl(ceo_pat, UT) & !grepl(not_ceo, UT) & !f(FORMER)]
p[, GOV := !f(FORMER) & (f(TRUSTEE) | f(OFFICER) | !(f(KEY_EMPLOYEE) | f(HIGH_COMP)))]

# rosters at the chosen years
last_year <- function(x, cond) x[cond][, .SD[TIME_FROM_MERGER == max(TIME_FROM_MERGER)], by = MERGER_ID]
first_year <- function(x, cond) x[cond][, .SD[TIME_FROM_MERGER == min(TIME_FROM_MERGER)], by = MERGER_ID]
d_last <- last_year(p, p$ROLE == "donor" & p$TIME_FROM_MERGER <= 0)
r_pre  <- last_year(p, p$ROLE == "recipient" & p$TIME_FROM_MERGER < 0)
r_post <- first_year(p, p$ROLE == "recipient" & p$TIME_FROM_MERGER >= 1)
r_pre_all  <- unique(p[ROLE == "recipient" & TIME_FROM_MERGER < 0, list(MERGER_ID, PERSON_KEY)])
r_post_all <- unique(p[ROLE == "recipient" & TIME_FROM_MERGER >= 1, list(MERGER_ID, PERSON_KEY, UT)])

pick_ceo <- function(x) {
  a <- x[IS_CEO_TITLE == TRUE][order(MERGER_ID, -fcoalesce(COMP_ORG, 0))][, .SD[1], by = MERGER_ID][
    , list(MERGER_ID, PERSON_KEY, BY = "title")]
  b <- x[!MERGER_ID %in% a$MERGER_ID & (f(OFFICER) | f(KEY_EMPLOYEE)) & fcoalesce(COMP_ORG, 0) > 0][
    order(MERGER_ID, -COMP_ORG)][, .SD[1], by = MERGER_ID][, list(MERGER_ID, PERSON_KEY, BY = "highest_paid")]
  rbind(a, b)
}
dc <- pick_ceo(d_last); setnames(dc, c("PERSON_KEY", "BY"), c("D_CEO", "D_CEO_BY"))
rc <- pick_ceo(r_pre);  setnames(rc, c("PERSON_KEY", "BY"), c("R_CEO", "R_CEO_BY"))

obs <- Reduce(intersect, list(unique(d_last$MERGER_ID), unique(r_pre$MERGER_ID), unique(r_post$MERGER_ID)))
L <- data.table(MERGER_ID = obs)
L <- merge(merge(L, dc, by = "MERGER_ID", all.x = TRUE), rc, by = "MERGER_ID", all.x = TRUE)
on_post <- function(id, key) paste(id, key) %in% r_post_all[, paste(MERGER_ID, PERSON_KEY)]
L[, `:=`(R_CEO_REMAINS = on_post(MERGER_ID, R_CEO), D_CEO_JOINS = on_post(MERGER_ID, D_CEO),
         D_CEO_ON_R_PRE = paste(MERGER_ID, D_CEO) %in% r_pre_all[, paste(MERGER_ID, PERSON_KEY)])]
ceo_post <- r_post_all[grepl(ceo_pat, UT) & !grepl(not_ceo, UT), unique(paste(MERGER_ID, PERSON_KEY))]
L[, R_CEO_STILL_CEO := paste(MERGER_ID, R_CEO) %in% ceo_post]
L[, CEO_CAT := fcase(is.na(D_CEO) | is.na(R_CEO), NA_character_,
                     D_CEO == R_CEO | D_CEO_ON_R_PRE, "shared_ceo",
                     R_CEO_REMAINS & !D_CEO_JOINS, "recipient_ceo_only",
                     R_CEO_REMAINS & D_CEO_JOINS, "both_ceos",
                     !R_CEO_REMAINS & D_CEO_JOINS, "donor_ceo_only",
                     default = "neither")]

# boards
gov <- function(x) unique(x[GOV == TRUE, list(MERGER_ID, PERSON_KEY)])
bp <- gov(r_pre); bq <- gov(r_post); bd <- gov(d_last)
key <- function(x) paste(x$MERGER_ID, x$PERSON_KEY)
B <- data.table(MERGER_ID = obs)
B <- merge(B, bp[, list(R_BOARD_PRE = .N), by = MERGER_ID], all.x = TRUE)
B <- merge(B, bq[, list(R_BOARD_POST = .N), by = MERGER_ID], all.x = TRUE)
B <- merge(B, bd[, list(D_BOARD = .N), by = MERGER_ID], all.x = TRUE)
B <- merge(B, bp[key(bp) %in% key(bq), list(RETAINED = .N), by = MERGER_ID], all.x = TRUE)
B <- merge(B, bd[key(bd) %in% key(bq) & !key(bd) %in% key(bp), list(DONOR_JOINERS = .N), by = MERGER_ID], all.x = TRUE)
B <- merge(B, bd[key(bd) %in% key(bp), list(INTERLOCKS = .N), by = MERGER_ID], all.x = TRUE)
for (v in c("RETAINED", "DONOR_JOINERS", "INTERLOCKS")) B[is.na(get(v)), (v) := 0L]
B[, `:=`(BOARD_RETAIN = RETAINED / R_BOARD_PRE, DONOR_SEAT_SHARE = DONOR_JOINERS / R_BOARD_POST,
         DONOR_JOIN_SHARE = DONOR_JOINERS / D_BOARD)]
B[, BOARD_CAT := fcase(is.na(R_BOARD_PRE) | is.na(R_BOARD_POST) | is.na(D_BOARD), NA_character_,
                       BOARD_RETAIN < 0.5, "recipient_turnover",
                       DONOR_JOINERS == 0, "intact_donor_dissolves",
                       DONOR_SEAT_SHARE < 0.2, "combine_minor",
                       default = "combine_major")]

L <- merge(L, B, by = "MERGER_ID", all = TRUE)
saveRDS(L, file.path(out_dir, "leadership.rds"))
fwrite(L, file.path(out_dir, "leadership.csv"))
cat("cases with donor, recipient-pre and recipient-post rosters:", length(obs), "\n")
print(L[, .N, by = CEO_CAT][order(CEO_CAT)][, pct := round(100 * N / sum(N), 1)][])
print(L[, .N, by = BOARD_CAT][order(BOARD_CAT)][, pct := round(100 * N / sum(N), 1)][])
print(L[!is.na(CEO_CAT), table(CEO_CAT, BOARD_CAT, useNA = "ifany")])
cat("recipient CEO who remains still holds a CEO title:", round(L[R_CEO_REMAINS == TRUE & !is.na(R_CEO), mean(R_CEO_STILL_CEO)], 3), "\n")
