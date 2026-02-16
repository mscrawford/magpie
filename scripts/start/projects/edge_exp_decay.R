# |  Edge-effect exponential decay comparison: SSP2 × 4 configs
# |  Config 1: OFF (baseline)
# |  Config 2: Form 3d, step formula (d=500m, degrad=0.25) — old default
# |  Config 3: Form 3d, exponential decay (lambda=59m, degrad=0.25)
# |  Config 4: Form 3d, exponential decay (lambda=59m, degrad=0.50)
# |  TS_benni timesteps (1995-2050)
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_exp_decay.R

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "TS_benni"
cfg$output <- c("output_check", "rds_report")

# Form 3d closure parameters (unchanged)
FORM3D <- list(
  beta   = 0.8784410,
  gamma  = -2.6885421,
  gamma2 = 5.9352517,
  gamma3 = -4.8536250
)

set_ssp2 <- function(cfg) {
  cfg <- gms::setScenario(cfg, c("SSP2", "NPI"))
  cfg$gms$c56_pollutant_prices <- "R34M410-SSP2-NPi2025"
  cfg$gms$c56_pollutant_prices_noselect <- "R34M410-SSP2-NPi2025"
  return(cfg)
}

set_3d_params <- function(cfg) {
  cfg$gms$s35_edge_carbon <- 1
  cfg$gms$s35_edge_form   <- 1
  cfg$gms$s35_edge_beta   <- FORM3D$beta
  cfg$gms$s35_edge_gamma  <- FORM3D$gamma
  cfg$gms$s35_edge_gamma2 <- FORM3D$gamma2
  cfg$gms$s35_edge_gamma3 <- FORM3D$gamma3
  return(cfg)
}

folders <- character(0)

# --- Run 1: SSP2 edge OFF ---
cfg1 <- set_ssp2(cfg)
cfg1$title <- "SSP2_exptest_OFF"
cfg1$gms$s35_edge_carbon <- 0
cat("\n===== Starting: SSP2_exptest_OFF (1 of 4) =====\n")
f1 <- start_run(cfg1, codeCheck = FALSE)
folders <- c(folders, f1)

# --- Run 2: SSP2 step d=500m degrad=0.25 (old default) ---
cfg2 <- set_ssp2(cfg)
cfg2 <- set_3d_params(cfg2)
cfg2$title <- "SSP2_exptest_step500"
cfg2$gms$s35_edge_formula <- 0  # step
cfg2$gms$s35_edge_depth   <- 0.5
cfg2$gms$s35_edge_degrad  <- 0.25
cat("\n===== Starting: SSP2_exptest_step500 (2 of 4) =====\n")
f2 <- start_run(cfg2, codeCheck = FALSE)
folders <- c(folders, f2)

# --- Run 3: SSP2 exponential lambda=59m degrad=0.25 ---
cfg3 <- set_ssp2(cfg)
cfg3 <- set_3d_params(cfg3)
cfg3$title <- "SSP2_exptest_exp59_d25"
cfg3$gms$s35_edge_formula <- 1  # exponential
cfg3$gms$s35_edge_lambda  <- 0.059
cfg3$gms$s35_edge_degrad  <- 0.25
cat("\n===== Starting: SSP2_exptest_exp59_d25 (3 of 4) =====\n")
f3 <- start_run(cfg3, codeCheck = FALSE)
folders <- c(folders, f3)

# --- Run 4: SSP2 exponential lambda=59m degrad=0.50 ---
cfg4 <- set_ssp2(cfg)
cfg4 <- set_3d_params(cfg4)
cfg4$title <- "SSP2_exptest_exp59_d50"
cfg4$gms$s35_edge_formula <- 1  # exponential
cfg4$gms$s35_edge_lambda  <- 0.059
cfg4$gms$s35_edge_degrad  <- 0.50
cat("\n===== Starting: SSP2_exptest_exp59_d50 (4 of 4) =====\n")
f4 <- start_run(cfg4, codeCheck = FALSE)
folders <- c(folders, f4)

cat("\n========== ALL 4 RUNS COMPLETE ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
