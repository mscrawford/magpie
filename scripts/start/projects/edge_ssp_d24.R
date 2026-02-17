# |  Edge-effect SSP comparison: SSP1, SSP2, SSP3, ON vs OFF
# |  6 runs in parallel (cfg$sequential <- FALSE)
# |  Full coup2100 timesteps (1995-2100)
# |  Edge ON = Form 3d, exponential decay (lambda=59m, degrad=0.24)
# |  d=0.24 is a compensating parameter for structural density bias
# |  (see docs/LITERATURE_VALIDATION_SYNTHESIS.md)
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_ssp_d24.R

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
  cfg
}

# --- Helper: set Form 3d exponential edge params ---
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon   <- 1
  cfg$gms$s35_edge_form     <- 1   # Form 3d
  cfg$gms$s35_edge_formula  <- 1   # exponential
  cfg$gms$s35_edge_lambda   <- 0.059
  cfg$gms$s35_edge_degrad   <- 0.24
  cfg
}

set_edge_off <- function(cfg) {
  cfg$gms$s35_edge_carbon   <- 0
  cfg
}

folders <- c()

# --- Run 1: SSP1 OFF ---
cfg1 <- set_ssp(cfg, "SSP1")
cfg1 <- set_edge_off(cfg1)
cfg1$title <- "SSP1_d24_OFF"
cat("\n===== Starting: SSP1_d24_OFF (1 of 6) =====\n")
f1 <- start_run(cfg1, codeCheck = FALSE)
folders <- c(folders, f1)

# --- Run 2: SSP1 ON ---
cfg2 <- set_ssp(cfg, "SSP1")
cfg2 <- set_edge_on(cfg2)
cfg2$title <- "SSP1_d24_ON"
cat("\n===== Starting: SSP1_d24_ON (2 of 6) =====\n")
f2 <- start_run(cfg2, codeCheck = FALSE)
folders <- c(folders, f2)

# --- Run 3: SSP2 OFF ---
cfg3 <- set_ssp(cfg, "SSP2")
cfg3 <- set_edge_off(cfg3)
cfg3$title <- "SSP2_d24_OFF"
cat("\n===== Starting: SSP2_d24_OFF (3 of 6) =====\n")
f3 <- start_run(cfg3, codeCheck = FALSE)
folders <- c(folders, f3)

# --- Run 4: SSP2 ON ---
cfg4 <- set_ssp(cfg, "SSP2")
cfg4 <- set_edge_on(cfg4)
cfg4$title <- "SSP2_d24_ON"
cat("\n===== Starting: SSP2_d24_ON (4 of 6) =====\n")
f4 <- start_run(cfg4, codeCheck = FALSE)
folders <- c(folders, f4)

# --- Run 5: SSP3 OFF ---
cfg5 <- set_ssp(cfg, "SSP3")
cfg5 <- set_edge_off(cfg5)
cfg5$title <- "SSP3_d24_OFF"
cat("\n===== Starting: SSP3_d24_OFF (5 of 6) =====\n")
f5 <- start_run(cfg5, codeCheck = FALSE)
folders <- c(folders, f5)

# --- Run 6: SSP3 ON ---
cfg6 <- set_ssp(cfg, "SSP3")
cfg6 <- set_edge_on(cfg6)
cfg6$title <- "SSP3_d24_ON"
cat("\n===== Starting: SSP3_d24_ON (6 of 6) =====\n")
f6 <- start_run(cfg6, codeCheck = FALSE)
folders <- c(folders, f6)

cat("\n========== ALL 6 RUNS LAUNCHED ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nRuns are solving in parallel. Check progress with:\n")
cat("  ls magpie/output/SSP*_d24_*/report.rds\n")
