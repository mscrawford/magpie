# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# Scenario definitions for the fst_levers experiment.
# See scripts/start/projects/fst_levers.R for the orchestrator and
# scripts/start/projects/fst_levers_README.md for the methods writeup.
#
# Question: under a Food System Transformation (FST) backdrop, how does
# AMBITIOUS LAND PROTECTION compete with 2nd-generation BIOENERGY demand for
# land, does CLIMATE POLICY change that competition, and how much does
# endogenous technological change (TC) contribute in each case?
#
# Design: 4 binary factors.
#
#   A. climate policy   : 1.5C carbon price vs current-policies price (Module 56)
#   B. bioenergy demand : 1.5C-consistent vs baseline 2nd-gen demand  (Module 60)
#   C. land protection  : Half-Earth + BII target vs neither    (Modules 22 + 44)
#   D. TC state         : TCendo vs TCbau (tau pinned to BAU)         (Module 13)
#
# The (CP off, Bio on) combination is deliberately EXCLUDED: 2nd-gen bioenergy
# demand at 1.5C levels without a carbon price is not a coherent scenario, since
# both come from the same coupled REMIND run. That leaves 3 of the 4 (CP, Bio)
# combinations x 2 protection arms = 6 cells, each run at TCendo and TCbau, plus
# BAU (TCendo only, the tau-pin source) = 13 runs.
#
# IDENTIFICATION CONSEQUENCE of that exclusion: this is NOT a 2^4 factorial. It
# is two 2^3 cubes sharing a face:
#   Cube A (CP = on) : Bio x Prot x TC
#   Cube B (Bio = off): CP  x Prot x TC
# Every effect involving CP and Bio JOINTLY (CP:Bio, CP:Bio:Prot, CP:Bio:TC and
# the four-way) is unidentifiable by construction. The bioenergy main effect is
# therefore conditional on CP being on, and must never be reported as a marginal
# effect over the whole design.
#
# "Equal ambition" decisions (see README section on methodology):
#   * Every lever transitions on the SAME 2025->2050 schedule. This required
#     moving the BII target off its defaults (s44_start_year 2030, s44_target_year
#     2100), which would otherwise have made biodiversity ambition ramp 50 years
#     later than every other lever.
#   * c56_emis_policy and c56_mute_ghgprices_until are held CONSTANT across all
#     12 FST cells, so Factor A toggles exactly one thing: the price scenario.
#   * Factor B's two arms are the SAME REMIND run family at two policy levels
#     (PkBudg650 vs NPi2025), not "bioenergy vs zero bioenergy".
#   * Non-CO2 MACCs are PRICE-DRIVEN, not forced to the maximum step, so N and
#     CH4 abatement scale with each cell's own REMIND carbon price instead of
#     being pinned at an ambition the CP-off cells never paid for. See .macc_block.

# ---- constant FST backdrop (identical in all 12 FST cells) ------------------

# Diet-transition block (EAT-Lancet FLX, 2500 kcal, 2025->2050 linear)
.diet_block <- list(
  s15_exo_diet                  = 1,
  c15_EAT_scen                  = "FLX",
  c15_kcal_scen                 = "2500kcal",
  s15_exo_foodscen_start        = 2025,
  s15_exo_foodscen_target       = 2050,
  s15_exo_foodscen_convergence  = 1
)

# Non-CO2 abatement block (Module 57 MACCs, on_aug22 realization).
#
# ALL FIVE MACC switches are price-driven (-1). They are NOT forced to a fixed
# step. This is a deliberate correction to the yield_gap / earlier fst_levers
# setting of s57_maxmac_n_* = 201 (maximum), which was internally contradictory:
#
#   * Forcing a step severs N abatement from the pollutant price, so the run
#     would honour a REMIND carbon-price scenario for CO2 while ignoring it for
#     N2O. Do not fix a step while imposing a price scenario you mean to honour.
#   * Step 201 is the maximum of the curve, ~1222 USD17MER/tCO2eq. The PkBudg650
#     price is ~620-640 USD17MER/tCO2eq at 2050, i.e. step ~103-106. Forcing 201
#     applied roughly twice the abatement effort the 1.5C price justifies.
#   * It also split N from CH4: the CH4 MACCs were left price-driven, so the
#     CP-off arm had maximal N abatement alongside near-zero CH4 abatement.
#   * Intermediate steps are arbitrary parameterizations, not meaningful units,
#     so hand-picking a "1.5C-equivalent" step (e.g. 106) would substitute one
#     arbitrary anchor for another.
#
# With -1 the model derives the step from the actual REMIND price per region and
# per timestep (57_maccs/on_aug22/preloop.gms:24-25, min(201, ceil(price/.../
# s57_step_length)+1); PBL_2022 -> s57_step_length = 22.4 USD17MER/tCeq/step).
# Non-CO2 ambition therefore tracks Factor A automatically: 1.5C-consistent in
# the CP-on cells, current-policies-consistent in the CP-off cells and in BAU.
#
# DESIGN CONSEQUENCE, must be carried into the analysis: nitrogen is no longer an
# independent FST atom. The MACC channel is now part of the CLIMATE POLICY factor,
# so Factor A's effect on N surplus includes both the MACC step and the endogenous
# price response. N surplus must not be read as an independent lever's outcome.
#
# Set explicitly rather than left at default so the intent is legible and the
# config assembly test can assert it (setScenario does not touch s57_*).
.macc_block <- list(
  s57_maxmac_n_soil             = -1,
  s57_maxmac_n_awms             = -1,
  s57_maxmac_ch4_rice           = -1,
  s57_maxmac_ch4_entferm        = -1,
  s57_maxmac_ch4_awms           = -1
)

# Water protection block (Module 42 environmental flow policy ON)
.water_block <- list(
  c42_env_flow_policy           = "on",
  s42_env_flow_scenario         = 2,
  s42_efp_startyear             = 2025,
  s42_efp_targetyear            = 2050
)

# GHG-policy FRAME, held constant so Factor A toggles only the price scenario.
# c56_emis_policy is inert until 2030 regardless (preloop.gms forces
# reddnatveg_nosoil for year <= sm_fix_SSP2 = 2025).
# c56_mute_ghgprices_until is not only about when prices bite: it also gates the
# start of the carbon-price-induced afforestation reward (preloop.gms:123).
.ghgframe_block <- list(
  c56_emis_policy               = "all_nosoil",
  c56_mute_ghgprices_until      = "y2025"
)

FST_BACKDROP <- c(.diet_block, .macc_block, .water_block, .ghgframe_block)

# ---- Factor A: climate policy (Module 56) -----------------------------------

# ON: 1.5C pathway, ~$300/tC by 2050
.cp_on <- list(
  c56_pollutant_prices          = "R34M410-SSP2-PkBudg650",
  c56_pollutant_prices_noselect = "R34M410-SSP2-PkBudg650"
)
# OFF: current policies. NOT a zero price - NPi2025 carries the actually-legislated
# price path, and a 3.67 USD17MER/tC floor (s56_minimum_cprice) applies regardless.
.cp_off <- list(
  c56_pollutant_prices          = "R34M410-SSP2-NPi2025",
  c56_pollutant_prices_noselect = "R34M410-SSP2-NPi2025"
)

# ---- Factor B: 2nd-generation bioenergy demand (Module 60) ------------------

# Both arms are real demand trajectories from the same R34M410-SSP2 REMIND family;
# the factor isolates POLICY-DRIVEN BECCS EXPANSION, not bioenergy per se.
# 1st-generation bioenergy is present in both arms and cannot be switched off
# (c60_1stgen_biodem has no "none" value), so this axis is strictly 2nd-gen.
# c60_res_2ndgenBE_dem is deliberately NOT set: it stays "ssp2" from setScenario
# in both arms, keeping the residue channel constant.
.bio_on <- list(
  c60_2ndgen_biodem             = "R34M410-SSP2-PkBudg650",
  c60_2ndgen_biodem_noselect    = "R34M410-SSP2-PkBudg650"
)
.bio_off <- list(
  c60_2ndgen_biodem             = "R34M410-SSP2-NPi2025",
  c60_2ndgen_biodem_noselect    = "R34M410-SSP2-NPi2025"
)

# ---- Factor C: ambitious land protection (Modules 22 + 44 + 29, BUNDLED) ----

# Three instruments, ONE factor. This mirrors the current-generation precedent in
# scripts/start/projects/paper_healthyLscps.R, whose "ecosystem stewardship"
# bundle is exactly area conservation + a biodiversity constraint + semi-natural
# vegetation on cropland.
#
# Rationale for bundling rather than three separate factors:
#   * s44_bii_target is itself a land-protection instrument, acting on the same
#     vm_land pools as Module 22. Left in the backdrop it would have made the
#     area-based "main effect" a residual on top of an already-binding floor.
#   * SNV (Module 29) is already coupled to Module 22 in the model: q29_land_snv
#     adds the conserved area on top of the SNV requirement, so the two enter one
#     constraint. Splitting them would be a distinction the model does not make.
# Together they are one coherent "ambitious land protection" lever.
#
# Still active in BOTH arms and NOT part of this factor (they are the floor the
# contrast sits on top of, and must be named as such in the methods):
#   * WDPA baseline protection (c22_base_protect = WDPA, ~14% of land in 2020)
#   * NPI avoided deforestation and avoided other-land conversion (c35_ad_policy
#     = npi, inherited from setScenario; note c35_aolc_policy is inert in GAMS,
#     c35_ad_policy drives both floors)
#
# The timing scalars are set IDENTICALLY in both arms, so the two blocks differ in
# exactly FIVE keys: c22_protect_scenario (+ _noselect), s44_bii_target, and
# s29_snv_shr (+ _noselect). Everything else is held.
#
# PROTECTION LEVEL. GSN_HalfEarth (~50% of global land) is the ambition tier that
# matches a 1.5C carbon price, but NO pre-existing start script in this repo uses
# it, and f22_consv_prio is a GAMS table: a set element with no matching column in
# consv_prio_areas.cs3 stays silently at 0 and behaves exactly like "none". So it
# is GATED on a data check -- see fst_levers_preflight.R, which must pass before
# launching. Documented fallback, in order: BH_IFL (precedented, and structurally
# unable to no-op because 22_land_conservation/.../presolve_ini.gms hard-codes
# protection of all remaining primary forest for IFL and BH_IFL), then
# IrrC_95pc_30by30, then 30by30.
#
# c44_bii_decrease stays 1 in BOTH arms. It is a legitimate instrument in its own
# right ("no net nature loss", as used in paper_healthyLscps.R), but setting it to
# 0 HERE would contaminate the control: that branch has no `s44_bii_target > 0`
# guard (44_biodiversity/bii_target/presolve.gms), so it would impose a
# no-BII-decline constraint on the OFF arm too.
#
# _noselect twins are set for c22 and s29 for the same reason as c60: they apply
# to countries outside policy_countries22 / policy_countries29. At the default
# (all countries selected) they carry zero weight, but they become load-bearing
# the moment anyone narrows the country set.
.prot_on <- list(
  c22_protect_scenario          = "GSN_HalfEarth",
  c22_protect_scenario_noselect = "GSN_HalfEarth",
  s22_conservation_start        = 2025,
  s22_conservation_target       = 2050,
  s22_restore_land              = 1,
  s44_bii_target                = 0.78,
  s44_start_year                = 2026,
  s44_target_year               = 2050,
  c44_bii_decrease              = 1,
  s29_snv_shr                   = 0.2,
  s29_snv_shr_noselect          = 0.2,
  s29_snv_scenario_start        = 2025,
  s29_snv_scenario_target       = 2050
)
.prot_off <- list(
  c22_protect_scenario          = "none",
  c22_protect_scenario_noselect = "none",
  s22_conservation_start        = 2025,
  s22_conservation_target       = 2050,
  s22_restore_land              = 1,
  s44_bii_target                = 0,
  s44_start_year                = 2026,
  s44_target_year               = 2050,
  c44_bii_decrease              = 1,
  s29_snv_shr                   = 0,
  s29_snv_shr_noselect          = 0,
  s29_snv_scenario_start        = 2025,
  s29_snv_scenario_target       = 2050
)

# ---- composed scenario list: BAU + 6 FST cells (TC state set by orchestrator)

FST_LEVERS_SCENARIOS <- list(

  # Identical to the yield_gap BAU: current-policies carbon price, no future
  # conservation, endogenous diet, baseline bioenergy. Single tau-pin source, kept
  # byte-identical across yield_gap / fst_levers so the pin stays comparable.
  # It is therefore ASYMMETRIC to the FST cells on c56_emis_policy and
  # c56_mute_ghgprices_until. Acceptable because BAU sits OUTSIDE the design and
  # is a context line only, never a decomposition corner.
  BAU = list(
    c56_pollutant_prices          = "R34M410-SSP2-NPi2025",
    c56_pollutant_prices_noselect = "R34M410-SSP2-NPi2025",
    c56_emis_policy               = "reddnatveg_nosoil",
    c56_mute_ghgprices_until      = "y2030",
    s15_exo_diet                  = 0
  ),

  CPon_BioOn_Prot     = c(FST_BACKDROP, .cp_on,  .bio_on,  .prot_on),
  CPon_BioOn_NoProt   = c(FST_BACKDROP, .cp_on,  .bio_on,  .prot_off),
  CPon_BioOff_Prot    = c(FST_BACKDROP, .cp_on,  .bio_off, .prot_on),
  CPon_BioOff_NoProt  = c(FST_BACKDROP, .cp_on,  .bio_off, .prot_off),
  CPoff_BioOff_Prot   = c(FST_BACKDROP, .cp_off, .bio_off, .prot_on),
  CPoff_BioOff_NoProt = c(FST_BACKDROP, .cp_off, .bio_off, .prot_off)
)

# The 6 FST cells each get a TCbau companion (tau pinned at BAU level). BAU
# itself is only run endogenously; its own tau is the single pin target. A SHARED
# BAU pin (not per-cell) is required: per-cell pinning would force dTC = 0 by
# construction and destroy cross-cell comparability.
FST_LEVERS_TCBAU_SCENARIOS <- c("CPon_BioOn_Prot", "CPon_BioOn_NoProt",
                                "CPon_BioOff_Prot", "CPon_BioOff_NoProt",
                                "CPoff_BioOff_Prot", "CPoff_BioOff_NoProt")

# Factor levels per FST cell. Consumed by fst_levers_plot.R to assemble the two
# cubes, so the analysis never has to parse run-name strings.
FST_LEVERS_DESIGN <- data.frame(
  scenario = c("CPon_BioOn_Prot", "CPon_BioOn_NoProt",
               "CPon_BioOff_Prot", "CPon_BioOff_NoProt",
               "CPoff_BioOff_Prot", "CPoff_BioOff_NoProt"),
  cp   = c("on",  "on",  "on",  "on",  "off", "off"),
  bio  = c("on",  "on",  "off", "off", "off", "off"),
  prot = c("on",  "off", "on",  "off", "on",  "off"),
  stringsAsFactors = FALSE
)

# Cube membership. Cube A holds CP fixed ON and varies Bio x Prot x TC; cube B
# holds Bio fixed OFF and varies CP x Prot x TC. They share the CPon_BioOff face.
FST_LEVERS_CUBES <- list(
  A = list(
    label      = "Cube A: bioenergy x protection (under 1.5C policy)",
    fixed      = c(cp = "on"),
    varying    = c("bio", "prot"),
    reference  = "CPon_BioOff_NoProt"
  ),
  B = list(
    label      = "Cube B: climate policy x protection (at baseline bioenergy)",
    fixed      = c(bio = "off"),
    varying    = c("cp", "prot"),
    reference  = "CPoff_BioOff_NoProt"
  )
)

# ---- helpers ----------------------------------------------------------------

# Guard against a silent switch collision: c() on named lists KEEPS duplicates,
# and applyTCScenario applies them in order, so a key appearing in two blocks
# would be silently resolved by position rather than by intent.
assertNoDuplicateSwitches <- function() {
  for (nm in names(FST_LEVERS_SCENARIOS)) {
    keys <- names(FST_LEVERS_SCENARIOS[[nm]])
    dup  <- keys[duplicated(keys)]
    if (length(dup) > 0) {
      stop("Scenario '", nm, "' sets these switches more than once: ",
           paste(unique(dup), collapse = ", "),
           ". Blocks must not overlap.")
    }
  }
  invisible(TRUE)
}
assertNoDuplicateSwitches()

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
