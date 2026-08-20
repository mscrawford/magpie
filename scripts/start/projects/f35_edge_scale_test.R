# =============================================================================
# f35_edge_scale paired confirming run (TENTATIVE / EXPLORATORY fork)
# SSP3base ON, identical config, differing ONLY in f35_edge_scale:
#   Run A = real per-cluster factor (the deliverable)
#   Run B = identity (all 1.0) = current model behaviour (clean paired baseline)
# Differences B->A isolate the factor: decision-relevance (land allocation) +
# edge-emission scaling + conservation (output_check / checkEmis).
# Usage: cd libraries/magpie && Rscript scripts/start/projects/f35_edge_scale_test.R
#
# PREREQUISITE (2026-06-24): the PIK VPN must be ON. The first launch attempts hit
# "http://rse.pik-potsdam.de/data/magpie/intern -> repository access failed" because the
# intern data repo is unreachable without the VPN, so inputs f56_emis_policy.csv,
# country2cell.rds, policy_definitions.csv, f70_capit_liv_regr.csv, f73_* (all untracked,
# intern-sourced) could not be fetched and the run aborted before GAMS. With the VPN on,
# the missing inputs download and the run proceeds. The GAMS edits + f35_edge_scale.csv are
# in place and compiled past config; only the input data was missing.
# =============================================================================
source("scripts/start_functions.R")
source("config/default.cfg")

WB     <- "/Users/turnip/Documents/Work/Projects/Fragmentation/audit/cell_cluster_missed_emissions/results"
MODCSV <- "modules/35_natveg/input/f35_edge_scale.csv"
REAL   <- file.path(WB, "f35_edge_scale.csv")
IDENT  <- file.path(WB, "f35_edge_scale_identity.csv")

cfg$gms$c_timesteps     <- "coup2100"   # match the SSP3base baseline
cfg$gms$s35_edge_carbon <- 1            # edge ON
cfg$output              <- c("output_check", "rds_report")
cfg$force_download      <- TRUE     # disk has rev4.126; config wants rev4.131 -> force the correct-revision fetch (VPN on enables intern/scp fallbacks)
cfg$recalc_npi_ndc      <- FALSE
cfg$sequential          <- TRUE         # A completes before B (no parallel thrash / CSV race)
cfg <- gms::setScenario(cfg, c("SSP3", "NPI"))

# Local repo providing additional_data_rev4.67.tgz: the 8 intern-only files (f56_emis_policy.csv,
# f12_interest_*, f70_capit_liv_regr.csv, f73_*, country2cell.rds, policy_definitions.csv) taken from the
# rev4.131 Workspace clone, repackaged on the on-disk rev4.63 additional_data template. The PIK intern repo
# is unreachable from the PC even with VPN; this lets prepare() find these files. (The 64 other rev4.63 aux
# files are revision-stale but cancel in the paired factor-vs-identity comparison.) Prepended so it wins.
cfg$repositories <- append(list("/private/tmp/claude-501/-Users-turnip-Documents-Work-Projects-Fragmentation/ab61601d-6695-40e0-93ee-65c0ac5d0d05/scratchpad/local_magpie_repo" = NULL),
                           cfg$repositories)

cat(sprintf("\n[%s] f35_edge_scale paired test starting\n", Sys.time()))

# --- Run A: real per-cluster factor ------------------------------------------
stopifnot(file.copy(REAL, MODCSV, overwrite = TRUE))
cfg$title <- "SSP3base_f35scaleON"
cat("\n===== Run A: SSP3base_f35scaleON (real factor) =====\n")
fA <- start_run(cfg, codeCheck = FALSE)
cat(sprintf("[%s] Run A returned: %s\n", Sys.time(), fA))

# --- Run B: identity (= current behaviour) -----------------------------------
stopifnot(file.copy(IDENT, MODCSV, overwrite = TRUE))
cfg$title <- "SSP3base_f35identON"
cat("\n===== Run B: SSP3base_f35identON (identity baseline) =====\n")
fB <- start_run(cfg, codeCheck = FALSE)
cat(sprintf("[%s] Run B returned: %s\n", Sys.time(), fB))

# --- restore the deliverable CSV to the module input -------------------------
file.copy(REAL, MODCSV, overwrite = TRUE)
cat(sprintf("\n[%s] ===== BOTH RUNS DONE =====\n", Sys.time()))
cat(sprintf("A (factor):   %s\nB (identity): %s\n", fA, fB))
