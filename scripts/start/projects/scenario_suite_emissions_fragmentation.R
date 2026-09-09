# |  Scenario suite: emissions + fragmentation futures (SCENARIO-CONSISTENT RCP).
# |  Narrative-consistent lever + RCP design (consistency with the SSP narrative > factorial symmetry):
# |    SSP1 Sustainability : 5 levers; sustainability world at RCP2.6, the all-levers package reaches RCP1.9.
# |                          mitigation = PkBudg650 (1.5C price).
# |    SSP2 Middle-of-road : base + mitig + 30by30 conservation + diet + all. Current policies at RCP4.5;
# |                          mitigation = PkBudg1000 (2C price) at RCP2.6; conservation = 30by30 (Kunming-Montreal).
# |    SSP3 Regional Rivalry: base ONLY (no sustainability interventions); high-forcing RCP7.0 world.
# |  = 11 edge-ON + 3 baseline edge-OFF + 5 broad-edge (~1 km) = 19 runs (SSP1 8, SSP2 8, SSP3 3).
# |  2026-09-09: switches aligned with the RIKEN fst_levers canonical set (Mike: 'use the switches canonically'):
# |    diet = s15_exo_diet 3 (MAgPIE's own EAT-Lancet realization, healthy_BMI, 2025->2050 fade; was mode 1 + FLX);
# |    conservation SSP1 = the full RIKEN protection bundle (area + BII floor 0.78 + SNV 0.2 + env flows, all to 2050);
# |    conservation SSP2 = 30by30 area only (decision open: bundle or area); mitigation runs price ALL land emissions
# |    (c56_emis_policy all_nosoil, prices unmuted from 2025; baselines keep the stock reddnatveg_nosoil / y2030 = RIKEN BAU);
# |    SSP2diet added as the diet-change scenario (RIKEN runs diet on SSP2; re-added on Mike's ask after the 07-01 drop).
# |    Not ported: tau pinning, the Japan bioenergy carve-out, the BioNone arm (RIKEN-specific).
# |  2026-08-29: edge model version L3 (haircut split + AGB-only factor + forest-weighted gate) - see set_edge_on.
# |
# |  RCP is per-CONFIG: gms::setScenario(cfg, c(ssp,"NPI",rcp)) sets the LPJmL cellular climate input
# |  AND c52_land_carbon_sink_rcp; c37_labor_rcp is set manually (module 37 offers only rcp119/rcp585
# |  -> nearest bracket). Per-RCP cellular inputs (ssp119/ssp126/ssp370) live in the local madrat pool
# |  (registered below), NOT the public server. ONE calibration is valid across RCPs of the same GCM+rev
# |  (the land-conversion calib is fit on the shared 1995-2015 historical climate; sm_fix_cc=2025).
# |
# |  Levers (verified against source 2026-07-01):
# |    mitig (price+bioe): c56 + c60 R34M410-SSPx-PkBudg{650 SSP1 | 1000 SSP2} (vs NPi2025 baseline).
# |    30by30            : c22_protect_scenario "30by30" (~30% land, Kunming-Montreal GBF), phase-in 2025->2050.
# |    halfearth         : c22_protect_scenario "GSN_HalfEarth" (~50% land, Dinerstein 2020), SSP1 only.
# |    diet  (EAT-Lancet): s15_exo_diet=3 (exodietmacro.gms:441, MAgPIE-specific EAT-Lancet), healthy_BMI, fade 2025->2050;
# |                        c15_EAT_scen deliberately NOT set (inert under mode 3; a non-BMI kcal target would route back to it).
# |    edge  broad       : s35_edge_lambda 1.0 km (vs 0.059) = ~1 km depth; intensity s35_edge_degrad held 0.50.
# |
# |  Usage: cd magpie && Rscript scripts/start/projects/scenario_suite_emissions_fragmentation.R
# |         SUITE_DRYRUN=1 Rscript ...  prints each run's wired config (cellular/c52/c37/c56/c22/diet) + exits.

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output          <- c("output_check", "rds_report")
cfg$force_download  <- FALSE
cfg$recalc_npi_ndc  <- FALSE
cfg$sequential      <- FALSE  # parallel GAMS solves

# Per-RCP LPJmL cellular inputs (ssp119/ssp126/ssp370 for rcp1p9/rcp2p6/rcp7p0) are in the local madrat
# pool, not on the public download server. Register it so setScenario's rcp token can resolve them.
cfg$repositories <- append(cfg$repositories,
                           list("file:///p/projects/rd3mod/inputdata/output_1.27" = NULL))

DRYRUN <- identical(Sys.getenv("SUITE_DRYRUN"), "1")

# ---------------------------------------------------------------------------
# Labor-productivity RCP bracket: module 37 offers only rcp119 / rcp585 -> nearest to the run's forcing.
labor_rcp <- function(rcp) if (rcp %in% c("rcp6p0", "rcp7p0", "rcp8p5")) "rcp585" else "rcp119"

# Baseline SSP: socioeconomics + NPi policy + RCP-consistent climate (each field set EXPLICITLY).
# setScenario(c(ssp,"NPI",rcp)) sets cfg$input['cellular'] (LPJmL climate) + c52_land_carbon_sink_rcp.
set_ssp_base <- function(cfg, ssp, rcp) {
  cfg <- gms::setScenario(cfg, c(ssp, "NPI", rcp))
  cfg$gms$c37_labor_rcp <- labor_rcp(rcp)   # setScenario does NOT set this; bracket manually
  price <- paste0("R34M410-", ssp, "-NPi2025")
  cfg$gms$c56_pollutant_prices          <- price
  cfg$gms$c56_pollutant_prices_noselect <- price
  cfg$gms$c60_2ndgen_biodem             <- price
  cfg$gms$c60_2ndgen_biodem_noselect    <- price
  cfg$gms$c22_protect_scenario          <- "none"
  cfg$gms$c22_protect_scenario_noselect <- "none"
  cfg$gms$s15_exo_diet                  <- 0
  cfg
}

# --- Lever: mitigation (high carbon price + co-moving 2nd-gen bioenergy at the SSP's peak budget) ---
set_price_high <- function(cfg, ssp, budget) {
  price <- paste0("R34M410-", ssp, "-", budget)
  cfg$gms$c56_pollutant_prices          <- price
  cfg$gms$c56_pollutant_prices_noselect <- price
  # GHG-policy frame of the RIKEN FST cells (fst_levers_config.R FST_BACKDROP): the price applies to ALL land emissions
  # except soil, from 2025. Stock default (reddnatveg_nosoil, muted until 2030) stays on the baselines, as RIKEN's BAU.
  cfg$gms$c56_emis_policy          <- "all_nosoil"
  cfg$gms$c56_mute_ghgprices_until <- "y2025"
  cfg
}
set_bioenergy_high <- function(cfg, ssp, budget) {
  bioe <- paste0("R34M410-", ssp, "-", budget)
  cfg$gms$c60_2ndgen_biodem          <- bioe
  cfg$gms$c60_2ndgen_biodem_noselect <- bioe
  cfg
}
# --- Lever: land conservation (c22 scenario "30by30" ~30% or "GSN_HalfEarth" ~50%), phase-in 2025->2050 ---
set_conservation <- function(cfg, scen, bundle = FALSE) {
  cfg$gms$c22_protect_scenario          <- scen
  cfg$gms$c22_protect_scenario_noselect <- scen
  cfg$gms$s22_conservation_start  <- 2025
  cfg$gms$s22_conservation_target <- 2050
  cfg$gms$s22_restore_land        <- 1
  if (isTRUE(bundle)) {
    # RIKEN .prot_on (fst_levers_config.R): land + water protection as ONE bundle, every instrument on the 2025->2050 schedule.
    cfg$gms$s44_bii_target    <- 0.78   # BII floor (module 44); start year MUST be a timestep > sm_fix_SSP2, else the target never fires
    cfg$gms$s44_start_year    <- 2030
    cfg$gms$s44_target_year   <- 2050
    cfg$gms$c44_bii_decrease  <- 1
    cfg$gms$s29_snv_shr       <- 0.2    # semi-natural vegetation share of cropland (module 29)
    cfg$gms$s29_snv_shr_noselect <- 0.2
    cfg$gms$s29_snv_scenario_start  <- 2025
    cfg$gms$s29_snv_scenario_target <- 2050
    cfg$gms$c42_env_flow_policy   <- "on"  # environmental flows (module 42), scenario 2
    cfg$gms$s42_env_flow_scenario <- 2
    cfg$gms$s42_efp_startyear     <- 2025
    cfg$gms$s42_efp_targetyear    <- 2050
  }
  cfg
}
# --- Lever: EAT-Lancet diet, RIKEN .diet_el (s15_exo_diet=3: MAgPIE's own EAT-Lancet realization, exodietmacro.gms:441) ---
set_diet_eatlancet <- function(cfg) {
  cfg$gms$s15_exo_diet                 <- 3
  cfg$gms$c15_kcal_scen                <- "healthy_BMI"   # NOT 2500kcal: a non-BMI target routes back to the c15_EAT_scen dataset
  cfg$gms$s15_exo_foodscen_start       <- 2025
  cfg$gms$s15_exo_foodscen_target      <- 2050
  cfg$gms$s15_exo_foodscen_convergence <- 1
  cfg
}

# --- Edge module OFF / ON (Bodirsky B1b, d=0.50; f35_edge_scale active by clone default) ---
set_edge_off <- function(cfg) { cfg$gms$s35_edge_carbon <- 0; cfg }
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon  <- 1
  cfg$gms$s35_edge_formula <- 1      # exponential decay
  cfg$gms$s35_edge_lambda  <- 0.059  # ~59 m penetration depth (default)
  cfg$gms$s35_edge_degrad  <- 0.50
  cfg$gms$s35_edge_beta    <- 0.8286
  cfg$gms$s35_edge_n       <- 0.7984
  # Model version L3 (promoted 2026-08-29, decision D1; ladder audit/edge_version_ladder/LADDER_REPORT.md):
  # stated explicitly so the launch record does not depend on default.cfg.
  cfg$gms$s32_edge_haircut  <- 1     # forestry haircut split: ndc + natural-curve aff carry the edge factor, plant exempt
  cfg$gms$s35_edge_agb_only <- 1     # edge factor on aboveground carbon only (item A / M7)
  cfg$gms$s35_edge_gate     <- 1     # forest-weighted Koeppen-A tropical share per cluster (M6); f35_edge_scale filled
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
  cfg <- set_ssp_base(cfg, p$ssp, p$rcp)
  if (isTRUE(p$price_high)) cfg <- set_price_high(cfg, p$ssp, p$budget)
  if (isTRUE(p$bioe_high))  cfg <- set_bioenergy_high(cfg, p$ssp, p$budget)
  if (!is.null(p$conserv))  cfg <- set_conservation(cfg, p$conserv, bundle = isTRUE(p$bundle))
  if (isTRUE(p$diet))       cfg <- set_diet_eatlancet(cfg)
  cfg
}

# Per-SSP lever + RCP design. RCP is per-config (within an SSP, levers imply different global forcing).
# Tag is ONE alphanumeric token (run_pattern ^([A-Za-z0-9]+)_bodirsky_); it keys CONFIG$policy$tags in config.R.
policies <- list(
  # SSP1 Sustainability: RCP2.6, all-levers -> RCP1.9; mitigation PkBudg650 (1.5C).
  list(tag = "SSP1base",      ssp = "SSP1", rcp = "rcp2p6", pair_off = TRUE),
  list(tag = "SSP1mitig",     ssp = "SSP1", rcp = "rcp2p6", budget = "PkBudg650",  price_high = TRUE, bioe_high = TRUE),
  list(tag = "SSP1halfearth", ssp = "SSP1", rcp = "rcp2p6", conserv = "GSN_HalfEarth", bundle = TRUE),
  list(tag = "SSP1diet",      ssp = "SSP1", rcp = "rcp2p6", diet = TRUE),
  list(tag = "SSP1all",       ssp = "SSP1", rcp = "rcp1p9", budget = "PkBudg650",  price_high = TRUE, bioe_high = TRUE,
                                                            conserv = "GSN_HalfEarth", bundle = TRUE, diet = TRUE),
  # SSP2 Middle: current policies RCP4.5; mitigation PkBudg1000 (2C) at RCP2.6; conservation 30by30 (area only);
  # diet-change scenario on the middle-of-the-road world (RIKEN precedent; re-added 2026-09-09 on Mike's ask).
  list(tag = "SSP2base",      ssp = "SSP2", rcp = "rcp4p5", pair_off = TRUE),
  list(tag = "SSP2mitig",     ssp = "SSP2", rcp = "rcp2p6", budget = "PkBudg1000", price_high = TRUE, bioe_high = TRUE),
  list(tag = "SSP230by30",    ssp = "SSP2", rcp = "rcp4p5", conserv = "30by30"),
  list(tag = "SSP2diet",      ssp = "SSP2", rcp = "rcp4p5", diet = TRUE),
  list(tag = "SSP2all",       ssp = "SSP2", rcp = "rcp2p6", budget = "PkBudg1000", price_high = TRUE, bioe_high = TRUE,
                                                            conserv = "30by30"),
  # SSP3 Regional Rivalry: base only; high-forcing RCP7.0.
  list(tag = "SSP3base",      ssp = "SSP3", rcp = "rcp7p0", pair_off = TRUE)
)

# ---------------------------------------------------------------------------
folders <- c(); n <- 0L
launch <- function(cfg_i, title) {
  cfg_i$title <- title; n <<- n + 1L
  if (DRYRUN) {
    lam <- if (is.null(cfg_i$gms$s35_edge_lambda)) NA_real_ else cfg_i$gms$s35_edge_lambda
    cat(sprintf("[dry] %-26s cellular=%-56s c52=%-6s c37=%-7s c56=%-24s emis=%-17s mute=%s c22=%-14s bii=%.2f snv=%.1f efp=%-3s diet=%s edge=%s/%.3f haircut=%s agb=%s gate=%s\n",
                title, basename(cfg_i$input[["cellular"]]),
                cfg_i$gms$c52_land_carbon_sink_rcp, cfg_i$gms$c37_labor_rcp,
                cfg_i$gms$c56_pollutant_prices, cfg_i$gms$c56_emis_policy, cfg_i$gms$c56_mute_ghgprices_until, cfg_i$gms$c22_protect_scenario,
                cfg_i$gms$s44_bii_target, cfg_i$gms$s29_snv_shr, cfg_i$gms$c42_env_flow_policy,
                cfg_i$gms$s15_exo_diet, cfg_i$gms$s35_edge_carbon, lam,
                cfg_i$gms$s32_edge_haircut, cfg_i$gms$s35_edge_agb_only, cfg_i$gms$s35_edge_gate))
    return(invisible(NULL))
  }
  cat(sprintf("\n===== %s (%d) =====\n", title, n))
  folders <<- c(folders, start_run(cfg_i, codeCheck = FALSE))
}

# 11 edge-ON + 3 baseline edge-OFF = 14
for (p in policies) {
  for (edge in if (isTRUE(p$pair_off)) c("OFF", "ON") else "ON") {
    cfg_i <- build_policy(cfg, p)
    cfg_i <- if (edge == "ON") set_edge_on(cfg_i) else set_edge_off(cfg_i)
    launch(cfg_i, paste0(p$tag, "_bodirsky_", edge))
  }
}

# Broad-edge (~1 km) sensitivity on a spanning subset: 3 baselines + 2 mitigation (SSP1/2 only) = 5.
# No SSP3mitig (SSP3 is base-only).
broad_subset <- c("SSP1base", "SSP2base", "SSP3base", "SSP1mitig", "SSP2mitig")
for (p in policies) if (p$tag %in% broad_subset) {
  launch(set_edge_broad(build_policy(cfg, p)), paste0(p$tag, "Broad_bodirsky_ON"))
}

if (DRYRUN) { cat(sprintf("\n[dry] %d configs built, none submitted.\n", n)); quit(save = "no") }
cat(sprintf("\n========== ALL %d RUNS LAUNCHED ==========\n", length(folders)))
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nMonitor:\n  ls magpie/output/SSP*_bodirsky_*/report.rds\n")
