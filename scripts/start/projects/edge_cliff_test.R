# |  Calibration cliff test: remedies for the y2030 deforestation spike
# |
# |  Root cause: MAgPIE historical calibration ends at y2015 (t_past).
# |  y2020/y2025 are the first optimized periods. By y2030, SSP demand
# |  trajectories diverge enough from historical that the optimizer
# |  makes a large one-period land reallocation (especially OAS).
# |  With no deforestation rate constraint, this appears as a spike.
# |
# |  Hypotheses tested:
# |    H1: s35_natveg_harvest_shr (harvest rate limit per timestep)
# |        Values: 0.5, 0.2, 0.05
# |        Mechanism: sets floor on remaining forest = (1-shr)*current
# |    H2: Higher timber harvest costs (2x default)
# |        Mechanism: makes clearing more expensive (soft constraint)
# |    H3: Higher cropland establishment cost (2x default)
# |        Mechanism: reduces incentive to convert any land to cropland
# |
# |  All runs: SSP1 + flat NPi2025 price + edge OFF + shift phase-out
# |  This isolates the structural spike from carbon price effects.
# |
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_cliff_test.R
# |  See: docs/edge_calibration/NPI_DEFORESTATION_SPIKE.md

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output <- c("output_check", "rds_report")
cfg$force_download <- FALSE
cfg$recalc_npi_ndc <- FALSE

# --- Common SSP1 + flat price config ---
make_base <- function(cfg) {
  cfg <- gms::setScenario(cfg, c("SSP1", "NPI"))
  cfg$gms$c56_pollutant_prices <- "R34M410-SSP2-NPi2025"
  cfg$gms$c56_pollutant_prices_noselect <- "R34M410-SSP2-NPi2025"
  cfg$gms$s35_forest_damage <- 2   # shift phase-out (SSP1 default)
  cfg$gms$s35_edge_carbon <- 0     # edge OFF
  return(cfg)
}

# --- H1a: s35_natveg_harvest_shr = 0.5 (max 50% per timestep) ---
cfg_h1a <- make_base(cfg)
cfg_h1a$gms$s35_natveg_harvest_shr <- 0.5
cfg_h1a$title <- "cliff_shr50"
cat("\n===== Starting: cliff_shr50 (H1a) =====\n")
f1 <- start_run(cfg_h1a, codeCheck = FALSE)

# --- H1b: s35_natveg_harvest_shr = 0.2 (max 20% per timestep) ---
cfg_h1b <- make_base(cfg)
cfg_h1b$gms$s35_natveg_harvest_shr <- 0.2
cfg_h1b$title <- "cliff_shr20"
cat("\n===== Starting: cliff_shr20 (H1b) =====\n")
f2 <- start_run(cfg_h1b, codeCheck = FALSE)

# --- H1c: s35_natveg_harvest_shr = 0.05 (max 5% per timestep) ---
cfg_h1c <- make_base(cfg)
cfg_h1c$gms$s35_natveg_harvest_shr <- 0.05
cfg_h1c$title <- "cliff_shr05"
cat("\n===== Starting: cliff_shr05 (H1c) =====\n")
f3 <- start_run(cfg_h1c, codeCheck = FALSE)

# --- H2: 2x timber harvest costs (shr=1 baseline) ---
cfg_h2 <- make_base(cfg)
cfg_h2$gms$s35_timber_harvest_cost_secdforest <- 4920   # 2x default
cfg_h2$gms$s35_timber_harvest_cost_primforest <- 7380   # 2x default
cfg_h2$gms$s35_timber_harvest_cost_other <- 6150         # 2x default
cfg_h2$title <- "cliff_cost2x"
cat("\n===== Starting: cliff_cost2x (H2) =====\n")
f4 <- start_run(cfg_h2, codeCheck = FALSE)

# --- H3: 2x cropland establishment cost (shr=1 baseline) ---
cfg_h3 <- make_base(cfg)
cfg_h3$gms$s39_cost_establish_crop <- 24600  # 2x default
cfg_h3$title <- "cliff_crop2x"
cat("\n===== Starting: cliff_crop2x (H3) =====\n")
f5 <- start_run(cfg_h3, codeCheck = FALSE)

cat("\n========== ALL 5 CLIFF TEST RUNS LAUNCHED ==========\n")
cat(sprintf("  H1a shr=0.5:     %s\n", f1))
cat(sprintf("  H1b shr=0.2:     %s\n", f2))
cat(sprintf("  H1c shr=0.05:    %s\n", f3))
cat(sprintf("  H2  cost 2x:     %s\n", f4))
cat(sprintf("  H3  crop 2x:     %s\n", f5))
cat("\nBaseline comparison: output/NPI_test_flatprice_* (shr=1, default costs)\n")
cat("\nAfter completion, run analysis:\n")
cat("  Rscript docs/edge_calibration/analyze_cliff_test.R\n")
