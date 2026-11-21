#' Retrieve BMF organization traits for merger organizations
#'
#' Thin wrapper around [panel990::bmf_retrieve()] for a set of EINs. The BMF
#' supplies NTEE codes and IRS ruling dates for [merger_attributes()].
#'
#' @param eins EINs (any format).
#' @param path,verbose Passed to [panel990::bmf_retrieve()].
#' @param ... Further arguments to [panel990::bmf_retrieve()].
#' @return A data.table with one row per `EIN2`.
#' @export
get_bmf <- function(eins, path = "PANEL990", verbose = TRUE, ...) {
  b <- panel990::bmf_retrieve(eins = unique(stats::na.omit(as_ein2(eins))), path = path, verbose = verbose, ...)
  b <- as.data.table(b)
  if ("EIN2" %in% names(b)) b <- b[!duplicated(EIN2)]
  b[]
}

# find the first matching column name in a BMF table
.bmf_col <- function(b, patterns) {
  for (p in patterns) { hit <- grep(p, names(b), ignore.case = TRUE, value = TRUE); if (length(hit)) return(hit[1L]) }
  NA_character_
}

.bmf_traits <- function(bmf) {
  if (is.null(bmf) || !nrow(bmf)) return(NULL)
  b <- as.data.table(bmf)
  ntee <- .bmf_col(b, c("^ntee_code_clean$", "^ntee_irs$", "^ntee_cd$", "^ntee_code$", "^ntee$"))
  nv2  <- .bmf_col(b, c("^nteev2$"))
  rule <- .bmf_col(b, c("^ruling_year$", "^ruling_date$", "ruling"))
  sub  <- .bmf_col(b, c("^subsection_code$", "^bmf_subsection_code$", "subsection"))
  out <- data.table(EIN2 = b$EIN2,
                    NTEE = if (!is.na(ntee)) as.character(b[[ntee]]) else NA_character_,
                    NTEEV2 = if (!is.na(nv2)) as.character(b[[nv2]]) else NA_character_,
                    RULING_YEAR = if (!is.na(rule)) suppressWarnings(as.integer(substr(gsub("[^0-9]", "", b[[rule]]), 1, 4))) else NA_integer_,
                    SUBSECTION = if (!is.na(sub)) as.character(b[[sub]]) else NA_character_)
  out[NTEE == "", NTEE := NA_character_]
  out[!(RULING_YEAR %between% c(1800L, 2100L)), RULING_YEAR := NA_integer_]
  out[, NTEE_MAJOR := substr(NTEE, 1, 1)]
  out[!duplicated(EIN2)]
}

#' Donor and recipient attribute tables
#'
#' One row per merger with the attributes of one side of it:
#'
#' * identifiers: `MERGER_ID`, `MERGER_GROUP_ID`, `ROLE`, `EIN2`;
#' * `SN_YEAR` (the donor's Schedule N year) and `REF_YEAR` (time 0 on this
#'   organization's fiscal calendar);
#' * name and address from the latest return filed in or before `REF_YEAR`;
#' * `FORMATION_YEAR` (990 header), `RULING_YEAR` (BMF), and `AGE`
#'   (`SN_YEAR` minus the earlier of the two);
#' * `NTEE`, `NTEE_MAJOR`, `NTEEV2`, `SUBSECTION` (BMF; organizations that
#'   have dissolved are often missing from the current BMF);
#' * `REVENUE`, `EXPENSES`, and `ASSETS` for `REF_YEAR - years_back` through
#'   `REF_YEAR`, in wide form (`REVENUE_T0`, `REVENUE_TM1`, ...), plus
#'   `N_YEARS_OBSERVED`.
#'
#' @param cases Output of [build_merger_cases()].
#' @param oy Organization-year table from [org_years()].
#' @param role `"donor"` or `"recipient"`.
#' @param years_back Years before `REF_YEAR` to include (4 gives five years).
#' @param bmf Optional BMF table from [get_bmf()].
#' @return A data.table, one row per `MERGER_ID`.
#' @export
merger_attributes <- function(cases, oy, role = c("donor", "recipient"), years_back = 4L, bmf = NULL) {
  role <- match.arg(role)
  cs <- as.data.table(cases)
  r <- merger_roles(cs)[ROLE == role]
  r <- merge(r, cs[, list(MERGER_ID, SN_YEAR = MERGER_YEAR)], by = "MERGER_ID")
  data.table::setnames(r, "EVENT_YEAR", "REF_YEAR")
  oy <- as.data.table(oy)
  # name and address: latest return at or before REF_YEAR, else earliest after
  addr_cols <- c(NAME = "ORG_NAME_L1", ADDRESS = "F9_00_ORG_ADDR_L1", CITY = "F9_00_ORG_ADDR_CITY",
                 STATE = "F9_00_ORG_ADDR_STATE", ZIP = "F9_00_ORG_ADDR_ZIP", RETURN_TYPE = "RETURN_TYPE",
                 FORMATION_YEAR = "F9_00_YEAR_FORMATION")
  have <- addr_cols[addr_cols %in% names(oy)]
  a <- oy[, c("EIN2", "TAX_YEAR", unname(have)), with = FALSE]
  data.table::setnames(a, unname(have), names(have))
  if ("FORMATION_YEAR" %in% names(a)) {
    a[, FORMATION_YEAR := suppressWarnings(as.integer(FORMATION_YEAR))]
    a[!(FORMATION_YEAR %between% c(1600L, 2100L)), FORMATION_YEAR := NA_integer_]
    fy <- a[, list(FY = if (all(is.na(FORMATION_YEAR))) NA_integer_ else min(FORMATION_YEAR, na.rm = TRUE)), by = EIN2]
    a[, FORMATION_YEAR := NULL]
  } else fy <- data.table(EIN2 = character(), FY = integer())
  ra <- merge(r[, list(MERGER_ID, EIN2, REF_YEAR)], a, by = "EIN2", allow.cartesian = TRUE)
  ra[, `:=`(.PRE = TAX_YEAR <= REF_YEAR, .DIST = abs(TAX_YEAR - REF_YEAR))]
  data.table::setorderv(ra, c("MERGER_ID", ".PRE", ".DIST"), c(1L, -1L, 1L))
  ra <- ra[!duplicated(MERGER_ID)][, c("EIN2", "REF_YEAR", "TAX_YEAR", ".PRE", ".DIST") := NULL]
  out <- merge(r, ra, by = "MERGER_ID", all.x = TRUE)
  out <- merge(out, fy[, list(EIN2, FORMATION_YEAR = FY)], by = "EIN2", all.x = TRUE)
  tr <- .bmf_traits(bmf)
  if (!is.null(tr)) out <- merge(out, tr, by = "EIN2", all.x = TRUE)
  else out[, `:=`(NTEE = NA_character_, NTEE_MAJOR = NA_character_, NTEEV2 = NA_character_, RULING_YEAR = NA_integer_, SUBSECTION = NA_character_)]
  out[, AGE := SN_YEAR - pmin(FORMATION_YEAR, RULING_YEAR, na.rm = TRUE)]
  # size: t-years_back .. t, wide
  off <- seq.int(-years_back, 0L)
  w <- rbindlist(lapply(off, function(o) r[, list(MERGER_ID, EIN2, TAX_YEAR = REF_YEAR + o, OFF = o)]))
  w <- merge(w, oy[, list(EIN2, TAX_YEAR, REVENUE, EXPENSES, ASSETS)], by = c("EIN2", "TAX_YEAR"), all.x = TRUE)
  nobs <- w[, list(N_YEARS_OBSERVED = sum(!is.na(REVENUE) | !is.na(ASSETS))), by = MERGER_ID]
  w[, LAB := fifelse(OFF == 0L, "T0", paste0("TM", -OFF))]
  wide <- data.table::dcast(w, MERGER_ID ~ LAB, value.var = c("REVENUE", "EXPENSES", "ASSETS"))
  ord <- paste0(rep(c("REVENUE", "EXPENSES", "ASSETS"), each = length(off)), "_", c("T0", paste0("TM", seq_len(years_back))))
  data.table::setcolorder(wide, c("MERGER_ID", intersect(ord, names(wide))))
  out <- merge(out, nobs, by = "MERGER_ID", all.x = TRUE)
  out <- merge(out, wide, by = "MERGER_ID", all.x = TRUE)
  first <- c("MERGER_ID", "MERGER_GROUP_ID", "ROLE", "EIN2", "SN_YEAR", "REF_YEAR", "NAME", "ADDRESS", "CITY",
             "STATE", "ZIP", "RETURN_TYPE", "FORMATION_YEAR", "RULING_YEAR", "AGE", "NTEE", "NTEE_MAJOR", "NTEEV2", "SUBSECTION",
             "N_YEARS_OBSERVED")
  data.table::setcolorder(out, intersect(first, names(out)))
  data.table::setorderv(out, c("SN_YEAR", "MERGER_ID"))
  out[]
}

utils::globalVariables(c("ROLE", "EVENT_YEAR", "SN_YEAR", "REF_YEAR", "FORMATION_YEAR", "FY", ".PRE", ".DIST",
                         "NTEE", "NTEE_MAJOR", "RULING_YEAR", "AGE", "OFF", "LAB", "ASSETS", "N_YEARS_OBSERVED"))
