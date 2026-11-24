# Person name keys for Part VII matching.
#
# "canonical" (the default) parses each name with peopleparser and keys a
# person on the canonical form of the first name plus the parsed surname:
# ROBERT, BOB, and BOBBY SMITH share the key "ROBERT SMITH", and titles and
# post-nominals (DR, PHD, CPA, ...) are removed before keying. "simple" is the
# original rule in person_key(): first and last token after removing
# punctuation and a short list of honorifics.

.name_cache <- new.env(parent = emptyenv())

#' Name keys for matching people across Part VII rosters
#'
#' Parses each distinct name once and returns its parts and its matching
#' key. Parsed names are cached for the R session, so later calls with the
#' same names are fast.
#'
#' With `method = "canonical"`, names are parsed with
#' [peopleparser::parse_name()] and [peopleparser::nickname_lookup()], and the
#' key is the canonical first name plus the parsed last name. Nicknames resolve to their formal name (BOB -> ROBERT),
#' and spelling variants to their most common spelling (DIANNE -> DIANE).
#' Names whose nickname is ambiguous keep their own spelling (KATHY, or PAT
#' without a gendered salutation). With `method = "simple"`, the key is
#' [person_key()].
#'
#' @param x Character vector of raw names.
#' @param method `"canonical"` or `"simple"`. `"canonical"` needs the
#'   peopleparser package; without it, `"simple"` is used with a warning.
#' @param prefixes Titles and post-nominals to strip, passed to
#'   [peopleparser::parse_name()]. Defaults to peopleparser's own list.
#' @param verbose Report progress for large batches.
#' @param workers Number of R processes for parsing, passed to
#'   [peopleparser::parse_names()]. The default, 1, parses in this R session
#'   whatever [future::plan()] is set. With more, that many workers are
#'   started for the call, and the call stops if any of them loads a
#'   different peopleparser build than this session (for example after a
#'   reinstall mid-build). Set the default for a session with
#'   `options(npmerger.name_workers = 8)`.
#' @return A data.table with one row per distinct input name: `PERSON_NAME`,
#'   `FIRST_NAME`, `MIDDLE_NAME`, `LAST_NAME`, `FIRST_CANONICAL`,
#'   `CANONICAL_RULE` (`self`, `spelling`, `nickname`, `ambiguous`), and
#'   `PERSON_KEY`. With `"simple"`, the parsed columns are `NA`.
#' @seealso [name_match_basis()] for why two names share a key.
#' @export
#' @examples
#' people <- c( "Robert Smith", "BOB SMITH", "Dr. Robert J. Smith PhD",
#'              "Kathy Lee", "MRS PAT JONES" )
#'
#' if ( requireNamespace( "peopleparser", quietly = TRUE ) ) {
#'   name_keys( people )
#' }
name_keys <- function(x, method = c("canonical", "simple"), prefixes = NULL, verbose = FALSE,
                      workers = getOption("npmerger.name_workers", 1L)) {
  method <- .name_method(match.arg(method))
  u <- unique(as.character(x))
  u <- u[!is.na(u) & nzchar(trimws(u))]
  if (method == "simple" || !length(u))
    return(data.table(PERSON_NAME = u, FIRST_NAME = NA_character_, MIDDLE_NAME = NA_character_,
                      LAST_NAME = NA_character_, FIRST_CANONICAL = NA_character_,
                      CANONICAL_RULE = NA_character_, PERSON_KEY = person_key(u)))
  pfx <- if (is.null(prefixes)) peopleparser::prx else prefixes
  slot <- paste0("canonical:", digest_prefixes(pfx))
  cache <- .name_cache[[slot]]
  todo <- if (is.null(cache)) u else setdiff(u, cache$PERSON_NAME)
  if (length(todo)) {
    r <- .parse_people(todo, pfx, workers, verbose)
    new <- data.table(PERSON_NAME = todo, FIRST_NAME = r$first_name, MIDDLE_NAME = r$middle_name,
                      LAST_NAME = r$last_name, FIRST_CANONICAL = r$first_name_canonical,
                      CANONICAL_RULE = r$canonical_rule)
    ok <- function(v) !is.na(v) & nzchar(v)
    new[, PERSON_KEY := fifelse(ok(FIRST_CANONICAL) & ok(LAST_NAME), paste(FIRST_CANONICAL, LAST_NAME),
                                NA_character_)]
    cache <- rbind(cache, new)
    data.table::setkeyv(cache, "PERSON_NAME")
    .name_cache[[slot]] <- cache
  }
  cache[list(u), on = "PERSON_NAME"]
}

#' @describeIn name_keys The key alone, one per element of `x` (`NA` for
#'   names that cannot be keyed).
#' @export
name_key <- function(x, method = c("canonical", "simple"), prefixes = NULL, verbose = FALSE,
                     workers = getOption("npmerger.name_workers", 1L)) {
  method <- match.arg(method)
  k <- name_keys(x, method, prefixes, verbose, workers)
  k$PERSON_KEY[match(as.character(x), k$PERSON_NAME)]
}

#' @describeIn name_keys Add already-parsed names to the session cache, for
#'   example a `name_keys` table saved in a project database.
#' @param keys A table from `name_keys()`.
#' @export
name_keys_preload <- function(keys, prefixes = NULL) {
  if (is.null(keys) || !nrow(keys) || !requireNamespace("peopleparser", quietly = TRUE)) return(invisible(0L))
  pfx <- if (is.null(prefixes)) peopleparser::prx else prefixes
  slot <- paste0("canonical:", digest_prefixes(pfx))
  k <- as.data.table(keys)[, c("PERSON_NAME", "FIRST_NAME", "MIDDLE_NAME", "LAST_NAME", "FIRST_CANONICAL",
                               "CANONICAL_RULE", "PERSON_KEY"), with = FALSE]
  cache <- unique(rbind(.name_cache[[slot]], k), by = "PERSON_NAME")
  data.table::setkeyv(cache, "PERSON_NAME")
  .name_cache[[slot]] <- cache
  invisible(nrow(k))
}

#' @describeIn name_keys Every name parsed this session (for saving).
#' @export
name_keys_cached <- function(prefixes = NULL) {
  if (!requireNamespace("peopleparser", quietly = TRUE)) return(NULL)
  pfx <- if (is.null(prefixes)) peopleparser::prx else prefixes
  .name_cache[[paste0("canonical:", digest_prefixes(pfx))]]
}

# ---- parsing --------------------------------------------------------------------

# Parse names with peopleparser::parse_names() (>= 0.2.4), with the nickname
# columns. workers = 1 parses in this session whatever future::plan() is set;
# more starts that many workers for the call, and parse_names() stops if any
# worker loads a different peopleparser build than this session. Sequential
# parses run in chunks so progress can be reported. Returns parse_name()'s
# columns plus first_name_canonical and canonical_rule, one row per element
# of `x`.
.parse_people <- function(x, prefixes, workers = 1L, verbose = FALSE) {
  workers <- max(1L, as.integer(workers))
  t0 <- Sys.time()
  if (verbose) message("Parsing ", format(length(x), big.mark = ","), " names with peopleparser (",
                       name_parser_id(), "; ", workers, if (workers == 1L) " process)" else " workers)")
  one <- function(v, w) peopleparser::parse_names(v, prefixes = prefixes, add_nicknames = TRUE, workers = w)
  out <- if (workers > 1L && length(x) >= 2000L) {
    one(x, workers)
  } else {
    chunks <- split(x, ceiling(seq_along(x) / 50000))
    rbindlist(lapply(seq_along(chunks), function(i) {
      r <- one(chunks[[i]], 1L)
      if (verbose && length(chunks) > 1L) {
        done <- min(i * 50000, length(x))
        sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
        message(sprintf("  %s of %s names (%.0f a second)", format(done, big.mark = ","),
                        format(length(x), big.mark = ","), done / sec))
      }
      r
    }))
  }
  if (verbose) message(sprintf("  parsed in %.1f min", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  as.data.table(out)
}

digest_prefixes <- function(p) paste(length(p), sum(utf8ToInt(paste(sort(p), collapse = "|"))), name_parser_id())

#' @describeIn name_keys The installed peopleparser that parsed the names:
#'   its version and commit (or build time, for a local install). Saved
#'   parses are reused only by the same parser.
#' @export
name_parser_id <- function() {
  if (!requireNamespace("peopleparser", quietly = TRUE)) return(NA_character_)
  d <- utils::packageDescription("peopleparser")
  paste0(d$Version, "@", if (!is.null(d$RemoteSha)) substr(d$RemoteSha, 1, 12) else paste("built", d$Built))
}

.name_method <- function(method) {
  if (method == "canonical" && !requireNamespace("peopleparser", quietly = TRUE)) {
    warning("Name key 'canonical' needs the peopleparser package; using 'simple'.", call. = FALSE)
    return("simple")
  }
  method
}

#' Why two Part VII names share a key
#'
#' For every person who appears on both the donor's and the recipient's
#' Part VII (the same `PERSON_KEY` in one merger case), compares the raw
#' first names on the two sides and records the basis of the match:
#'
#' * `exact`: the same first name appears on both sides;
#' * `nickname`, `spelling`, `cognate`, `compound`: the two first names are a
#'   reviewed pair in [peopleparser::first_name_pairs] (BOB / ROBERT,
#'   STEVEN / STEPHEN, JUAN / JOHN, MARYANN / MARY ANN);
#' * `misspelling`, `sound_alike`: an unreviewed pair in the same table
#'   (AAREN / AARON);
#' * `indirect`: the names share a canonical form but are not a direct pair,
#'   for example a nickname of one spelling and the other spelling (KATIE /
#'   CATHERINE through KATHERINE). These are the ones to check by hand.
#'
#' With the `"simple"` key every match is `exact` or `indirect` (the simple
#' key ignores first names after the first token, so `indirect` there means
#' the raw first names differ).
#'
#' @param part7 The `part7` table from [build_merger_data()] or
#'   [merger_part7()].
#' @return A data.table, one row per merger case and shared person:
#'   `MERGER_ID`, `PERSON_KEY`, `DONOR_FIRST`, `RECIP_FIRST` (raw first names,
#'   `;; `-separated when several), `DONOR_NAMES`, `RECIP_NAMES`,
#'   `MATCH_BASIS`, and `REVIEW` (`TRUE` for `indirect`, `misspelling`, and
#'   `sound_alike`).
#' @export
name_match_basis <- function(part7) {
  p <- as.data.table(part7)[!is.na(PERSON_KEY)]
  # people on both rosters of a case (IN_BOTH, computed here so any Part VII
  # table works)
  both <- p[, list(N_ROLES = uniqueN(ROLE)), by = list(MERGER_ID, PERSON_KEY)][N_ROLES == 2L]
  p <- p[both[, list(MERGER_ID, PERSON_KEY)], on = c("MERGER_ID", "PERSON_KEY")]
  empty <- data.table(MERGER_ID = character(), PERSON_KEY = character(), DONOR_FIRST = character(),
                      RECIP_FIRST = character(), DONOR_NAMES = character(), RECIP_NAMES = character(),
                      MATCH_BASIS = character(), REVIEW = logical())
  if (!nrow(p)) return(empty)
  first <- if ("FIRST_NAME" %in% names(p) && any(!is.na(p$FIRST_NAME))) toupper(p$FIRST_NAME) else
    vapply(strsplit(toupper(gsub("[^A-Za-z ]", " ", p$PERSON_NAME)), " +"), function(z) {
      z <- z[nzchar(z)]; if (length(z)) z[1] else NA_character_ }, "")
  p[, FIRST := first]
  side <- function(r) p[ROLE == r, list(F = list(unique(stats::na.omit(FIRST))),
                                        N = paste(unique(PERSON_NAME), collapse = ";; ")), by = list(MERGER_ID, PERSON_KEY)]
  m <- merge(side("donor"), side("recipient"), by = c("MERGER_ID", "PERSON_KEY"), suffixes = c("_D", "_R"))
  if (!nrow(m)) return(empty)

  pairs <- if (requireNamespace("peopleparser", quietly = TRUE)) {
    v <- as.data.table(peopleparser::first_name_pairs)[, list(a = name_short, b = name_long, type)]
    rbind(v, v[, list(a = b, b = a, type)])
  } else data.table(a = character(), b = character(), type = character())
  rank <- c("nickname", "spelling", "cognate", "compound", "misspelling", "sound_alike")
  pairs <- unique(pairs[, list(R = min(match(type, rank))), by = list(a, b)])
  # every donor first name against every recipient first name, in one join
  m[, .ID := .I]
  ex <- m[, data.table::CJ(a = F_D[[1]], b = F_R[[1]], unique = TRUE), by = .ID]
  ex <- pairs[ex, on = c("a", "b")]
  ex[, R := as.numeric(R)]
  ex[a == b, R := 0]
  best <- ex[, list(R = suppressWarnings(min(R, na.rm = TRUE))), by = .ID]
  m[best, on = ".ID", R := i.R]
  basis <- fifelse(is.na(m$R) | is.infinite(m$R), "indirect",
                   fifelse(m$R == 0, "exact", rank[pmax(m$R, 1L)]))
  out <- m[, list(MERGER_ID, PERSON_KEY,
                  DONOR_FIRST = vapply(F_D, paste, "", collapse = ";; "),
                  RECIP_FIRST = vapply(F_R, paste, "", collapse = ";; "),
                  DONOR_NAMES = N_D, RECIP_NAMES = N_R)]
  out[, MATCH_BASIS := basis]
  out[, REVIEW := MATCH_BASIS %in% c("indirect", "misspelling", "sound_alike")]
  out[]
}

utils::globalVariables(c("FIRST_NAME", "MIDDLE_NAME", "LAST_NAME", "FIRST_CANONICAL", "CANONICAL_RULE", "IN_BOTH",
                         "FIRST", "F_D", "F_R", "N_D", "N_R", "MATCH_BASIS", "REVIEW", "name_short", "name_long",
                         "type", "a", "b", ".ID", "R", "i.R", "N_ROLES"))
