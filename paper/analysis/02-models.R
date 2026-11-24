# Matched difference-in-differences for two-party merger recipients, for
# the paper: every outcome, the breakouts, and the sensitivity variants.
# All of the work is done by npmerger functions; this script runs them on
# the project database and writes the tables the paper reads.
#
# Input:  the project folder (ROOT, default ~/Documents/NPMERGER), built
#         with dev/build-project.R
# Output: paper/data/did_*.csv
#
# Run from the repository root:  Rscript paper/analysis/02-models.R

devtools::load_all( quiet = TRUE )
library( data.table )

root <- Sys.getenv( "ROOT", file.path( Sys.getenv("USERPROFILE", path.expand("~")),
                                       "Documents", "NPMERGER" ) )
proj <- merger_project( root )
out  <- file.path( "paper", "data" )
dir.create( out, showWarnings = FALSE, recursive = TRUE )

# everything the models need, built once by the "model" stage
dd <- load_model_data( proj )
dd

variants <- did_variants()
base     <- variants$base

# ---- long differences ------------------------------------------------------------------

# main specification, pooled and by every breakout variable
main <- do.call( did_breakouts, c( list( data = dd ), base ) )

# the other variants, pooled
others <- did_sensitivity( dd, variants = variants[ names(variants) != "base" ] )

ld <- rbind( main, others )

# ---- event study and baseline means -----------------------------------------------------

es    <- do.call( did_event_study, c( list( data = dd ), base[ names(base) != "post" ] ) )
means <- do.call( did_baseline_means, c( list( data = dd ), base[ names(base) != "post" ] ) )

# ---- sample funnel and composition ------------------------------------------------------

funnel <- do.call( did_funnel, c( list( data = dd ), base[ names(base) != "post" ] ) )

# the step labels the paper looks up
funnel[ , step := c(
  "merger2 cases (2010-2024)",
  "cases with recipient returns t-2..t+2",
  "recipient units with a t-2 baseline",
  "units without other merger events in the window",
  "units with >= 1 same-year control (recipient match)",
  "units with >= 1 same-year control (combined match)",
  "comparison pool org-years",
  "comparison pool organizations",
  "control org-years used (recipient match)"
) ]

comp <- do.call( did_composition, c( list( data = dd ), base[ names(base) != "post" ] ) )

# ---- write ---------------------------------------------------------------------------

fwrite( ld,     file.path( out, "did_long_difference.csv" ) )
fwrite( es,     file.path( out, "did_event_study.csv" ) )
fwrite( means,  file.path( out, "did_baseline_means.csv" ) )
fwrite( funnel, file.path( out, "did_funnel.csv" ) )
fwrite( comp,   file.path( out, "did_sample_composition.csv" ) )

fwrite( db_read( proj, "match_balance" ),  file.path( out, "did_balance.csv" ) )
fwrite( db_read( proj, "match_coverage" ), file.path( out, "did_coverage.csv" ) )
