# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# Scenario definitions for the fst_levers experiment (2^4 design).
# See scripts/start/projects/fst_levers.R for the orchestrator.
#
# Question: under a Food System Transformation (FST) backdrop, how do area-based
# forest protection, 2nd-generation bioenergy demand, and a dietary shift reshape
# land use, and how much does endogenous technological change (TC) contribute
# under each policy combination?
#
# Design: a 2x2x2 of (forest protection) x (bioenergy demand) x (diet) under a
# shared FST backdrop, each cell run with endogenous TC ("TCendo") and with tau
# pinned to BAU ("TCbau"), plus BAU itself (TCendo only; its endo tau is the pin
# target). Inventory: 8 cells x 2 TC states = 16 + BAU = 17 runs.
#
#   Factor A  forest protection : 30by30 area-based conservation ON vs OFF
#                                 (Module 22; avoided deforestation c35 stays
#                                  on in BOTH arms, inherited from NPI).
#   Factor B  bioenergy demand  : 1.5C-consistent 2nd-gen demand ON vs OFF
#                                 (Module 60; OFF = zero demand + residues off).
#   Factor C  diet              : EAT-Lancet FLX 2500 kcal ON vs endogenous OFF
#                                 (Module 15; OFF = s15_exo_diet = 0, the model's
#                                  own diet projection, matching yield_gap's
#                                  TransNoDiet).
#   Factor D  TC state          : TCendo vs TCbau (tau pinned to BAU).
#
# FST backdrop (constant across all 8 cells) = the yield_gap FST atoms MINUS the
# three now-toggled factors (protection, bioenergy, diet): PkBudg650 carbon price
# + biodiversity (BII 0.78) + N MACCs (max) + water EFP.
#
# Climate-policy choice: PkBudg650 (~$300/tC in 2050, 1.5C pathway), with the
# matching R34M410-SSP2-PkBudg650 bioenergy demand in the "with bioenergy" arm.
#
# Diet was promoted from a fixed backdrop atom (the original 2^3 design) to a
# toggled factor (2026-06-20) so the experiment resolves diet's marginal effect
# and its interactions with protection / bioenergy on the current model, rather
# than relying on the frozen yield_gap diet x TC result.

# ---- shared FST backdrop blocks (constant across all 8 cells) ---------------

# Carbon-price block (1.5C / PkBudg650)
.energy_block <- list(
  c56_pollutant_prices          = "R34M410-SSP2-PkBudg650",
  c56_pollutant_prices_noselect = "R34M410-SSP2-PkBudg650",
  c56_emis_policy               = "all_nosoil",
  c56_mute_ghgprices_until      = "y2025"
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

FST_BACKDROP <- c(.energy_block, .biodiv_block, .nitrogen_block, .water_block)

# ---- Factor A: area-based forest protection (Module 22) ---------------------

# ON: 30by30 future conservation (+ WDPA baseline), 2025->2050 transition
.protect_on <- list(
  c22_protect_scenario          = "30by30",
  c22_protect_scenario_noselect = "30by30",
  s22_conservation_start        = 2025,
  s22_conservation_target       = 2050,
  s22_restore_land              = 1
)
# OFF: no additional future protection (WDPA baseline + NPI avoided-deforestation
# remain; only the 30by30 area lever is removed). Re-affirmed explicitly so the
# OFF arm is symmetric and legible.
.protect_off <- list(
  c22_protect_scenario          = "none",
  c22_protect_scenario_noselect = "none"
)

# ---- Factor B: 2nd-generation bioenergy demand (Module 60) ------------------

# ON: 1.5C-consistent demand from the same R34M410-SSP2-PkBudg650 energy run.
# c60_2ndgen_biodem_noselect is load-bearing (blended with the select value in
# preloop), so it must be set too.
.bioenergy_on <- list(
  c60_2ndgen_biodem             = "R34M410-SSP2-PkBudg650",
  c60_2ndgen_biodem_noselect    = "R34M410-SSP2-PkBudg650"
)
# OFF: zero 2nd-gen demand. Needs all three: biodem="none" (sets demand to 0),
# residues off (else the SSP2 residue-BE baseline persists), and dem_min=0 (else
# the presolve floor reintroduces a small demand per region).
.bioenergy_off <- list(
  c60_2ndgen_biodem             = "none",
  c60_2ndgen_biodem_noselect    = "none",
  c60_res_2ndgenBE_dem          = "off",
  s60_2ndgen_bioenergy_dem_min  = 0
)

# ---- Factor C: dietary shift (Module 15) -----------------------------------

# ON: EAT-Lancet FLX, 2500 kcal, 2025->2050 linear convergence.
.diet_on <- list(
  s15_exo_diet                  = 1,
  c15_EAT_scen                  = "FLX",
  c15_kcal_scen                 = "2500kcal",
  s15_exo_foodscen_start        = 2025,
  s15_exo_foodscen_target       = 2050,
  s15_exo_foodscen_convergence  = 1
)
# OFF: no exogenous diet shift; the model's endogenous diet projection runs
# (s15_exo_diet = 0). Same "no diet transition" arm as yield_gap's TransNoDiet.
.diet_off <- list(
  s15_exo_diet                  = 0
)

# ---- composed scenario list: BAU + 2x2x2 cells (TC state set by orchestrator)

FST_LEVERS_SCENARIOS <- list(

  # Identical to the yield_gap BAU: ~no carbon price, no future conservation,
  # endogenous diet, baseline (NPi) bioenergy. Single tau-pin source; outside
  # the 2^4 cube (different backdrop), used only as a context line in analysis.
  BAU = list(
    c56_pollutant_prices          = "R34M410-SSP2-NPi2025",
    c56_pollutant_prices_noselect = "R34M410-SSP2-NPi2025",
    c56_emis_policy               = "reddnatveg_nosoil",
    c56_mute_ghgprices_until      = "y2030",
    s15_exo_diet                  = 0
  ),

  # 8 cube cells = {Protect,NoProtect} x {BioOn,BioOff} x {DietOn,DietOff}.
  # Reference corner (all OFF) = NoProtect_BioOff_DietOff.
  Protect_BioOn_DietOn     = c(FST_BACKDROP, .protect_on,  .bioenergy_on,  .diet_on),
  Protect_BioOn_DietOff    = c(FST_BACKDROP, .protect_on,  .bioenergy_on,  .diet_off),
  Protect_BioOff_DietOn    = c(FST_BACKDROP, .protect_on,  .bioenergy_off, .diet_on),
  Protect_BioOff_DietOff   = c(FST_BACKDROP, .protect_on,  .bioenergy_off, .diet_off),
  NoProtect_BioOn_DietOn   = c(FST_BACKDROP, .protect_off, .bioenergy_on,  .diet_on),
  NoProtect_BioOn_DietOff  = c(FST_BACKDROP, .protect_off, .bioenergy_on,  .diet_off),
  NoProtect_BioOff_DietOn  = c(FST_BACKDROP, .protect_off, .bioenergy_off, .diet_on),
  NoProtect_BioOff_DietOff = c(FST_BACKDROP, .protect_off, .bioenergy_off, .diet_off)
)

# The 8 FST cells each get a TCbau companion (tau pinned at BAU level). BAU
# itself is only run endogenously; its own tau is the single pin target.
FST_LEVERS_TCBAU_SCENARIOS <- c(
  "Protect_BioOn_DietOn",   "Protect_BioOn_DietOff",
  "Protect_BioOff_DietOn",  "Protect_BioOff_DietOff",
  "NoProtect_BioOn_DietOn",  "NoProtect_BioOn_DietOff",
  "NoProtect_BioOff_DietOn", "NoProtect_BioOff_DietOff")

# Note: c35_ad_policy (avoided deforestation) is deliberately NOT set here. It
# is inherited as "npi" from setScenario(cfg, c("SSP2","NPI")) in BOTH protection
# arms - the area-based-only design keeps the deforestation policy constant.

# ---- helpers (identical in behaviour to yield_gap) --------------------------

# Apply a scenario's switches to a cfg object
applyTCScenario <- function(cfg, scenario_name) {
  s <- FST_LEVERS_SCENARIOS[[scenario_name]]
  if (is.null(s)) stop("Unknown scenario: ", scenario_name,
                       ". Available: ", paste(names(FST_LEVERS_SCENARIOS), collapse = ", "))
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
