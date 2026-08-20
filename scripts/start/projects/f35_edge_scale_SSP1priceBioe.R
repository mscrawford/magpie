# =============================================================================
# Keystone #3 Step C: f35_edge_scale paired run in SSP1priceBioe (CARBON-PRICED)
# =============================================================================
# Isolates the SCALED factor magnitude sensitivity under a carbon price (the
# decision-sensitivity test the user asked for). SSP1priceBioe = PkBudg650 CO2 price
# + PkBudg650 2nd-gen bioenergy, edge ON, identical config, differing ONLY in
# f35_edge_scale.csv:
#   Run A = real per-cluster factor (median 1.27)  -> scaled haircut
#   Run B = identity (all 1.0)                      -> current/unscaled behaviour
# A - B isolates the SCALED factor's effect on land allocation (Step B gave the
# UNSCALED lower bound ~0.13% of land via ON/OFF; this gives the scaled number).
#
# Helper functions copied VERBATIM from scripts/start/projects/edge_policy_pipeline.R
# (the verified 2026-06-20 SSP1priceBioe config). Intern repo reachable (VPN on),
# inputs cached at rev4.131 -> force_download=FALSE, no local_magpie_repo needed.
# Usage: cd libraries/magpie && Rscript scripts/start/projects/f35_edge_scale_SSP1priceBioe.R
# =============================================================================
source("scripts/start_functions.R")
source("config/default.cfg")

WB     <- "/Users/turnip/Documents/Work/Projects/Fragmentation/audit/cell_cluster_missed_emissions/results"
MODCSV <- "modules/35_natveg/input/f35_edge_scale.csv"
REAL   <- file.path(WB, "f35_edge_scale.csv")
IDENT  <- file.path(WB, "f35_edge_scale_identity.csv")
stopifnot(file.exists(REAL), file.exists(IDENT))

# --- levers (verbatim from edge_policy_pipeline.R) ---------------------------
set_ssp_base <- function(cfg, ssp) {
  cfg <- gms::setScenario(cfg, c(ssp, "NPI"))
  price <- paste0("R34M410-", ssp, "-NPi2025")
  bioe  <- paste0("R34M410-", ssp, "-NPi2025")
  cfg$gms$c56_pollutant_prices          <- price
  cfg$gms$c56_pollutant_prices_noselect <- price
  cfg$gms$c60_2ndgen_biodem             <- bioe
  cfg$gms$c60_2ndgen_biodem_noselect    <- bioe
  cfg$gms$c22_protect_scenario          <- "none"
  cfg$gms$c22_protect_scenario_noselect <- "none"
  cfg$gms$s15_exo_diet                  <- 0
  cfg
}
set_price_high <- function(cfg, ssp) {
  price <- paste0("R34M410-", ssp, "-PkBudg650")
  cfg$gms$c56_pollutant_prices          <- price
  cfg$gms$c56_pollutant_prices_noselect <- price
  cfg
}
set_bioenergy_high <- function(cfg, ssp) {
  bioe <- paste0("R34M410-", ssp, "-PkBudg650")
  cfg$gms$c60_2ndgen_biodem          <- bioe
  cfg$gms$c60_2ndgen_biodem_noselect <- bioe
  cfg
}
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon  <- 1
  cfg$gms$s35_edge_formula <- 1
  cfg$gms$s35_edge_lambda  <- 0.059
  cfg$gms$s35_edge_degrad  <- 0.50
  cfg$gms$s35_edge_beta    <- 0.8286
  cfg$gms$s35_edge_n       <- 0.7984
  cfg
}

# --- run controls (match the f35 paired test + the policy pipeline) ----------
cfg$gms$c_timesteps <- "coup2100"
cfg$output          <- c("output_check", "rds_report")
cfg$force_download  <- FALSE
cfg$recalc_npi_ndc  <- FALSE
cfg$sequential      <- TRUE          # A completes before B (no CSV race)

# build SSP1priceBioe + edge ON
cfg <- set_ssp_base(cfg, "SSP1")
cfg <- set_price_high(cfg, "SSP1")
cfg <- set_bioenergy_high(cfg, "SSP1")
cfg <- set_edge_on(cfg)

cat(sprintf("\n[%s] Step C SSP1priceBioe f35 paired run starting\n", Sys.time()))

# --- Run A: real per-cluster factor ------------------------------------------
stopifnot(file.copy(REAL, MODCSV, overwrite = TRUE))
cfg$title <- "SSP1priceBioe_f35scaleON"
cat("\n===== Run A: SSP1priceBioe_f35scaleON (real factor) =====\n")
fA <- start_run(cfg, codeCheck = FALSE)
cat(sprintf("[%s] Run A returned: %s\n", Sys.time(), fA))

# --- Run B: identity (= unscaled behaviour) ----------------------------------
stopifnot(file.copy(IDENT, MODCSV, overwrite = TRUE))
cfg$title <- "SSP1priceBioe_f35identON"
cat("\n===== Run B: SSP1priceBioe_f35identON (identity baseline) =====\n")
fB <- start_run(cfg, codeCheck = FALSE)
cat(sprintf("[%s] Run B returned: %s\n", Sys.time(), fB))

# --- restore the deliverable CSV to the module input -------------------------
file.copy(REAL, MODCSV, overwrite = TRUE)
cat(sprintf("\n[%s] ===== BOTH RUNS DONE =====\nA (factor):   %s\nB (identity): %s\n", Sys.time(), fA, fB))
