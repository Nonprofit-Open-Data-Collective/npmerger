# Donor size relative to recipient: paired-circle diagram.
#
# Each row is a group of mergers by the donor's baseline assets as a share of
# the recipient's (baseline = mean of t-3 and t-2, 2024 dollars). The
# recipient circle is fixed (100%); the donor circle's AREA is the group's
# median ratio. Labels give the count (share of the sample), and the median
# donor and recipient assets in the group.
#
# Sample: recipients in the analysis (recipient match, did_sample.rds) with a
# donor baseline. Run dev/analysis/did-recipients.R first.
# Output: ROOT/analysis/size_ratio_circles.png (suggested breaks),
#         size_ratio_circles_original.png (0-5-20-40-60-80-100% breaks),
#         size_ratio_groups.csv

library(data.table)
root <- Sys.getenv("ROOT", file.path(Sys.getenv("USERPROFILE", path.expand("~")), "Documents", "NPMERGER"))
a <- file.path(root, "analysis")
s <- readRDS(file.path(a, "did_sample.rds"))
u <- s$unit[T_ID %in% s$sets_r$SET & D_OK == TRUE & R_REAL_ASSETS > 0]
u[, RATIO := pmax(D_REAL_ASSETS, 0) / R_REAL_ASSETS]

money <- function(x) fifelse(x >= 1e9, sprintf("$%.1fb", x / 1e9), fifelse(x >= 1e6, sprintf("$%.1fm", x / 1e6),
                     sprintf("$%.0fk", x / 1e3)))

groups <- function(breaks, labels) {
  u[, G := cut(RATIO, breaks, labels = labels, right = FALSE)]
  g <- u[, list(N = .N, MED_RATIO = median(RATIO), D_MED = median(D_REAL_ASSETS), R_MED = median(R_REAL_ASSETS)), by = G]
  g[, PCT := 100 * N / sum(N)][order(G)]
}

draw <- function(g, file, title) {
  r0 <- 1                                     # recipient radius (100%)
  rd <- r0 * sqrt(g$MED_RATIO)                # donor radius: area proportional to the ratio
  h  <- pmax(2 * pmax(rd, r0) + 0.5, 2.6)     # row heights
  yc <- rev(cumsum(rev(h)) - rev(h) / 2)      # row centres, first group on top
  xd <- 0; xr <- max(rd) + r0 + 0.6           # donor and recipient centres
  xt <- xr + r0 + 0.5                         # text
  png(file, width = 1700, height = 220 * sum(h) / 2.6 + 260, res = 170)
  par(mar = c(0.5, 0.5, 3.2, 0.5))
  plot(NA, xlim = c(-max(rd) - 3.4, xt + 6.2), ylim = c(0, sum(h)), asp = 1, axes = FALSE, xlab = "", ylab = "")
  title(title, adj = 0, cex.main = 1.05, font.main = 2, line = 1.7)
  mtext("Circle area = median donor assets as a share of recipient assets (recipient = 100%). Baseline mean of t-3 and t-2, 2024 dollars.",
        side = 3, adj = 0, line = 0.5, cex = 0.62, col = "grey35")
  th <- seq(0, 2 * pi, length.out = 200)
  for (i in seq_len(nrow(g))) {
    y <- yc[i]
    polygon(xd + rd[i] * cos(th), y + rd[i] * sin(th), col = adjustcolor("#d0661c", 0.85), border = NA)
    polygon(xr + r0 * cos(th), y + r0 * sin(th), col = adjustcolor("#1f5fa8", 0.85), border = NA)
    text(-max(rd) - 0.4, y + 0.25, as.character(g$G[i]), adj = 1, font = 2, cex = 0.95)
    text(-max(rd) - 0.4, y - 0.3, sprintf("median %s", ifelse(g$MED_RATIO[i] >= 1, sprintf("%.1fx", g$MED_RATIO[i]),
                                                               sprintf("%.1f%%", 100 * g$MED_RATIO[i]))),
         adj = 1, cex = 0.72, col = "grey30")
    text(xt, y + 0.55, sprintf("%s mergers (%.0f%%)", format(g$N[i], big.mark = ","), g$PCT[i]), adj = 0, font = 2, cex = 0.82)
    text(xt, y + 0.0, sprintf("Donor median assets: %s", money(g$D_MED[i])), adj = 0, cex = 0.76, col = "#a34f12")
    text(xt, y - 0.55, sprintf("Recipient median assets: %s", money(g$R_MED[i])), adj = 0, cex = 0.76, col = "#174a85")
  }
  text(xd, sum(h) - 0.05, "Donor", font = 2, cex = 0.8, col = "#a34f12")
  text(xr, sum(h) - 0.05, "Recipient", font = 2, cex = 0.8, col = "#174a85")
  invisible(dev.off())
}

g_sug <- groups(c(-Inf, .01, .05, .10, .25, .50, 1, Inf),
                c("Under 1%", "1-5%", "5-10%", "10-25%", "25-50%", "50-100%", "100%+"))
g_orig <- groups(c(-Inf, .05, .20, .40, .60, .80, 1, Inf),
                 c("0-5%", "5-20%", "20-40%", "40-60%", "60-80%", "80-100%", "100%+"))
n <- format(nrow(u), big.mark = ",")
draw(g_sug, file.path(a, "size_ratio_circles.png"), sprintf("Donor size relative to recipient (%s two-party mergers)", n))
draw(g_orig, file.path(a, "size_ratio_circles_original.png"), sprintf("Donor size relative to recipient (%s two-party mergers)", n))
fwrite(rbind(g_sug[, breaks := "suggested"], g_orig[, breaks := "original"]), file.path(a, "size_ratio_groups.csv"))
print(g_sug); print(g_orig)
