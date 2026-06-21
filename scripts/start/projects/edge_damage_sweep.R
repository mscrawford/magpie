# |  EDGE DAMAGE SWEEP - literature-core extreme-damage scenarios.
# |
# |  Behavioral re-runs that vary the edge DAMAGE parameters - intensity d0 (s35_edge_degrad)
# |  and penetration depth lambda (s35_edge_lambda) - across a literature-anchored ladder, while
# |  holding the shipped closure GEOMETRY fixed (beta/n, forestry_buffer=1). Land use re-optimizes,
# |  so this tests whether more extreme but defensible edge damage changes the SSP1 price co-benefit
# |  SINK, the SSP1/SSP3 base SOURCE, and the land-use allocation.
# |
# |  Damage ladder (d0, lambda_km) - anchors verified 2026-06-21 (Consensus):
# |    d50l059  (0.50, 0.059)  D0 baseline / reproducibility anchor (Brinck/Taubert biophysical core)
# |    d60l059  (0.60, 0.059)  D1 high intensity        (Yang 2025 at-edge beta1 -> d0 ~ 0.60)
# |    d50l120  (0.50, 0.120)  Dc central depth         (Zhao 2021 African median 110-150 m; tests
# |                                                      whether the shipped 59 m is conservative)
# |    d50l285  (0.50, 0.285)  D2 CK15 total-degradation (Chaplin-Kramer 2015 joint fit: reproduces
# |                                                      25%@500m AND 10%@1.5km, incl. confounders)
# |    d60l285  (0.60, 0.285)  D3 upper corner          (Yang intensity x CK15 depth)
# |
# |  Scenarios: SSP1 base (NPi), SSP1 priceBioe (PkBudg650), SSP3 base (NPi).
# |    -> 5 damage x 3 scenarios = 15 behavioral runs.
# |
# |  Settings MIRROR edge_forestry_buffer_sweep.R / edge_policy_pipeline.R exactly. Edge-ON closure:
# |  Bodirsky B1b exp-decay, beta=0.8286, n=0.7984, forestry_buffer=1 (shipped geometry, held fixed).
# |  d50l059 must reproduce the shipped buff100 runs bit-identically (correctness check).
# |
# |  Titles: <scenario>_<dmgTag>_bodirsky_ON. The dmg code precedes "_bodirsky" so these runs do
# |  NOT match the policy find_latest("^<tag>_bodirsky_(ON|OFF)_") and will not pollute scripts 11-15.
# |
# |  Usage - MUST run with the main renv ACTIVE, else every run aborts at node startup with
# |  "cannot open file 'renv/activate.R'" (renv::project() NULL -> start_functions skips renv
# |  setup but still ships the .Rprofile that sources renv/activate.R; also picks up the WRONG
# |  upstream magpie4 2.70.0 instead of the fork's edge-aware 2.76.x). Launch FROM the magpie root:
# |    cd <magpie> && Rscript scripts/start/projects/edge_damage_sweep.R
# |  or without a shell cd:  env -C <magpie> Rscript scripts/start/projects/edge_damage_sweep.R
# |  (NOTE: setwd()+source(".Rprofile") AFTER startup does NOT work - rlang/etc. load from the
# |   startup lib first, then clash when renv switches libpaths. R must START in the magpie root.)
# |  Pre-launch check: renv::project() non-NULL AND magpie4 from renv/library (fork 2.76.x).

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output          <- c("output_check", "rds_report")
cfg$force_download  <- FALSE
cfg$recalc_npi_ndc  <- FALSE
cfg$sequential      <- FALSE  # parallel GAMS solves, SLURM auto-detected by start_run

# ---------------------------------------------------------------------------
# Baseline SSP setup (identical to edge_forestry_buffer_sweep.R set_ssp_base).
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

# --- Edge module ON (Bodirsky B1b); damage params d0/lambda parameterized ----
# Geometry held at shipped values (beta/n, forestry_buffer=1); only degrad + lambda vary.
set_edge_on <- function(cfg, d0, lambda_km) {
  cfg$gms$s35_edge_carbon          <- 1
  cfg$gms$s35_edge_formula         <- 1          # exponential decay
  cfg$gms$s35_edge_lambda          <- lambda_km
  cfg$gms$s35_edge_degrad          <- d0
  cfg$gms$s35_edge_beta            <- 0.8286
  cfg$gms$s35_edge_n               <- 0.7984
  cfg$gms$s35_edge_forestry_buffer <- 1          # shipped geometry (explicit; do not inherit default)
  cfg
}

# ---------------------------------------------------------------------------
# Damage ladder: list(tag, d0, lambda_km).
damage <- list(
  list(tag = "d50l059", d0 = 0.50, lambda = 0.059),  # D0 baseline (shipped)
  list(tag = "d60l059", d0 = 0.60, lambda = 0.059),  # D1 intensity  (Yang)
  list(tag = "d50l120", d0 = 0.50, lambda = 0.120),  # Dc central depth (Zhao)
  list(tag = "d50l285", d0 = 0.50, lambda = 0.285),  # D2 CK15 total-degradation
  list(tag = "d60l285", d0 = 0.60, lambda = 0.285)   # D3 upper corner
)

# Scenarios: list(tag, ssp, price).
scenarios <- list(
  list(tag = "SSP1base",      ssp = "SSP1", price = FALSE),
  list(tag = "SSP1priceBioe", ssp = "SSP1", price = TRUE),
  list(tag = "SSP3base",      ssp = "SSP3", price = FALSE)
)

folders <- c()
n     <- 0L
total <- length(scenarios) * length(damage)

cat(sprintf("\n===== EDGE DAMAGE SWEEP: %d runs (%d scenarios x %d damage configs) =====\n",
            total, length(scenarios), length(damage)))

for (sc in scenarios) {
  for (dm in damage) {
    n <- n + 1L
    cfg_i <- set_ssp_base(cfg, sc$ssp)
    if (isTRUE(sc$price)) cfg_i <- set_priceBioe(cfg_i, sc$ssp)
    cfg_i <- set_edge_on(cfg_i, dm$d0, dm$lambda)
    cfg_i$title <- paste0(sc$tag, "_", dm$tag, "_bodirsky_ON")
    cat(sprintf("\n----- Starting: %s (%d/%d)  [d0=%.2f lambda=%.3f km] -----\n",
                cfg_i$title, n, total, dm$d0, dm$lambda))
    f <- start_run(cfg_i, codeCheck = FALSE)
    folders <- c(folders, f)
  }
}

cat("\n========== ALL ", total, " DAMAGE-SWEEP RUNS LAUNCHED ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nRuns solving in parallel on SLURM. Check progress with:\n")
cat("  squeue -u $USER\n")
cat("  ls output/SSP*_d??l???_bodirsky_ON_*/report.rds\n")
