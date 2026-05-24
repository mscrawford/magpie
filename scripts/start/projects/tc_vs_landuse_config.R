# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# Scenario definitions for the "TC vs land-use change" experiment.
# See scripts/start/projects/tc_vs_landuse.R for the orchestrator.
#
# Three scenarios:
#   BAU    : no carbon price, no diet transition
#   Energy : moderate 2C carbon price with comprehensive AFOLU coverage, no diet
#   Full   : Energy + EAT-Lancet Flexitarian (2500 kcal) diet transition

TC_VS_LANDUSE_SCENARIOS <- list(

  BAU = list(
    # Carbon price: default ~no price
    c56_pollutant_prices          = "R34M410-SSP2-NPi2025",
    c56_pollutant_prices_noselect = "R34M410-SSP2-NPi2025",
    c56_emis_policy               = "reddnatveg_nosoil",
    c56_mute_ghgprices_until      = "y2030",
    # Diet: endogenous
    s15_exo_diet                  = 0
  ),

  Energy = list(
    # Carbon price: 2C pathway, comprehensive AFOLU coverage (CO2 LULUCF + CH4 + N2O)
    c56_pollutant_prices          = "R34M410-SSP2-PkBudg1000",
    c56_pollutant_prices_noselect = "R34M410-SSP2-PkBudg1000",
    c56_emis_policy               = "all_nosoil",
    c56_mute_ghgprices_until      = "y2025",
    # Diet: endogenous
    s15_exo_diet                  = 0
  ),

  Full = list(
    # Carbon price: same as Energy
    c56_pollutant_prices          = "R34M410-SSP2-PkBudg1000",
    c56_pollutant_prices_noselect = "R34M410-SSP2-PkBudg1000",
    c56_emis_policy               = "all_nosoil",
    c56_mute_ghgprices_until      = "y2025",
    # Diet: EAT-Lancet Flexitarian, 2500 kcal/cap/day, linear transition 2025-2050
    s15_exo_diet                  = 1,
    c15_EAT_scen                  = "FLX",
    c15_kcal_scen                 = "2500kcal",
    s15_exo_foodscen_start        = 2025,
    s15_exo_foodscen_target       = 2050,
    s15_exo_foodscen_convergence  = 1
  )
)

# TC blending fractions for the sweep (f = 1 is covered by the endogenous reference)
TC_VS_LANDUSE_FRACTIONS <- c(0, 1/2, 3/4)

# Scenarios that get a TC sweep (BAU is only the tau-source baseline)
TC_VS_LANDUSE_SWEEP_SCENARIOS <- c("Energy", "Full")

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
