# Build the npmerger project database: every stage, one DuckDB file, one
# log per stage. Replaces dev/build-database.R and dev/build-matching.R.
#
# Env vars:
#   ROOT    project folder (default ~/Documents/NPMERGER)
#   STAGES  stages to run, e.g. "match,model" (default all three)
#   YEARS   Schedule N years, e.g. "2009:2025" (default efile_years())
#   NAME_WORKERS  R processes for parsing Part VII names (default 1: in this
#                 session; see ?name_keys)
#   R_LIBS  an R library to use first, e.g. ROOT/rlib holding the pinned
#           peopleparser, so installs elsewhere cannot change it mid-build
#
# The 2026-11-23 build:
#   R_LIBS=~/Documents/NPMERGER/rlib NAME_WORKERS=8 Rscript dev/build-project.R
#
# Run from the repository root:
#   Rscript dev/build-project.R

devtools::load_all( quiet = TRUE )

root   <- Sys.getenv( "ROOT", file.path( Sys.getenv("USERPROFILE", path.expand("~")),
                                         "Documents", "NPMERGER" ) )
stages <- strsplit( Sys.getenv( "STAGES", "merger,match,model" ), "," )[[1]]
yrs    <- Sys.getenv( "YEARS", "" )
years  <- if ( nzchar(yrs) ) eval( parse( text = yrs ) ) else efile_years()

options( npmerger.name_workers = as.integer( Sys.getenv( "NAME_WORKERS", "1" ) ) )

proj <- merger_project( root )

build_merger_database(
  project = proj,
  stages  = stages,
  years   = years
)

proj
cat( readLines( file.path( proj$root, "README.md" ) ), sep = "\n" )
