# |  Edge Bodirsky closure comparison: SSP1/2/3 × {OFF, ON}
# |  6 runs in parallel
# |  Full coup2100 timesteps (1995-2100)
# |  Bodirsky B1b closure: E = kappa_j * (1-p)^n * A^beta
# |  beta=0.8286, n=0.7984 (cluster FE model, R²=0.977)
# |  d=0.50 = physical equilibrium value (Chaplin-Kramer acute zone)
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_pipeline.R

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

# --- Edge ON (Bodirsky B1b, d=0.50) ---
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon   <- 1
  cfg$gms$s35_edge_formula  <- 1      # exponential decay
  cfg$gms$s35_edge_lambda   <- 0.059
  cfg$gms$s35_edge_degrad   <- 0.50
  cfg$gms$s35_edge_beta     <- 0.8286
  cfg$gms$s35_edge_n        <- 0.7984
  cfg
}

folders <- c()

# --- SSP1 ---
cfg1 <- set_ssp(cfg, "SSP1"); cfg1 <- set_edge_off(cfg1)
cfg1$title <- "SSP1_bodirsky_OFF"
cat("\n===== Starting: SSP1_bodirsky_OFF (1/6) =====\n")
f1 <- start_run(cfg1, codeCheck = FALSE); folders <- c(folders, f1)

cfg2 <- set_ssp(cfg, "SSP1"); cfg2 <- set_edge_on(cfg2)
cfg2$title <- "SSP1_bodirsky_ON"
cat("\n===== Starting: SSP1_bodirsky_ON (2/6) =====\n")
f2 <- start_run(cfg2, codeCheck = FALSE); folders <- c(folders, f2)

# --- SSP2 ---
cfg3 <- set_ssp(cfg, "SSP2"); cfg3 <- set_edge_off(cfg3)
cfg3$title <- "SSP2_bodirsky_OFF"
cat("\n===== Starting: SSP2_bodirsky_OFF (3/6) =====\n")
f3 <- start_run(cfg3, codeCheck = FALSE); folders <- c(folders, f3)

cfg4 <- set_ssp(cfg, "SSP2"); cfg4 <- set_edge_on(cfg4)
cfg4$title <- "SSP2_bodirsky_ON"
cat("\n===== Starting: SSP2_bodirsky_ON (4/6) =====\n")
f4 <- start_run(cfg4, codeCheck = FALSE); folders <- c(folders, f4)

# --- SSP3 ---
cfg5 <- set_ssp(cfg, "SSP3"); cfg5 <- set_edge_off(cfg5)
cfg5$title <- "SSP3_bodirsky_OFF"
cat("\n===== Starting: SSP3_bodirsky_OFF (5/6) =====\n")
f5 <- start_run(cfg5, codeCheck = FALSE); folders <- c(folders, f5)

cfg6 <- set_ssp(cfg, "SSP3"); cfg6 <- set_edge_on(cfg6)
cfg6$title <- "SSP3_bodirsky_ON"
cat("\n===== Starting: SSP3_bodirsky_ON (6/6) =====\n")
f6 <- start_run(cfg6, codeCheck = FALSE); folders <- c(folders, f6)

cat("\n========== ALL 6 RUNS LAUNCHED ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nRuns are solving in parallel. Check progress with:\n")
cat("  ls magpie/output/SSP*_bodirsky_*/report.rds\n")
