# |  Edge pipeline Option B comparison: SSP1/2/3 × {OFF, INST, OPTB}
# |  9 runs in parallel
# |  Full coup2100 timesteps (1995-2100)
# |  Tests Option B symmetric pipeline (tau=13yr) vs instant and OFF
# |  d=0.50 = physical equilibrium value
# |  Option B = symmetric realized-loss pipeline (replaces asymmetric Option C)
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_optionB.R

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

# --- Edge OFF ---
set_edge_off <- function(cfg) {
  cfg$gms$s35_edge_carbon <- 0
  cfg
}

# --- Edge ON, instant (d=0.50, no pipeline) ---
set_edge_instant <- function(cfg) {
  cfg$gms$s35_edge_carbon   <- 1
  cfg$gms$s35_edge_form     <- 1   # Form 3d
  cfg$gms$s35_edge_formula  <- 1   # exponential
  cfg$gms$s35_edge_lambda   <- 0.059
  cfg$gms$s35_edge_degrad   <- 0.50
  cfg$gms$s35_edge_pipeline <- 0   # instant release
  cfg
}

# --- Edge ON, Option B symmetric pipeline (d=0.50, tau=13yr) ---
set_edge_optB <- function(cfg) {
  cfg$gms$s35_edge_carbon   <- 1
  cfg$gms$s35_edge_form     <- 1   # Form 3d
  cfg$gms$s35_edge_formula  <- 1   # exponential
  cfg$gms$s35_edge_lambda   <- 0.059
  cfg$gms$s35_edge_degrad   <- 0.50
  cfg$gms$s35_edge_pipeline <- 1   # Option B symmetric pipeline
  cfg$gms$s35_edge_tau      <- 13  # Brinck 2017
  cfg$gms$s35_edge_thist    <- 41  # calibrated to Brinck 0.34 GtC/yr
  cfg
}

folders <- c()

# --- SSP1 ---
cfg1 <- set_ssp(cfg, "SSP1"); cfg1 <- set_edge_off(cfg1)
cfg1$title <- "SSP1_optB_OFF"
cat("\n===== Starting: SSP1_optB_OFF (1/9) =====\n")
f1 <- start_run(cfg1, codeCheck = FALSE); folders <- c(folders, f1)

cfg2 <- set_ssp(cfg, "SSP1"); cfg2 <- set_edge_instant(cfg2)
cfg2$title <- "SSP1_optB_INST"
cat("\n===== Starting: SSP1_optB_INST (2/9) =====\n")
f2 <- start_run(cfg2, codeCheck = FALSE); folders <- c(folders, f2)

cfg3 <- set_ssp(cfg, "SSP1"); cfg3 <- set_edge_optB(cfg3)
cfg3$title <- "SSP1_optB_SYMM"
cat("\n===== Starting: SSP1_optB_SYMM (3/9) =====\n")
f3 <- start_run(cfg3, codeCheck = FALSE); folders <- c(folders, f3)

# --- SSP2 ---
cfg4 <- set_ssp(cfg, "SSP2"); cfg4 <- set_edge_off(cfg4)
cfg4$title <- "SSP2_optB_OFF"
cat("\n===== Starting: SSP2_optB_OFF (4/9) =====\n")
f4 <- start_run(cfg4, codeCheck = FALSE); folders <- c(folders, f4)

cfg5 <- set_ssp(cfg, "SSP2"); cfg5 <- set_edge_instant(cfg5)
cfg5$title <- "SSP2_optB_INST"
cat("\n===== Starting: SSP2_optB_INST (5/9) =====\n")
f5 <- start_run(cfg5, codeCheck = FALSE); folders <- c(folders, f5)

cfg6 <- set_ssp(cfg, "SSP2"); cfg6 <- set_edge_optB(cfg6)
cfg6$title <- "SSP2_optB_SYMM"
cat("\n===== Starting: SSP2_optB_SYMM (6/9) =====\n")
f6 <- start_run(cfg6, codeCheck = FALSE); folders <- c(folders, f6)

# --- SSP3 ---
cfg7 <- set_ssp(cfg, "SSP3"); cfg7 <- set_edge_off(cfg7)
cfg7$title <- "SSP3_optB_OFF"
cat("\n===== Starting: SSP3_optB_OFF (7/9) =====\n")
f7 <- start_run(cfg7, codeCheck = FALSE); folders <- c(folders, f7)

cfg8 <- set_ssp(cfg, "SSP3"); cfg8 <- set_edge_instant(cfg8)
cfg8$title <- "SSP3_optB_INST"
cat("\n===== Starting: SSP3_optB_INST (8/9) =====\n")
f8 <- start_run(cfg8, codeCheck = FALSE); folders <- c(folders, f8)

cfg9 <- set_ssp(cfg, "SSP3"); cfg9 <- set_edge_optB(cfg9)
cfg9$title <- "SSP3_optB_SYMM"
cat("\n===== Starting: SSP3_optB_SYMM (9/9) =====\n")
f9 <- start_run(cfg9, codeCheck = FALSE); folders <- c(folders, f9)

cat("\n========== ALL 9 RUNS LAUNCHED ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nRuns are solving in parallel. Check progress with:\n")
cat("  ls magpie/output/SSP*_optB_*/report.rds\n")
