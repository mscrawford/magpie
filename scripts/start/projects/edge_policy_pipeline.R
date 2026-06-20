# |  Edge policy-decomposition pipeline: 6 policy configs x {edge OFF, ON} = 12 runs
# |  SSP1 {baseline, +price+bioenergy, +conservation, +combined+diet}, SSP2 base, SSP3 base
# |  Reference = SSP1 NPi baseline. Edge OFF/ON gives the within-policy edge isolation.
# |
# |  Levers (all verified against source 2026-06-20):
# |    price  high   : c56 R34M410-SSPx-PkBudg650 (most stringent / ~1.5C peak budget in R34M410;
# |                    PkBudg500 does NOT ship). baseline = R34M410-SSPx-NPi2025.
# |    bioe   high   : c60 R34M410-SSPx-PkBudg650 2nd-gen demand (~99 EJ/yr 2050, ~13x NPi floor).
# |    consv  30x30  : c22_protect_scenario "30by30", s22_conservation_target 2030.
# |    diet   EATLanc: s15_exo_diet 3 (MAgPIE planetary-health flexitarian; c15_EAT_scen is
# |                    ignored under =3 so it is intentionally NOT set).
# |  Edge ON: Bodirsky B1b closure E = kappa_j*(1-p)^n*A^beta; beta=0.8286, n=0.7984, d=0.50.
# |
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_policy_pipeline.R

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output          <- c("output_check", "rds_report")
cfg$force_download  <- FALSE
cfg$recalc_npi_ndc  <- FALSE
cfg$sequential      <- FALSE  # parallel GAMS solves

# ---------------------------------------------------------------------------
# Baseline SSP setup: socioeconomics + NPi baseline policy on every lever.
# Every lever is set EXPLICITLY (not left to clone defaults) so each run is
# fully specified and the baselines are unambiguous.
set_ssp_base <- function(cfg, ssp) {
  cfg <- gms::setScenario(cfg, c(ssp, "NPI"))
  price <- paste0("R34M410-", ssp, "-NPi2025")
  bioe  <- paste0("R34M410-", ssp, "-NPi2025")
  cfg$gms$c56_pollutant_prices          <- price
  cfg$gms$c56_pollutant_prices_noselect <- price
  cfg$gms$c60_2ndgen_biodem             <- bioe
  cfg$gms$c60_2ndgen_biodem_noselect    <- bioe
  cfg$gms$c22_protect_scenario          <- "none"   # WDPA base protection only
  cfg$gms$c22_protect_scenario_noselect <- "none"
  cfg$gms$s15_exo_diet                  <- 0        # regression-based diet (no shift)
  cfg
}

# --- Lever: high carbon price (PkBudg650, most stringent ~1.5C peak budget) ---
set_price_high <- function(cfg, ssp) {
  price <- paste0("R34M410-", ssp, "-PkBudg650")
  cfg$gms$c56_pollutant_prices          <- price
  cfg$gms$c56_pollutant_prices_noselect <- price
  cfg
}

# --- Lever: high 2nd-gen bioenergy demand (PkBudg650 trajectory) ---
set_bioenergy_high <- function(cfg, ssp) {
  bioe <- paste0("R34M410-", ssp, "-PkBudg650")
  cfg$gms$c60_2ndgen_biodem          <- bioe
  cfg$gms$c60_2ndgen_biodem_noselect <- bioe
  cfg
}

# --- Lever: 30x30 land conservation (30% protected by 2030) ---
set_conservation_30x30 <- function(cfg) {
  cfg$gms$c22_protect_scenario          <- "30by30"
  cfg$gms$c22_protect_scenario_noselect <- "30by30"
  cfg$gms$s22_conservation_start  <- 2025
  cfg$gms$s22_conservation_target <- 2030
  cfg
}

# --- Lever: EAT-Lancet flexitarian (MAgPIE planetary-health realization) ---
# s15_exo_diet=3 sources targets from the EAT-Lancet recommendation bands; the
# food-group inclusion flags + 2025->2050 fade are already at activating defaults.
set_diet_eatlancet <- function(cfg) {
  cfg$gms$s15_exo_diet <- 3
  cfg
}

# --- Edge module OFF / ON (Bodirsky B1b, d=0.50) ---
set_edge_off <- function(cfg) {
  cfg$gms$s35_edge_carbon <- 0
  cfg
}
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
# Build a policy config (edge not yet set) from the base + active levers.
build_policy <- function(cfg, policy) {
  cfg <- set_ssp_base(cfg, policy$ssp)
  if (isTRUE(policy$price_high))   cfg <- set_price_high(cfg, policy$ssp)
  if (isTRUE(policy$bioe_high))    cfg <- set_bioenergy_high(cfg, policy$ssp)
  if (isTRUE(policy$conservation)) cfg <- set_conservation_30x30(cfg)
  if (isTRUE(policy$diet))         cfg <- set_diet_eatlancet(cfg)
  cfg
}

# Six policy configs. Tag begins with SSP[0-9] and is parsed downstream.
policies <- list(
  list(tag = "SSP1base",       ssp = "SSP1"),
  list(tag = "SSP1priceBioe",  ssp = "SSP1", price_high = TRUE, bioe_high = TRUE),
  list(tag = "SSP1consv",      ssp = "SSP1", conservation = TRUE),
  list(tag = "SSP1combined",   ssp = "SSP1", price_high = TRUE, bioe_high = TRUE,
                                             conservation = TRUE, diet = TRUE),
  list(tag = "SSP2base",       ssp = "SSP2"),
  list(tag = "SSP3base",       ssp = "SSP3")
)

# ---------------------------------------------------------------------------
folders <- c()
n     <- 0L
total <- length(policies) * 2L

for (policy in policies) {
  for (edge in c("OFF", "ON")) {
    n <- n + 1L
    cfg_i <- build_policy(cfg, policy)                       # fresh copy of base cfg
    cfg_i <- if (edge == "ON") set_edge_on(cfg_i) else set_edge_off(cfg_i)
    cfg_i$title <- paste0(policy$tag, "_bodirsky_", edge)
    cat(sprintf("\n===== Starting: %s (%d/%d) =====\n", cfg_i$title, n, total))
    f <- start_run(cfg_i, codeCheck = FALSE)
    folders <- c(folders, f)
  }
}

cat("\n========== ALL 12 RUNS LAUNCHED ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nRuns are solving in parallel. Check progress with:\n")
cat("  ls magpie/output/SSP*_bodirsky_*/report.rds\n")
