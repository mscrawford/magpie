# |  Scenario suite: emissions + fragmentation futures. DESIGN B (Mike, 2026-09-09): a decomposable 2^3 lever cube on SSP1.
# |
# |  Canonical set (17 runs):
# |    SSP1 cube        : mitigation (M) x protection (P) x diet (D), each on/off, at ONE climate input (RCP2.6) for every
# |                       cell, so factor effects and interactions decompose cleanly (RIKEN fst_levers algebra applies).
# |                       8 cells, edge ON; the all-off corner also edge OFF.          -> 9 runs
# |    SSP2 / SSP3 base : context lines at their narrative climate (RCP4.5 / RCP7.0), edge OFF + ON.  -> 4 runs
# |    broad edge       : ~1 km penetration sensitivity on the SSP1 corners (all-off, all-on) and the two context bases. -> 4 runs
# |
# |  Factor atoms (the RIKEN fst_levers canonical switches, fst_levers_config.R / fst_levers_v2_config.R; Mike 2026-09-09:
# |  'use the switches canonically'; RIKEN found the earlier diet + protection programming wrong):
# |    M on : c56_pollutant_prices + c60_2ndgen_biodem (and _noselect twins) = R34M410-SSP1-PkBudg650 (1.5C, price and
# |           bioenergy are the two images of ONE REMIND solution and stay paired).  M off: R34M410-SSP1-NPi2025.
# |    P on : c22 GSN_HalfEarth 2025->2050 + s22_restore_land 1 + BII floor 0.78 (start 2030 = first timestep > 2025,
# |           target 2050) + SNV 0.2 2025->2050 + environmental flows on (scenario 2, 2025->2050).
# |    P off: none of them, set EXPLICITLY (env flows OFF overrides the SSP1 scenario column, which sets them on).
# |    D on : s15_exo_diet 3 (MAgPIE's own EAT-Lancet realization, exodietmacro.gms:441), c15_kcal_scen healthy_BMI,
# |           fade 2025->2050, convergence 1; c15_EAT_scen deliberately NOT set (inert under mode 3; a non-BMI kcal
# |           target would route back to that dataset).  D off: s15_exo_diet 0.
# |    Backdrop, constant in all 8 cells (RIKEN FST_BACKDROP): c56_emis_policy all_nosoil, c56_mute_ghgprices_until y2025;
# |           MACC switches price-driven (-1, the fork default). The SSP2/SSP3 context bases keep the stock frame
# |           (reddnatveg_nosoil, y2030), as RIKEN's BAU does.
# |    Not ported: tau pinning / TC factor, the Japan bioenergy carve-out, the BioNone arm (RIKEN-specific).
# |
# |  Cell tags are one alphanumeric token (run_pattern ^([A-Za-z0-9]+)_bodirsky_): SSP1M{0,1}P{0,1}D{0,1}; legacy names
# |  map onto corners (SSP1base = SSP1M0P0D0, SSP1mitig = M1P0D0, SSP1halfearth = M0P1D0, SSP1diet = M0P0D1, SSP1all = M1P1D1).
# |
# |  Climate per world: gms::setScenario(cfg, c(ssp,"NPI",rcp)) sets the LPJmL cellular input AND c52_land_carbon_sink_rcp;
# |  c37_labor_rcp is bracketed manually (module 37 offers rcp119 / rcp585). Per-RCP cellular inputs live in the local
# |  madrat pool registered below. One calibration is valid across RCPs of the same GCM + rev (sm_fix_cc = 2025).
# |  Edge model version L3 (2026-08-29): haircut split + AGB-only factor + forest-weighted gate, stated explicitly.
# |
# |  Usage: cd magpie && Rscript scripts/start/projects/scenario_suite_emissions_fragmentation.R
# |         SUITE_DRYRUN=1 Rscript ...                 prints each run's wired switches and exits
# |         SUITE_DRYRUN=1 SUITE_DUMP=<dir> Rscript ... additionally writes each run's resolved cfg$gms (+ input) as JSON

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output          <- c("output_check", "rds_report")
cfg$force_download  <- FALSE
cfg$recalc_npi_ndc  <- FALSE
cfg$sequential      <- FALSE  # parallel GAMS solves

# Per-RCP LPJmL cellular inputs (ssp126 for rcp2p6, ssp245 for rcp4p5, ssp370 for rcp7p0) are in the local madrat
# pool, not on the public download server. Register it so setScenario's rcp token can resolve them.
cfg$repositories <- append(cfg$repositories,
                           list("file:///p/projects/rd3mod/inputdata/output_1.27" = NULL))

DRYRUN <- identical(Sys.getenv("SUITE_DRYRUN"), "1")
DUMP   <- Sys.getenv("SUITE_DUMP", "")

# ---------------------------------------------------------------------------
# Labor-productivity RCP bracket: module 37 offers only rcp119 / rcp585 -> nearest to the run's forcing.
labor_rcp <- function(rcp) if (rcp %in% c("rcp6p0", "rcp7p0", "rcp8p5")) "rcp585" else "rcp119"

# World: socioeconomics + NPi policy + the world's climate input (each field set EXPLICITLY, every factor OFF).
set_world <- function(cfg, ssp, rcp) {
  cfg <- gms::setScenario(cfg, c(ssp, "NPI", rcp))
  cfg$gms$c37_labor_rcp <- labor_rcp(rcp)
  cfg <- set_mitigation(cfg, ssp, on = FALSE)
  cfg <- set_protection(cfg, on = FALSE)
  cfg <- set_diet(cfg, on = FALSE)
  cfg
}

# --- Backdrop of the cube (RIKEN FST_BACKDROP): constant in every cell, so no factor carries it ---
set_cube_backdrop <- function(cfg) {
  cfg$gms$c56_emis_policy          <- "all_nosoil"
  cfg$gms$c56_mute_ghgprices_until <- "y2025"
  cfg
}

# --- Factor M: mitigation = 1.5C carbon price AND the co-moving 2nd-gen bioenergy demand of the same REMIND run ---
set_mitigation <- function(cfg, ssp, on) {
  scen <- paste0("R34M410-", ssp, "-", if (on) "PkBudg650" else "NPi2025")
  cfg$gms$c56_pollutant_prices          <- scen
  cfg$gms$c56_pollutant_prices_noselect <- scen
  cfg$gms$c60_2ndgen_biodem             <- scen
  cfg$gms$c60_2ndgen_biodem_noselect    <- scen
  cfg
}

# --- Factor P: land + water protection as ONE bundle (RIKEN .prot_on / .prot_off), every instrument on the 2025->2050 schedule ---
set_protection <- function(cfg, on) {
  scen <- if (on) "GSN_HalfEarth" else "none"
  cfg$gms$c22_protect_scenario          <- scen
  cfg$gms$c22_protect_scenario_noselect <- scen
  cfg$gms$s22_conservation_start  <- 2025
  cfg$gms$s22_conservation_target <- 2050
  cfg$gms$s22_restore_land        <- 1                       # in both levels, as RIKEN
  cfg$gms$s44_bii_target    <- if (on) 0.78 else 0          # BII floor (module 44)
  cfg$gms$s44_start_year    <- 2030                          # MUST be a timestep > sm_fix_SSP2 (2025), else the target never fires
  cfg$gms$s44_target_year   <- 2050
  cfg$gms$c44_bii_decrease  <- 1
  cfg$gms$s29_snv_shr          <- if (on) 0.2 else 0        # semi-natural vegetation share of cropland (module 29)
  cfg$gms$s29_snv_shr_noselect <- if (on) 0.2 else 0
  cfg$gms$s29_snv_scenario_start  <- 2025
  cfg$gms$s29_snv_scenario_target <- 2050
  cfg$gms$c42_env_flow_policy   <- if (on) "on" else "off"  # environmental flows (module 42); off overrides the SSP1 column
  cfg$gms$s42_env_flow_scenario <- 2
  cfg$gms$s42_efp_startyear     <- 2025
  cfg$gms$s42_efp_targetyear    <- 2050
  cfg
}

# --- Factor D: EAT-Lancet diet, RIKEN .diet_el ---
set_diet <- function(cfg, on) {
  if (on) {
    cfg$gms$s15_exo_diet                 <- 3
    cfg$gms$c15_kcal_scen                <- "healthy_BMI"   # NOT 2500kcal
    cfg$gms$s15_exo_foodscen_start       <- 2025
    cfg$gms$s15_exo_foodscen_target      <- 2050
    cfg$gms$s15_exo_foodscen_convergence <- 1
  } else {
    cfg$gms$s15_exo_diet <- 0
  }
  cfg
}

# --- Edge module OFF / ON (model version L3) and the broad ~1 km sensitivity ---
set_edge_off <- function(cfg) { cfg$gms$s35_edge_carbon <- 0; cfg }
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon  <- 1
  cfg$gms$s35_edge_formula <- 1      # exponential decay
  cfg$gms$s35_edge_lambda  <- 0.059  # ~59 m penetration depth (default)
  cfg$gms$s35_edge_degrad  <- 0.50
  cfg$gms$s35_edge_beta    <- 0.8286
  cfg$gms$s35_edge_n       <- 0.7984
  cfg$gms$s32_edge_haircut  <- 1     # forestry haircut split: ndc + natural-curve aff carry the edge factor, plant exempt
  cfg$gms$s35_edge_agb_only <- 1     # edge factor on aboveground carbon only
  cfg$gms$s35_edge_gate     <- 1     # forest-weighted Koeppen-A tropical share per cluster; f35_edge_scale filled
  cfg
}
set_edge_broad <- function(cfg) { cfg <- set_edge_on(cfg); cfg$gms$s35_edge_lambda <- 1.0; cfg }

# ---------------------------------------------------------------------------
# The design: 8 cube cells on SSP1 (fixed RCP2.6, cube backdrop) + 2 context bases (stock frame).
cube <- list()
for (M in 0:1) for (P in 0:1) for (D in 0:1) {
  cube[[length(cube) + 1]] <- list(tag = sprintf("SSP1M%dP%dD%d", M, P, D), ssp = "SSP1", rcp = "rcp2p6",
                                   M = M == 1, P = P == 1, D = D == 1, cube = TRUE)
}
context <- list(list(tag = "SSP2base", ssp = "SSP2", rcp = "rcp4p5", cube = FALSE),
                list(tag = "SSP3base", ssp = "SSP3", rcp = "rcp7p0", cube = FALSE))
policies <- c(cube, context)

build_policy <- function(cfg, p) {
  cfg <- set_world(cfg, p$ssp, p$rcp)
  if (isTRUE(p$cube)) {
    cfg <- set_cube_backdrop(cfg)
    cfg <- set_mitigation(cfg, p$ssp, on = isTRUE(p$M))
    cfg <- set_protection(cfg, on = isTRUE(p$P))
    cfg <- set_diet(cfg, on = isTRUE(p$D))
  }
  cfg
}

edge_off_tags <- c("SSP1M0P0D0", "SSP2base", "SSP3base")               # edge OFF pairs
broad_tags    <- c("SSP1M0P0D0", "SSP1M1P1D1", "SSP2base", "SSP3base")  # ~1 km sensitivity

# ---------------------------------------------------------------------------
folders <- c(); n <- 0L
launch <- function(cfg_i, title) {
  cfg_i$title <- title; n <<- n + 1L
  if (DRYRUN) {
    lam <- if (is.null(cfg_i$gms$s35_edge_lambda)) NA_real_ else cfg_i$gms$s35_edge_lambda
    cat(sprintf("[dry] %-24s cellular=%-56s c52=%-6s c37=%-7s c56=%-24s c60=%-24s emis=%-17s mute=%s c22=%-14s bii=%.2f snv=%.1f efp=%-3s diet=%s edge=%s/%.3f\n",
                title, basename(cfg_i$input[["cellular"]]),
                cfg_i$gms$c52_land_carbon_sink_rcp, cfg_i$gms$c37_labor_rcp,
                cfg_i$gms$c56_pollutant_prices, cfg_i$gms$c60_2ndgen_biodem,
                cfg_i$gms$c56_emis_policy, cfg_i$gms$c56_mute_ghgprices_until, cfg_i$gms$c22_protect_scenario,
                cfg_i$gms$s44_bii_target, cfg_i$gms$s29_snv_shr, cfg_i$gms$c42_env_flow_policy,
                cfg_i$gms$s15_exo_diet, cfg_i$gms$s35_edge_carbon, lam))
    if (nzchar(DUMP)) {
      dir.create(DUMP, showWarnings = FALSE, recursive = TRUE)
      jsonlite::write_json(list(title = title, input = as.list(cfg_i$input), gms = cfg_i$gms),
                           file.path(DUMP, paste0(title, ".json")), auto_unbox = TRUE, pretty = TRUE, digits = NA)
    }
    return(invisible(NULL))
  }
  cat(sprintf("\n===== %s (%d) =====\n", title, n))
  folders <<- c(folders, start_run(cfg_i, codeCheck = FALSE))
}

# 10 edge-ON + 3 edge-OFF = 13
for (p in policies) {
  for (edge in if (p$tag %in% edge_off_tags) c("OFF", "ON") else "ON") {
    cfg_i <- build_policy(cfg, p)
    cfg_i <- if (edge == "ON") set_edge_on(cfg_i) else set_edge_off(cfg_i)
    launch(cfg_i, paste0(p$tag, "_bodirsky_", edge))
  }
}
# broad-edge sensitivity = 4
for (p in policies) if (p$tag %in% broad_tags) {
  launch(set_edge_broad(build_policy(cfg, p)), paste0(p$tag, "Broad_bodirsky_ON"))
}

if (DRYRUN) { cat(sprintf("\n[dry] %d configs built, none submitted.\n", n)); quit(save = "no") }
cat(sprintf("\n========== ALL %d RUNS LAUNCHED ==========\n", length(folders)))
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nMonitor:\n  ls magpie/output/SSP*_bodirsky_*/report.rds\n")
