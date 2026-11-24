#' Normalize organization names for matching
#'
#' Upper-cases, replaces `&` with `AND`, strips punctuation, and drops
#' leading `THE` and legal suffixes (`INC`, `CORP`, `LLC`, ...). Program
#' words such as `FOUNDATION` are kept, since they distinguish
#' organizations.
#'
#' @param x Character vector of names.
#' @return Character vector of keys (`NA` for blank names).
#' @export
#' @examples
#' orgs <- c( "The Arc of Maine, Inc.", "ARC OF MAINE",
#'            "Smith & Jones Co." )
#'
#' org_name_key( orgs )
org_name_key <- function(x) {
  u <- toupper(as.character(x))
  u <- gsub("&", " AND ", u, fixed = TRUE)
  u <- gsub("[^A-Z0-9 ]", " ", u)
  u <- gsub("\\b(INC|INCORPORATED|CORP|CORPORATION|CO|LLC|LTD|LIMITED|PC|NFP|NP)\\b", " ", u)
  u <- trimws(gsub(" +", " ", u))
  u <- sub("^THE ", "", u)
  u[!nzchar(u)] <- NA_character_
  u
}

#' Name index of 990 filers
#'
#' Reads name and address fields from the 990 header for the given years
#' (no EIN filter) to support [recover_recipient_ein()].
#'
#' @param years Tax years.
#' @param path,source,verbose Passed to [panel990::download_tables()].
#' @return A data.table with `EIN2`, `TAX_YEAR`, `NAME_KEY`, `ZIP5`, `STATE`,
#'   one row per distinct combination.
#' @export
get_name_index <- function(years, path = "PANEL990", source = panel990::data_source(), verbose = TRUE) {
  dl <- panel990::download_tables(years = years, tables = "F9-P00-T00-HEADER", source = source, path = path, verbose = verbose)
  rd <- panel990::read_tables(dl, columns = c("EIN2", "OBJECTID", "TAX_YEAR", "ORG_NAME_L1", "F9_00_ORG_ADDR_ZIP", "F9_00_ORG_ADDR_STATE"),
                              unique_rows = FALSE, verbose = FALSE)
  h <- rbindlist(lapply(rd$tables, as.data.table), fill = TRUE)
  name_index(h)
}

#' @rdname get_name_index
#' @param header Header rows with `EIN2`, `TAX_YEAR`, `ORG_NAME_L1`,
#'   `F9_00_ORG_ADDR_ZIP`, `F9_00_ORG_ADDR_STATE`.
#' @export
name_index <- function(header) {
  h <- as.data.table(header)
  unique(data.table(EIN2 = h$EIN2, TAX_YEAR = as.integer(h$TAX_YEAR), NAME_KEY = org_name_key(h$ORG_NAME_L1),
                    ZIP5 = substr(gsub("[^0-9]", "", h$F9_00_ORG_ADDR_ZIP), 1, 5), STATE = toupper(h$F9_00_ORG_ADDR_STATE))[!is.na(NAME_KEY)])
}

#' Recover missing recipient EINs by name and location
#'
#' About 28% of Schedule N recipient lines have no usable EIN. For lines
#' whose recipient is not an individual or business, this looks the
#' recipient's name up in an index of 990 filers. It accepts a match only
#' when exactly one EIN carries that normalized name in the same ZIP code,
#' or failing that, in the same state.
#'
#' @param tx Output of [sn_transactions()].
#' @param names A name index from [get_name_index()] or [name_index()].
#' @param types Recipient types eligible for recovery.
#' @return `tx` with recovered `RECIP_EIN` values and an `EIN_SOURCE` column
#'   (`"reported"`, `"name_zip"`, `"name_state"`, or `NA`). Recovered lines
#'   with an unknown type become `"unknown_with_ein"`.
#' @export
recover_recipient_ein <- function(tx, names, types = c("501c3", "other_exempt", "unknown", "other", "government")) {
  tx <- data.table::copy(as.data.table(tx))
  nx <- as.data.table(names)
  tx[, EIN_SOURCE := fifelse(!is.na(RECIP_EIN), "reported", NA_character_)]
  tx[, ROW_ID_ := .I]
  cand <- tx[is.na(RECIP_EIN) & RECIP_TYPE %in% types & !is.na(RECIP_NAME),
             list(ROW_ID_, NAME_KEY = org_name_key(RECIP_NAME), ZIP5 = substr(gsub("[^0-9]", "", RECIP_ZIP), 1, 5),
                  STATE = toupper(RECIP_STATE))]
  cand <- cand[!is.na(NAME_KEY)]
  uniq <- function(by) {
    u <- unique(nx[, c("EIN2", by), with = FALSE])
    u[, N := .N, by = by][N == 1L][, N := NULL]
  }
  z <- merge(cand[!is.na(ZIP5) & nzchar(ZIP5)], uniq(c("NAME_KEY", "ZIP5")), by = c("NAME_KEY", "ZIP5"))
  s <- merge(cand[!ROW_ID_ %in% z$ROW_ID_ & !is.na(STATE)], uniq(c("NAME_KEY", "STATE")), by = c("NAME_KEY", "STATE"))
  hit <- rbind(z[, list(ROW_ID_, EIN2, SRC = "name_zip")], s[, list(ROW_ID_, EIN2, SRC = "name_state")])
  tx[hit, `:=`(RECIP_EIN = clean_ein(i.EIN2), EIN_SOURCE = i.SRC), on = "ROW_ID_"]
  tx[EIN_SOURCE %in% c("name_zip", "name_state") & RECIP_TYPE == "unknown", RECIP_TYPE := "unknown_with_ein"]
  tx[, SELF_TRANSFER := !is.na(RECIP_EIN) & RECIP_EIN == clean_ein(EIN2)]
  tx[, ROW_ID_ := NULL][]
}

utils::globalVariables(c("EIN_SOURCE", "NAME_KEY", "ZIP5", "STATE", "N", "SRC", "i.EIN2", "i.SRC", "RECIP_ZIP", "RECIP_STATE"))
