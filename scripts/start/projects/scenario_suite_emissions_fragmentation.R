# |  Scenario suite: emissions + fragmentation futures.
# |  3 SSP x 5 lever-configs (edge ON) + 3 baseline edge-OFF = 18 runs,
# |  + a broad-edge (~1 km penetration) damage sensitivity on a 6-run subset = 24 total.
# |  Edge ON runs use the newest model: f35_edge_scale active (clone default, presolve.gms).
# |
# |  Levers (verified against source 2026-06-30):
# |    mitig (price+bioe): c56 + c60 R34M410-SSPx-PkBudg650 (vs NPi2025 baseline).
# |    halfearth         : c22_protect_scenario "GSN_HalfEarth" (GSN ~50% land, Dinerstein 2020),
# |                        phase-in 2025->2050.
# |    diet  (EAT-Lancet): s15_exo_diet=1 = EAT-Lancet Commission (exodietmacro.gms:372), FLX
# |                        flexitarian + healthy_BMI. (NOT =3, the MAgPIE-specific variant.)
# |    edge  broad       : s35_edge_lambda 1.0 km (vs 0.059 default) = ~1 km penetration depth;
# |                        intensity s35_edge_degrad held 0.50 (depth-only sensitivity).
# |
# |  Usage: cd magpie && Rscript scripts/start/projects/scenario_suite_emissions_fragmentation.R

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output          <- c("output_check", "rds_report")
cfg$force_download  <- FALSE
cfg$recalc_npi_ndc  <- FALSE
cfg$sequential      <- FALSE  # parallel GAMS solves

# ---------------------------------------------------------------------------
# Baseline SSP: socioeconomics + NPi on every lever (each set EXPLICITLY).
set_ssp_base <- function(cfg, ssp) {
  cfg <- gms::setScenario(cfg, c(ssp, "NPI"))
  price <- paste0("R34M410-", ssp, "-NPi2025")
  bioe  <- paste0("R34M410-", ssp, "-NPi2025")
  cfg$gms$c56_pollutant_prices          <- price
  cfg$gms$c56_pollutant_prices_noselect <- price
  cfg$gms$c60_2ndgen_biodem             <- bioe
  cfg$gms$c60_2ndgen_biodem_noselect    <- bioe
  cfg$gms$c22_protect_scenario          <- "none"
  cfg$gms$c22_protect_scenario_noselect <- "none"
  cfg$gms$s15_exo_diet                  <- 0
  cfg
}

# --- Lever: mitigation (high carbon price, PkBudg650 ~1.5C peak budget) ---
set_price_high <- function(cfg, ssp) {
  price <- paste0("R34M410-", ssp, "-PkBudg650")
  cfg$gms$c56_pollutant_prices          <- price
  cfg$gms$c56_pollutant_prices_noselect <- price
  cfg
}
# --- Lever: high 2nd-gen bioenergy demand (PkBudg650 trajectory; co-moves with price) ---
set_bioenergy_high <- function(cfg, ssp) {
  bioe <- paste0("R34M410-", ssp, "-PkBudg650")
  cfg$gms$c60_2ndgen_biodem          <- bioe
  cfg$gms$c60_2ndgen_biodem_noselect <- bioe
  cfg
}
# --- Lever: Half-Earth land conservation (GSN ~50% protection, phase-in 2025->2050) ---
set_conservation_halfearth <- function(cfg) {
  cfg$gms$c22_protect_scenario          <- "GSN_HalfEarth"
  cfg$gms$c22_protect_scenario_noselect <- "GSN_HalfEarth"
  cfg$gms$s22_conservation_start  <- 2025
  cfg$gms$s22_conservation_target <- 2050
  cfg
}
# --- Lever: EAT-Lancet Commission diet (s15_exo_diet=1, FLX flexitarian, healthy_BMI) ---
set_diet_eatlancet <- function(cfg) {
  cfg$gms$s15_exo_diet  <- 1            # =1 EAT-Lancet Commission (exodietmacro.gms:372)
  cfg$gms$c15_EAT_scen  <- "FLX"        # flexitarian (module default; set explicit)
  cfg$gms$c15_kcal_scen <- "healthy_BMI"
  cfg
}

# --- Edge module OFF / ON (Bodirsky B1b, d=0.50; f35_edge_scale active by clone default) ---
set_edge_off <- function(cfg) {
  cfg$gms$s35_edge_carbon <- 0
  cfg
}
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon  <- 1
  cfg$gms$s35_edge_formula <- 1      # exponential decay
  cfg$gms$s35_edge_lambda  <- 0.059  # ~59 m penetration depth (default)
  cfg$gms$s35_edge_degrad  <- 0.50
  cfg$gms$s35_edge_beta    <- 0.8286
  cfg$gms$s35_edge_n       <- 0.7984
  cfg
}
# --- Edge-damage sensitivity: broad ~1 km penetration (depth-only; intensity held) ---
set_edge_broad <- function(cfg) {
  cfg <- set_edge_on(cfg)
  cfg$gms$s35_edge_lambda <- 1.0     # ~1 km penetration (vs 0.059); degrad stays 0.50
  cfg
}

# ---------------------------------------------------------------------------
build_policy <- function(cfg, p) {
  cfg <- set_ssp_base(cfg, p$ssp)
  if (isTRUE(p$price_high)) cfg <- set_price_high(cfg, p$ssp)
  if (isTRUE(p$bioe_high))  cfg <- set_bioenergy_high(cfg, p$ssp)
  if (isTRUE(p$halfearth))  cfg <- set_conservation_halfearth(cfg)
  if (isTRUE(p$diet))       cfg <- set_diet_eatlancet(cfg)
  cfg
}

# 3 SSP x 5 lever-configs. Tag begins SSP[0-9], parsed downstream by run_pattern.
ssp_block <- function(ssp) list(
  list(tag = paste0(ssp, "base"),      ssp = ssp, pair_off = TRUE),
  list(tag = paste0(ssp, "mitig"),     ssp = ssp, price_high = TRUE, bioe_high = TRUE),
  list(tag = paste0(ssp, "halfearth"), ssp = ssp, halfearth = TRUE),
  list(tag = paste0(ssp, "diet"),      ssp = ssp, diet = TRUE),
  list(tag = paste0(ssp, "all"),       ssp = ssp, price_high = TRUE, bioe_high = TRUE,
                                                  halfearth = TRUE, diet = TRUE))
policies <- c(ssp_block("SSP1"), ssp_block("SSP2"), ssp_block("SSP3"))

# ---------------------------------------------------------------------------
folders <- c(); n <- 0L
launch <- function(cfg_i, title) {
  cfg_i$title <- title; n <<- n + 1L
  cat(sprintf("\n===== %s (%d) =====\n", title, n))
  folders <<- c(folders, start_run(cfg_i, codeCheck = FALSE))
}

# 15 edge-ON + 3 baseline edge-OFF = 18
for (p in policies) {
  for (edge in if (isTRUE(p$pair_off)) c("OFF", "ON") else "ON") {
    cfg_i <- build_policy(cfg, p)
    cfg_i <- if (edge == "ON") set_edge_on(cfg_i) else set_edge_off(cfg_i)
    launch(cfg_i, paste0(p$tag, "_bodirsky_", edge))
  }
}

# Broad-edge (~1 km) sensitivity on a spanning subset: 3 baselines + 3 mitigation = 6
broad_subset <- c("SSP1base", "SSP2base", "SSP3base", "SSP1mitig", "SSP2mitig", "SSP3mitig")
for (p in policies) if (p$tag %in% broad_subset) {
  launch(set_edge_broad(build_policy(cfg, p)), paste0(p$tag, "Broad_bodirsky_ON"))
}

cat(sprintf("\n========== ALL %d RUNS LAUNCHED ==========\n", length(folders)))
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nMonitor:\n  ls magpie/output/SSP*_bodirsky_*/report.rds\n")
