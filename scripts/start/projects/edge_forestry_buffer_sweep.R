# |  SECOND AUDIT #2 - behavioral plantation-edge-buffer sweep.
# |
# |  Re-runs SSP1 base + SSP1 priceBioe (bodirsky_ON) across the new geometry lever
# |    s35_edge_forestry_buffer in {0.0, 0.25, 0.5, 0.75, 1.0}  -> 10 runs.
# |  The lever weights the forestry (plantation) term in the closure GEOMETRY forest
# |  area p35_forest_area only (presolve.gms:274-280); the edge-affected carbon stock
# |  is unchanged (natural forest only). w=1.0 reproduces the shipped runs bit-identically
# |  (correctness check vs SSP1{base,priceBioe}_bodirsky_ON_2026-06-20); w=0.0 fully
# |  excludes plantations from the geometry (the fixed-land "+78 source" geometry, now
# |  run behaviorally so land use can re-optimize).
# |
# |  Settings mirror edge_policy_pipeline.R exactly (verified against the existing
# |  SSP1base / SSP1priceBioe config.yml 2026-06-20). Edge-ON closure: Bodirsky B1b
# |  exp-decay, lambda=0.059, d=0.50, beta=0.8286, n=0.7984.
# |
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_forestry_buffer_sweep.R

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output          <- c("output_check", "rds_report")
cfg$force_download  <- FALSE
cfg$recalc_npi_ndc  <- FALSE
cfg$sequential      <- FALSE  # parallel GAMS solves, SLURM auto-detected by start_run

# ---------------------------------------------------------------------------
# Baseline SSP setup (identical to edge_policy_pipeline.R set_ssp_base).
set_ssp_base <- function(cfg, ssp) {
  cfg <- gms::setScenario(cfg, c(ssp, "NPI"))
  base <- paste0("R34M410-", ssp, "-NPi2025")
  cfg$gms$c56_pollutant_prices          <- base
  cfg$gms$c56_pollutant_prices_noselect <- base
  cfg$gms$c60_2ndgen_biodem             <- base
  cfg$gms$c60_2ndgen_biodem_noselect    <- base
  cfg$gms$c22_protect_scenario          <- "none"
  cfg$gms$c22_protect_scenario_noselect <- "none"
  cfg$gms$s15_exo_diet                  <- 0
  cfg
}

# --- price+bioenergy lever (PkBudg650 on both c56 and c60) -------------------
set_priceBioe <- function(cfg, ssp) {
  pk <- paste0("R34M410-", ssp, "-PkBudg650")
  cfg$gms$c56_pollutant_prices          <- pk
  cfg$gms$c56_pollutant_prices_noselect <- pk
  cfg$gms$c60_2ndgen_biodem             <- pk
  cfg$gms$c60_2ndgen_biodem_noselect    <- pk
  cfg
}

# --- Edge module ON (Bodirsky B1b, d=0.50) - identical to edge_policy_pipeline.R
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon  <- 1
  cfg$gms$s35_edge_formula <- 1      # exponential decay
  cfg$gms$s35_edge_lambda  <- 0.059
  cfg$gms$s35_edge_degrad  <- 0.50
  cfg$gms$s35_edge_beta    <- 0.8286
  cfg$gms$s35_edge_n       <- 0.7984
  cfg
}

# ---------------------------------------------------------------------------
# Sweep grid: {base, priceBioe} x buffer weight.
buffers   <- c(0.00, 0.25, 0.50, 0.75, 1.00)
scenarios <- list(
  list(tag = "SSP1base",      ssp = "SSP1", price = FALSE),
  list(tag = "SSP1priceBioe", ssp = "SSP1", price = TRUE)
)

folders <- c()
n     <- 0L
total <- length(scenarios) * length(buffers)

for (sc in scenarios) {
  for (w in buffers) {
    n <- n + 1L
    cfg_i <- set_ssp_base(cfg, sc$ssp)
    if (isTRUE(sc$price)) cfg_i <- set_priceBioe(cfg_i, sc$ssp)
    cfg_i <- set_edge_on(cfg_i)
    cfg_i$gms$s35_edge_forestry_buffer <- w
    # tag e.g. SSP1priceBioe_buff050 (3-digit hundredths so 0.5 -> 050)
    wtag <- sprintf("buff%03d", as.integer(round(w * 100)))
    cfg_i$title <- paste0(sc$tag, "_bodirsky_ON_", wtag)
    cat(sprintf("\n===== Starting: %s (%d/%d)  [s35_edge_forestry_buffer=%.2f] =====\n",
                cfg_i$title, n, total, w))
    f <- start_run(cfg_i, codeCheck = FALSE)
    folders <- c(folders, f)
  }
}

cat("\n========== ALL ", total, " SWEEP RUNS LAUNCHED ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nRuns solving in parallel on SLURM. Check progress with:\n")
cat("  squeue -u $USER\n")
cat("  ls magpie/output/SSP1*_bodirsky_ON_buff*/report.rds\n")
