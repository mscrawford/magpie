# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# ---- LINEAGE / STATUS -------------------------------------------------------
# LIVE - BASE LAYER of a three-file stack. NOT superseded, despite the newer
# v2/v5 filenames sitting beside it:
#     fst_levers_v5_config.R  ->  sources v2  ->  sources THIS FILE
# The lever atoms (.cp_*, .bio_*, .prot_*, .diet_*) and the corrected BII start
# year live here, so the current arm depends on this file. Do not delete or
# bypass it. Only fst_levers_v5_config.R is an entry point.
# See RIKEN/04-fst-levers/LINEAGE.md for which arm is current.
# -----------------------------------------------------------------------------

# Scenario definitions for the fst_levers experiment.
# See scripts/start/projects/fst_levers.R for the orchestrator and
# scripts/start/projects/fst_levers_README.md for the methods writeup.
#
# Question: as a Food System Transformation (FST) is assembled from its levers,
# how do AMBITIOUS LAND-AND-WATER PROTECTION, 2nd-generation BIOENERGY demand, a
# DIETARY SHIFT and CLIMATE POLICY interact in reshaping land use, and how much
# does endogenous technological change (TC) contribute in each case?
#
# Design: 5 binary factors.
#
#   1. TC state         : TCendo vs TCbau (tau pinned to BAU)        (Module 13)
#   2. climate policy   : 1.5C carbon price vs current-policies price (Module 56)
#   3. bioenergy demand : 1.5C-consistent vs baseline 2nd-gen demand  (Module 60)
#   4. land+water protect: Half-Earth + BII + SNV + env-flows vs none (Mod 22+44+29+42)
#   5. diet             : EAT-Lancet FLX transition vs endogenous diet (Module 15)
#
# STRUCTURAL CHANGE vs the earlier 4-factor version: diet and environmental-flow
# water protection used to sit in a constant FST backdrop. Diet is now its own
# FACTOR (5), and water protection has been folded INTO the protection bundle
# (4), which is now a land-AND-water lever. The backdrop shrinks to just the
# non-CO2 MACC block and the GHG-policy frame (see below).
#
# THE HOLE: the (climate policy off, bioenergy on) combination is EXCLUDED.
# 1.5C-level 2nd-gen bioenergy demand without a carbon price is not a coherent
# scenario -- the c56 price and the c60 demand come from the SAME coupled REMIND
# run, so an NPi price with PkBudg650 bioenergy would pair two halves of two
# different energy-system solutions.
#
# THE KEPT COUNTERFACTUAL: (climate policy on, bioenergy off) is the MIRROR of the
# hole -- a PkBudg650 price with NPi bioenergy demand. It is ALSO two uncoupled
# REMIND runs and so is NOT a believed scenario either. Unlike the hole we KEEP
# it, as a labelled DECOMPOSITION DEVICE: it is the only way to read a bioenergy
# main effect at all (Cube A varies Bio with climate policy held on). A future
# coupled REMIND-MAgPIE run would resolve it; at this exploratory stage the
# decomposition value is worth the inconsistency, provided it is never quoted as
# a standalone scenario. See the README "hole + counterfactual" section.
#
# That leaves 3 coherent (climate, bio) combinations -- (on,on), (on,off),
# (off,off) -- x 2 protection x 2 diet = 12 policy cells, each run at TCendo and
# TCbau, plus BAU (TCendo only, the tau-pin source) = 25 runs.
#
# IDENTIFICATION CONSEQUENCE of the hole: this is NOT a full 2^5. It is two 2^4
# cubes sharing a 2^3 face:
#   Cube A (climate = on): Bio x Prot x Diet x TC
#   Cube B (bio     = off): Climate x Prot x Diet x TC
# Every effect involving CLIMATE and BIO JOINTLY (Climate:Bio and every higher
# interaction that contains both) is unidentifiable by construction. The bioenergy
# main effect is therefore conditional on climate policy being on, and must never
# be reported as a marginal effect over the whole design.
#
# ---- 2026-08-03 EXTENSION: a THIRD climate level, CP20 (2.0C) ---------------
#
# WHY: all four `CPon_BioOn_*_TCbau` runs are infeasible -- they solve to 2040 and
# fail at 2045, identically, whether protection and diet are on or off. The
# binding driver is the PkBudg650 2nd-gen bioenergy ramp (1932 -> 3336 -> 5181
# Mt DM/yr across 2035-2045) against frozen tau. PkBudg1000 (~2.0C) relieves BOTH
# sides at once: a lower carbon price AND a lower BECCS demand. Precedent for the
# pairing: scripts/start/test_runs.R:64-65 and project_WetHorizons.R:62-63 both
# set c56 and c60 to the same PkBudg1000 tag, and test_runs.R:51 records the same
# remedy ("SSP3-PkBudg650 is not feasible, therefore only PkBudg1000 is used").
#
# 16 new runs: CP20_{BioOn,BioOff} x {Prot,NoProt} x {DietOn,DietOff} x
# {TCendo,TCbau}. They pin to the SAME BAU tau as every other TCbau run, so they
# need no new Phase-1 dependency and launch in one wave.
#
# CP20_BioOn is the COHERENT 2.0C corner (PkBudg1000 price + PkBudg1000 demand).
# CP20_BioOff is the same labelled counterfactual device as CPon_BioOff
# (PkBudg1000 price + NPi bioenergy) -- it is what makes the bioenergy effect and
# the protection erosion readable at 2.0C, and it supplies the middle point of the
# climate gradient (current policy -> 2.0C -> 1.5C) at baseline bioenergy.
#
# IDENTIFICATION: the climate factor is now THREE-LEVEL, which the binary 2^k
# machinery cannot consume. CP20 therefore sits OUTSIDE both cubes: Cube A stays
# (cp == "on"), Cube B must be filtered to cp %in% c("off","on") EXPLICITLY, not
# just to bio == "off" -- otherwise it silently collects 24 cells for a 16-cell
# decomposition. FST_LEVERS_CUBES$B$levels below carries that restriction so the
# analysis cannot forget it. The 2.0C runs are read as a third arm in the
# regime-wise views (isolation slices, the tau-by-regime figure), not as cube
# corners.
#
# "Equal ambition" decisions (see README section on methodology):
#   * Every policy lever transitions on the SAME 2025->2050 schedule. This
#     required moving the BII target off its defaults (s44_start_year 2030,
#     s44_target_year 2100), which would otherwise have made biodiversity
#     ambition ramp 50 years later than every other lever.
#   * c56_emis_policy and c56_mute_ghgprices_until are held CONSTANT across all
#     12 FST cells, so the climate factor toggles exactly one thing: the price.
#   * The bioenergy factor's two arms are the SAME REMIND run family at two policy
#     levels (PkBudg650 vs NPi2025), not "bioenergy vs zero bioenergy".
#   * Non-CO2 MACCs are PRICE-DRIVEN, not forced to the maximum step, so N and
#     CH4 abatement scale with each cell's own REMIND carbon price instead of
#     being pinned at an ambition the climate-off cells never paid for. See
#     .macc_block.

# ---- constant FST backdrop (identical in all 12 FST cells) ------------------
#
# The backdrop is now only the two blocks that are NOT levers of this experiment:
# the non-CO2 abatement setting and the GHG-policy frame. Diet moved out to become
# Factor 5; environmental-flow water protection moved into the protection bundle
# (Factor 4). Do NOT re-add diet or water here.

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
#     climate-off arm had maximal N abatement alongside near-zero CH4 abatement.
#   * Intermediate steps are arbitrary parameterizations, not meaningful units,
#     so hand-picking a "1.5C-equivalent" step (e.g. 106) would substitute one
#     arbitrary anchor for another.
#
# With -1 the model derives the step from the actual REMIND price per region and
# per timestep (57_maccs/on_aug22/preloop.gms:24-25, min(201, ceil(price/.../
# s57_step_length)+1); PBL_2022 -> s57_step_length = 22.4 USD17MER/tCeq/step).
# Non-CO2 ambition therefore tracks the CLIMATE factor automatically: 1.5C-
# consistent in the climate-on cells, current-policies-consistent otherwise.
#
# DESIGN CONSEQUENCE, must be carried into the analysis: N surplus now has TWO
# channels in this design, not one. (a) The MACC channel is part of the CLIMATE
# factor -- the climate price sets the abatement step and the endogenous price
# response. (b) The DIET factor moves N through food demand -- an EAT-Lancet shift
# changes livestock demand and therefore manure and fertiliser N. N surplus must
# be attributed to BOTH factors, never read as a single lever's outcome.
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

# GHG-policy FRAME, held constant so the climate factor toggles only the price
# scenario. c56_emis_policy is inert until 2030 regardless (preloop.gms forces
# reddnatveg_nosoil for year <= sm_fix_SSP2 = 2025).
# c56_mute_ghgprices_until is not only about when prices bite: it also gates the
# start of the carbon-price-induced afforestation reward (preloop.gms:123).
.ghgframe_block <- list(
  c56_emis_policy               = "all_nosoil",
  c56_mute_ghgprices_until      = "y2025"
)

FST_BACKDROP <- c(.macc_block, .ghgframe_block)

# ---- Factor 2: climate policy (Module 56) -----------------------------------

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
# 2.0C: the PkBudg1000 pathway, the middle rung between NPi2025 and PkBudg650.
# Added 2026-08-03 (see the header extension note). MUST be used together with
# .bio_20 - a PkBudg1000 price against a PkBudg650 or NPi bioenergy demand is the
# same two-halves-of-two-energy-systems defect the hole exists to avoid.
.cp_20 <- list(
  c56_pollutant_prices          = "R34M410-SSP2-PkBudg1000",
  c56_pollutant_prices_noselect = "R34M410-SSP2-PkBudg1000"
)

# ---- Factor 3: 2nd-generation bioenergy demand (Module 60) ------------------

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
# The 2.0C-consistent bioenergy demand, the partner of .cp_20. Pairing these two
# is not a style preference: c56 and c60 are the price-side and land-side images
# of ONE energy-system solution, and scenario_config.csv only ever sets them
# together (columns coupling / emulator / input). Both default to the NPi tag, so
# changing only the price is silently inconsistent with nothing in the config to
# show for it - which is exactly what the yield_gap experiment did.
.bio_20 <- list(
  c60_2ndgen_biodem             = "R34M410-SSP2-PkBudg1000",
  c60_2ndgen_biodem_noselect    = "R34M410-SSP2-PkBudg1000"
)

# ---- Factor 4: land+water protection (Modules 22 + 44 + 29 + 42, BUNDLED) ---

# FOUR instruments, ONE factor: area conservation (22), a biodiversity floor
# (44), semi-natural vegetation on cropland (29), and environmental-flow water
# protection (42). The land part mirrors the current-generation precedent in
# scripts/start/projects/paper_healthyLscps.R, whose "ecosystem stewardship"
# bundle is exactly area conservation + a biodiversity constraint + SNV. Water is
# added here so the protection lever is land AND water, not land alone.
#
# Rationale for bundling rather than four separate factors:
#   * s44_bii_target is itself a land-protection instrument, acting on the same
#     vm_land pools as Module 22. Left in the backdrop it would have made the
#     area-based "main effect" a residual on top of an already-binding floor.
#   * SNV (Module 29) is already coupled to Module 22 in the model: q29_land_snv
#     adds the conserved area on top of the SNV requirement, so the two enter one
#     constraint. Splitting them would be a distinction the model does not make.
#   * Environmental-flow protection (Module 42) is the WATER limb of the same
#     "protect ecosystems" ambition. Keeping it a separate always-on backdrop
#     line would have hidden its land-competition cost inside every cell instead
#     of attributing it to the protection factor where it belongs.
# Together they are one coherent "ambitious land-and-water protection" lever.
#
# Still active in BOTH arms and NOT part of this factor (they are the floor the
# contrast sits on top of, and must be named as such in the methods):
#   * WDPA baseline protection (c22_base_protect = WDPA, ~14% of land in 2020)
#   * NPI avoided deforestation and avoided other-land conversion (c35_ad_policy
#     = npi, inherited from setScenario; note c35_aolc_policy is inert in GAMS,
#     c35_ad_policy drives both floors)
#   * The base 5% environmental-flow reservation (s42_env_flow_base_fraction),
#     which applies to the non-EFP share of every region regardless of the policy
#     switch. "Water protection off" is therefore the base reservation only, not
#     zero environmental water.
#
# The land timing scalars (s22_*, s44_*, s29_*) are set IDENTICALLY in both arms,
# so those are held. The two blocks differ in:
#   * c22_protect_scenario (+ _noselect)   GSN_HalfEarth vs none
#   * s44_bii_target                       0.78 vs 0
#   * s29_snv_shr (+ _noselect)            0.2 vs 0
#   * c42_env_flow_policy                  "on" vs "off"
# Plus the ON arm sets the three s42 water scalars (scenario + start/target year),
# which the OFF arm omits: with c42_env_flow_policy = "off" the fader parameter
# p42_efp(t,"off") is identically 0 (42_water_demand/all_sectors_aug13/
# preloop.gms:15), so those scalars are inert in the OFF arm and there is nothing
# to hold them equal against. They therefore appear in the ON-vs-OFF diff.
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
# the moment anyone narrows the country set. Module 42's EFP has no country-subset
# switch, so there is no c42 _noselect twin to set.
.prot_on <- list(
  c22_protect_scenario          = "GSN_HalfEarth",
  c22_protect_scenario_noselect = "GSN_HalfEarth",
  s22_conservation_start        = 2025,
  s22_conservation_target       = 2050,
  s22_restore_land              = 1,
  s44_bii_target                = 0.78,
  # 2030, NOT 2026. Module 44 builds p44_bii_target inside
  #   if (m_year(t) = s44_start_year AND s44_bii_target > 0, ... )
  # an EXACT timestep match, unlike every other lever here, which uses an
  # m_*_time_interpol fader anchored at a year that need not be a timestep. 2026
  # satisfies the module's own abort guard (s44_start_year > sm_fix_SSP2 = 2025)
  # but is NOT on the timestep grid (...2020, 2025, 2030...), so the block never
  # fired: p44_bii_target stayed at its preloop 0 across all 15336 entries, total
  # shortfall was exactly 0, and vm_cost_bv_loss never accrued. The BII floor was
  # INERT in every run before 2026-08-18. 2030 is the earliest year that is both a
  # timestep and > 2025. Verified against the old batch, where start_year 2030
  # gives 1540 nonzero target entries and a 0.76 shortfall at 2100.
  s44_start_year                = 2030,
  s44_target_year               = 2050,
  c44_bii_decrease              = 1,
  s29_snv_shr                   = 0.2,
  s29_snv_shr_noselect          = 0.2,
  s29_snv_scenario_start        = 2025,
  s29_snv_scenario_target       = 2050,
  c42_env_flow_policy           = "on",
  s42_env_flow_scenario         = 2,
  s42_efp_startyear             = 2025,
  s42_efp_targetyear            = 2050
)
.prot_off <- list(
  c22_protect_scenario          = "none",
  c22_protect_scenario_noselect = "none",
  s22_conservation_start        = 2025,
  s22_conservation_target       = 2050,
  s22_restore_land              = 1,
  s44_bii_target                = 0,
  # Kept identical to .prot_on so the protection factor toggles s44_bii_target
  # alone. Inert here regardless (the module block also requires target > 0).
  s44_start_year                = 2030,
  s44_target_year               = 2050,
  c44_bii_decrease              = 1,
  s29_snv_shr                   = 0,
  s29_snv_shr_noselect          = 0,
  s29_snv_scenario_start        = 2025,
  s29_snv_scenario_target       = 2050,
  c42_env_flow_policy           = "off"
)

# ---- Factor 5: dietary shift (Module 15) ------------------------------------

# Restored to a FACTOR (it was the constant diet backdrop in the 4-factor
# version). ON = an exogenous EAT-Lancet FLX 2500 kcal diet, converging linearly
# 2025->2050. OFF = the endogenous diet MAgPIE derives from income and prices.
#
# The OFF arm sets ONLY s15_exo_diet = 0: with the exogenous-diet switch off the
# c15_EAT_scen / c15_kcal_scen / convergence scalars have no effect (15_food/
# .../ selects the endogenous demand path), so there is nothing to hold equal and
# they appear in the ON-vs-OFF diff.
.diet_on <- list(
  s15_exo_diet                  = 1,
  c15_EAT_scen                  = "FLX",
  c15_kcal_scen                 = "2500kcal",
  s15_exo_foodscen_start        = 2025,
  s15_exo_foodscen_target       = 2050,
  s15_exo_foodscen_convergence  = 1
)
.diet_off <- list(
  s15_exo_diet                  = 0
)

# ---- composed scenario list: BAU + 12 FST cells (TC state set by orchestrator)

# Each FST cell is c(backdrop, climate, bio, prot, diet). The 12 cells are the 3
# coherent (climate,bio) combinations x 2 protection x 2 diet.
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

  # (climate on, bio on) : coherent 1.5C corner
  CPon_BioOn_Prot_DietOn    = c(FST_BACKDROP, .cp_on,  .bio_on,  .prot_on,  .diet_on),
  CPon_BioOn_Prot_DietOff   = c(FST_BACKDROP, .cp_on,  .bio_on,  .prot_on,  .diet_off),
  CPon_BioOn_NoProt_DietOn  = c(FST_BACKDROP, .cp_on,  .bio_on,  .prot_off, .diet_on),
  CPon_BioOn_NoProt_DietOff = c(FST_BACKDROP, .cp_on,  .bio_on,  .prot_off, .diet_off),

  # (climate on, bio off) : the KEPT counterfactual face (PkBudg650 price + NPi
  # bioenergy). Not a believed scenario; the decomposition device that lets Cube A
  # read a bioenergy main effect. See the header "KEPT COUNTERFACTUAL" note.
  CPon_BioOff_Prot_DietOn    = c(FST_BACKDROP, .cp_on,  .bio_off, .prot_on,  .diet_on),
  CPon_BioOff_Prot_DietOff   = c(FST_BACKDROP, .cp_on,  .bio_off, .prot_on,  .diet_off),
  CPon_BioOff_NoProt_DietOn  = c(FST_BACKDROP, .cp_on,  .bio_off, .prot_off, .diet_on),
  CPon_BioOff_NoProt_DietOff = c(FST_BACKDROP, .cp_on,  .bio_off, .prot_off, .diet_off),

  # (climate off, bio off) : coherent current-policies corner
  CPoff_BioOff_Prot_DietOn    = c(FST_BACKDROP, .cp_off, .bio_off, .prot_on,  .diet_on),
  CPoff_BioOff_Prot_DietOff   = c(FST_BACKDROP, .cp_off, .bio_off, .prot_on,  .diet_off),
  CPoff_BioOff_NoProt_DietOn  = c(FST_BACKDROP, .cp_off, .bio_off, .prot_off, .diet_on),
  CPoff_BioOff_NoProt_DietOff = c(FST_BACKDROP, .cp_off, .bio_off, .prot_off, .diet_off),

  # ---- 2026-08-03: the third climate level, 2.0C (PkBudg1000) ---------------
  # (climate 2.0C, bio 2.0C) : coherent 2.0C corner. The reason the arm exists -
  # the 1.5C version of this corner has no frozen-tau solution (fails at 2045).
  CP20_BioOn_Prot_DietOn    = c(FST_BACKDROP, .cp_20, .bio_20,  .prot_on,  .diet_on),
  CP20_BioOn_Prot_DietOff   = c(FST_BACKDROP, .cp_20, .bio_20,  .prot_on,  .diet_off),
  CP20_BioOn_NoProt_DietOn  = c(FST_BACKDROP, .cp_20, .bio_20,  .prot_off, .diet_on),
  CP20_BioOn_NoProt_DietOff = c(FST_BACKDROP, .cp_20, .bio_20,  .prot_off, .diet_off),

  # (climate 2.0C, bio off) : the same labelled counterfactual device as
  # CPon_BioOff (PkBudg1000 price + NPi bioenergy). Not a believed scenario; it is
  # what makes the bioenergy effect and the protection erosion readable at 2.0C,
  # and it is the middle rung of the baseline-bioenergy climate gradient.
  CP20_BioOff_Prot_DietOn    = c(FST_BACKDROP, .cp_20, .bio_off, .prot_on,  .diet_on),
  CP20_BioOff_Prot_DietOff   = c(FST_BACKDROP, .cp_20, .bio_off, .prot_on,  .diet_off),
  CP20_BioOff_NoProt_DietOn  = c(FST_BACKDROP, .cp_20, .bio_off, .prot_off, .diet_on),
  CP20_BioOff_NoProt_DietOff = c(FST_BACKDROP, .cp_20, .bio_off, .prot_off, .diet_off)
)

# The 12 FST cells each get a TCbau companion (tau pinned at BAU level). BAU
# itself is only run endogenously; its own tau is the single pin target. A SHARED
# BAU pin (not per-cell) is required: per-cell pinning would force dTC = 0 by
# construction and destroy cross-cell comparability.
FST_LEVERS_TCBAU_SCENARIOS <- c(
  "CPon_BioOn_Prot_DietOn",    "CPon_BioOn_Prot_DietOff",
  "CPon_BioOn_NoProt_DietOn",  "CPon_BioOn_NoProt_DietOff",
  "CPon_BioOff_Prot_DietOn",   "CPon_BioOff_Prot_DietOff",
  "CPon_BioOff_NoProt_DietOn", "CPon_BioOff_NoProt_DietOff",
  "CPoff_BioOff_Prot_DietOn",  "CPoff_BioOff_Prot_DietOff",
  "CPoff_BioOff_NoProt_DietOn","CPoff_BioOff_NoProt_DietOff",
  "CP20_BioOn_Prot_DietOn",    "CP20_BioOn_Prot_DietOff",
  "CP20_BioOn_NoProt_DietOn",  "CP20_BioOn_NoProt_DietOff",
  "CP20_BioOff_Prot_DietOn",   "CP20_BioOff_Prot_DietOff",
  "CP20_BioOff_NoProt_DietOn", "CP20_BioOff_NoProt_DietOff"
)

# Factor levels per FST cell. Consumed by the analysis to assemble the two cubes,
# so it never has to parse run-name strings. Columns: the four policy factors
# (cp, bio, prot, diet); the TC factor is added by the analysis from the run
# suffix (_TCendo / _TCbau).
# DERIVED from the scenario names through an explicit token map, not maintained
# as hand-aligned parallel vectors. With the 2.0C level the vectors would be five
# columns x 20 rows of positional bookkeeping in which one misaligned entry
# mislabels a cell silently. The map also STOPS on an unrecognised token, which is
# the property that matters: the binary idiom this replaces,
# `ifelse(tk == "CPon", "on", "off")`, would have quietly filed every CP20 run
# under current policy.
FST_LEVERS_TOKENS <- list(
  cp   = c(CPoff  = "off", CP20 = "20", CPon  = "on"),
  bio  = c(BioOff = "off", BioOn = "on"),
  prot = c(NoProt = "off", Prot  = "on"),
  diet = c(DietOff = "off", DietOn = "on")
)

parseCellName <- function(scen) {
  tk <- strsplit(scen, "_", fixed = TRUE)[[1]]
  if (length(tk) != length(FST_LEVERS_TOKENS))
    stop("FST cell name '", scen, "' has ", length(tk), " tokens; expected ",
         length(FST_LEVERS_TOKENS), " (climate_bio_protection_diet).")
  lv <- Map(function(field, token) {
    x <- unname(FST_LEVERS_TOKENS[[field]][token])
    if (is.na(x))
      stop("unknown ", field, " token '", token, "' in scenario '", scen,
           "'. Add it to FST_LEVERS_TOKENS -- and check every consumer that ",
           "assumes this factor is binary, the 2^k cubes above all.")
    x
  }, names(FST_LEVERS_TOKENS), tk)
  data.frame(c(list(scenario = scen), lv), stringsAsFactors = FALSE)
}

FST_LEVERS_DESIGN <- do.call(rbind, lapply(
  setdiff(names(FST_LEVERS_SCENARIOS), "BAU"), parseCellName))

# Cube membership. Two 2^4 cubes (each Prot x Diet x TC x one of {Bio, Climate})
# sharing the 2^3 face (climate on, bio off) x Prot x Diet x TC.
#   Cube A holds climate fixed ON and varies Bio x Prot x Diet x TC.
#   Cube B holds bio fixed OFF and varies Climate x Prot x Diet x TC.
# TC is added by the analysis as the fourth varying factor of each cube (from the
# run suffix). The `varying` lists below name the three factors that vary WITHIN
# the design table; the analysis crosses each with TC.
#
# `levels` pins the admissible level set of a VARYING factor. It exists because
# the climate factor is no longer binary: Cube B selects on bio == "off", and
# with the 2.0C arm present that selection returns 24 cells for what must be a
# 16-cell 2^4 decomposition. Cube A needs no such pin - fixing cp == "on" already
# excludes CP20. Any consumer building a cube MUST apply `levels`.
FST_LEVERS_CUBES <- list(
  A = list(
    label      = "Cube A: bioenergy x protection x diet (under 1.5C policy)",
    fixed      = c(cp = "on"),
    varying    = c("bio", "prot", "diet"),
    levels     = list(),
    reference  = "CPon_BioOff_NoProt_DietOff"
  ),
  B = list(
    label      = "Cube B: climate policy x protection x diet (at baseline bioenergy)",
    fixed      = c(bio = "off"),
    varying    = c("cp", "prot", "diet"),
    levels     = list(cp = c("off", "on")),   # EXCLUDES the 2.0C arm by design
    reference  = "CPoff_BioOff_NoProt_DietOff"
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
