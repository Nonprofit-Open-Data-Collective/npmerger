# Matched difference-in-differences for merger recipients.
#
# build_model_data() assembles everything the models need from the merger
# data and the matching data, once. merger_did(), did_event_study(),
# did_breakouts(), and did_sensitivity() then run any design or variant
# from that object without going back to the 990 files.

# ---- settings ------------------------------------------------------------------

#' Outcomes for the merger models
#'
#' @param set `"all"` (every outcome) or `"core"` (revenue, assets, margin,
#'   expenses / assets, employees).
#' @return A named character vector: names are outcome codes, values are
#'   labels.
#' @export
did_outcomes <- function(set = c("all", "core")) {
  set <- match.arg(set)
  core <- c(LOG_REVENUE = "Revenue", LOG_ASSETS = "Total assets", MARGIN = "Operating margin",
            LOG_EXP_ASSETS = "Expenses / assets", LOG_EMPLOYEES = "Employees")
  ext <- c(LOG_EXPENSES = "Expenses", EQUITY_RATIO = "Equity ratio", DEBT_RATIO = "Debt ratio",
           MONTHS_CASH = "Months of cash", DEFICIT = "Deficit year", LOG_STAFF_EXP = "Staff expenses",
           LOG_CONTRIB = "Contributions", LOG_PROGREV = "Program revenue", CONTRIB_SHARE = "Contribution share",
           REVENUE_HHI = "Revenue concentration (HHI)", ADMIN_RATIO = "Administrative ratio")
  if (set == "core") core else c(core, ext)
}

#' Designs for the merger models
#'
#' * `"naive | recipient match"`: the recipient alone, against controls
#'   matched to the recipient;
#' * `"proforma | recipient match"`: before the merger, recipient plus
#'   donor(s); after, the recipient; same controls;
#' * `"proforma | combined match"`: the same outcome, against controls
#'   matched to the combined recipient + donor baseline.
#'
#' @return A character vector of design names.
#' @export
did_designs <- function() c("naive | recipient match", "proforma | recipient match", "proforma | combined match")

#' Sensitivity variants used in the paper
#'
#' Each variant is a list of arguments to [merger_did()]. `base` is the main
#' specification; the others change one thing each. Add your own by
#' appending to the list.
#'
#' @return A named list of argument lists.
#' @export
#' @examples
#' v <- did_variants()
#'
#' names( v )
#'
#' # add a variant: three controls instead of five
#' v$k3 <- modifyList( v$base, list( k = 3L ) )
did_variants <- function() {
  base <- list(k = 5L, spec = "margin", gap = 0L, keep = ~ OTHER == FALSE, post = 2L)
  m <- function(...) utils::modifyList(base, list(...))
  list(
    base         = base,
    k1           = m(k = 1L),
    k10          = m(k = 10L),
    equity       = m(spec = "equity"),
    gap2         = m(gap = 2L),
    through2021  = m(keep = ~ OTHER == FALSE & YEAR <= 2021L),
    keep_other   = m(keep = ~ TRUE),
    ntee_current = m(keep = ~ OTHER == FALSE & NTEE_CURRENT),
    unaffiliated = m(keep = ~ OTHER == FALSE & AFFILIATED == FALSE),
    full990      = m(keep = ~ OTHER == FALSE & R_EZ == FALSE),
    post1        = m(post = 1L))
}

#' Unit-level breakout variables
#'
#' @return Character vector of the `units` columns that [did_breakouts()]
#'   can use.
#' @export
did_breakout_vars <- function() c("DOSE_BIN", "SIZE_BAND", "AFFILIATED", "TYPOLOGY", "CEO_CAT", "BOARD_CAT")

# ---- model data -------------------------------------------------------------------

.comp_cols <- c("REVENUE", "EXPENSES", "ASSETS", "LIABILITIES", "NET_ASSETS", "CASH", "SURPLUS", "STAFF_EXP",
                "CONTRIBUTIONS", "PROGRAM_REVENUE", "INVEST_INCOME", "OTHER_REVENUE", "FUNC_EXP", "MGMT_EXP")

#' Build the data for the merger models
#'
#' Assembles, once, everything [merger_did()] and the other model functions
#' need: one row per treated recipient with its breakout variables, the
#' candidate controls for each matching specification (including a match on
#' the combined recipient + donor baseline), donor component sums for the
#' pro forma outcomes, and the organization-years the models read.
#'
#' @param merger_data The list from [build_merger_data()].
#' @param match_data The list from [build_match_data()], with its `panel`.
#' @param max_k Most controls per treated unit any model will use.
#' @param max_year_gap Largest calendar-year gap between a recipient and its
#'   controls any model will use.
#' @param event Event years kept around each merger.
#' @param verbose Print progress.
#' @return A list of class `merger_model_data`: `units`, `cases`,
#'   `candidates` (named `r_<spec>` for recipient matches and `c_margin` for
#'   the combined match), `panel` (outcome components for the
#'   organization-years used), `donors` (donor sums by unit and event year),
#'   `n_donors`, and `info`.
#' @export
build_model_data <- function(merger_data, match_data, max_k = 10L, max_year_gap = 2L, event = -3:2,
                             verbose = TRUE) {
  say <- function(...) if (verbose) message(...)
  md <- merger_data; mm <- match_data
  panel <- as.data.table(mm$panel)
  if (!nrow(panel)) stop("`match_data$panel` is empty; build it with build_match_data().", call. = FALSE)
  miss <- setdiff(c(.comp_cols, "EZ", "EMPLOYEES"), names(panel))
  if (length(miss)) stop("The panel lacks ", paste(miss, collapse = ", "),
                         ". Rebuild it with this version of get_panel().", call. = FALSE)
  data.table::setkeyv(panel, c("EIN2", "TAX_YEAR"))
  smp <- as.data.table(mm$sample); tr <- as.data.table(mm$treated)
  typ <- if (!is.null(md$typology)) as.data.table(md$typology) else
    merger_typology(md$cases, md$donors, md$recipients, md$transfers)
  lead <- if (!is.null(md$leadership)) as.data.table(md$leadership) else merger_leadership(md$part7)

  # ---- treated units and their breakout variables
  say("Treated units")
  cases_u <- smp[, list(T_ID = paste(MATCH_YEAR, RECIP_EIN2, sep = "-"), MERGER_ID, DONOR_EIN2, MERGER_YEAR,
                        AFFILIATED, R_OTHER_EVENTS, D_HAS_FIRST, D_REAL_ASSETS, D_REAL_EXPENSES, D_REAL_REVENUE,
                        D_MARGIN, D_EMPLOYEES)]
  cases_u <- merge(cases_u[T_ID %in% tr$T_ID], typ[, list(MERGER_ID, TYPOLOGY = as.character(TYPOLOGY))],
                   by = "MERGER_ID", all.x = TRUE)
  unit <- cases_u[, list(AFFILIATED = any(AFFILIATED %in% TRUE), OTHER = any(R_OTHER_EVENTS > 0),
                         D_OK = all(D_HAS_FIRST %in% TRUE), TYPOLOGY = TYPOLOGY[1],
                         D_REAL_ASSETS = sum(D_REAL_ASSETS), D_REAL_EXPENSES = sum(D_REAL_EXPENSES),
                         D_REAL_REVENUE = sum(D_REAL_REVENUE),
                         D_SURPLUS_R = sum(D_MARGIN * pmax(D_REAL_REVENUE, 0)),
                         D_EMPLOYEES = sum(fcoalesce(D_EMPLOYEES, 0))), by = T_ID]
  unit <- merge(tr[, list(T_ID, EIN2, YEAR, R_REAL_ASSETS = REAL_ASSETS, R_MARGIN = MARGIN)], unit, by = "T_ID")

  xf <- as.data.table(md$transfers)[, list(MERGER_ID, FMV = fifelse(FLAG_OUTLIER %in% TRUE, NA_real_, FMV_ASSETS))]
  fmv <- merge(cases_u[, list(T_ID, MERGER_ID)], xf, by = "MERGER_ID", all.x = TRUE)[
    , list(FMV = if (all(is.na(FMV))) NA_real_ else sum(FMV, na.rm = TRUE)), by = T_ID]
  unit <- merge(unit, fmv, by = "T_ID", all.x = TRUE)
  b2 <- panel[unit[, list(EIN2, TAX_YEAR = YEAR - 2L)], on = c("EIN2", "TAX_YEAR")]
  ntee_cur <- if ("NTEE_SOURCE" %in% names(b2)) b2$NTEE_SOURCE %in% c("bmf", "current") else rep(TRUE, nrow(b2))
  unit[, `:=`(R_ASSETS_B = b2$ASSETS, R_EZ = b2$EZ %in% TRUE, NTEE_CURRENT = ntee_cur)]
  unit[, DOSE := fifelse(R_ASSETS_B > 0 & FMV >= 0, FMV / R_ASSETS_B, NA_real_)]
  unit[, DOSE_BIN := cut(DOSE, c(-Inf, 0.01, 0.10, 0.50, Inf), right = FALSE,
                         labels = c("<1%", "1-10%", "10-50%", ">=50%"))]
  unit[, DOSE_BIN := factor(fifelse(is.na(DOSE_BIN), "unknown", as.character(DOSE_BIN)),
                            levels = c("<1%", "1-10%", "10-50%", ">=50%", "unknown"))]
  unit[, SIZE_BAND := cut(R_REAL_ASSETS, c(-Inf, 1e7, 1e8, Inf), right = FALSE,
                          labels = c("<$10m", "$10-100m", ">=$100m"))]
  # two-party merger types only (the first two levels are multi-party)
  unit[, TYPOLOGY := factor(TYPOLOGY, typology_levels()[3:8])]

  one <- cases_u[, if (.N == 1L) list(MERGER_ID = MERGER_ID), by = T_ID]
  one <- merge(one, lead[, list(MERGER_ID, CEO_CAT, BOARD_CAT)], by = "MERGER_ID")
  unit[one, on = "T_ID", `:=`(CEO_CAT = i.CEO_CAT, BOARD_CAT = i.BOARD_CAT)]
  unit[, CEO_CAT := factor(CEO_CAT, levels = c("recipient_ceo_only", "both_ceos", "donor_ceo_only", "neither",
                                               "shared_ceo"))]
  unit[, BOARD_CAT := factor(BOARD_CAT, levels = c("intact_donor_dissolves", "combine_minor", "combine_major",
                                                   "recipient_turnover"))]

  # ---- candidate controls
  say("Candidate controls")
  comb <- unit[D_OK == TRUE & !is.na(R_MARGIN) & !is.na(D_SURPLUS_R)]
  comb <- merge(tr[T_ID %in% comb$T_ID],
                comb[, list(T_ID, D_REAL_ASSETS, D_REAL_EXPENSES, D_REAL_REVENUE, D_SURPLUS_R)], by = "T_ID")
  comb[, `:=`(MARGIN = {
                rv <- pmax(REAL_REVENUE, 0) + pmax(D_REAL_REVENUE, 0)
                fifelse(rv > 0, pmin(pmax((MARGIN * pmax(REAL_REVENUE, 0) + D_SURPLUS_R) / rv, -1), 1), MARGIN)
              },
              REAL_ASSETS = REAL_ASSETS + D_REAL_ASSETS, REAL_EXPENSES = REAL_EXPENSES + D_REAL_EXPENSES,
              REAL_REVENUE = REAL_REVENUE + D_REAL_REVENUE)]
  comb[, EQUITY_RATIO := NA_real_]   # not recomputed for the combined baseline
  st <- mm$settings
  arg <- function(nm, default) if (!is.null(st[[nm]])) st[[nm]] else default
  cand <- lapply(mm$candidates, function(x) as.data.table(x)[abs(YEAR_GAP) <= max_year_gap])
  names(cand) <- paste0("r_", names(mm$candidates))
  cand$c_margin <- match_candidates(comb, mm$pool, ntee_chars = arg("ntee_chars", 2L),
                                    size = arg("size", c("REAL_ASSETS", "REAL_EXPENSES")), health = "MARGIN",
                                    size_caliper = arg("size_caliper", log(2)), max_year_gap = max_year_gap)
  # keep the closest max_k candidates for every gap a model can ask for
  top <- function(x) {
    x <- x[, list(T_ID, C_EIN2, C_YEAR, YEAR_GAP, DIST)]
    data.table::setorderv(x, c("T_ID", "DIST"))
    unique(rbindlist(lapply(0:max_year_gap, function(g) x[abs(YEAR_GAP) <= g, utils::head(.SD, max_k), by = T_ID])))
  }
  pool_n <- nrow(mm$pool); pool_orgs <- uniqueN(mm$pool$EIN2)
  cand <- lapply(cand, top)

  # ---- donor sums and the organization-years the models read
  say("Outcome panel")
  need <- unique(rbind(
    rbindlist(lapply(cand, function(x) unique(x[, list(EIN2 = C_EIN2, YEAR = C_YEAR)]))),
    unit[, list(EIN2, YEAR)]))
  need <- rbind(need[, list(TAX_YEAR = YEAR + event), by = list(EIN2, YEAR)][, list(EIN2, TAX_YEAR)],
                cases_u[, list(TAX_YEAR = MERGER_YEAR + event[event < 0]), by = list(EIN2 = DONOR_EIN2, MERGER_ID)][
                  , list(EIN2, TAX_YEAR)])
  op <- panel[unique(need), on = c("EIN2", "TAX_YEAR"), nomatch = NULL,
              c("EIN2", "TAX_YEAR", "EZ", "EMPLOYEES", .comp_cols), with = FALSE]
  op[EZ %in% TRUE, c("FUNC_EXP", "MGMT_EXP") := NA_real_]
  data.table::setkeyv(op, c("EIN2", "TAX_YEAR"))

  nsum <- function(v) if (anyNA(v)) NA_real_ else sum(v)
  don <- cases_u[, list(SET = T_ID, D = DONOR_EIN2, MY = MERGER_YEAR)]
  don <- don[, list(E = event[event < 0]), by = list(SET, D, MY)][, TAX_YEAR := MY + E]
  don <- op[don, on = c(EIN2 = "D", "TAX_YEAR"), nomatch = NULL]
  don <- don[, c(list(D_N = .N, D_EMPLOYEES = sum(fcoalesce(EMPLOYEES, 0))), lapply(.SD, nsum)),
             by = list(SET, E), .SDcols = .comp_cols]
  data.table::setnames(don, .comp_cols, paste0("D_", .comp_cols))
  n_don <- cases_u[, list(N_DON = uniqueN(DONOR_EIN2)), by = list(SET = T_ID)]

  info <- list(n_cases_merger2 = sum(as.data.table(md$cases)$TYPE == "merger2"), n_sample = nrow(smp),
               n_treated = nrow(tr), pool_n = pool_n, pool_orgs = pool_orgs, max_k = as.integer(max_k),
               max_year_gap = as.integer(max_year_gap), event = as.integer(event))
  structure(list(units = unit[], cases = cases_u[], candidates = cand, panel = op[], donors = don[],
                 n_donors = n_don[], info = info),
            class = c("merger_model_data", "list"))
}

#' @export
print.merger_model_data <- function(x, ...) {
  cat("<merger_model_data>\n")
  cat(sprintf("  units:      %s treated recipients (%s without other mergers in the window)\n",
              format(nrow(x$units), big.mark = ","), format(sum(!x$units$OTHER), big.mark = ",")))
  for (nm in names(x$candidates))
    cat(sprintf("  %-11s %s candidate rows\n", paste0(nm, ":"), format(nrow(x$candidates[[nm]]), big.mark = ",")))
  cat(sprintf("  panel:      %s org-years\n", format(nrow(x$panel), big.mark = ",")))
  cat(sprintf("  limits:     k <= %d, year gap <= %d\n", x$info$max_k, x$info$max_year_gap))
  invisible(x)
}

# ---- internals ------------------------------------------------------------------------

.keep_units <- function(data, keep) {
  u <- data$units
  if (is.null(keep)) return(u)
  if (inherits(keep, "formula")) keep <- keep[[length(keep)]]
  if (is.character(keep)) keep <- str2lang(keep)
  idx <- eval(keep, u, parent.frame())
  u[idx %in% TRUE]
}

.sets <- function(cand, u, k, gap, het) {
  cand <- cand[T_ID %in% u$T_ID & abs(YEAR_GAP) <= gap]
  data.table::setorderv(cand, c("T_ID", "DIST"))
  ctrl <- cand[, utils::head(.SD, k), by = T_ID, .SDcols = c("C_EIN2", "C_YEAR")]
  ctrl[, W := 1 / .N, by = T_ID]
  uu <- u[T_ID %in% ctrl$T_ID]
  s <- rbind(uu[, list(SET = T_ID, ORG = EIN2, YEAR, TREAT = 1L, W = 1)],
             ctrl[, list(SET = T_ID, ORG = C_EIN2, YEAR = C_YEAR, TREAT = 0L, W)])
  merge(s, uu[, c("T_ID", het), with = FALSE], by.x = "SET", by.y = "T_ID")
}

.design_sets <- function(data, u, k, spec, gap, het) {
  if (k > data$info$max_k) stop("k = ", k, " is above `max_k` (", data$info$max_k, ") in build_model_data().",
                                call. = FALSE)
  if (gap > data$info$max_year_gap) stop("gap = ", gap, " is above `max_year_gap` (", data$info$max_year_gap,
                                         ") in build_model_data().", call. = FALSE)
  rc <- data$candidates[[paste0("r_", spec)]]
  if (is.null(rc)) stop("No candidates for spec '", spec, "'.", call. = FALSE)
  cc <- data$candidates[[paste0("c_", spec)]]
  rs <- .sets(rc, u, k, gap, het)
  cs <- if (!is.null(cc)) .sets(cc, u, k, gap, het) else NULL
  list("naive | recipient match" = list(rs, FALSE), "proforma | recipient match" = list(rs, TRUE),
       "proforma | combined match" = list(cs, TRUE))
}

.bnd <- function(x, lo, hi) pmin(pmax(x, lo), hi)

.make_y <- function(d) suppressWarnings({
  y <- d$TAX_YEAR
  lg <- function(x) fifelse(x > 0, log(real_dollars(x, y)), NA_real_)
  pos <- function(v) pmax(fcoalesce(v, 0), 0)
  src <- pos(d$CONTRIBUTIONS) + pos(d$PROGRAM_REVENUE) + pos(d$INVEST_INCOME) + pos(d$OTHER_REVENUE)
  d[, `:=`(
    LOG_REVENUE = lg(REVENUE), LOG_ASSETS = lg(ASSETS), LOG_EXPENSES = lg(EXPENSES),
    MARGIN = fifelse(REVENUE > 0, .bnd(SURPLUS / REVENUE, -1, 1), NA_real_),
    LOG_EXP_ASSETS = fifelse(EXPENSES > 0 & ASSETS > 0, log(EXPENSES / ASSETS), NA_real_),
    LOG_EMPLOYEES = fifelse(EZ %in% FALSE, log1p(EMPLOYEES), NA_real_),
    EQUITY_RATIO = fifelse(ASSETS > 0, .bnd(NET_ASSETS / ASSETS, -1, 1), NA_real_),
    DEBT_RATIO = fifelse(ASSETS > 0, .bnd(LIABILITIES / ASSETS, 0, 2), NA_real_),
    MONTHS_CASH = fifelse(EXPENSES > 0, .bnd(CASH / (EXPENSES / 12), 0, 120), NA_real_),
    DEFICIT = fifelse(!is.na(SURPLUS), as.numeric(SURPLUS < 0), NA_real_),
    LOG_STAFF_EXP = lg(STAFF_EXP), LOG_CONTRIB = lg(CONTRIBUTIONS), LOG_PROGREV = lg(PROGRAM_REVENUE),
    CONTRIB_SHARE = fifelse(src > 0 & !is.na(CONTRIBUTIONS), pos(CONTRIBUTIONS) / src, NA_real_),
    REVENUE_HHI = fifelse(src > 0 & !is.na(CONTRIBUTIONS),
                          (pos(CONTRIBUTIONS)^2 + pos(PROGRAM_REVENUE)^2 + pos(INVEST_INCOME)^2 +
                             pos(OTHER_REVENUE)^2) / src^2, NA_real_),
    ADMIN_RATIO = fifelse(FUNC_EXP > 0, .bnd(MGMT_EXP / FUNC_EXP, 0, 1), NA_real_))]
})

.trim <- function(v) { q <- stats::quantile(v, c(.01, .99), na.rm = TRUE); pmin(pmax(v, q[1]), q[2]) }

.outcome_data <- function(data, sets, proforma, het) {
  d <- sets[, list(E = data$info$event), by = c("SET", "ORG", "YEAR", "TREAT", "W", het)]
  d[, TAX_YEAR := YEAR + E]
  d <- data$panel[d, on = c(EIN2 = "ORG", "TAX_YEAR")]
  data.table::setnames(d, "EIN2", "ORG")
  if (proforma) {
    d <- merge(merge(d, data$donors, by = c("SET", "E"), all.x = TRUE), data$n_donors, by = "SET", all.x = TRUE)
    pre <- d$TREAT == 1L & d$E < 0
    for (v in .comp_cols) data.table::set(d, which(pre), v, d[[v]][pre] + d[[paste0("D_", v)]][pre])
    d[pre, EMPLOYEES := fcoalesce(EMPLOYEES, 0) + D_EMPLOYEES]
    d[pre & (is.na(D_N) | D_N < N_DON), (.comp_cols) := NA_real_]
  }
  .make_y(d)
  d[, LOG_EXP_ASSETS := .trim(LOG_EXP_ASSETS)]
  d[]
}

.coefs <- function(m, design, y, spec, variant) {
  ct <- fixest::coeftable(m)
  data.table(variant = variant, design = design, outcome = y, spec = spec, term = sub("^TREAT:?", "", rownames(ct)),
             estimate = ct[, 1], se = ct[, 2], p = ct[, 4], n_obs = stats::nobs(m),
             n_sets = length(unique(m$fixef_id$SET)))
}

.long_diff <- function(d, design, variant, post, outcomes, het, gap) {
  yfe <- if (gap > 0) "+ TAX_YEAR" else ""
  lhs <- paste(c("SET", "ORG", "TREAT", "W", "YEAR", het), collapse = " + ")
  w <- data.table::dcast(d[E %in% c(-2L, post)], stats::as.formula(paste(lhs, "~ E")), value.var = outcomes)
  if (length(outcomes) == 1L)
    data.table::setnames(w, as.character(c(-2L, post)), paste0(outcomes, "_", c(-2L, post)))
  res <- list()
  for (y in outcomes) {
    w[, DY := get(paste0(y, "_", post)) - get(paste0(y, "_-2"))][, TAX_YEAR := YEAR]
    dd <- w[!is.na(DY)]
    dd <- dd[SET %in% dd[TREAT == 1L, SET] & SET %in% dd[TREAT == 0L, SET]]
    if (!nrow(dd)) next
    dd[TREAT == 0L, W := 1 / .N, by = SET]
    fit <- function(rhs) fixest::feols(stats::as.formula(paste("DY ~", rhs, "| SET", yfe)), dd, weights = ~W,
                                       cluster = ~ SET + ORG, notes = FALSE)
    res <- c(res, list(.coefs(fit("TREAT"), design, y, "pooled", variant)))
    for (h in het) if (any(!is.na(dd[[h]]))) {
      r <- tryCatch(.coefs(fit(paste0("TREAT:", h)), design, y, h, variant), error = function(e) NULL)
      res <- c(res, list(r))
    }
  }
  rbindlist(res)
}

.need_fixest <- function() if (!requireNamespace("fixest", quietly = TRUE))
  stop("The merger models need the 'fixest' package: install.packages(\"fixest\").", call. = FALSE)

# ---- models ---------------------------------------------------------------------------

#' Matched difference-in-differences for merger recipients
#'
#' Long-difference estimates, from `t-2` to `t+post`, of the change in each
#' outcome for merger recipients against their matched controls, for each
#' design in [did_designs()]. Each treated unit and its `k` closest controls
#' form a set; models have set fixed effects, control weights of `1/k`, and
#' standard errors clustered by set and organization.
#'
#' @param data A [build_model_data()] object.
#' @param k Controls per treated unit.
#' @param spec Matching specification: `"margin"` or `"equity"` (the names
#'   of `health` in [build_match_data()]).
#' @param gap Largest calendar-year gap between a recipient and its
#'   controls (with a gap above 0, the models add tax-year fixed effects).
#' @param keep A one-sided formula (or quoted expression or string),
#'   evaluated in `data$units`, that selects the
#'   treated units (e.g. `~ OTHER == FALSE & YEAR <= 2021L`), or `NULL`
#'   for all.
#' @param post Last event year of the long difference.
#' @param designs Designs to run, from [did_designs()].
#' @param outcomes Outcome codes, from `names(did_outcomes())`.
#' @param het Unit-level variables to interact with treatment (see
#'   [did_breakouts()]).
#' @param label Value of the `variant` column.
#' @return A data.table: `variant`, `design`, `outcome`, `spec` (`"pooled"`
#'   or the breakout variable), `term`, `estimate`, `se`, `p`, `n_obs`,
#'   `n_sets`. Log outcomes are log points; ratios and shares are
#'   proportions.
#' @export
merger_did <- function(data, k = 5L, spec = "margin", gap = 0L, keep = ~ OTHER == FALSE, post = 2L,
                       designs = did_designs(), outcomes = names(did_outcomes()), het = NULL, label = "base") {
  .need_fixest()
  u <- .keep_units(data, keep)
  hv <- intersect(did_breakout_vars(), names(u))
  ds <- .design_sets(data, u, k, spec, gap, hv)[designs]
  rbindlist(lapply(names(ds), function(nm) {
    if (is.null(ds[[nm]][[1]])) return(NULL)
    d <- .outcome_data(data, ds[[nm]][[1]], ds[[nm]][[2]], hv)
    .long_diff(d, nm, label, post, outcomes, het, gap)
  }))
}

#' @describeIn merger_did Breakouts: the treatment effect within each level
#'   of each variable in `by` (one model per variable), alongside the pooled
#'   estimate.
#' @param by Breakout variables, from [did_breakout_vars()].
#' @param ... Further arguments to `merger_did()`.
#' @export
did_breakouts <- function(data, by = did_breakout_vars(), ...) merger_did(data, het = by, ...)

#' @describeIn merger_did Sensitivity: `merger_did()` once per variant, with
#'   the variant's name in `variant`.
#' @param variants A named list of argument lists, as from [did_variants()].
#' @export
did_sensitivity <- function(data, variants = did_variants(), ...) {
  rbindlist(lapply(names(variants), function(v)
    do.call(merger_did, c(list(data = data, label = v), variants[[v]], list(...)))))
}

#' Event-study estimates for merger recipients
#'
#' Difference between recipients and their matched controls in each event
#' year, relative to `t-2`, with unit and set-by-event-year fixed effects.
#'
#' @inheritParams merger_did
#' @return A data.table as from [merger_did()], with `spec = "event"` and an
#'   event-year column `E`.
#' @export
did_event_study <- function(data, k = 5L, spec = "margin", gap = 0L, keep = ~ OTHER == FALSE,
                            designs = did_designs(), outcomes = names(did_outcomes()), label = "base") {
  .need_fixest()
  u <- .keep_units(data, keep)
  hv <- intersect(did_breakout_vars(), names(u))
  ds <- .design_sets(data, u, k, spec, gap, hv)[designs]
  rbindlist(lapply(names(ds), function(nm) {
    if (is.null(ds[[nm]][[1]])) return(NULL)
    d <- .outcome_data(data, ds[[nm]][[1]], ds[[nm]][[2]], hv)
    rbindlist(lapply(outcomes, function(y) {
      dd <- d[!is.na(get(y))][, UNIT := paste(SET, ORG, YEAR)]
      m <- fixest::feols(stats::as.formula(paste(y, "~ i(E, TREAT, ref = -2) | UNIT + SET^E")), dd,
                         weights = ~W, cluster = ~ SET + ORG, notes = FALSE)
      x <- .coefs(m, nm, y, "event", label)
      x[, E := as.integer(sub("^E::(-?[0-9]+):TREAT$", "\\1", rownames(fixest::coeftable(m))))]
    }))
  }))
}

#' Baseline means, sample funnel, and sample composition
#'
#' Descriptive companions to [merger_did()] for the same sets.
#'
#' @inheritParams merger_did
#' @return `did_baseline_means()`: mean of each outcome at `t-2`, by design
#'   and `TREAT`. `did_funnel()`: a `step`, `n` table from merger cases to
#'   the units and controls used. `did_composition()`: the number of treated
#'   units in each level of each breakout variable.
#' @export
did_baseline_means <- function(data, k = 5L, spec = "margin", gap = 0L, keep = ~ OTHER == FALSE,
                               designs = did_designs(), outcomes = names(did_outcomes())) {
  u <- .keep_units(data, keep)
  hv <- intersect(did_breakout_vars(), names(u))
  ds <- .design_sets(data, u, k, spec, gap, hv)[designs]
  rbindlist(lapply(names(ds), function(nm) {
    if (is.null(ds[[nm]][[1]])) return(NULL)
    d <- .outcome_data(data, ds[[nm]][[1]], ds[[nm]][[2]], hv)
    d[E == -2L, c(list(design = nm), lapply(.SD, function(x) mean(x, na.rm = TRUE))), by = TREAT, .SDcols = outcomes]
  }))
}

#' @rdname did_baseline_means
#' @export
did_funnel <- function(data, k = 5L, spec = "margin", gap = 0L, keep = ~ OTHER == FALSE) {
  u <- .keep_units(data, keep)
  ds <- .design_sets(data, u, k, spec, gap, character())
  rs <- ds[[1]][[1]]; cs <- ds[[3]][[1]]
  i <- data$info
  data.table(
    step = c("merger2 cases", "cases with recipient returns t-2..t+2", "recipient units with a t-2 baseline",
             "units kept", "units with >= 1 control (recipient match)", "units with >= 1 control (combined match)",
             "comparison pool org-years", "comparison pool organizations", "control org-years used (recipient match)"),
    n = c(i$n_cases_merger2, i$n_sample, i$n_treated, nrow(u), uniqueN(rs$SET),
          if (is.null(cs)) NA_integer_ else uniqueN(cs$SET), i$pool_n, i$pool_orgs,
          rs[TREAT == 0L, uniqueN(paste(ORG, YEAR))]))
}

#' @rdname did_baseline_means
#' @export
did_composition <- function(data, k = 5L, spec = "margin", gap = 0L, keep = ~ OTHER == FALSE) {
  u <- .keep_units(data, keep)
  rs <- .design_sets(data, u, k, spec, gap, character())[[1]][[1]]
  an <- u[T_ID %in% rs$SET]
  rbindlist(lapply(intersect(did_breakout_vars(), names(an)), function(v)
    an[, list(N = .N), by = list(level = as.character(get(v)))][, var := v]))
}

utils::globalVariables(c(
  "MATCH_YEAR", "RECIP_EIN2", "DONOR_EIN2", "MERGER_YEAR", "R_OTHER_EVENTS", "D_HAS_FIRST", "D_REAL_ASSETS",
  "D_REAL_EXPENSES", "D_REAL_REVENUE", "D_MARGIN", "D_EMPLOYEES", "D_OK", "D_SURPLUS_R", "R_REAL_ASSETS", "R_MARGIN",
  "REAL_ASSETS", "REAL_EXPENSES", "REAL_REVENUE", "MARGIN", "EQUITY_RATIO", "R_ASSETS_B", "R_EZ", "NTEE_CURRENT",
  "DOSE", "DOSE_BIN", "SIZE_BAND", "i.CEO_CAT", "i.BOARD_CAT", "YEAR_GAP", "C_EIN2", "C_YEAR", "DIST", "SET", "D",
  "MY", "E", "D_N", "N_DON", "ORG", "TREAT", "W", "DY", "UNIT", "OTHER", "ASSETS", "LIABILITIES", "NET_ASSETS",
  "CASH", "LOG_EXP_ASSETS", "FUNC_EXP", "var", "level", "T_ID", "YEAR", "N"))
