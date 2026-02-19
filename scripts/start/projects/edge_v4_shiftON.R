# |  Edge pipeline v5: SSP1/SSP2/SSP3 x {OFF, ON}
# |  6 GAMS runs total — INST vs PIPELINE views extracted from same ON report
# |  Parameters: d0=0.50, lambda=59m (biophysical-only)
# |  Pipeline: tau=13yr, T_hist=41yr (computed in magpie4 reportEmissions.R)
# |  Shifting cultivation: SSP1/SSP2 = phase-out (default), SSP3 = ON (persistent)
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_v5.R

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output <- c("output_check", "rds_report")
cfg$force_download <- FALSE
cfg$recalc_npi_ndc <- FALSE
cfg$sequential <- FALSE  # parallel GAMS solves

# --- Helper: configure SSP ---
set_ssp <- function(cfg, ssp) {
  cfg <- gms::setScenario(cfg, c(ssp, "NPI"))
  prices <- switch(ssp,
    SSP1 = "R34M410-SSP1-PkBudg650",
    SSP2 = "R34M410-SSP2-NPi2025",
    SSP3 = "R34M410-SSP3-NPi2025"
  )
  cfg$gms$c56_pollutant_prices <- prices
  cfg$gms$c56_pollutant_prices_noselect <- prices
  # SSP3: shifting cultivation ON (persistent); SSP1/SSP2: phase-out (default=2)
  if (ssp == "SSP3") {
    cfg$gms$s35_forest_damage <- 1
  } else {
    cfg$gms$s35_forest_damage <- 2
  }
  cfg
}

# --- Edge OFF ---
set_edge_off <- function(cfg) {
  cfg$gms$s35_edge_carbon <- 0
  cfg
}

# --- Edge ON (d=0.50, lambda=59m) ---
# GAMS sees the instant equilibrium effect on carbon density.
# magpie4 reportEmissions.R computes both instant flow and pipeline flow
# from the same GDX, so no separate INST vs PIPELINE GAMS runs needed.
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon   <- 1
  cfg$gms$s35_edge_form     <- 1      # Form 3d (regional gamma)
  cfg$gms$s35_edge_formula  <- 1      # exponential decay
  cfg$gms$s35_edge_lambda   <- 0.059  # Taubert 2018
  cfg$gms$s35_edge_degrad   <- 0.50   # Brinck 2017
  cfg
}

folders <- c()

# --- SSP1 ---
cfg1 <- set_ssp(cfg, "SSP1"); cfg1 <- set_edge_off(cfg1)
cfg1$title <- "SSP1_v5_OFF"
cat("\n===== Starting: SSP1_v5_OFF (1/6) =====\n")
f1 <- start_run(cfg1, codeCheck = FALSE); folders <- c(folders, f1)

cfg2 <- set_ssp(cfg, "SSP1"); cfg2 <- set_edge_on(cfg2)
cfg2$title <- "SSP1_v5_ON"
cat("\n===== Starting: SSP1_v5_ON (2/6) =====\n")
f2 <- start_run(cfg2, codeCheck = FALSE); folders <- c(folders, f2)

# --- SSP2 ---
cfg3 <- set_ssp(cfg, "SSP2"); cfg3 <- set_edge_off(cfg3)
cfg3$title <- "SSP2_v5_OFF"
cat("\n===== Starting: SSP2_v5_OFF (3/6) =====\n")
f3 <- start_run(cfg3, codeCheck = FALSE); folders <- c(folders, f3)

cfg4 <- set_ssp(cfg, "SSP2"); cfg4 <- set_edge_on(cfg4)
cfg4$title <- "SSP2_v5_ON"
cat("\n===== Starting: SSP2_v5_ON (4/6) =====\n")
f4 <- start_run(cfg4, codeCheck = FALSE); folders <- c(folders, f4)

# --- SSP3 ---
cfg5 <- set_ssp(cfg, "SSP3"); cfg5 <- set_edge_off(cfg5)
cfg5$title <- "SSP3_v5_OFF"
cat("\n===== Starting: SSP3_v5_OFF (5/6) =====\n")
f5 <- start_run(cfg5, codeCheck = FALSE); folders <- c(folders, f5)

cfg6 <- set_ssp(cfg, "SSP3"); cfg6 <- set_edge_on(cfg6)
cfg6$title <- "SSP3_v5_ON"
cat("\n===== Starting: SSP3_v5_ON (6/6) =====\n")
f6 <- start_run(cfg6, codeCheck = FALSE); folders <- c(folders, f6)

cat("\n========== ALL 6 RUNS LAUNCHED ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nSSP1/SSP2: shifting cultivation phase-out (s35_forest_damage=2).\n")
cat("SSP3: shifting cultivation ON (s35_forest_damage=1).\n")
cat("Each ON run reports both instant and pipeline flow (from magpie4).\n")
cat("Check progress: ls magpie/output/SSP*_v5_*/report.rds\n")
