# |  NPI deforestation spike test: SSP1 with flat carbon price
# |  Purpose: Demonstrate that the y2030 deforestation spike in SSP1 is caused
# |  by the PkBudg650 carbon price jump ($4 -> $1036/tC at y2035), NOT by
# |  NPI constraints or edge effects.
# |
# |  Test: Run SSP1 demographics with SSP2's flat NPi2025 price ($4/tC forever).
# |  Expected: y2030 spike disappears; deforestation is smooth.
# |
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_npi_test.R
# |  See: docs/edge_calibration/NPI_DEFORESTATION_SPIKE.md

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output <- c("output_check", "rds_report")
cfg$force_download <- FALSE
cfg$recalc_npi_ndc <- FALSE

# --- Run A: SSP1 with PkBudg650 (should show the spike) ---
cfg_a <- gms::setScenario(cfg, c("SSP1", "NPI"))
cfg_a$gms$c56_pollutant_prices <- "R34M410-SSP1-PkBudg650"
cfg_a$gms$c56_pollutant_prices_noselect <- "R34M410-SSP1-PkBudg650"
cfg_a$gms$s35_forest_damage <- 2  # shift phase-out
cfg_a$gms$s35_edge_carbon <- 0    # edge OFF (isolate the price effect)
cfg_a$title <- "NPI_test_PkBudg650"

cat("\n===== Starting: NPI_test_PkBudg650 (1/2) =====\n")
cat("SSP1 + PkBudg650 carbon price (spike expected at y2030)\n")
f1 <- start_run(cfg_a, codeCheck = FALSE)

# --- Run B: SSP1 with flat NPi2025 price (spike should disappear) ---
cfg_b <- gms::setScenario(cfg, c("SSP1", "NPI"))
cfg_b$gms$c56_pollutant_prices <- "R34M410-SSP2-NPi2025"
cfg_b$gms$c56_pollutant_prices_noselect <- "R34M410-SSP2-NPi2025"
cfg_b$gms$s35_forest_damage <- 2  # shift phase-out
cfg_b$gms$s35_edge_carbon <- 0    # edge OFF
cfg_b$title <- "NPI_test_flatprice"

cat("\n===== Starting: NPI_test_flatprice (2/2) =====\n")
cat("SSP1 + flat NPi2025 carbon price (no spike expected)\n")
f2 <- start_run(cfg_b, codeCheck = FALSE)

cat("\n========== BOTH TEST RUNS LAUNCHED ==========\n")
cat(sprintf("  Spike run:    %s\n", f1))
cat(sprintf("  No-spike run: %s\n", f2))
cat("\nAfter completion, compare deforestation at y2030:\n")
cat("  Rscript -e 'for(d in c(\"<spike_dir>\",\"<nospike_dir>\")) {\n")
cat("    r <- as.data.table(readRDS(file.path(d,\"report.rds\")))\n")
cat("    cat(basename(d), \"y2030:\", r[variable==\"Emissions|CO2|Land|Land-use Change|+|Deforestation\" & region==\"World\" & period==2030, value], \"\\n\")\n")
cat("  }'\n")
