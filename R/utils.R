#' Parse efile checkbox values
#'
#' Schedule N (and most efile checkboxes) mix `0/1`, `true/false`, and `X`
#' encodings across schema versions. This normalizes them to logical.
#'
#' @param x A character (or numeric/logical) vector.
#' @param na_value Value to return for blanks and unrecognized codes.
#'   Defaults to `NA`; use `FALSE` when a blank box means "No".
#' @return A logical vector the same length as `x`.
#' @export
#' @examples
#' flags <- c( "1", "true", "X", "0", "false", NA, "" )
#'
#' sn_flag( flags )
sn_flag <- function(x, na_value = NA) {
  x <- tolower(trimws(as.character(x)))
  out <- rep(as.logical(na_value), length(x))
  out[x %in% c("1", "true", "x", "y", "yes")] <- TRUE
  out[x %in% c("0", "false", "n", "no")] <- FALSE
  out
}

#' Clean EINs
#'
#' `clean_ein()` returns a 9-digit character EIN, or `NA` for blanks and
#' placeholder values (all zeros, all nines, wrong length). `as_ein2()`
#' converts to the `EIN-XX-XXXXXXX` key used by the NCCS efile tables.
#'
#' @param x A vector of EINs in any common format (with or without dashes,
#'   numeric with dropped leading zeros, or `EIN-XX-XXXXXXX`).
#' @return A character vector.
#' @export
#' @examples
#' eins <- c( "01-0215911", "10215911", "000000000",
#'            "EIN-01-0215911", NA )
#'
#' clean_ein( eins )
#'
#' as_ein2( "010215911" )
clean_ein <- function(x) {
  x <- gsub("[^0-9]", "", as.character(x))
  short <- !is.na(x) & nchar(x) %in% 7:8
  x[short] <- formatC(as.numeric(x[short]), width = 9, format = "d", flag = "0")
  bad <- is.na(x) | nchar(x) != 9 | x %in% c("000000000", "999999999", "123456789")
  x[bad] <- NA_character_
  x
}

#' @rdname clean_ein
#' @export
as_ein2 <- function(x) {
  x <- clean_ein(x)
  ifelse(is.na(x), NA_character_, paste0("EIN-", substr(x, 1, 2), "-", substr(x, 3, 9)))
}

#' Classify the free-text IRC section / entity type of a Schedule N recipient
#'
#' Schedule N column (g) is free text: dozens of spellings of 501(c)(3),
#' entity types (LLC, corporation), "individual", "government", and so on.
#' This maps it to a small set of recipient types.
#'
#' @param x Character vector from `SN_01_LTD_RECIP_IRC_SECTION` or
#'   `SN_02_DOA_RECIP_IRC_SECTION`.
#' @return A character vector with values `"501c3"`, `"other_exempt"`,
#'   `"government"`, `"individual"`, `"business"`, `"other"`, or `"unknown"`.
#' @export
#' @examples
#' irc <- c( "501(c)(3)", "501 C 3", "501(c)(6)", "LLC",
#'           "Individual", "City of Portland", NA )
#'
#' parse_irc_section( irc )
parse_irc_section <- function(x) {
  u <- toupper(gsub("[^A-Za-z0-9]", "", as.character(x)))
  data.table::fcase(
    is.na(u) | u %in% c("", "NA", "NONE", "0", "NOTAPPLICABLE"), "unknown",
    grepl("^(501)?C?3$|501C3|^3$|PUBLICCHARITY|CHARIT|PRIVATEFOUND|FOUNDATION|CHURCH|509A|170B", u), "501c3",
    grepl("^501C?[0-9]+|TAXEXEMPT|NONPROFIT|EXEMPT|^527|^115", u), "other_exempt",
    grepl("GOV|CITY|COUNTY|STATE|MUNICIP|SCHOOLDIST|TOWN|VILLAGE|FEDERAL|TRIBE", u), "government",
    grepl("INDIVID|PERSON|MEMBER|STUDENT|SCHOLAR", u), "individual",
    grepl("LLC|CORP|INC|PARTNER|LLP|LP$|COMPANY|BUSINESS|FORPROFIT|TRUST|BANK", u), "business",
    default = "other"
  )
}

# internal: does a recipient type count as a nonprofit recipient?
.np_types <- c("501c3", "other_exempt", "unknown_with_ein")
