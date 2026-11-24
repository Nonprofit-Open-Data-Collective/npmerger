# Evidence features added to the filing-level table from sn_filings().
# Each add_*() function takes the filing table plus the relevant 990 rows
# and returns the filing table with new columns. They are pure functions of
# their inputs, so they can be tested without downloads; get_evidence_tables()
# retrieves the inputs.

# ---- helpers -----------------------------------------------------------------

.dt <- function(x) if (is.null(x)) NULL else as.data.table(x)

.need <- function(x, cols, what) {
  miss <- setdiff(cols, names(x))
  if (length(miss)) stop(sprintf("`%s` is missing column(s): %s", what, paste(miss, collapse = ", ")), call. = FALSE)
}

.with_recip_ein2 <- function(fl) {
  fl <- as.data.table(fl)
  if (!"RECIP_EIN2" %in% names(fl)) fl[, RECIP_EIN2 := as_ein2(TOP_RECIP_EIN)]
  fl[, TAX_YEAR := as.integer(TAX_YEAR)]
  fl
}

# rows of `tab` for (ein, year + offset), returned with the pair index
.window_join <- function(pairs, ein_col, offsets, tab, keep) {
  if (is.null(tab) || !nrow(tab)) return(data.table(.PAIR = integer())[, (keep) := list()][0])
  w <- rbindlist(lapply(offsets, function(o)
    data.table(.PAIR = pairs$.PAIR, EIN2 = pairs[[ein_col]], TAX_YEAR = pairs$TAX_YEAR + o)))
  w <- w[!is.na(EIN2)]
  merge(w, tab[, c("EIN2", "TAX_YEAR", keep), with = FALSE], by = c("EIN2", "TAX_YEAR"))
}

#' Normalize person names for matching
#'
#' Upper-cases, strips punctuation, titles and suffixes (Mr, Dr, Jr, MD,
#' PhD, ...), and keeps the first and last remaining tokens, so
#' `"Dr. Jane Q. Smith, PhD"` and `"JANE SMITH"` match.
#'
#' @param x Character vector of names.
#' @return Character vector of keys (`NA` when fewer than two tokens remain).
#' @export
#' @examples
#' people <- c( "Dr. Jane Q. Smith, PhD", "JANE SMITH", "Smith" )
#'
#' person_key( people )
person_key <- function(x) {
  x <- toupper(gsub("[^A-Za-z ]", " ", as.character(x)))
  x <- gsub("\\b(MR|MRS|MS|MISS|DR|REV|HON|JR|SR|II|III|IV|MD|PHD|ESQ|CPA|RN|DDS|JD|MBA|EDD)\\b", " ", x)
  w <- strsplit(trimws(gsub(" +", " ", x)), " ")
  vapply(w, function(z) if (length(z) < 2L) NA_character_ else paste(z[1L], z[length(z)]), "")
}

#' Pattern for merger language in narrative text
#'
#' The default regular expression used to flag Schedule O narratives that
#' mention a merger. On 2021 returns it matched 33% of two-party merger
#' donors and 54% of multi-party merger donors, against 4% of closures and
#' 6% of all Schedule O filers.
#'
#' @return A single regular expression (case-insensitive use intended).
#' @export
merger_text_pattern <- function() "merge|merger|consolidat|combin|acquir|affiliat"

# ---- Part VII leadership overlap ---------------------------------------------

#' Part VII leadership overlap between donor and recipient
#'
#' Matches the people listed on the donor's Part VII in years
#' `t + donor_window` against those on the recipient's Part VII in years
#' `t + recip_window`, using the name key from [name_keys()].
#'
#' On 2019-21 data, 87% of two-party pairs that checked a Schedule N line
#' 2a-2c box shared at least one person, against 9% for closures; about 40%
#' of asset transfers with no box checked also shared people.
#'
#' @param fl Filing table from [sn_filings()] (needs `EIN2`, `TAX_YEAR`, and
#'   `TOP_RECIP_EIN` or `RECIP_EIN2`).
#' @param p7 Part VII person rows with `EIN2`, `TAX_YEAR`, and the name column.
#' @param donor_window,recip_window Year offsets from the Schedule N year.
#' @param min_shared Shared people needed to set `LEADER_P7`.
#' @param name_col Name column in `p7`.
#' @param name_key `"canonical"` or `"simple"`; see [name_keys()].
#' @return `fl` with `N_DONOR_P7`, `N_RECIP_P7`, `N_SHARED_P7`, and
#'   `LEADER_P7` (`NA` when either side has no Part VII rows in the window).
#' @export
leader_overlap <- function(fl, p7, donor_window = -1:0, recip_window = 0:1,
                           min_shared = 1L, name_col = "F9_07_COMP_DTK_NAME_PERS",
                           name_key = c("canonical", "simple")) {
  name_key <- match.arg(name_key)
  fl <- .with_recip_ein2(fl)
  for (v in c("N_DONOR_P7", "N_RECIP_P7", "N_SHARED_P7", "LEADER_P7")) if (v %in% names(fl)) fl[, (v) := NULL]
  p7 <- .dt(p7)
  .need(p7, c("EIN2", "TAX_YEAR", name_col), "p7")
  k <- unique(data.table(EIN2 = p7$EIN2, TAX_YEAR = as.integer(p7$TAX_YEAR), KEY = name_key(p7[[name_col]], name_key))[!is.na(KEY)])
  fl[, .PAIR := .I]
  pr <- fl[!is.na(RECIP_EIN2), list(.PAIR, EIN2, RECIP_EIN2, TAX_YEAR)]
  dn <- unique(.window_join(pr, "EIN2", donor_window, k, "KEY")[, list(.PAIR, KEY)])
  rn <- unique(.window_join(pr, "RECIP_EIN2", recip_window, k, "KEY")[, list(.PAIR, KEY)])
  sh <- merge(dn, rn, by = c(".PAIR", "KEY"))
  cnt <- function(x, nm) { r <- x[, .N, by = .PAIR]; data.table::setnames(r, "N", nm); r }
  fl <- Reduce(function(a, b) merge(a, b, by = ".PAIR", all.x = TRUE),
               list(fl, cnt(dn, "N_DONOR_P7"), cnt(rn, "N_RECIP_P7"), cnt(sh, "N_SHARED_P7")))
  for (v in c("N_DONOR_P7", "N_RECIP_P7", "N_SHARED_P7")) fl[is.na(get(v)), (v) := 0L]
  fl[, LEADER_P7 := fifelse(N_DONOR_P7 > 0 & N_RECIP_P7 > 0, N_SHARED_P7 >= min_shared, NA)]
  fl[, .PAIR := NULL][]
}

# ---- multi-party mergers ------------------------------------------------------

#' Count dissolving donors that share a successor
#'
#' For each Part I filing whose dominant nonprofit successor is
#' `TOP_RECIP_EIN`, counts the distinct dissolving donors with the same
#' dominant successor within `window` years. A count of 2 or more marks a
#' multi-party merger (`mergerN`) or, with a new recipient, a consolidation.
#'
#' @param fl Filing table from [sn_filings()].
#' @param window Years either side of the filing's tax year.
#' @param min_top_share A donor counts only when the successor receives at
#'   least this share of its transferred value (or is its only nonprofit
#'   recipient). Keeps large charities that collect small residual gifts
#'   from many closures from looking like serial acquirers.
#' @param final_as_termination Count Part-II-only filings with the
#'   final-return box (`FINAL_RETURN`, from [add_filing_history()]) as
#'   dissolving donors. See [merger_rules()].
#' @return `fl` with `N_DONORS` (`NA` for filings without a dominant
#'   successor).
#' @export
add_donor_counts <- function(fl, window = 1L, min_top_share = 0.75, final_as_termination = TRUE) {
  fl <- .with_recip_ein2(fl)
  if ("N_DONORS" %in% names(fl)) fl[, N_DONORS := NULL]
  fl[, .DOM := .terminated(fl, final_as_termination) & !is.na(TOP_RECIP_EIN) &
       TOP_RECIP_EIN != clean_ein(EIN2) & .one_successor(fl, min_top_share)]
  d <- unique(fl[.DOM == TRUE, list(R = TOP_RECIP_EIN, D = EIN2, Y = TAX_YEAR)])
  pairs <- merge(d, d, by = "R", allow.cartesian = TRUE, suffixes = c("", "2"))
  pairs <- pairs[abs(Y - Y2) <= window]
  n <- pairs[, list(N_DONORS = uniqueN(D2)), by = list(R, D, Y)]
  fl <- merge(fl, n, by.x = c("TOP_RECIP_EIN", "EIN2", "TAX_YEAR"), by.y = c("R", "D", "Y"), all.x = TRUE, sort = FALSE)
  fl[.DOM == FALSE, N_DONORS := NA_integer_]
  fl[, .DOM := NULL][]
}

# ---- donor and recipient filing history ---------------------------------------

#' Donor and recipient filing history
#'
#' Adds the donor's final-return flag and whether it filed again later, and
#' the recipient's formation year, whether it is newly formed, and whether
#' it filed after the merger year.
#'
#' @param fl Filing table from [sn_filings()].
#' @param header 990 header rows (`F9-P00-T00-HEADER`) for donors and
#'   recipients, with `EIN2`, `TAX_YEAR`, `OBJECTID`, `F9_00_RETURN_FINAL_X`,
#'   `F9_00_RETURN_INITIAL_X`, and `F9_00_YEAR_FORMATION`.
#' @param new_entity_years A recipient formed (or filing an initial return)
#'   within this many years before the merger year counts as new.
#' @return `fl` with `FINAL_RETURN`, `DONOR_FILES_LATER`, `R_FORMED`,
#'   `R_INITIAL_NEAR`, `R_NEW`, `R_IN_EFILE`, and `R_FILES_LATER`.
#' @export
add_filing_history <- function(fl, header, new_entity_years = 1L) {
  fl <- .with_recip_ein2(fl)
  h <- .dt(header)
  .need(h, c("EIN2", "TAX_YEAR", "OBJECTID", "F9_00_RETURN_FINAL_X", "F9_00_RETURN_INITIAL_X", "F9_00_YEAR_FORMATION"), "header")
  h <- data.table(EIN2 = h$EIN2, TAX_YEAR = as.integer(h$TAX_YEAR), OBJECTID = h$OBJECTID,
                  FINAL = sn_flag(h$F9_00_RETURN_FINAL_X, FALSE), INITIAL = sn_flag(h$F9_00_RETURN_INITIAL_X, FALSE),
                  FORMED = suppressWarnings(as.integer(h$F9_00_YEAR_FORMATION)))
  h[!(FORMED %between% c(1600L, 2100L)), FORMED := NA_integer_]
  span <- h[, list(LAST = max(TAX_YEAR), FORMED = if (all(is.na(FORMED))) NA_integer_ else min(FORMED, na.rm = TRUE)), by = EIN2]
  drop <- intersect(c("FINAL_RETURN", "DONOR_FILES_LATER", "R_FORMED", "R_INITIAL_NEAR", "R_NEW", "R_IN_EFILE", "R_FILES_LATER"), names(fl))
  if (length(drop)) fl[, (drop) := NULL]
  fl[, FINAL_RETURN := OBJECTID %in% h[FINAL == TRUE, OBJECTID]]
  fl[, DONOR_FILES_LATER := span$LAST[match(EIN2, span$EIN2)] > TAX_YEAR]
  ri <- match(fl$RECIP_EIN2, span$EIN2)
  fl[, `:=`(R_FORMED = span$FORMED[ri], R_IN_EFILE = !is.na(ri), R_FILES_LATER = span$LAST[ri] > TAX_YEAR)]
  init <- h[INITIAL == TRUE, list(EIN2, IY = TAX_YEAR)]
  fl[, .PAIR := .I]
  near <- merge(fl[!is.na(RECIP_EIN2), list(.PAIR, EIN2 = RECIP_EIN2, TAX_YEAR)], init, by = "EIN2")
  near <- near[IY >= TAX_YEAR - new_entity_years & IY <= TAX_YEAR + 1L, unique(.PAIR)]
  fl[, R_INITIAL_NEAR := .PAIR %in% near]
  fl[, R_NEW := (!is.na(R_FORMED) & R_FORMED >= TAX_YEAR - new_entity_years) | R_INITIAL_NEAR]
  fl[is.na(RECIP_EIN2), `:=`(R_NEW = NA, R_INITIAL_NEAR = NA, R_IN_EFILE = NA)]
  fl[, .PAIR := NULL][]
}

# ---- corroborating disclosures -----------------------------------------------

#' Corroborating merger disclosures
#'
#' Flags Schedule O merger language on the donor's and the recipient's
#' returns, and a significant change to the recipient's governing documents
#' (Part VI line 4). With `merger_rules(promote = TRUE)`, [classify_transactions()] promotes an asset transfer to
#' a merger when at least two of these agree (see [merger_rules()]).
#'
#' @param fl Filing table from [sn_filings()].
#' @param so Schedule O rows with `EIN2`, `TAX_YEAR`, `SO_00_EXPLANATION_TEXT`.
#' @param p6 Part VI rows with `EIN2`, `TAX_YEAR`, `F9_06_GVRN_CHANGE_DOC_X`.
#' @param pattern Regular expression for merger language.
#' @param so_recip_window,gov_window Year offsets for the recipient checks.
#' @return `fl` with `SO_MERGER_TEXT_DONOR`, `SO_MERGER_TEXT_RECIP`, and
#'   `GOV_DOC_CHANGE_RECIP`.
#' @export
add_corroboration <- function(fl, so = NULL, p6 = NULL, pattern = merger_text_pattern(),
                              so_recip_window = 0L, gov_window = 0:1) {
  fl <- .with_recip_ein2(fl)
  fl[, .PAIR := .I]
  pr <- fl[, list(.PAIR, EIN2, RECIP_EIN2, TAX_YEAR)]
  if (!is.null(so)) {
    so <- .dt(so); .need(so, c("EIN2", "TAX_YEAR", "SO_00_EXPLANATION_TEXT"), "so")
    hit <- unique(data.table(EIN2 = so$EIN2, TAX_YEAR = as.integer(so$TAX_YEAR))[
      grepl(pattern, so$SO_00_EXPLANATION_TEXT, ignore.case = TRUE)])
    hit[, HIT := TRUE]
    fl[, SO_MERGER_TEXT_DONOR := .PAIR %in% .window_join(pr, "EIN2", 0L, hit, "HIT")$.PAIR]
    fl[, SO_MERGER_TEXT_RECIP := .PAIR %in% .window_join(pr, "RECIP_EIN2", so_recip_window, hit, "HIT")$.PAIR]
  }
  if (!is.null(p6)) {
    p6 <- .dt(p6); .need(p6, c("EIN2", "TAX_YEAR", "F9_06_GVRN_CHANGE_DOC_X"), "p6")
    chg <- unique(data.table(EIN2 = p6$EIN2, TAX_YEAR = as.integer(p6$TAX_YEAR))[
      sn_flag(p6$F9_06_GVRN_CHANGE_DOC_X, FALSE)])
    chg[, HIT := TRUE]
    fl[, GOV_DOC_CHANGE_RECIP := .PAIR %in% .window_join(pr, "RECIP_EIN2", gov_window, chg, "HIT")$.PAIR]
  }
  fl[, .PAIR := NULL][]
}

# ---- affiliation ----------------------------------------------------------------

#' Affiliation between donor and recipient
#'
#' Records whether the donor and recipient belong to one family of
#' organizations. This is kept separate from the transaction label: about a
#' third of two-party mergers and two-thirds of multi-party mergers in
#' 2019-21 were between affiliated organizations.
#'
#' @param fl Filing table from [sn_filings()].
#' @param sr Schedule R Part II rows (`SR-P02-T01-ID-RLTD-TAX-EXEMPED-ORGS`)
#'   with `EIN2` and `SR_02_RLTD_ORG_EIN`.
#' @param sa Schedule A Part I rows with `EIN2` and
#'   `SA_01_PCSTAT_SUPPORT_ORG_X`.
#' @param header Header rows with `EIN2` and `F9_00_GROUP_EXEMPT_NUM`.
#' @return `fl` with `AFF_SCHED_R`, `AFF_SUPPORT_ORG`, `AFF_GROUP`, and
#'   `AFFILIATED` (any of the three).
#' @export
add_affiliation <- function(fl, sr = NULL, sa = NULL, header = NULL) {
  fl <- .with_recip_ein2(fl)
  fl[, `:=`(AFF_SCHED_R = FALSE, AFF_SUPPORT_ORG = FALSE, AFF_GROUP = FALSE)]
  if (!is.null(sr)) {
    sr <- .dt(sr); .need(sr, c("EIN2", "SR_02_RLTD_ORG_EIN"), "sr")
    links <- unique(paste(sr$EIN2, as_ein2(sr$SR_02_RLTD_ORG_EIN)))
    fl[, AFF_SCHED_R := !is.na(RECIP_EIN2) & (paste(EIN2, RECIP_EIN2) %in% links | paste(RECIP_EIN2, EIN2) %in% links)]
  }
  if (!is.null(sa)) {
    sa <- .dt(sa); .need(sa, c("EIN2", "SA_01_PCSTAT_SUPPORT_ORG_X"), "sa")
    fl[, AFF_SUPPORT_ORG := EIN2 %in% sa$EIN2[sn_flag(sa$SA_01_PCSTAT_SUPPORT_ORG_X, FALSE)]]
  }
  if (!is.null(header) && "F9_00_GROUP_EXEMPT_NUM" %in% names(header)) {
    h <- .dt(header)
    g <- unique(data.table(EIN2 = h$EIN2, G = gsub("[^0-9]", "", h$F9_00_GROUP_EXEMPT_NUM)))
    g <- g[!is.na(G) & nzchar(G) & as.numeric(G) > 0]
    gd <- g[, list(G = list(G)), by = EIN2]
    dg <- gd$G[match(fl$EIN2, gd$EIN2)]; rg <- gd$G[match(fl$RECIP_EIN2, gd$EIN2)]
    fl[, AFF_GROUP := mapply(function(a, b) length(a) > 0 && length(b) > 0 && length(intersect(a, b)) > 0, dg, rg)]
  }
  fl[, AFFILIATED := AFF_SCHED_R | AFF_SUPPORT_ORG | AFF_GROUP][]
}

# ---- mission similarity -----------------------------------------------------------

#' Mission-statement similarity between donor and recipient
#'
#' Jaccard similarity of the word sets (words longer than three letters) in
#' the donor's and recipient's mission statements. Descriptive only: it
#' does not count toward promotion. Median similarity in 2019-21 was .07
#' for two-party mergers and .03 for asset transfers; random pairs score 0.
#'
#' @param fl Filing table from [sn_filings()].
#' @param mission Rows with `EIN2` and a mission text column.
#' @param text_col Mission text column.
#' @return `fl` with `MISSION_SIM`.
#' @export
add_mission_similarity <- function(fl, mission, text_col = "F9_03_ORG_MISSION_PURPOSE") {
  fl <- .with_recip_ein2(fl)
  m <- .dt(mission); .need(m, c("EIN2", text_col), "mission")
  m <- m[!is.na(get(text_col)) & nzchar(get(text_col)), list(TXT = get(text_col)[1L]), by = EIN2]
  tok <- function(x) { w <- unique(strsplit(gsub("[^a-z ]", " ", tolower(x)), " +")[[1L]]); w[nchar(w) > 3L] }
  words <- stats::setNames(lapply(m$TXT, tok), m$EIN2)
  jac <- function(a, b) {
    A <- words[[a]]; B <- words[[b]]
    if (is.null(A) || is.null(B) || !length(A) || !length(B)) return(NA_real_)
    length(intersect(A, B)) / length(union(A, B))
  }
  fl[, MISSION_SIM := mapply(function(a, b) if (is.na(b)) NA_real_ else jac(a, b), EIN2, RECIP_EIN2, USE.NAMES = FALSE)][]
}

utils::globalVariables(c(
  ".PAIR", ".DOM", "KEY", "RECIP_EIN2", "N_DONOR_P7", "N_RECIP_P7", "N_SHARED_P7", "R", "D", "Y", "Y2", "D2",
  "FINAL", "INITIAL", "FORMED", "LAST", "IY", "FINAL_RETURN", "R_FORMED", "R_INITIAL_NEAR", "R_IN_EFILE",
  "R_FILES_LATER", "HIT", "SO_MERGER_TEXT_DONOR", "SO_MERGER_TEXT_RECIP", "GOV_DOC_CHANGE_RECIP",
  "AFF_SCHED_R", "AFF_SUPPORT_ORG", "AFF_GROUP", "AFFILIATED", "G", "TXT", "MISSION_SIM"
))
