# |  SSP3 + Option B + shifting cultivation kept ON (no fade-out)
# |  Single additional scenario to test combined edge + persistent shifting cult
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_optB_shiftcult.R

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output <- c("output_check", "rds_report")
cfg$force_download <- FALSE
cfg$recalc_npi_ndc <- FALSE
cfg$sequential <- FALSE

# SSP3 + NPI
cfg <- gms::setScenario(cfg, c("SSP3", "NPI"))
cfg$gms$c56_pollutant_prices <- "R34M410-SSP3-NPi2025"
cfg$gms$c56_pollutant_prices_noselect <- "R34M410-SSP3-NPi2025"

# Edge ON, Option B symmetric pipeline
cfg$gms$s35_edge_carbon   <- 1
cfg$gms$s35_edge_form     <- 1
cfg$gms$s35_edge_formula  <- 1
cfg$gms$s35_edge_lambda   <- 0.059
cfg$gms$s35_edge_degrad   <- 0.50
cfg$gms$s35_edge_pipeline <- 1
cfg$gms$s35_edge_tau      <- 13
cfg$gms$s35_edge_thist    <- 41

# Keep shifting cultivation ON (no fade-out)
cfg$gms$s35_forest_damage <- 1

cfg$title <- "SSP3_optB_SYMM_shiftON"
cat("\n===== Starting: SSP3_optB_SYMM_shiftON =====\n")
start_run(cfg, codeCheck = FALSE)
cat("\nRun launched. Check progress with:\n")
cat("  ls magpie/output/SSP3_optB_SYMM_shiftON*/report.rds\n")
