# |  Edge-effect scenario comparison: 3 SSPs x 2 edge settings = 6 runs
# |  Runs sequentially with TS_benni timesteps (y1995-y2050, 8 steps)
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_scenario_comparison.R

source("scripts/start_functions.R")
source("config/default.cfg")

# --- Common settings ---
cfg$gms$c_timesteps <- "TS_benni"
cfg$output <- c("output_check", "rds_report")

make_ssp_cfg <- function(cfg, ssp, edge_on) {
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

  edge_label <- if (edge_on) "edgeON" else "edgeOFF"
  cfg$title <- paste0(ssp, "_", edge_label)
  cfg$gms$s35_edge_carbon <- as.integer(edge_on)

  return(cfg)
}

# --- Run all 6 sequentially ---
folders <- character(0)
for (ssp in c("SSP1", "SSP2", "SSP3")) {
  for (edge_on in c(FALSE, TRUE)) {
    run_cfg <- make_ssp_cfg(cfg, ssp, edge_on)
    cat(sprintf("\n===== Starting: %s =====\n", run_cfg$title))
    folder <- start_run(run_cfg, codeCheck = FALSE)
    folders <- c(folders, folder)
    cat(sprintf("Completed: %s -> %s\n", run_cfg$title, folder))
  }
}

cat("\n========== ALL 6 RUNS COMPLETE ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
