# |  Edge gate + develop-merge verification run: SSP1/2/3 bodirsky ON only.
# |  Mirrors edge_pipeline.R config exactly (produced the 2026-03-06 runs).
# |  Only the 3 ON scenarios are re-run: the tropical gate sits inside
# |  if(s35_edge_carbon = 1, ...), so the OFF runs are unchanged.
# |  Bodirsky B1b closure: E = kappa_j * (1-p)^n * A^beta; d=0.50.
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_verify_3ON.R

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output <- c("output_check", "rds_report")
cfg$force_download <- FALSE
cfg$recalc_npi_ndc <- FALSE
cfg$sequential <- FALSE  # parallel GAMS solves

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

cfg1 <- set_ssp(cfg, "SSP1"); cfg1 <- set_edge_on(cfg1)
cfg1$title <- "SSP1_bodirsky_ON_v2"
cat("\n===== Starting: SSP1_bodirsky_ON_v2 (1/3) =====\n")
f1 <- start_run(cfg1, codeCheck = FALSE); folders <- c(folders, f1)

cfg2 <- set_ssp(cfg, "SSP2"); cfg2 <- set_edge_on(cfg2)
cfg2$title <- "SSP2_bodirsky_ON_v2"
cat("\n===== Starting: SSP2_bodirsky_ON_v2 (2/3) =====\n")
f2 <- start_run(cfg2, codeCheck = FALSE); folders <- c(folders, f2)

cfg3 <- set_ssp(cfg, "SSP3"); cfg3 <- set_edge_on(cfg3)
cfg3$title <- "SSP3_bodirsky_ON_v2"
cat("\n===== Starting: SSP3_bodirsky_ON_v2 (3/3) =====\n")
f3 <- start_run(cfg3, codeCheck = FALSE); folders <- c(folders, f3)

cat("\n========== 3 ON RUNS LAUNCHED ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nCheck progress with:\n")
cat("  ls magpie/output/SSP*_bodirsky_ON_v2_*/report.rds\n")
