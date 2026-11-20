#' Build merger identifiers
#'
#' `merger_id()` builds the pair identifier `YEAR-FROMEIN-TOEIN` (9-digit
#' EINs, donor first). `merger_group_id()` builds `YEAR-TOEIN`, which links
#' all donors folding into one recipient.
#'
#' @param year Merger year (the donor's Schedule N tax year).
#' @param from_ein Donor (closing organization) EIN.
#' @param to_ein Recipient (successor organization) EIN.
#' @return A character vector.
#' @export
#' @examples
#' merger_id(2020, "01-0215911", "010431680")
#' merger_group_id(2020, "010431680")
merger_id <- function(year, from_ein, to_ein) {
  f <- clean_ein(from_ein); t <- clean_ein(to_ein)
  ifelse(is.na(year) | is.na(f) | is.na(t), NA_character_, paste(as.integer(year), f, t, sep = "-"))
}

#' @rdname merger_id
#' @export
merger_group_id <- function(year, to_ein) {
  t <- clean_ein(to_ein)
  ifelse(is.na(year) | is.na(t), NA_character_, paste(as.integer(year), t, sep = "-"))
}

#' Build merger cases (donor-recipient pairs)
#'
#' Turns classified filings into donor-recipient pairs with `MERGER_ID`,
#' `MERGER_GROUP_ID`, the merger year on each side's fiscal calendar, and
#' a role table.
#'
#' @param classified Output of [classify_transactions()].
#' @param tx Output of [sn_transactions()].
#' @param types Transaction types to keep.
#' @return A data.table of cases.
#' @export
build_merger_cases <- function(classified, tx, types = c("merger2", "mergerN", "consolidation")) {
  .not_yet("build_merger_cases", "Plan step 4")
}

#' Value of assets transferred to each recipient
#'
#' @param tx Output of [sn_transactions()].
#' @param cases Output of [build_merger_cases()].
#' @return A data.table of FMV by merger and asset class, with outlier flags.
#' @export
transfer_value <- function(tx, cases) {
  .not_yet("transfer_value", "Plan step 4")
}
