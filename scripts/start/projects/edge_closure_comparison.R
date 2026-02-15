# |  Edge-effect closure comparison: 3 SSPs x 3 edge configs = 9 runs
# |  Configs: OFF, Form 3b (global gamma), Form 3d (regional gamma + p^3)
# |  Full timeline: 1995-2100, standard 5-year timesteps
# |  Runs sequentially (~30-40 min each, ~5 hours total)
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_closure_comparison.R

source("scripts/start_functions.R")
source("config/default.cfg")

# --- Common settings ---
cfg$output <- c("output_check", "rds_report")

# Form 3b parameters (defaults in input.gms)
FORM3B <- list(
  beta   = 0.8275597,
  gamma  = 0.1806961,
  gamma2 = -1.2761439,
  gamma3 = 0  # unused
)

# Form 3d parameters
FORM3D <- list(
  beta   = 0.8784410,
  gamma  = -2.6885421,
  gamma2 = 5.9352517,
  gamma3 = -4.8536250
)

make_run_cfg <- function(cfg, ssp, edge_mode) {
  # edge_mode: "OFF", "3b", "3d"
  cfg <- gms::setScenario(cfg, c(ssp, "NPI"))

  if (ssp == "SSP1") {
    cfg$gms$c56_pollutant_prices <- "R34M410-SSP1-PkBudg650"
    cfg$gms$c56_pollutant_prices_noselect <- "R34M410-SSP1-PkBudg650"
  } else if (ssp == "SSP2") {
    cfg$gms$c56_pollutant_prices <- "R34M410-SSP2-NPi2025"
    cfg$gms$c56_pollutant_prices_noselect <- "R34M410-SSP2-NPi2025"
  } else {
    cfg$gms$c56_pollutant_prices <- "R34M410-SSP3-NPi2025"
    cfg$gms$c56_pollutant_prices_noselect <- "R34M410-SSP3-NPi2025"
  }

  cfg$title <- paste0(ssp, "_edge", edge_mode)

  if (edge_mode == "OFF") {
    cfg$gms$s35_edge_carbon <- 0
  } else if (edge_mode == "3b") {
    cfg$gms$s35_edge_carbon <- 1
    cfg$gms$s35_edge_form   <- 0
    cfg$gms$s35_edge_beta   <- FORM3B$beta
    cfg$gms$s35_edge_gamma  <- FORM3B$gamma
    cfg$gms$s35_edge_gamma2 <- FORM3B$gamma2
    cfg$gms$s35_edge_gamma3 <- FORM3B$gamma3
  } else if (edge_mode == "3d") {
    cfg$gms$s35_edge_carbon <- 1
    cfg$gms$s35_edge_form   <- 1
    cfg$gms$s35_edge_beta   <- FORM3D$beta
    cfg$gms$s35_edge_gamma  <- FORM3D$gamma
    cfg$gms$s35_edge_gamma2 <- FORM3D$gamma2
    cfg$gms$s35_edge_gamma3 <- FORM3D$gamma3
  }

  return(cfg)
}

# --- Run all 9 sequentially ---
edge_modes <- c("OFF", "3b", "3d")
folders <- character(0)

for (ssp in c("SSP1", "SSP2", "SSP3")) {
  for (em in edge_modes) {
    run_cfg <- make_run_cfg(cfg, ssp, em)
    cat(sprintf("\n===== Starting: %s (run %d of 9) =====\n",
        run_cfg$title, length(folders) + 1))
    folder <- start_run(run_cfg, codeCheck = FALSE)
    folders <- c(folders, folder)
    cat(sprintf("Completed: %s -> %s\n", run_cfg$title, folder))
  }
}

cat("\n========== ALL 9 RUNS COMPLETE ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nRun output reporting on each folder, then use edge_emissions_plots.R\n")
