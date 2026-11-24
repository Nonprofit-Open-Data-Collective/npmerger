# Run the package checks locally, the same way CI does.
#
#   Rscript dev/check.R          offline tests + R CMD check
#   Rscript dev/check.R live     also the live download test (merger stage)
#   Rscript dev/check.R full     live test through the match and model stages
#
# Vignettes need Pandoc. A plain terminal often lacks it while RStudio ships
# its own copy, so this script points rmarkdown at RStudio's Pandoc when none
# is on the path. Without Pandoc, R CMD check fails at "re-building
# vignettes".
#
# The live test reuses the download cache in NPMERGER_LIVE_CACHE, or
# ~/Documents/NPMERGER/PANEL990 if that exists.

args <- commandArgs(trailingOnly = TRUE)

if (!rmarkdown::pandoc_available()) {
  rs <- c(Sys.getenv("RSTUDIO_PANDOC"),
          "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools",
          "C:/Program Files/RStudio/bin/quarto/bin/tools",
          "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools",
          "/usr/lib/rstudio/resources/app/bin/quarto/bin/tools")
  rs <- rs[nzchar(rs) & dir.exists(rs)]
  if (length(rs)) Sys.setenv(RSTUDIO_PANDOC = rs[1])
  if (!rmarkdown::pandoc_available())
    stop("Pandoc not found. Install it (https://pandoc.org) or set RSTUDIO_PANDOC.", call. = FALSE)
}
message("Pandoc ", as.character(rmarkdown::pandoc_version()))

if (length(args) && args[1] %in% c("live", "full")) {
  Sys.setenv(NPMERGER_LIVE = if (args[1] == "live") "merger" else "full")
  if (!nzchar(Sys.getenv("NPMERGER_LIVE_CACHE"))) {
    home <- Sys.getenv("USERPROFILE", path.expand("~"))
    cache <- file.path(home, "Documents", "NPMERGER", "PANEL990")
    if (dir.exists(cache)) Sys.setenv(NPMERGER_LIVE_CACHE = cache)
  }
  devtools::test(filter = "live", stop_on_failure = TRUE)
  Sys.unsetenv("NPMERGER_LIVE")
}

res <- devtools::check(document = FALSE, manual = FALSE, error_on = "warning")
print(res)
