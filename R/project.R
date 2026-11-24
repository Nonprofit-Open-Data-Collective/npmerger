# A project folder holds one npmerger build: the download cache, one DuckDB
# database with every table, logs, and model results.

#' Create or open an npmerger project folder
#'
#' A project keeps one build together:
#'
#' ```
#' <root>/
#'   PANEL990/          panel990 download cache (reused by later builds)
#'   npmerger.duckdb    every table, plus build_info and build_log
#'   logs/              one log per stage run, <stage>-<time>.log
#'   results/           model estimates
#'   README.md          tables, row counts, and build settings
#' ```
#'
#' @param root Project folder. Created if it does not exist.
#' @return A list of class `merger_project` with `root`, `cache`, `db`,
#'   `logs`, and `results` paths.
#' @export
#' @examples
#' proj <- merger_project( file.path( tempdir(), "NPMERGER" ) )
#'
#' proj
merger_project <- function(root = file.path(path.expand("~"), "NPMERGER")) {
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  p <- list(root = root, cache = file.path(root, "PANEL990"), db = file.path(root, "npmerger.duckdb"),
            logs = file.path(root, "logs"), results = file.path(root, "results"))
  for (d in c(p$root, p$cache, p$logs, p$results)) dir.create(d, showWarnings = FALSE, recursive = TRUE)
  structure(p, class = c("merger_project", "list"))
}

#' @export
print.merger_project <- function(x, ...) {
  cat("<merger_project>", x$root, "\n")
  tabs <- if (file.exists(x$db)) tryCatch(db_tables(x), error = function(e) character()) else character()
  stages <- c(merger = "cases", match = "match_pool", model = "model_units")
  for (s in names(stages))
    cat(sprintf("  %-7s %s\n", s, if (stages[[s]] %in% tabs) "built" else "not built"))
  invisible(x)
}

.need_db <- function() {
  for (p in c("DBI", "duckdb")) if (!requireNamespace(p, quietly = TRUE))
    stop("Project databases need the '", p, "' package.", call. = FALSE)
}

.db_connect <- function(project, read_only = FALSE) {
  .need_db()
  # newer duckdb prints a notice about its home folder on every connection
  drv <- if ("shared_home" %in% names(formals(duckdb::duckdb))) duckdb::duckdb(shared_home = FALSE) else duckdb::duckdb()
  DBI::dbConnect(drv, project$db, read_only = read_only)
}

#' Tables in a project database
#'
#' @param project A [merger_project()].
#' @return `db_tables()`: table names. `db_read()`: a data.table.
#'   `db_write()`: the row counts written, invisibly.
#' @export
db_tables <- function(project) {
  if (!file.exists(project$db)) return(character())
  con <- .db_connect(project, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbListTables(con)
}

#' @rdname db_tables
#' @param table Table name.
#' @param query Optional SQL instead of a whole table.
#' @export
db_read <- function(project, table = NULL, query = NULL) {
  con <- .db_connect(project, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  sql <- if (!is.null(query)) query else sprintf("SELECT * FROM \"%s\"", table)
  as.data.table(DBI::dbGetQuery(con, sql))
}

#' @rdname db_tables
#' @param tables A named list of data frames.
#' @export
db_write <- function(project, tables) {
  con <- .db_connect(project)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  n <- integer()
  for (nm in names(tables)) {
    x <- tables[[nm]]
    if (is.null(x)) next
    x <- as.data.frame(x)
    dup <- names(x)[duplicated(tolower(names(x)))]
    if (length(dup)) stop("Table '", nm, "' has column names that differ only in case (",
                          paste(dup, collapse = ", "), "); DuckDB cannot store it.", call. = FALSE)
    for (v in names(x)) if (is.factor(x[[v]])) x[[v]] <- as.character(x[[v]])
    DBI::dbWriteTable(con, nm, x, overwrite = TRUE)
    n[nm] <- nrow(x)
  }
  invisible(n)
}

# key/value settings stored as deparsed R
.kv_table <- function(stage, x) {
  data.table(stage = stage, item = names(x),
             value = vapply(x, function(v) paste(deparse(v, width.cutoff = 500L), collapse = " "), ""))
}
.kv_read <- function(project, stage) {
  if (!"build_settings" %in% db_tables(project)) return(list())
  s <- db_read(project, query = sprintf("SELECT item, value FROM build_settings WHERE stage = '%s'", stage))
  stats::setNames(lapply(s$value, function(v) eval(str2lang(v), baseenv())), s$item)
}
.kv_write <- function(project, stage, x) {
  s <- stage
  old <- if ("build_settings" %in% db_tables(project)) db_read(project, "build_settings") else NULL
  if (!is.null(old)) old <- old[old$stage != s]
  db_write(project, list(build_settings = rbind(old, .kv_table(s, x))))
}

# ---- logging ------------------------------------------------------------------------

# Run `expr`, copying its messages and warnings to a log file in the project.
# With echo = FALSE, messages go to the log only.
.with_log <- function(project, stage, expr, settings = list(), echo = TRUE) {
  f <- file.path(project$logs, sprintf("%s-%s.log", stage, format(Sys.time(), "%Y%m%d-%H%M%S")))
  con <- file(f, open = "wt")
  on.exit(close(con), add = TRUE)
  w <- function(...) { cat(..., "\n", sep = "", file = con); flush(con) }
  t0 <- Sys.time()
  g <- function(...) tryCatch(suppressWarnings(system2("git", c("-C", shQuote(getwd()), ...), stdout = TRUE,
                                                       stderr = FALSE)), error = function(e) character())
  git <- g("rev-parse", "--short", "HEAD")
  # mark builds from a checkout with uncommitted changes to tracked files
  if (length(git) && length(g("status", "--porcelain", "--untracked-files=no"))) git <- paste0(git[1], "+dirty")
  w("# npmerger ", stage, " stage, started ", format(t0, "%Y-%m-%d %H:%M:%S"))
  w("# npmerger ", as.character(utils::packageVersion("npmerger")),
    if (length(git) && nzchar(git[1])) paste0(" (git ", git[1], ")") else "",
    "; panel990 ", tryCatch(as.character(utils::packageVersion("panel990")), error = function(e) "-"),
    "; fiscal ", tryCatch(as.character(utils::packageVersion("fiscal")), error = function(e) "-"),
    "; data.table ", as.character(utils::packageVersion("data.table")), "; ", R.version.string)
  for (nm in names(settings)) w("# ", nm, " = ", paste(deparse(settings[[nm]], width.cutoff = 500L), collapse = " "))
  stamp <- function() sprintf("[%6.1f min] ", as.numeric(difftime(Sys.time(), t0, units = "mins")))
  out <- withCallingHandlers(expr,
    message = function(m) {
      w(stamp(), sub("\n$", "", conditionMessage(m)))
      if (!echo) invokeRestart("muffleMessage")
    },
    warning = function(m) w(stamp(), "WARNING: ", conditionMessage(m)))
  mins <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
  w("# finished ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " (", mins, " min)")
  w("")
  utils::capture.output(print(utils::sessionInfo()), file = con)
  attr(out, "run_minutes") <- mins
  attr(out, "log_file") <- f
  attr(out, "git") <- if (length(git)) git[1] else NA_character_
  out
}

.log_build <- function(project, stage, x, tables) {
  old <- if ("build_log" %in% db_tables(project)) db_read(project, "build_log") else NULL
  row <- data.table(stage = stage, built = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                    minutes = attr(x, "run_minutes") %||% NA_real_,
                    npmerger = as.character(utils::packageVersion("npmerger")),
                    git = attr(x, "git") %||% NA_character_,
                    log = basename(attr(x, "log_file") %||% NA_character_),
                    tables = paste(sprintf("%s (%s)", names(tables), format(tables, big.mark = ",")), collapse = "; "))
  db_write(project, list(build_log = rbind(old, row, fill = TRUE)))
}

# ---- stages -----------------------------------------------------------------------

.merger_tables <- c("sched_n", "transactions", "cases", "transfers", "donors", "recipients", "part7", "fiscal",
                    "leadership", "typology", "name_matches", "name_keys", "labels", "manifest")

#' Build a project database stage by stage
#'
#' Runs the npmerger workflow into one project folder ([merger_project()]),
#' writing every table to one DuckDB database and a log for each stage:
#'
#' 1. `"merger"`: [build_merger_data()]. Schedule N, the classifier, and
#'    tables about the organizations involved, including
#'    [merger_leadership()] and [merger_typology()]. Stands alone: it reads
#'    only the returns of the organizations that filed Schedule N or
#'    received assets.
#' 2. `"match"`: [build_match_data()]. The full 990 panel, the research
#'    sample, the comparison pool, candidates, and balance.
#' 3. `"model"`: [build_model_data()]. Treated units, trimmed candidate
#'    sets, donor sums, and the organization-years the models read.
#'
#' Each stage reads what it needs from the database, so stages can be run
#' separately and later ones rerun without repeating earlier ones. Results
#' of the models themselves are not stored; run [merger_did()] and friends
#' on [load_model_data()].
#'
#' @param project A [merger_project()].
#' @param stages Stages to run, in order.
#' @param years Schedule N tax years for the merger stage.
#' @param merger_args,match_args,model_args Lists of further arguments to
#'   [build_merger_data()], [build_match_data()], [build_model_data()].
#' @param verbose Print progress (it is always logged).
#' @return The project, invisibly.
#' @export
#' @examples
#' \dontrun{
#' proj <- merger_project( "~/NPMERGER" )
#'
#' build_merger_database( proj, years = efile_years() )
#'
#' dd  <- load_model_data( proj )
#' fit <- merger_did( dd )
#' }
build_merger_database <- function(project, stages = c("merger", "match", "model"), years = efile_years(),
                                  merger_args = list(), match_args = list(), model_args = list(), verbose = TRUE) {
  stages <- match.arg(stages, several.ok = TRUE)
  run <- function(stage, settings, f) .with_log(project, stage, f(), settings, echo = verbose)
  if ("merger" %in% stages) {
    st <- c(list(years = years), merger_args)
    # names parsed in an earlier build are reused (parsing is the slow step),
    # but only when the same peopleparser build parsed them
    parser <- name_parser_id()
    if ("name_keys" %in% db_tables(project) && identical(.kv_read(project, "merger")$name_parser, parser))
      name_keys_preload(db_read(project, "name_keys"))
    md <- run("merger", c(st, list(name_parser = parser)),
              function() do.call(build_merger_data, c(list(years = years, path = project$cache, verbose = TRUE),
                                                      merger_args)))
    tabs <- md[intersect(.merger_tables, names(md))]
    tabs$name_keys <- name_keys_cached()
    n <- db_write(project, tabs)
    .kv_write(project, "merger", c(st, list(rules = unclass(merger_args$rules %||% merger_rules()),
                                            name_parser = parser)))
    .log_build(project, "merger", md, n)
    rm(md); gc()
  }
  if ("match" %in% stages) {
    md <- load_merger_data(project)
    mm <- run("match", match_args, function() do.call(build_match_data, c(list(merger_data = md, path = project$cache,
                                                                               verbose = TRUE), match_args)))
    tabs <- c(list(panel_990 = mm$panel, research_sample = mm$sample, research_baseline = mm$baseline,
                   match_treated = mm$treated, match_events = mm$events, match_pool = mm$pool,
                   match_balance = mm$balance, match_coverage = mm$coverage),
              stats::setNames(mm$candidates, paste0("match_candidates_", names(mm$candidates))))
    n <- db_write(project, tabs)
    .kv_write(project, "match", mm$settings)
    .log_build(project, "match", mm, n)
    rm(md, mm); gc()
  }
  if ("model" %in% stages) {
    md <- load_merger_data(project)
    mm <- load_match_data(project)
    dd <- run("model", model_args, function() do.call(build_model_data, c(list(merger_data = md, match_data = mm,
                                                                               verbose = TRUE), model_args)))
    tabs <- c(list(model_units = dd$units, model_cases = dd$cases, model_panel = dd$panel,
                   model_donors = dd$donors, model_n_donors = dd$n_donors),
              stats::setNames(dd$candidates, paste0("model_candidates_", names(dd$candidates))))
    n <- db_write(project, tabs)
    .kv_write(project, "model", dd$info)
    .log_build(project, "model", dd, n)
  }
  write_project_readme(project)
  invisible(project)
}

#' Load stage outputs from a project database
#'
#' Rebuild the objects that [build_merger_data()], [build_match_data()], and
#' [build_model_data()] return, from the tables [build_merger_database()]
#' wrote.
#'
#' @param project A [merger_project()].
#' @param panel Load the full 990 panel too (several million rows).
#' @return A `merger_data`, `merger_match_data`, or `merger_model_data`
#'   object.
#' @export
load_merger_data <- function(project) {
  tabs <- db_tables(project)
  if (!"cases" %in% tabs) stop("The merger stage has not been built in ", project$root, ".", call. = FALSE)
  md <- lapply(stats::setNames(nm = intersect(.merger_tables, tabs)), function(t) db_read(project, t))
  if (!is.null(md$cases)) class(md$cases) <- c("merger_cases", class(md$cases))
  if (!is.null(md$typology)) md$typology[, TYPOLOGY := factor(TYPOLOGY, typology_levels())]
  structure(md, class = c("merger_data", "list"))
}

#' @rdname load_merger_data
#' @export
load_match_data <- function(project, panel = TRUE) {
  tabs <- db_tables(project)
  if (!"match_pool" %in% tabs) stop("The match stage has not been built in ", project$root, ".", call. = FALSE)
  rd <- function(t) if (t %in% tabs) db_read(project, t) else NULL
  cn <- sub("^match_candidates_", "", grep("^match_candidates_", tabs, value = TRUE))
  pn <- if (panel) rd("panel_990") else data.table()
  if (nrow(pn)) data.table::setkeyv(pn, c("EIN2", "TAX_YEAR"))
  structure(list(panel = pn, sample = rd("research_sample"), baseline = rd("research_baseline"),
                 treated = rd("match_treated"), events = rd("match_events"), pool = rd("match_pool"),
                 candidates = stats::setNames(lapply(paste0("match_candidates_", cn), rd), cn),
                 balance = rd("match_balance"), coverage = rd("match_coverage"),
                 settings = .kv_read(project, "match")),
            class = c("merger_match_data", "list"))
}

#' @rdname load_merger_data
#' @export
load_model_data <- function(project) {
  tabs <- db_tables(project)
  if (!"model_units" %in% tabs) stop("The model stage has not been built in ", project$root, ".", call. = FALSE)
  cn <- sub("^model_candidates_", "", grep("^model_candidates_", tabs, value = TRUE))
  u <- db_read(project, "model_units")
  u[, DOSE_BIN := factor(DOSE_BIN, c("<1%", "1-10%", "10-50%", ">=50%", "unknown"))]
  u[, SIZE_BAND := factor(SIZE_BAND, c("<$10m", "$10-100m", ">=$100m"))]
  u[, TYPOLOGY := factor(TYPOLOGY, typology_levels()[3:8])]
  u[, CEO_CAT := factor(CEO_CAT, c("recipient_ceo_only", "both_ceos", "donor_ceo_only", "neither", "shared_ceo"))]
  u[, BOARD_CAT := factor(BOARD_CAT, c("intact_donor_dissolves", "combine_minor", "combine_major",
                                       "recipient_turnover"))]
  op <- db_read(project, "model_panel")
  data.table::setkeyv(op, c("EIN2", "TAX_YEAR"))
  structure(list(units = u, cases = db_read(project, "model_cases"),
                 candidates = stats::setNames(lapply(paste0("model_candidates_", cn), function(t) db_read(project, t)), cn),
                 panel = op, donors = db_read(project, "model_donors"), n_donors = db_read(project, "model_n_donors"),
                 info = .kv_read(project, "model")),
            class = c("merger_model_data", "list"))
}

#' Write the project README
#'
#' Lists every table in the project database with its row count, and the
#' build log. [build_merger_database()] calls it after each run.
#'
#' @param project A [merger_project()].
#' @return The README path, invisibly.
#' @export
write_project_readme <- function(project) {
  tabs <- db_tables(project)
  n <- vapply(tabs, function(t) db_read(project, query = sprintf("SELECT COUNT(*) AS n FROM \"%s\"", t))$n, 0)
  lg <- if ("build_log" %in% tabs) db_read(project, "build_log") else NULL
  stage_of <- function(t) fcase(t %in% .merger_tables, "merger", grepl("^(panel_990|research_|match_)", t), "match",
                                grepl("^model_", t), "model", default = "project")
  x <- data.table(table = tabs, rows = n, stage = stage_of(tabs))[order(match(stage, c("merger", "match", "model",
                                                                                         "project")), table)]
  txt <- c("# npmerger project", "",
           "Built with the npmerger package. Open the database in R with:", "",
           "```r", sprintf("proj <- merger_project( \"%s\" )", project$root), "",
           "md <- load_merger_data( proj )   # merger stage", "mm <- load_match_data( proj )    # match stage",
           "dd <- load_model_data( proj )    # model stage", "```", "",
           "## Tables in `npmerger.duckdb`", "", "| stage | table | rows |", "|---|---|---|",
           sprintf("| %s | `%s` | %s |", x$stage, x$table, format(x$rows, big.mark = ",")), "",
           "## Build log", "",
           if (!is.null(lg)) c("| stage | built | minutes | npmerger | git | log |", "|---|---|---|---|---|---|",
                               sprintf("| %s | %s | %s | %s | %s | `logs/%s` |", lg$stage, lg$built, lg$minutes,
                                       lg$npmerger, lg$git, lg$log)) else "Nothing built yet.",
           "", "`PANEL990/` is the panel990 download cache. Later builds reuse it.")
  f <- file.path(project$root, "README.md")
  writeLines(txt, f)
  invisible(f)
}

utils::globalVariables(c("stage", "item", "value"))
