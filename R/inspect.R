#' Schedule N checkbox fields
#'
#' The yes/no questions on Schedule N, as column suffixes in the raw
#' header tables (`SN_01_ORG_...` for Part I, `SN_02_ORG_...` for Part II).
#' Lines 2a-2d appear in both parts; the rest only in Part I.
#' @return A named character vector: output column name = raw suffix.
#' @export
#' @examples
#' sn_checkboxes()
sn_checkboxes <- function() {
  c(DIR_SUCCESSOR_X        = "DTK_DIR_SUCCESSOR_X",       # 2a director/trustee/officer of successor
    EMPL_SUCCESSOR_X       = "DTK_EMPL_SUCCESSOR_X",      # 2b employee of successor
    OWN_SUCCESSOR_X        = "DTK_OWN_SUCCESSOR_X",       # 2c owner of successor
    REC_COMP_X             = "DTK_REC_COMP_X",            # 2d receives compensation from successor
    ASSET_DIST_GVRN_X      = "ASSET_DIST_GVRN_X",         # 3 distribution under governing documents
    REQ_NOTIFY_ATTORNEY_X  = "REQ_NOTIFY_ATTORNEY_X",     # 4a required to notify attorney general
    ATTORNEY_NOTIFIED_X    = "ATTORNEY_NOTIFIED_X",       # 4b attorney general notified
    LIAB_PAID_X            = "LIAB_PAID_X",               # 5 all liabilities paid
    BOND_OUTSTANDING_X     = "BOND_OUTSTANDING_X",        # 6a tax-exempt bonds outstanding
    BOND_LIAB_DISCHARGED_X = "BOND_LIAB_DISCHARGED_X")    # 6b bond liabilities discharged
}

#' Labeled Schedule N table for inspection
#'
#' Stacks Schedule N Part I and Part II asset lines into one tidy table: one
#' row per asset line, with the part's checkbox answers as extra columns,
#' the filing's classifier label and key evidence, and a flag on the line(s)
#' that go to the merger recipient. A filing part with a header but no asset
#' lines gets one row with empty asset fields, so every labeled filing
#' appears.
#'
#' @param sn An `sn_raw` object from [get_schedule_n()].
#' @param labeled The labeled filing table, [sched_n_table()] (the `sched_n`
#'   element of [build_merger_data()]).
#' @param cases Optional merger cases from [build_merger_cases()] (the
#'   `cases` element). Used to name the merger recipient of each donor
#'   filing.
#' @param transactions Optional asset lines with recovered recipient EINs
#'   (the `transactions` element). Used when its rows line up with
#'   `sn_transactions(sn)`; otherwise only reported EINs are used.
#' @param label_cols Columns of `labeled` to carry onto every row.
#' @return A data.table with filing columns (`OBJECTID`, `EIN2`, `ORG_NAME`,
#'   `TAX_YEAR`, `TAX_PERIOD_END`, `URL`, the `label_cols`, `MERGER_ID`,
#'   `MERGER_RECIP_EIN2`, `HAS_RECIPIENT_ROW`, `P3_TEXT`), line columns
#'   (`PART`, `LINE`, `ASSET_DESC`, `DIST_DATE`, `FMV`, `FMV_METHOD`,
#'   `RECIP_EIN2`, `EIN_SOURCE`, `RECIP_NAME`, `RECIP_CITY`, `RECIP_STATE`,
#'   `RECIP_ZIP`, `IRC_SECTION`, `RECIP_TYPE`, `SELF_TRANSFER`,
#'   `IS_MERGER_RECIPIENT`), and the checkbox columns in [sn_checkboxes()]
#'   (`NA` where the part does not ask the question).
#' @seealso [sn_inspection()] to draw review samples.
#' @export
sn_labeled <- function(sn, labeled, cases = NULL, transactions = NULL,
                       label_cols = c("TYPE", "BASIS", "AFFILIATED", "TERMINATED", "FINAL_RETURN", "LEADER",
                                      "LEADER_SN", "LEADER_P7", "SN_MERGER_TEXT", "N_CORROBORATE", "N_NP_RECIP",
                                      "TOP_SHARE", "FMV_TOTAL", "N_DONORS", "R_NEW")) {
  lab <- as.data.table(labeled)
  label_cols <- intersect(label_cols, names(lab))
  chr <- function(x, v) if (!is.null(x) && v %in% names(x)) as.character(x[[v]]) else rep(NA_character_, NROW(x))

  # asset lines, in sn_transactions() order (Part I rows, then Part II rows)
  tx <- sn_transactions(sn)
  tx[, RECIP_CITY := c(chr(sn$p1_assets, "SN_01_LTD_RECIP_ADDR_CITY"), chr(sn$p2_assets, "SN_02_DOA_RECIP_ADDR_CITY"))]
  tx[, EIN_SOURCE := fifelse(is.na(RECIP_EIN), NA_character_, "reported")]
  if (!is.null(transactions)) {
    t2 <- as.data.table(transactions)
    if (nrow(t2) == nrow(tx) && identical(t2$OBJECTID, tx$OBJECTID) && "RECIP_EIN" %in% names(t2)) {
      tx[, RECIP_EIN := t2$RECIP_EIN]
      if ("EIN_SOURCE" %in% names(t2)) tx[, EIN_SOURCE := t2$EIN_SOURCE]
    } else warning("`transactions` does not line up with sn_transactions(sn); using reported recipient EINs only.", call. = FALSE)
  }
  tx[, LINE := seq_len(.N), by = list(OBJECTID, PART)]

  # checkbox answers, one row per filing and part
  hdr <- function(x, part) {
    if (is.null(x) || !nrow(x)) return(NULL)
    p <- sprintf("SN_%02d_ORG_", part)
    out <- data.table(OBJECTID = x$OBJECTID, EIN2 = x$EIN2, TAX_YEAR = as.integer(x$TAX_YEAR), PART = part)
    for (nm in names(sn_checkboxes())) out[, (nm) := sn_flag(chr(x, paste0(p, sn_checkboxes()[[nm]])))]
    out[!duplicated(out[, list(OBJECTID, PART)])]
  }
  cb <- rbindlist(list(hdr(sn$p1_header, 1L), hdr(sn$p2_header, 2L)), fill = TRUE)
  if (!nrow(cb)) cb <- data.table(OBJECTID = character(), EIN2 = character(), TAX_YEAR = integer(), PART = integer())

  # header-only parts get one empty line
  empty <- cb[!tx, on = c("OBJECTID", "PART"), list(OBJECTID, EIN2, TAX_YEAR, PART)]
  x <- rbindlist(list(tx, empty), fill = TRUE)
  x[is.na(LINE), LINE := 0L]
  x <- merge(x, cb[, !c("EIN2", "TAX_YEAR")], by = c("OBJECTID", "PART"), all.x = TRUE, sort = FALSE)
  x <- x[OBJECTID %in% lab$OBJECTID]

  # filing-level facts: name, period, URL, Part III text, label
  ids <- rbindlist(lapply(sn[intersect(c("p1_header", "p2_header", "p1_assets", "p2_assets"), names(sn))], function(t)
    if (is.null(t) || !nrow(t)) NULL else data.table(OBJECTID = t$OBJECTID, ORG_NAME = chr(t, "ORG_NAME_L1"),
                                                      TAX_PERIOD_END = chr(t, "TAX_PERIOD_END_DATE"), URL = chr(t, "URL"))))
  ids <- ids[!duplicated(OBJECTID)]
  p3 <- sn$p3_text
  if (!is.null(p3) && nrow(p3) && "SN_03_EXPLANATION_TEXT" %in% names(p3)) {
    p3 <- data.table(OBJECTID = p3$OBJECTID, REF = chr(p3, "SN_03_FORM_LINE_REFERENCE"), TXT = chr(p3, "SN_03_EXPLANATION_TEXT"))
    p3 <- p3[!is.na(TXT) & nzchar(trimws(TXT)),
             list(P3_TEXT = paste(fifelse(is.na(REF), TXT, paste0(REF, ": ", TXT)), collapse = " | ")), by = OBJECTID]
  } else p3 <- data.table(OBJECTID = character(), P3_TEXT = character())
  fl <- lab[, c("OBJECTID", label_cols), with = FALSE]
  fl <- merge(fl, ids, by = "OBJECTID", all.x = TRUE)
  fl <- merge(fl, p3, by = "OBJECTID", all.x = TRUE)
  if (!is.null(cases) && nrow(cases)) {
    cs <- as.data.table(cases)[!is.na(DONOR_OBJECTID), list(OBJECTID = DONOR_OBJECTID, MERGER_ID, MERGER_RECIP_EIN2 = RECIP_EIN2)]
    fl <- merge(fl, cs[!duplicated(OBJECTID)], by = "OBJECTID", all.x = TRUE)
  } else fl[, `:=`(MERGER_ID = NA_character_, MERGER_RECIP_EIN2 = NA_character_)]
  x <- merge(x, fl, by = "OBJECTID", all.x = TRUE, sort = FALSE)

  x[, RECIP_EIN2 := as_ein2(RECIP_EIN)]
  x[, IS_MERGER_RECIPIENT := !is.na(MERGER_RECIP_EIN2) & !is.na(RECIP_EIN2) & RECIP_EIN2 == MERGER_RECIP_EIN2]
  x[, HAS_RECIPIENT_ROW := any(IS_MERGER_RECIPIENT), by = OBJECTID]
  x[is.na(MERGER_RECIP_EIN2), HAS_RECIPIENT_ROW := NA]

  first <- c("OBJECTID", "EIN2", "ORG_NAME", "TAX_YEAR", "TAX_PERIOD_END", label_cols, "MERGER_ID", "MERGER_RECIP_EIN2",
             "HAS_RECIPIENT_ROW", "PART", "LINE", "IS_MERGER_RECIPIENT", "ASSET_DESC", "DIST_DATE", "FMV", "FMV_METHOD",
             "RECIP_EIN2", "EIN_SOURCE", "RECIP_NAME", "RECIP_CITY", "RECIP_STATE", "RECIP_ZIP", "IRC_SECTION",
             "RECIP_TYPE", "SELF_TRANSFER", intersect(names(sn_checkboxes()), names(x)), "P3_TEXT", "URL")
  for (nm in setdiff(names(sn_checkboxes()), names(x))) x[, (nm) := NA]
  first <- unique(c(first, names(sn_checkboxes())))
  x <- x[, first, with = FALSE]
  ord <- match(x$TYPE, transaction_types())
  x <- x[order(ord, OBJECTID, PART, LINE)]
  x[]
}

#' Draw inspection samples from the labeled Schedule N table
#'
#' Samples labeled filings, stratified by classifier label, and returns
#' every row of each sampled filing. With `num` greater than 1, the tables
#' do not share filings, so they can go to different reviewers.
#'
#' @param x A table from [sn_labeled()].
#' @param num Number of inspection tables.
#' @param n Filings (cases) per table.
#' @param types Labels to sample. Default: every label in `x`.
#' @param per_type Optional named integer vector of filings per label in
#'   each table (overrides the even split of `n`).
#' @param seed Random seed, or `NULL` to leave the seed alone.
#' @param review_cols Add empty review columns (`REVIEW_TYPE`,
#'   `REVIEW_IS_MERGER`, `REVIEW_RECIPIENT_OK`, `REVIEW_NOTE`).
#' @return A list of `num` data.tables. Each has `TABLE` and `CASE` (1..n)
#'   in front of the [sn_labeled()] columns, sorted by label, case, part,
#'   and line.
#' @export
#' @examples
#' \dontrun{
#' sn <- get_schedule_n( efile_years() )
#' md <- build_merger_data( sn = sn )
#'
#' lab <-
#'   sn_labeled(
#'     sn,
#'     md$sched_n,
#'     md$cases,
#'     md$transactions
#'   )
#'
#' # three stratified samples of 100 filings each
#' tabs <- sn_inspection( lab, num = 3, n = 100 )
#'
#' data.table::fwrite( tabs[[1]], "inspection-01.csv" )
#' }
sn_inspection <- function(x, num = 1L, n = 100L, types = NULL, per_type = NULL, seed = 1L, review_cols = TRUE) {
  x <- as.data.table(x)
  fl <- unique(x[, list(OBJECTID, TYPE)])
  types <- types %||% intersect(c(transaction_types(), sort(unique(fl$TYPE))), unique(fl$TYPE))
  if (is.null(per_type)) {
    k <- length(types)
    per_type <- stats::setNames(rep(n %/% k, k) + c(rep(1L, n %% k), rep(0L, k - n %% k)), types)
  } else types <- names(per_type)
  if (!is.null(seed)) set.seed(seed)
  draw <- rbindlist(lapply(types, function(t) {
    ids <- fl$OBJECTID[fl$TYPE == t]
    need <- per_type[[t]] * num
    if (length(ids) < need) warning(sprintf("Only %d '%s' filings for %d requested; using all of them.", length(ids), t, need), call. = FALSE)
    ids <- if (length(ids) > 1L) sample(ids, min(need, length(ids))) else ids[seq_len(min(need, length(ids)))]
    data.table(OBJECTID = ids, TABLE = rep(seq_len(num), each = per_type[[t]])[seq_along(ids)])
  }))
  lapply(seq_len(num), function(i) {
    d <- draw[TABLE == i]
    out <- merge(d, x, by = "OBJECTID", sort = FALSE)
    out <- out[order(match(TYPE, transaction_types()), OBJECTID, PART, LINE)]
    out[, CASE := match(OBJECTID, unique(OBJECTID))]
    data.table::setcolorder(out, c("TABLE", "CASE"))
    if (review_cols) out[, `:=`(REVIEW_TYPE = NA_character_, REVIEW_IS_MERGER = NA, REVIEW_RECIPIENT_OK = NA, REVIEW_NOTE = NA_character_)]
    out[]
  })
}

utils::globalVariables(c("RECIP_CITY", "LINE", "IS_MERGER_RECIPIENT", "HAS_RECIPIENT_ROW", "MERGER_RECIP_EIN2",
                         "RECIP_EIN2", "REF", "TXT", "P3_TEXT", "TABLE", "CASE", "DONOR_OBJECTID", "REVIEW_TYPE",
                         "REVIEW_IS_MERGER", "REVIEW_RECIPIENT_OK", "REVIEW_NOTE"))
