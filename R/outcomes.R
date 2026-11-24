# Outcome measures drawn from the merger and financial-vulnerability
# literatures that the 'fiscal' ratios do not cover: growth, volatility and
# deficit history (trend_measures), Tuckman-Chang vulnerability flags
# (tuckman_chang), and a combined donor + recipient pre-merger baseline
# (merger_proforma).

# ---- trends ---------------------------------------------------------------------

#' Growth, volatility, and deficit history within each organization
#'
#' Year-over-year growth, revenue volatility, and the count of deficit years
#' over a trailing window. Windows are defined on calendar years and never
#' use future years. Growth needs a return in the prior calendar year, so
#' filing gaps give `NA` rather than a multi-year change.
#'
#' Growth is the symmetric (Davis-Haltiwanger-Schuh) rate
#' `(v[t] - v[t-1]) / ((|v[t]| + |v[t-1]|) / 2)`, bounded to -2..2. Unlike a
#' log change it is defined for zero and negative values (net assets), and
#' it is close to the percentage change for small changes.
#'
#' @param x An organization-year table with [merger_measures()] columns.
#' @param vars Columns to compute growth for; each adds `<var>_GROWTH`.
#' @param k Trailing window length in years for volatility and deficits.
#' @param min_obs Minimum returns in the window for `REVENUE_CV` and
#'   `DEFICIT_YEARS` (otherwise `NA`).
#' @param id,time Organization and year columns.
#' @return `x` with `<var>_GROWTH` columns, `REVENUE_CV` (coefficient of
#'   variation of revenue over the window), `DEFICIT_YEARS` (returns in the
#'   window with expenses above revenue), and `N_TRAIL_YEARS` (returns in
#'   the window).
#' @references Mayer, W. J. (2023). Simmer or boil: Revenue volatility and
#'   nonprofit dissolution. *Nonprofit and Voluntary Sector Quarterly*.
#' @export
#' @examples
#' x <-
#'   data.frame(
#'     EIN2     = "A",
#'     TAX_YEAR = 2018:2021,
#'     REVENUE  = c( 100, 120, 90, 90 ),
#'     SURPLUS  = c(   5,  -2, -8,  1 )
#'   )
#'
#' trend_measures( x, vars = "REVENUE" )
trend_measures <- function(x, vars = c("REVENUE", "EXPENSES", "CONTRIBUTIONS", "PROGRAM_REVENUE", "NET_ASSETS"),
                           k = 3L, min_obs = k, id = "EIN2", time = "TAX_YEAR") {
  dt <- data.table::copy(as.data.table(x))
  vars <- intersect(vars, names(dt))
  key <- dt[, list(ID_ = get(id), T_ = as.integer(get(time)))]
  for (v in vars) {
    cur <- data.table(ID_ = key$ID_, T_ = key$T_, V_ = as.numeric(dt[[v]]))
    prev <- cur[, list(ID_, T_ = T_ + 1L, P_ = V_)]
    p <- prev[cur, on = c("ID_", "T_"), mult = "first"]$P_
    den <- (abs(cur$V_) + abs(p)) / 2
    data.table::set(dt, j = paste0(v, "_GROWTH"), value = fifelse(!is.na(den) & den > 0, (cur$V_ - p) / den, NA_real_))
  }
  s <- data.table(ID_ = key$ID_, T_ = key$T_,
                  R_ = if ("REVENUE" %in% names(dt)) as.numeric(dt$REVENUE) else NA_real_,
                  D_ = if ("SURPLUS" %in% names(dt)) as.numeric(dt$SURPLUS) < 0 else NA)
  lagged <- rbindlist(lapply(seq_len(k) - 1L, function(j) s[, list(ID_, T_ = T_ + j, R_, D_)]))
  agg <- lagged[, list(N_ = .N,
                       CV_ = if (sum(!is.na(R_)) >= 2L && mean(R_, na.rm = TRUE) > 0) stats::sd(R_, na.rm = TRUE) / mean(R_, na.rm = TRUE) else NA_real_,
                       DY_ = if (all(is.na(D_))) NA_integer_ else sum(D_, na.rm = TRUE)),
                by = list(ID_, T_)]
  a <- agg[s, on = c("ID_", "T_")]
  dt[, `:=`(REVENUE_CV = fifelse(a$N_ >= min_obs, a$CV_, NA_real_),
            DEFICIT_YEARS = fifelse(a$N_ >= min_obs, as.integer(a$DY_), NA_integer_),
            N_TRAIL_YEARS = as.integer(a$N_))]
  dt[]
}

.trend_cols <- c(paste0(c("REVENUE", "EXPENSES", "CONTRIBUTIONS", "PROGRAM_REVENUE", "NET_ASSETS"), "_GROWTH"),
                 "REVENUE_CV", "DEFICIT_YEARS", "N_TRAIL_YEARS")

# ---- Tuckman-Chang -----------------------------------------------------------------

#' Tuckman-Chang financial vulnerability flags
#'
#' Tuckman and Chang (1991) call an organization financially vulnerable when
#' it is in the most vulnerable quintile on any of four indicators: equity
#' (net assets / revenue), revenue concentration (`REVENUE_HHI`),
#' administrative costs (management and general / total expenses), and
#' operating margin (surplus / revenue). Low equity, low administrative
#' costs (little to cut), low margins, and high concentration are
#' vulnerable. Greenlee and Trussel (2000) and Hager (2001) use the same four.
#'
#' Cutoffs are quantiles computed within `by` groups of `reference`. Pass
#' the full 990 panel ([get_panel()]) as `reference`, so merger
#' organizations are ranked against all filers rather than against each
#' other. The admin and concentration indicators need the full Form 990, so
#' 990-EZ filers are flagged on equity and margin only.
#'
#' @param x Organization-year table with `REVENUE`, `SURPLUS`, `NET_ASSETS`,
#'   `REVENUE_HHI`, and `ADMIN_RATIO` (from [merger_measures()] or
#'   [panel_measures()]).
#' @param reference Table used for the cutoffs (default `x`).
#' @param by Grouping columns for the cutoffs (e.g. `c("TAX_YEAR",
#'   "NTEE_MAJOR")`).
#' @param q Quantile that defines the vulnerable tail.
#' @return `x` with indicators `TC_EQUITY`, `TC_HHI`, `TC_ADMIN`,
#'   `TC_MARGIN`; flags `TC_LOW_EQUITY`, `TC_HIGH_HHI`, `TC_LOW_ADMIN`,
#'   `TC_LOW_MARGIN`; `TC_N_OBS` (indicators available), `TC_N_FLAGS`,
#'   `TC_ANY` (at least one flag), and `TC_ALL` (all four flagged; `NA`
#'   unless all four are available). The cutoffs are in `attr(, "cutoffs")`.
#' @references Tuckman, H. P., & Chang, C. F. (1991). *Nonprofit and
#'   Voluntary Sector Quarterly*, 20(4), 445-460. Greenlee, J. S., &
#'   Trussel, J. M. (2000). *Nonprofit Management and Leadership*, 11(2),
#'   199-210.
#' @export
tuckman_chang <- function(x, reference = x, by = "TAX_YEAR", q = 0.2) {
  ind <- function(d) {
    d <- as.data.table(d)
    rv <- as.numeric(d$REVENUE)
    data.table(TC_EQUITY = fifelse(rv > 0, as.numeric(d$NET_ASSETS) / rv, NA_real_),
               TC_HHI = if ("REVENUE_HHI" %in% names(d)) as.numeric(d$REVENUE_HHI) else NA_real_,
               TC_ADMIN = if ("ADMIN_RATIO" %in% names(d)) as.numeric(d$ADMIN_RATIO) else NA_real_,
               TC_MARGIN = fifelse(rv > 0, as.numeric(d$SURPLUS) / rv, NA_real_))
  }
  .need(as.data.table(x), c("REVENUE", "SURPLUS", "NET_ASSETS", by), "x")
  ref <- cbind(as.data.table(reference)[, by, with = FALSE], ind(reference))
  qn <- function(v, p) if (all(is.na(v))) NA_real_ else as.numeric(stats::quantile(v, p, na.rm = TRUE, names = FALSE))
  cut <- ref[, list(CUT_EQUITY = qn(TC_EQUITY, q), CUT_HHI = qn(TC_HHI, 1 - q),
                    CUT_ADMIN = qn(TC_ADMIN, q), CUT_MARGIN = qn(TC_MARGIN, q), N_REF = .N), by = by]
  out <- data.table::copy(as.data.table(x))
  out[, names(ind(out)) := ind(out)]
  cm <- cut[out[, by, with = FALSE], on = by]
  out[, `:=`(TC_LOW_EQUITY = TC_EQUITY <= cm$CUT_EQUITY, TC_HIGH_HHI = TC_HHI >= cm$CUT_HHI,
             TC_LOW_ADMIN = TC_ADMIN <= cm$CUT_ADMIN, TC_LOW_MARGIN = TC_MARGIN <= cm$CUT_MARGIN)]
  fl <- c("TC_LOW_EQUITY", "TC_HIGH_HHI", "TC_LOW_ADMIN", "TC_LOW_MARGIN")
  m <- as.matrix(out[, fl, with = FALSE])
  out[, `:=`(TC_N_OBS = as.integer(rowSums(!is.na(m))), TC_N_FLAGS = as.integer(rowSums(m, na.rm = TRUE)))]
  out[, `:=`(TC_ANY = fifelse(TC_N_OBS > 0L, TC_N_FLAGS > 0L, NA),
             TC_ALL = fifelse(TC_N_OBS == 4L, TC_N_FLAGS == 4L, NA))]
  attr(out, "cutoffs") <- cut[]
  out[]
}

# ---- pro forma baseline -----------------------------------------------------------

.additive_cols <- c("REVENUE", "EXPENSES", "SURPLUS", "ASSETS", "ASSETS_BOY", "LIABILITIES", "NET_ASSETS", "DEBT",
                    "CONTRIBUTIONS", "PROGRAM_REVENUE", "INVEST_INCOME", "OTHER_REVENUE", "NONCASH_CONTRIB", "GRANTS",
                    "STAFF_EXP", "EXEC_COMP", "PROGRAM_EXP", "MGMT_EXP", "FUNDR_EXP", "EMPLOYEES")

#' Combined donor + recipient (pro forma) series
#'
#' Before a merger the recipient's own books exclude the donor, so comparing
#' the recipient before and after mixes the merger's effect with the
#' mechanical jump from absorbing the donor (and, in a rescue, the donor's
#' weak ratios). The pro forma series sums the recipient and its donor(s)
#' in each pre-merger year, on each organization's own fiscal calendar, and
#' uses the recipient alone from `pre_max + 1` on. Ratios are recomputed
#' from the summed amounts.
#'
#' Amounts a 990-EZ donor does not report (functional expenses, employees,
#' revenue breakdown) count as zero, and `PF_EZ_MEMBERS` counts those
#' donors. `REVENUE_HHI` is `NA` in years with an EZ member. 'fiscal' ratio
#' columns are not carried over: compute them from the summed amounts if
#' needed.
#'
#' @param fp Output of [merger_fiscal_panel()].
#' @param level `"merger"` (one recipient and one donor per series) or
#'   `"group"` (all donors in a `MERGER_GROUP_ID`, aligned on each donor's
#'   own time from merger, with the recipient's years from the group's
#'   first merger).
#' @param pre_max Last event year summed (default -1: the donor's final
#'   year, 0, is often a partial year).
#' @param require_all When `TRUE`, pre-merger years in which any donor has
#'   no return are set to `NA`.
#' @return A data.table with `ROLE = "combined"`, the ID column
#'   (`MERGER_ID` or `MERGER_GROUP_ID`), `EIN2` and `TAX_YEAR` of the
#'   recipient, `TIME_FROM_MERGER`, the summed measures, recomputed ratios,
#'   `N_DONORS`, `N_DONORS_OBS`, `PF_EZ_MEMBERS`, and `PF_COMPLETE`.
#' @export
merger_proforma <- function(fp, level = c("merger", "group"), pre_max = -1L, require_all = TRUE) {
  level <- match.arg(level)
  fp <- as.data.table(fp)
  idc <- if (level == "merger") "MERGER_ID" else "MERGER_GROUP_ID"
  .need(fp, c(idc, "ROLE", "EIN2", "TAX_YEAR", "TIME_FROM_MERGER"), "fp")
  num <- intersect(.additive_cols, names(fp))
  rec <- fp[ROLE == "recipient"]
  if (level == "group") {
    first <- fp[, list(MERGER_ID = sort(unique(MERGER_ID))[1L]), by = MERGER_GROUP_ID]
    rec <- rec[MERGER_ID %in% first$MERGER_ID]
  }
  rec <- rec[, c(idc, "EIN2", "TAX_YEAR", "TIME_FROM_MERGER", "EZ", num), with = FALSE]
  don <- unique(fp[ROLE == "donor" & TIME_FROM_MERGER <= pre_max], by = c(idc, "EIN2", "TIME_FROM_MERGER"))
  nd <- unique(fp[ROLE == "donor", c(idc, "EIN2"), with = FALSE])[, list(N_DONORS = .N), by = idc]
  # 990-only amounts a 990-EZ donor lacks count as zero
  ez_only <- setdiff(num, c("REVENUE", "EXPENSES", "SURPLUS", "ASSETS", "ASSETS_BOY", "LIABILITIES", "NET_ASSETS",
                            "CONTRIBUTIONS", "PROGRAM_REVENUE", "GRANTS"))
  for (v in ez_only) don[EZ %in% TRUE & is.na(get(v)), (v) := 0]
  dsum <- don[, c(list(N_DONORS_OBS = .N, PF_EZ_MEMBERS = sum(EZ %in% TRUE)),
                  lapply(.SD, function(v) if (anyNA(v)) NA_real_ else sum(v))),
              by = c(idc, "TIME_FROM_MERGER"), .SDcols = num]
  out <- merge(rec, dsum, by = c(idc, "TIME_FROM_MERGER"), all.x = TRUE, suffixes = c("", ".D"))
  out <- merge(out, nd, by = idc, all.x = TRUE)
  out[is.na(N_DONORS), N_DONORS := 0L]
  pre <- out$TIME_FROM_MERGER <= pre_max
  for (v in num) {
    dv <- out[[paste0(v, ".D")]]
    data.table::set(out, i = which(pre), j = v, value = out[[v]][pre] + dv[pre])
  }
  out[, PF_COMPLETE := !pre | (!is.na(N_DONORS_OBS) & N_DONORS_OBS == N_DONORS)]
  if (require_all) for (v in num) data.table::set(out, i = which(!out$PF_COMPLETE), j = v, value = NA_real_)
  out[!pre, `:=`(N_DONORS_OBS = NA_integer_, PF_EZ_MEMBERS = NA_integer_)]
  out[, grep("\\.D$", names(out), value = TRUE) := NULL]
  # recompute ratios from the summed amounts
  r <- function(a, b) if (all(c(a, b) %in% names(out))) fifelse(out[[b]] > 0, out[[a]] / out[[b]], NA_real_) else NA_real_
  if ("MGMT_EXP" %in% num) {
    out[, ADMIN_RATIO := r("MGMT_EXP", "EXPENSES")]
    out[, OVERHEAD_RATIO := fifelse(EXPENSES > 0, (MGMT_EXP + fcoalesce(if ("FUNDR_EXP" %in% num) FUNDR_EXP else NA_real_, 0)) / EXPENSES, NA_real_)]
  }
  if (all(c("CONTRIBUTIONS", "PROGRAM_REVENUE", "INVEST_INCOME", "OTHER_REVENUE") %in% num))
    out[, REVENUE_HHI := revenue_hhi(CONTRIBUTIONS, PROGRAM_REVENUE, INVEST_INCOME, OTHER_REVENUE,
                                     ok = !(EZ %in% TRUE) & fcoalesce(PF_EZ_MEMBERS, 0L) == 0L)]
  if ("EMPLOYEES" %in% num) {
    per <- function(v) if (v %in% num) fifelse(out$EMPLOYEES > 0, out[[v]] / out$EMPLOYEES, NA_real_) else NA_real_
    out[, `:=`(REV_PER_EMPLOYEE = per("REVENUE"), EXP_PER_EMPLOYEE = per("EXPENSES"), COMP_PER_EMPLOYEE = per("STAFF_EXP"))]
  }
  if ("SURPLUS" %in% num) out[, DEFICIT := SURPLUS < 0]
  if ("NET_ASSETS" %in% num) out[, NEG_NET_ASSETS := NET_ASSETS < 0]
  out[, ROLE := "combined"][, EZ := NULL]
  data.table::setcolorder(out, c(idc, "ROLE", "EIN2", "TAX_YEAR", "TIME_FROM_MERGER"))
  data.table::setorderv(out, c(idc, "TIME_FROM_MERGER"))
  out[]
}

utils::globalVariables(c("ID_", "T_", "V_", "P_", "R_", "D_", "N_", "CV_", "DY_", "REVENUE_CV", "DEFICIT_YEARS",
                         "N_TRAIL_YEARS", "TC_EQUITY", "TC_HHI", "TC_ADMIN", "TC_MARGIN", "TC_N_OBS", "TC_N_FLAGS",
                         "TC_ANY", "TC_ALL", "N_DONORS", "N_DONORS_OBS", "PF_EZ_MEMBERS", "PF_COMPLETE",
                         "MERGER_GROUP_ID", "ROLE", "NET_ASSETS"))
