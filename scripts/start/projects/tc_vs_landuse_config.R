# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# Scenario definitions for the "TC vs land-use change" experiment.
# See scripts/start/projects/tc_vs_landuse.R for the orchestrator.
#
# Sequential additive design (each row adds one layer on top of the previous):
#   BAU         : no carbon price, no land conservation, no diet
#   Energy      : 1.5C carbon price (PkBudg650) with comprehensive AFOLU coverage
#   EnergyCons  : Energy + land conservation (30by30, future + WDPA baseline)
#   Full        : Energy + land conservation + EAT-Lancet Flexitarian diet
#
# Climate-policy choice: PkBudg650 (~$300/tC in 2050, 1.5C pathway). The prior
# round used PkBudg1000 (2C) but all sweep runs were feasible at any f, which
# suggested the 2C signal didn't bind hard enough to differentiate scenarios.

# Shared carbon-price block for all non-BAU scenarios (1.5C / PkBudg650)
.energy_block <- list(
  c56_pollutant_prices          = "R34M410-SSP2-PkBudg650",
  c56_pollutant_prices_noselect = "R34M410-SSP2-PkBudg650",
  c56_emis_policy               = "all_nosoil",
  c56_mute_ghgprices_until      = "y2025"
)

# Shared land-conservation block (30by30 future + WDPA baseline, 2025->2050)
.landcons_block <- list(
  c22_protect_scenario          = "30by30",
  c22_protect_scenario_noselect = "30by30",
  s22_conservation_start        = 2025,
  s22_conservation_target       = 2050,
  s22_restore_land              = 1
)

# Shared diet-transition block (EAT-Lancet FLX, 2500 kcal, 2025->2050 linear)
.diet_block <- list(
  s15_exo_diet                  = 1,
  c15_EAT_scen                  = "FLX",
  c15_kcal_scen                 = "2500kcal",
  s15_exo_foodscen_start        = 2025,
  s15_exo_foodscen_target       = 2050,
  s15_exo_foodscen_convergence  = 1
)

# Biodiversity target block (Module 44 bii_target realization)
# s44_bii_target = 0.78 per default.cfg notes: "(very) strong increase of BII"
# Linear ramp from s44_start_year (2030) to s44_target_year (2100, defaults)
.biodiv_block <- list(
  s44_bii_target                = 0.78,
  c44_bii_decrease              = 1
)

# Nitrogen abatement block (Module 57 MACCs, on_aug22 realization)
# s57_maxmac_n_soil = 201 / s57_maxmac_n_awms = 201 force the MACC mitigation
# step to its maximum (per default.cfg: "201: maximum level of mitigation").
# This adds N-specific MACC abatement on top of the base NUE trajectory --
# we do NOT change c50_scen_neff (base trajectory stays at SSP2 default).
.nitrogen_block <- list(
  s57_maxmac_n_soil             = 201,
  s57_maxmac_n_awms             = 201
)

# Water protection block (Module 42, environmental flow policy ON)
# c42_env_flow_policy = "on" applies global EFP. s42_env_flow_scenario = 2
# uses the Smakhtin (2004) gridcell-specific algorithm (default), so the
# s42_env_flow_fraction has no effect under this scenario. Start/target
# years aligned with the other FST transitions (2025-2050).
.water_block <- list(
  c42_env_flow_policy           = "on",
  s42_env_flow_scenario         = 2,
  s42_efp_startyear             = 2025,
  s42_efp_targetyear            = 2050
)

TC_VS_LANDUSE_SCENARIOS <- list(

  BAU = list(
    # Default ~no carbon price; default conservation; endogenous diet
    c56_pollutant_prices          = "R34M410-SSP2-NPi2025",
    c56_pollutant_prices_noselect = "R34M410-SSP2-NPi2025",
    c56_emis_policy               = "reddnatveg_nosoil",
    c56_mute_ghgprices_until      = "y2030",
    s15_exo_diet                  = 0
  ),

  Energy         = .energy_block,
  EnergyCons     = c(.energy_block, .landcons_block),
  Full           = c(.energy_block, .landcons_block, .diet_block),
  FullPlus       = c(.energy_block, .landcons_block, .diet_block,
                     .biodiv_block, .nitrogen_block, .water_block),

  # "EnergyFST minus diet" = FullPlus minus the diet transition. Gives the
  # missing 2x2 cell ("Diet OFF" with all other FST layers ON) needed to
  # cleanly decompose TC vs Diet within the full-FST frame.
  EnergyConsBioN = c(.energy_block, .landcons_block,
                     .biodiv_block, .nitrogen_block, .water_block)
)

# TC blending fractions for the sweep (f = 1 is covered by the endogenous reference)
TC_VS_LANDUSE_FRACTIONS <- c(0, 1/2, 3/4)

# Scenarios that get a TC sweep (BAU is only the tau-source baseline)
TC_VS_LANDUSE_SWEEP_SCENARIOS <- c("Energy", "EnergyCons", "Full", "FullPlus", "EnergyConsBioN")

# Apply a scenario's switches to a cfg object
applyTCScenario <- function(cfg, scenario_name) {
  s <- TC_VS_LANDUSE_SCENARIOS[[scenario_name]]
  if (is.null(s)) stop("Unknown scenario: ", scenario_name,
                       ". Available: ", paste(names(TC_VS_LANDUSE_SCENARIOS), collapse = ", "))
  for (k in names(s)) cfg$gms[[k]] <- s[[k]]
  cfg
}

# Apply exo-TC flags (for sweep runs that fix tau exogenously)
applyExoTCFlags <- function(cfg) {
  cfg$gms$tc                          <- "exo"
  cfg$gms$c13_croparea_consv          <- 0
  cfg$gms$s13_ignore_tau_historical   <- 1
  cfg
}

# Standard run-name convention
tcRunName <- function(scenario_name, f = NA) {
  if (is.na(f)) {
    sprintf("TC_%s_endo", scenario_name)
  } else {
    sprintf("TC_%s_f%02d", scenario_name, round(f * 100))
  }
}
