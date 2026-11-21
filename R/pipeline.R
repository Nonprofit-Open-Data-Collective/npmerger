#' Tax years available in the e-file release
#'
#' The years covered by the default NCCS e-file release (v3_1). Year windows
#' used by [build_merger_data()] are clipped to this range.
#'
#' @return Integer vector.
#' @export
efile_years <- function() 2009:2025

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Build the full merger dataset
#'
#' Runs the whole pipeline: Schedule N retrieval, EIN recovery,
#' filing-level features, merger evidence, classification, merger cases,
#' transfer values, donor and recipient attributes, the Part VII panel, and
#' the fiscal panel. Every stage is also available as its own function.
#'
#' Pre-fetched inputs (`sn`, `evidence`, `core`, `names`, `bmf_data`) are
#' used instead of retrieving them, which makes it possible to run the
#' pipeline offline, for example on [npmerger_example()].
#'
#' @param years Schedule N tax years. Ignored when `sn` is supplied.
#' @param path Cache directory for all downloads.
#' @param rules A [merger_rules()] object.
#' @param types Transaction types that become merger cases.
#' @param recover_eins Recover missing recipient EINs by name
#'   ([recover_recipient_ein()]).
#' @param pre,post Years before and after the merger in the fiscal panel.
#' @param years_back Years before the merger in the attribute tables.
#' @param ratios,fit,weights,smooth,k Passed to [merger_fiscal_panel()].
#' @param bmf Retrieve BMF traits (NTEE, ruling year) for attributes.
#' @param sn,evidence,core,names,bmf_data Optional pre-fetched inputs.
#' @param verbose Print progress.
#' @return A list of class `merger_data` with `sched_n` (one row per Schedule N
#'   filing), `cases`, `transfers`, `donors`, `recipients`, `part7`,
#'   `fiscal`, `transactions` (asset lines), and `manifest` (row counts per
#'   stage).
#' @export
#' @examples
#' ex <- npmerger_example()
#' md <- build_merger_data(sn = ex$sn, evidence = ex$evidence, core = ex$core,
#'                         names = ex$names, bmf_data = ex$bmf, ratios = FALSE)
#' md
build_merger_data <- function(years = NULL, path = "PANEL990", rules = merger_rules(),
                              types = c("merger2", "mergerN", "consolidation"), recover_eins = TRUE,
                              pre = 5L, post = 5L, years_back = 4L, ratios = TRUE, fit = NULL, weights = NULL,
                              smooth = c("none", "trailing"), k = 3L, bmf = TRUE,
                              sn = NULL, evidence = NULL, core = NULL, names = NULL, bmf_data = NULL,
                              verbose = TRUE) {
  smooth <- match.arg(smooth)
  say <- function(...) if (verbose) message(...)
  clip <- function(y) intersect(y, efile_years())
  log <- list()
  note <- function(step, x) log[[length(log) + 1L]] <<- data.table(step = step, rows = NROW(x))

  if (is.null(sn)) { if (is.null(years)) stop("Supply `years` or `sn`.", call. = FALSE); say("Schedule N"); sn <- get_schedule_n(years, path = path, verbose = verbose) }
  sn_years <- sort(unique(sn$p1_header$TAX_YEAR, sn$p2_header$TAX_YEAR))
  tx <- sn_transactions(sn); note("asset lines", tx)
  if (recover_eins) {
    names <- names %||% { say("Name index"); get_name_index(clip(seq(min(sn_years) - 1L, max(sn_years) + 1L)), path = path, verbose = verbose) }
    tx <- recover_recipient_ein(tx, names)
    note("asset lines with recovered EIN", tx[EIN_SOURCE %in% c("name_zip", "name_state")])
  }
  fl <- sn_filings(sn, tx); note("Schedule N filings", fl)
  evidence <- evidence %||% { say("Evidence tables"); get_evidence_tables(fl, years = clip(seq(min(sn_years) - 1L, max(sn_years) + 1L)), path = path, verbose = verbose) }
  lab <- classify_transactions(merger_features(fl, evidence, rules), rules)
  cases <- build_merger_cases(lab, tx, header = evidence$header, types = types); note("merger cases", cases)
  eins <- unique(c(cases$DONOR_EIN2, cases$RECIP_EIN2))
  if (is.null(core)) {
    say("Core tables")
    cy <- clip(seq(min(cases$MERGER_YEAR) - max(pre, years_back), max(cases$RECIP_MERGER_YEAR) + post))
    core <- get_core(eins, cy, path = path, verbose = verbose)
  }
  oy <- org_years(core); note("organization-years", oy)
  if (bmf && is.null(bmf_data)) { say("BMF"); bmf_data <- tryCatch(get_bmf(eins, path = path, verbose = verbose), error = function(e) { warning("BMF retrieval failed: ", conditionMessage(e), call. = FALSE); NULL }) }
  transfers <- transfer_value(cases, tx, oy)
  donors <- merger_attributes(cases, oy, "donor", years_back, bmf_data)
  recipients <- merger_attributes(cases, oy, "recipient", years_back, bmf_data)
  part7 <- if (!is.null(core$p7) && nrow(core$p7)) merger_part7(cases, core$p7) else NULL
  note("Part VII person-years", part7)
  fiscal <- merger_fiscal_panel(cases, oy, pre, post, ratios = ratios, fit = fit, weights = weights, smooth = smooth, k = k)
  note("fiscal panel org-years", fiscal)
  structure(list(sched_n = sched_n_table(lab), cases = cases, transfers = transfers, donors = donors,
                 recipients = recipients, part7 = part7, fiscal = fiscal, transactions = tx,
                 manifest = rbindlist(log), labels = lab[, .N, by = TYPE][order(-N)]),
            class = c("merger_data", "list"))
}

#' @export
print.merger_data <- function(x, ...) {
  cat("<merger_data>\n")
  cat("Schedule N filings by type:\n")
  for (i in seq_len(nrow(x$labels))) cat(sprintf("  %-18s %7d\n", x$labels$TYPE[i], x$labels$N[i]))
  cat("Tables:\n")
  for (nm in c("cases", "transfers", "donors", "recipients", "part7", "fiscal"))
    cat(sprintf("  %-11s %7d rows\n", nm, NROW(x[[nm]])))
  invisible(x)
}

#' Example data for offline use
#'
#' A small extract of 2021 Schedule N filings with the evidence, core, name
#' index, and BMF rows needed to run [build_merger_data()] without
#' downloading anything. Built by `data-raw/example.R`.
#'
#' @return A list with `sn`, `evidence`, `core`, `names`, and `bmf`.
#' @export
#' @examples
#' ex <- npmerger_example()
#' ex$sn
npmerger_example <- function() {
  f <- system.file("extdata", "npmerger-example.rds", package = "npmerger")
  if (!nzchar(f)) stop("Example data not found; reinstall npmerger.", call. = FALSE)
  readRDS(f)
}

utils::globalVariables(c("step", "rows"))
