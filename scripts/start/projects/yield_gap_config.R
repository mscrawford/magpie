# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# Scenario definitions for the yield-gap experiment.
# See scripts/start/projects/yield_gap.R for the orchestrator.
#
# Three transformation packages:
#   BAU         : default ~no carbon price, no land conservation, no diet
#   TransNoDiet : full FST backdrop minus the diet transition
#                 (carbon + 30by30 + biodiv + N MACCs + water EFP)
#   TransDiet   : full FST backdrop including the diet transition
#                 (TransNoDiet + EAT-Lancet FLX)
#
# Each transition package is run twice: once with endogenous TC ("TCendo"),
# once with tau pinned to BAU's trajectory ("TCbau"). BAU itself runs
# only with endogenous TC; its endo tau IS the TCbau reference for the
# transition runs.
#
# Climate-policy choice: PkBudg650 (~$300/tC in 2050, 1.5C pathway).

# Shared carbon-price block (1.5C / PkBudg650)
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
.biodiv_block <- list(
  s44_bii_target                = 0.78,
  c44_bii_decrease              = 1
)

# Nitrogen abatement block (Module 57 MACCs at max step, on_aug22 realization)
.nitrogen_block <- list(
  s57_maxmac_n_soil             = 201,
  s57_maxmac_n_awms             = 201
)

# Water protection block (Module 42 environmental flow policy ON)
.water_block <- list(
  c42_env_flow_policy           = "on",
  s42_env_flow_scenario         = 2,
  s42_efp_startyear             = 2025,
  s42_efp_targetyear            = 2050
)

YIELD_GAP_SCENARIOS <- list(

  BAU = list(
    # Default ~no carbon price; default conservation; endogenous diet
    c56_pollutant_prices          = "R34M410-SSP2-NPi2025",
    c56_pollutant_prices_noselect = "R34M410-SSP2-NPi2025",
    c56_emis_policy               = "reddnatveg_nosoil",
    c56_mute_ghgprices_until      = "y2030",
    s15_exo_diet                  = 0
  ),

  # Full FST backdrop minus diet: carbon + 30by30 + biodiv + N MACCs + water EFP
  TransNoDiet = c(.energy_block, .landcons_block,
                  .biodiv_block, .nitrogen_block, .water_block),

  # Full FST backdrop including diet
  TransDiet   = c(.energy_block, .landcons_block, .diet_block,
                  .biodiv_block, .nitrogen_block, .water_block)
)

# Scenarios that get a TCbau companion (tau pinned at BAU level). BAU itself
# is only run endogenously; its own tau is the pin target.
YIELD_GAP_TCBAU_SCENARIOS <- c("TransNoDiet", "TransDiet")

# Apply a scenario's switches to a cfg object
applyTCScenario <- function(cfg, scenario_name) {
  s <- YIELD_GAP_SCENARIOS[[scenario_name]]
  if (is.null(s)) stop("Unknown scenario: ", scenario_name,
                       ". Available: ", paste(names(YIELD_GAP_SCENARIOS), collapse = ", "))
  for (k in names(s)) cfg$gms[[k]] <- s[[k]]
  cfg
}

# Apply exo-TC flags (for TCbau runs that fix tau to BAU's trajectory)
applyExoTCFlags <- function(cfg) {
  cfg$gms$tc                          <- "exo"
  cfg$gms$c13_croparea_consv          <- 0
  cfg$gms$s13_ignore_tau_historical   <- 1
  cfg
}

# Run-name convention: <scenario>_<TCstate>, TCstate in {TCendo, TCbau}
tcRunName <- function(scenario_name, tc_state = "TCendo") {
  if (!tc_state %in% c("TCendo", "TCbau")) {
    stop("tc_state must be 'TCendo' or 'TCbau', got: ", tc_state)
  }
  sprintf("%s_%s", scenario_name, tc_state)
}
