#' Leadership inspection file
#'
#' A tidy, one-row-per-person table for checking by hand how Part VII names
#' are matched across a merger. For each sampled case it lists:
#'
#' * `ORG A`: everyone on the donor's Part VII in the `pre` years;
#' * `ORG B`: everyone on the recipient's Part VII in the `pre` years;
#' * `MERGED`: everyone on the recipient's Part VII in the `post` years.
#'
#' A person is one name key ([name_keys()], the key the matching uses), so
#' the file shows exactly what the matcher treats as the same person. When
#' a person's name, title, pay, or hours differ across years, the values are
#' joined with `;;`, each followed by the years it applies to, for example
#' `PRESIDENT {t=-2,-1};; CEO {t=0}`.
#'
#' Cases are drawn in equal numbers from three groups by the share of ORG A
#' people who appear in MERGED: `none` (0), `some` (above 0 and below 0.5),
#' and `most` (0.5 or more). Only cases with an ORG A roster and a MERGED
#' roster are eligible.
#'
#' @param merger_data The list from [build_merger_data()] (uses `part7`,
#'   and `leadership`, `donors`, `recipients` when present), or a project
#'   from [merger_project()].
#' @param n Number of cases to sample.
#' @param types Merger types to sample from.
#' @param pre,post Event years for the rosters before and after the merger.
#' @param seed Random seed for the sample.
#' @param file CSV path to write, or `NULL` to only return the table.
#' @return A data.table, invisibly when `file` is given: `MERGER_ID`,
#'   `TYPE`, `RETENTION` (group), `SHARE_A_RETAINED`, `CEO_CAT`,
#'   `BOARD_CAT`, `CASE`, `ORG_EIN2`, `ORG_NAME`, `PERSON_KEY`, `NAME`,
#'   `TITLE`, `PAY` (compensation from the organization), `HOURS`,
#'   `POSITION`, `PERIODS`, and flags `IN_ORG_A`, `IN_ORG_B`, `IN_MERGED`,
#'   `RETAINED_FROM_A` (in ORG A and in MERGED), `MATCH_BASIS` (for people on
#'   both the donor's and the recipient's rosters, why the names matched; see
#'   [name_match_basis()]), and `GOVERNING` (trustee or
#'   officer, or a 990-EZ listing).
#' @export
#' @examples
#' \dontrun{
#' proj <- merger_project( "~/Documents/NPMERGER" )
#'
#' leadership_inspection(
#'   merger_data = proj,
#'   n           = 100,
#'   file        = file.path( proj$root, "leadership-inspection.csv" )
#' )
#' }
leadership_inspection <- function(merger_data, n = 100L, types = c("merger2", "mergerN", "consolidation"),
                                  pre = -2:0, post = 1:2, seed = 1L, file = NULL) {
  md <- if (inherits(merger_data, "merger_project")) load_merger_data(merger_data) else merger_data
  if (is.null(md$part7)) stop("`merger_data` has no `part7` table.", call. = FALSE)
  p <- as.data.table(md$part7)[!is.na(PERSON_KEY)]
  if (!is.null(md$cases)) p <- p[MERGER_ID %in% as.data.table(md$cases)[TYPE %in% types, MERGER_ID]]
  p[, CASE := fcase(ROLE == "donor" & TIME_FROM_MERGER %in% pre, "ORG A",
                    ROLE == "recipient" & TIME_FROM_MERGER %in% pre, "ORG B",
                    ROLE == "recipient" & TIME_FROM_MERGER %in% post, "MERGED", default = NA_character_)]
  p <- p[!is.na(CASE)]

  # who appears in which roster, and retention of ORG A people
  who <- unique(p[, list(MERGER_ID, CASE, PERSON_KEY)])
  a <- who[CASE == "ORG A", list(MERGER_ID, PERSON_KEY)]
  m <- who[CASE == "MERGED", list(MERGER_ID, PERSON_KEY)]
  ok <- intersect(unique(a$MERGER_ID), unique(m$MERGER_ID))
  a <- a[MERGER_ID %in% ok]
  a[, RET := paste(MERGER_ID, PERSON_KEY) %in% paste(m$MERGER_ID, m$PERSON_KEY)]
  sh <- a[, list(SHARE_A_RETAINED = mean(RET)), by = MERGER_ID]
  sh[, RETENTION := fcase(SHARE_A_RETAINED == 0, "none", SHARE_A_RETAINED < 0.5, "some", default = "most")]

  # equal numbers from each group (as far as each group allows)
  set.seed(seed)
  grp <- c("none", "some", "most")
  take <- stats::setNames(rep(n %/% 3L, 3L) + c(rep(1L, n %% 3L), rep(0L, 3L - n %% 3L)), grp)
  avail <- sh[, .N, by = RETENTION]
  cnt <- function(g) { v <- avail[RETENTION == g, N]; if (length(v)) v else 0L }
  for (g in grp) take[g] <- min(take[g], cnt(g))
  short <- n - sum(take)
  for (g in grp) if (short > 0) {
    extra <- min(short, cnt(g) - take[g])
    take[g] <- take[g] + extra; short <- short - extra
  }
  pick <- rbindlist(lapply(grp, function(g) {
    x <- sh[RETENTION == g]
    x[sample.int(nrow(x), take[[g]])]
  }))
  p <- p[MERGER_ID %in% pick$MERGER_ID]
  who <- who[MERGER_ID %in% pick$MERGER_ID]

  # collapse each person's years into one row per roster
  tt <- function(t) paste0("{t=", paste(sort(unique(t)), collapse = ","), "}")
  across <- function(v, t) {
    d <- data.table(v = as.character(v), t = t)[!is.na(v) & nzchar(v)]
    if (!nrow(d)) return(NA_character_)
    d <- d[, list(v = paste(sort(unique(v)), collapse = " / ")), by = t]   # several rows in one year
    d <- d[, list(t = list(t)), by = v][order(vapply(t, min, 0))]
    paste(vapply(seq_len(nrow(d)), function(i) paste(d$v[i], tt(d$t[[i]])), ""), collapse = ";; ")
  }
  pay <- function(x) ifelse(is.na(x), NA_character_, format(round(x), big.mark = ",", scientific = FALSE, trim = TRUE))
  pos <- function(tr, of, ke, hc, fo) {
    z <- c(if (any(tr %in% TRUE)) "trustee", if (any(of %in% TRUE)) "officer", if (any(ke %in% TRUE)) "key employee",
           if (any(hc %in% TRUE)) "highest compensated", if (any(fo %in% TRUE)) "former")
    if (length(z)) paste(z, collapse = ", ") else NA_character_
  }
  f <- function(v) v %in% TRUE
  out <- p[, list(ORG_EIN2 = EIN2[1],
                  NAME = across(PERSON_NAME, TIME_FROM_MERGER), TITLE = across(TITLE, TIME_FROM_MERGER),
                  PAY = across(pay(COMP_ORG), TIME_FROM_MERGER), HOURS = across(HOURS, TIME_FROM_MERGER),
                  POSITION = pos(TRUSTEE, OFFICER, KEY_EMPLOYEE, HIGH_COMP, FORMER),
                  PERIODS = paste(sort(unique(TIME_FROM_MERGER)), collapse = ","),
                  GOVERNING = any(!f(FORMER) & (f(TRUSTEE) | f(OFFICER) | !(f(KEY_EMPLOYEE) | f(HIGH_COMP))))),
           by = list(MERGER_ID, CASE, PERSON_KEY)]
  on <- function(cs) paste(out$MERGER_ID, out$PERSON_KEY) %in% who[CASE == cs, paste(MERGER_ID, PERSON_KEY)]
  out[, `:=`(IN_ORG_A = on("ORG A"), IN_ORG_B = on("ORG B"), IN_MERGED = on("MERGED"))]
  out[, RETAINED_FROM_A := IN_ORG_A & IN_MERGED]
  nb <- if (!is.null(md$name_matches)) as.data.table(md$name_matches) else name_match_basis(md$part7)
  out[nb, on = c("MERGER_ID", "PERSON_KEY"), MATCH_BASIS := i.MATCH_BASIS]

  # case context
  out <- merge(out, pick[, list(MERGER_ID, RETENTION, SHARE_A_RETAINED = round(SHARE_A_RETAINED, 3))], by = "MERGER_ID")
  if (!is.null(md$cases)) out <- merge(out, as.data.table(md$cases)[, list(MERGER_ID, TYPE)], by = "MERGER_ID", all.x = TRUE)
  if (!is.null(md$leadership)) out <- merge(out, as.data.table(md$leadership)[, list(MERGER_ID, CEO_CAT, BOARD_CAT)],
                                            by = "MERGER_ID", all.x = TRUE)
  nm <- rbind(if (!is.null(md$donors)) as.data.table(md$donors)[, list(MERGER_ID, ROLE = "donor", ORG_NAME = NAME)],
              if (!is.null(md$recipients)) as.data.table(md$recipients)[, list(MERGER_ID, ROLE = "recipient", ORG_NAME = NAME)])
  if (!is.null(nm)) {
    out[, ROLE := fifelse(CASE == "ORG A", "donor", "recipient")]
    out <- merge(out, nm, by = c("MERGER_ID", "ROLE"), all.x = TRUE)
    out[, ROLE := NULL]
  }
  for (v in c("TYPE", "CEO_CAT", "BOARD_CAT", "ORG_NAME")) if (!v %in% names(out)) out[, (v) := NA_character_]

  out[, CASE := factor(CASE, c("ORG A", "ORG B", "MERGED"))]
  out[, RETENTION := factor(RETENTION, grp)]
  data.table::setorderv(out, c("RETENTION", "MERGER_ID", "CASE", "PERSON_KEY"))
  out[, CASE := as.character(CASE)][, RETENTION := as.character(RETENTION)]
  data.table::setcolorder(out, c("MERGER_ID", "TYPE", "RETENTION", "SHARE_A_RETAINED", "CEO_CAT", "BOARD_CAT", "CASE",
                                 "ORG_EIN2", "ORG_NAME", "PERSON_KEY", "NAME", "TITLE", "PAY", "HOURS", "POSITION",
                                 "PERIODS", "IN_ORG_A", "IN_ORG_B", "IN_MERGED", "RETAINED_FROM_A", "MATCH_BASIS",
                                 "GOVERNING"))
  if (!is.null(file)) {
    data.table::fwrite(out, file)
    return(invisible(out))
  }
  out[]
}

utils::globalVariables(c("i.MATCH_BASIS", "CASE", "RET", "SHARE_A_RETAINED", "RETENTION", "PERSON_NAME", "HOURS", "IN_ORG_A",
                         "IN_ORG_B", "IN_MERGED", "RETAINED_FROM_A", "ROLE", "ORG_NAME", "NAME"))
