# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# ---- LINEAGE / STATUS -------------------------------------------------------
# LIVE - MIDDLE LAYER of a three-file stack. Sourced by fst_levers_v5_config.R,
# sources fst_levers_config.R. Holds the Japan exclusion machinery and the
# FSTL2/FSTL3 designs. Not an entry point on its own for current work.
# See RIKEN/04-fst-levers/LINEAGE.md for which arm is current.
# -----------------------------------------------------------------------------

# fst_levers ROUND 2 ("v2"): the 1.5C coherent corner, re-run with the Japan
# residue artifact removed and the dietary lever switched to MAgPIE's own
# EAT-Lancet realization.
#
# Run with:
#   FST_LEVERS_CONFIG=scripts/start/projects/fst_levers_v2_config.R \
#   FST_LEVERS_SUMMARY=output/fst_levers_v2_summary.rds \
#   FST_LEVERS_QOS=short Rscript scripts/start/projects/fst_levers.R
#
# This file REPLACES the scenario list of fst_levers_config.R (which it sources
# first, for the factor blocks and helpers). Nothing here touches the 41 runs of
# the 2026-08 batch: every v2 run carries an FSTL2_ prefix, so no folder name
# collides and the orchestrator skips everything that already completed.
#
# ---- WHY v2 exists ---------------------------------------------------------
#
# All four 1.5C `CPon_BioOn_*_TCbau` corners are infeasible: they fail at 2045 on
# ONE constraint, q60_res_2ndgenBE for JAPAN - Japan's exogenous SSP2 residue
# demand for 2nd-generation bioenergy exceeds what its frozen-tau residue supply
# can deliver. That constraint carries NO feasibility slack (unlike q21_trade_reg,
# which has v21_import_for_feasibility), so a single land-poor region's residue
# shortfall hard-fails the entire global solve. It is a MODEL-CORNER artifact,
# not a physical "1.5C + bioenergy is impossible" result.
#
# v2 removes that artifact so the design can be discussed on its land-use merits,
# and leaves the artifact itself for a later, separate fix.
#
# #############################################################################
# 2026-08-18: CHANGE 1 (the module-60 residue patch) HAS BEEN REVERTED.
#
# Mike's call after the 1.5C round. Exempting Japan's residue demand ALONE still
# left all four TCbau corners infeasible, so the patch did not buy the 1.5C
# dynamics it was written for. The model source goes back to stock and the Japan
# exemption is expressed in CONFIG ALONE. The patch is preserved verbatim, with
# its backward-compatibility proof, in project memory
# `magpie_residue_noselect_patch` (clone commit a6581aea1).
#
# REPRODUCIBILITY CONSEQUENCE: every FSTL2_* and FSTL3_* run on disk was produced
# WITH the patch applied. They CANNOT be reproduced from the current tree without
# re-applying it. Their folders already exist so the orchestrator skips them - do
# not delete one expecting a re-run to recreate the same scenario.
#
# CHANGE 1 is kept below verbatim as the record of what the patch did and why.
# #############################################################################
#
# ---- CHANGE 1: Japan's exogenous residue demand is switched off -------------
#
# Implemented with the country-selection ("noselect") idiom the module already
# uses for the DEDICATED 2nd-gen demand. That idiom did NOT previously reach the
# RESIDUE channel: i60_res_2ndgenBE_dem was set from one global switch with no
# country split, so the only available lever was c60_res_2ndgenBE_dem = "off",
# which would have zeroed residue bioenergy demand in EVERY region - a real
# scenario change, not the surgical fix wanted here.
#
# A _noselect twin was therefore added to module 60 (input.gms + presolve.gms +
# config/default.cfg), mirroring preloop.gms:30-31 exactly:
#
#   i60_res_2ndgenBE_dem(t,i) = f60(...,"%c60_res_2ndgenBE_dem%")          * shr
#                             + f60(...,"%c60_res_2ndgenBE_dem_noselect%") * (1-shr)
#
# where shr = p60_region_BE_shr(t,i) is the population share of scen_countries60
# in region i. Two properties make this exact rather than approximate:
#
#   * BACKWARD COMPATIBLE: both switches default to "ssp2" and scen_countries60
#     defaults to all countries, so shr = 1 and the blend collapses to
#     x*1 + y*0 = x. Every pre-existing run is bit-identical. (Verified by dry
#     run: the unchanged config still reports 41 skipped, 0 launched.)
#   * EXACT FOR JAPAN: region JPN contains exactly ONE country (JPN) in
#     input/regionmappingH12.csv, so dropping JPN from scen_countries60 gives
#     shr = 0 for that region and shr = 1 for every other region. No partial-
#     region contamination anywhere.
#
# The "off" column of f60_2ndgenBE_residue_dem.cs3 is identically zero (checked:
# 0 nonzero entries across all 456 rows), so Japan's residue demand becomes 0
# from 2030 on. History is untouched: presolve.gms harmonizes t <= sm_fix_SSP2
# (2025) to "ssp2" for all regions before the blend applies.
#
# NOTE the coupling this creates, and why it is safe here: scen_countries60 also
# selects the DEDICATED demand (c60_2ndgen_biodem vs _noselect). Narrowing the
# country set would therefore hand Japan the _noselect dedicated scenario too -
# except that .bio_on/.bio_off/.bio_20 set BOTH twins to the SAME tag, so the
# dedicated channel is unchanged. fst_levers_v2_config_test.R asserts exactly
# that for every v2 cell; if anyone ever sets the twins differently, it fails.
#
# ---- CHANGE 2: the dietary lever becomes MAgPIE's own EAT-Lancet diet -------
#
# Was: s15_exo_diet = 1 + c15_EAT_scen = "FLX" + c15_kcal_scen = "2500kcal" - an
# EXOGENOUS EAT-Lancet Flexitarian diet, i.e. intake is replaced wholesale by a
# food-specific dataset. config/default.cfg calls that implementation
# DEPRECATED and points at s15_exo_diet = 3 instead.
#
# Now: s15_exo_diet = 3, the "MAgPIE-specific realization of the EAT-Lancet
# diet", where the model's own regression-based demand projections are kept and
# CONSTRAINED by the EAT-Lancet recommended intake ranges (f15_rec_EATLancet,
# from f15_targets_EATLancet_iso.cs3), with staples rebalanced to the calorie
# target. Endogenous in composition, bounded by the guideline - which is what
# "the endogenous EL diet" means. Precedent: project_EAT2p0.R:109 (the EL2.0
# runs) whose entire diet component is exactly `cfg$gms$s15_exo_diet <- 3`.
#
# c15_kcal_scen is set to "healthy_BMI", the EL2.0 / MAgPIE default, and NOT
# carried over as "2500kcal". This is load-bearing rather than cosmetic:
# exodietmacro.gms:354-357 routes any kcal target that is not one of the named
# BMI variants into `i15_intake_scen_target = sum(kfo,
# i15_intake_EATLancet_all(iso,"%c15_kcal_scen%","%c15_EAT_scen%",kfo))` - so
# keeping "2500kcal" would pull the calorie target straight back out of the
# EXOGENOUS EAT-Lancet dataset and re-activate c15_EAT_scen, defeating the point
# of the switch. c15_EAT_scen is therefore not set at all in the v2 diet block;
# under (s15_exo_diet=3, c15_kcal_scen=healthy_BMI) it is inert.
#
# The 2025->2050 linear fade-in is preserved, so the diet lever still transitions
# on the same schedule as every other lever ("equal ambition"). It applies to the
# s15_exo_diet=3 path as well: exodietmacro.gms:679-684 blends p15_intake_detail
# towards the scenario target with i15_exo_foodscen_fader.
#
# ---- What is NOT changed ---------------------------------------------------
#
#   * The tau pin. Phase 2 still pins to the EXISTING BAU_TCendo gdx from the
#     2026-08 batch (BAU is listed below only so the orchestrator can find and
#     skip it; it is NOT re-run, and its own residue demand is untouched). tau is
#     a productivity trajectory, and a shared BAU pin is what makes cells
#     comparable - see the base config's note on per-cell pinning.
#   * Every other factor block: backdrop, climate, bioenergy, protection are
#     taken verbatim from fst_levers_config.R.
#
# ---- Scope of this launch --------------------------------------------------
#
# The coherent 1.5C corner only: CPon (PkBudg650 price) + BioOn (PkBudg650
# 2nd-gen demand) x {Prot,NoProt} x {DietEL,DietOff} x {TCendo,TCbau} = 8 runs.
# That is the 2^3 (protection x diet x TC) block at the corner that previously
# had no frozen-tau solution, which is the question this round has to answer.
# It does NOT support a bioenergy main effect (no BioOff arm here); adding the
# 8 CPon_BioOff cells is a four-line change if the group wants that contrast.
# If the TCbau corners still fail at 1.5C, the same cells re-run with .cp_20 +
# .bio_20 (2.0C, PkBudg1000) are the documented next rung.

source("scripts/start/projects/fst_levers_config.R")

.base_scenarios <- FST_LEVERS_SCENARIOS

# ---- v2 base overrides (arm-level, not per-cell) ----------------------------

# Called by the orchestrator AFTER config/default.cfg and gms::setScenario, so
# `all_iso_countries` is in scope and setScenario's own c60_res_2ndgenBE_dem =
# "ssp2" is already in place and is overridden here rather than silently
# inherited. Applied BEFORE applyTCScenario, and no v2 scenario block sets any
# of these keys, so nothing downstream can quietly undo it.
FSTL2_EXCLUDED_ISO <- "JPN"

fstLeversBaseOverrides <- function(cfg) {
  iso <- strsplit(gsub("[[:space:]]", "", all_iso_countries), ",", fixed = TRUE)[[1]]
  iso <- iso[nzchar(iso)]
  if (!FSTL2_EXCLUDED_ISO %in% iso) {
    stop("fst_levers v2: '", FSTL2_EXCLUDED_ISO, "' is not in all_iso_countries; ",
         "the Japan bioenergy exemption would silently be a no-op.")
  }
  # scen_countries60 drives the DEDICATED 2nd-gen demand split (preloop.gms:30-31)
  # and, since the 2026-08-18 revert, nothing else. Stock MAgPIE gives the RESIDUE
  # channel no country split, so c60_res_2ndgenBE_dem applies globally - Japan
  # included. Set explicitly rather than inherited so the value is visible here.
  cfg$gms$scen_countries60     <- paste(setdiff(iso, FSTL2_EXCLUDED_ISO), collapse = ",")
  cfg$gms$c60_res_2ndgenBE_dem <- "ssp2"
  cfg
}

# ---- Factor 3 variant: the 1.5C ramp for everyone EXCEPT Japan --------------

# Identical to .bio_on for every selected country, but the de-selected one
# (Japan, already excluded from scen_countries60 by fstLeversBaseOverrides) falls
# through to the _noselect scenario and stays on the NPi2025 baseline trajectory.
# So Japan is exempted from the 1.5C BECCS ramp without touching any other region.
#
# NPi2025, not zero, and not "none": the _noselect value is used directly as a
# column of f60_bioenergy_dem, so it must be a member of scen2nd60. "none" is NOT
# a member - it is a special case handled earlier in preloop.gms and keyed on the
# SELECTED switch only, so putting it here would be an invalid set element rather
# than a switch-off. NPi2025 is also exactly what this design already means by
# "baseline bioenergy demand" (.bio_off), which keeps the arm interpretable.
.bio_on_xjp <- list(
  c60_2ndgen_biodem             = "R34M410-SSP2-PkBudg650",
  c60_2ndgen_biodem_noselect    = "R34M410-SSP2-NPi2025"
)

# ---- Factor 5, v2 arm: MAgPIE's own EAT-Lancet diet -------------------------

# ON = s15_exo_diet 3. Deliberately no c15_EAT_scen (inert here, and setting it
# would invite the 2500kcal trap documented in the header).
.diet_el <- list(
  s15_exo_diet                  = 3,
  c15_kcal_scen                 = "healthy_BMI",
  s15_exo_foodscen_start        = 2025,
  s15_exo_foodscen_target       = 2050,
  s15_exo_foodscen_convergence  = 1
)

# ---- composed scenario list -------------------------------------------------

# BAU is carried over byte-identical from the base config so the orchestrator
# resolves and SKIPS the existing BAU_TCendo run and reuses its gdx as the tau
# pin. It is never re-run by this arm.
FST_LEVERS_SCENARIOS <- list(

  BAU = .base_scenarios$BAU,

  FSTL2_CPon_BioOn_Prot_DietEL    = c(FST_BACKDROP, .cp_on, .bio_on, .prot_on,  .diet_el),
  FSTL2_CPon_BioOn_Prot_DietOff   = c(FST_BACKDROP, .cp_on, .bio_on, .prot_on,  .diet_off),
  FSTL2_CPon_BioOn_NoProt_DietEL  = c(FST_BACKDROP, .cp_on, .bio_on, .prot_off, .diet_el),
  FSTL2_CPon_BioOn_NoProt_DietOff = c(FST_BACKDROP, .cp_on, .bio_on, .prot_off, .diet_off),

  # ---- 2026-08-17 ESCALATION: the same 4 cells at 2.0C ----------------------
  # The 1.5C round above ran and ALL FOUR TCbau corners are infeasible, every one
  # at 2045 (last optimal 2040), every one on a JAPAN constraint - but no longer
  # the residue one, which is now clear:
  #   Prot_DietEL    q35_min_forest   JPN_51   short 0.0022 Mha
  #   Prot_DietOff   q60_bioenergy_reg JPN     short 11.3 mio GJ/yr
  #   NoProt_DietEL  q21_trade_reg    JPN.livst_rum  short 0.0004
  #   NoProt_DietOff q35_min_forest   JPN_51   short 0.0298 Mha
  # So the residue switch-off worked and Japan is simply out of land at 1.5C
  # bioenergy under frozen tau: the binding constraint walks along instead of
  # disappearing. Mike's instructed ladder is 1.5C -> 2.0C -> stop and discuss.
  # PkBudg1000 relieves the carbon price AND the bioenergy demand together, and
  # .cp_20 MUST be paired with .bio_20 (the coherence rule the hole enforces).
  # The 1.5C cells stay in this list so the orchestrator SKIPS them rather than
  # re-running them.
  FSTL2_CP20_BioOn_Prot_DietEL    = c(FST_BACKDROP, .cp_20, .bio_20, .prot_on,  .diet_el),
  FSTL2_CP20_BioOn_Prot_DietOff   = c(FST_BACKDROP, .cp_20, .bio_20, .prot_on,  .diet_off),
  FSTL2_CP20_BioOn_NoProt_DietEL  = c(FST_BACKDROP, .cp_20, .bio_20, .prot_off, .diet_el),
  FSTL2_CP20_BioOn_NoProt_DietOff = c(FST_BACKDROP, .cp_20, .bio_20, .prot_off, .diet_off),

  # ---- 2026-08-18 ROUND 3: Japan exempted from the DEDICATED ramp too -------
  # Mike's call after seeing the 1.5C result. The residue switch-off cleared
  # q60_res_2ndgenBE but the corner still failed, with the binding constraint
  # walking to Japan's dedicated bioenergy demand, its minimum-forest floor and a
  # trade balance. This arm asks the obvious follow-up: if Japan is exempted from
  # the 1.5C BECCS ramp ENTIRELY, does 1.5C solve under frozen tau?
  #
  # No model change needed - the dedicated channel has had a _noselect twin all
  # along, and scen_countries60 already excludes JPN, so this is purely a config
  # difference (see .bio_on_xjp). The bio token is BioOnXJP, a THIRD level of the
  # bioenergy factor, deliberately named so no consumer can mistake it for the
  # global BioOn arm: Japan is on baseline demand while everyone else ramps.
  FSTL3_CPon_BioOnXJP_Prot_DietEL    = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on,  .diet_el),
  FSTL3_CPon_BioOnXJP_Prot_DietOff   = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on,  .diet_off),
  FSTL3_CPon_BioOnXJP_NoProt_DietEL  = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off, .diet_el),
  FSTL3_CPon_BioOnXJP_NoProt_DietOff = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off, .diet_off),

  # ---- 2026-08-18 ROUND 4: the same four cells with NO model change ---------
  # The module-60 residue patch is reverted, so Japan's RESIDUE demand follows the
  # global ssp2 scenario again while its DEDICATED demand stays on NPi2025 through
  # the stock _noselect twin. This is the one rung of the feasibility ladder never
  # tested, and the decisive one:
  #
  #   Japan fully on ................. TCbau 0/4   FSTL2_CPon, pre-patch
  #   residue off, dedicated on ...... TCbau 0/4   FSTL2_CPon, post-patch
  #   residue off, dedicated off ..... TCbau 4/4   FSTL3
  #   residue ON,  dedicated off ..... this arm    <- untested
  #
  # If these four TCbau corners solve, the patch was never load-bearing and the
  # whole Japan exemption is pure config. If they do not, the patch has to return.
  #
  # The SWITCH SET here is byte-identical to FSTL3's - the difference lives in the
  # model source, not in cfg. Hence a distinct bio token (BioOnXJPded), so that no
  # downstream consumer can pool the two arms on switch equality alone.
  FSTL4_CPon_BioOnXJPded_Prot_DietEL    = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on,  .diet_el),
  FSTL4_CPon_BioOnXJPded_Prot_DietOff   = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on,  .diet_off),
  FSTL4_CPon_BioOnXJPded_NoProt_DietEL  = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off, .diet_el),
  FSTL4_CPon_BioOnXJPded_NoProt_DietOff = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off, .diet_off)
)

FST_LEVERS_TCBAU_SCENARIOS <- c(
  "FSTL2_CPon_BioOn_Prot_DietEL",   "FSTL2_CPon_BioOn_Prot_DietOff",
  "FSTL2_CPon_BioOn_NoProt_DietEL", "FSTL2_CPon_BioOn_NoProt_DietOff",
  "FSTL2_CP20_BioOn_Prot_DietEL",   "FSTL2_CP20_BioOn_Prot_DietOff",
  "FSTL2_CP20_BioOn_NoProt_DietEL", "FSTL2_CP20_BioOn_NoProt_DietOff",
  "FSTL3_CPon_BioOnXJP_Prot_DietEL",   "FSTL3_CPon_BioOnXJP_Prot_DietOff",
  "FSTL3_CPon_BioOnXJP_NoProt_DietEL", "FSTL3_CPon_BioOnXJP_NoProt_DietOff",
  "FSTL4_CPon_BioOnXJPded_Prot_DietEL",   "FSTL4_CPon_BioOnXJPded_Prot_DietOff",
  "FSTL4_CPon_BioOnXJPded_NoProt_DietEL", "FSTL4_CPon_BioOnXJPded_NoProt_DietOff"
)

# ---- design table -----------------------------------------------------------

# The diet factor gains a THIRD level, so - exactly as with the three-level
# climate factor - it can no longer be consumed by the binary 2^k machinery
# without an explicit level pin. v2 is a standalone 2^3 (prot x diet x TC) block
# at a fixed (cp=on, bio=on) corner, so it defines no cubes at all; any later
# merge with the 2026-08 batch must pin diet levels explicitly.
FST_LEVERS_TOKENS$diet <- c(FST_LEVERS_TOKENS$diet, DietEL = "el")
# A THIRD bioenergy level: the 1.5C ramp everywhere EXCEPT Japan. Named so that no
# consumer can silently pool it with the global BioOn arm - the two are not the
# same scenario, and any 2^k machinery must pin levels rather than assume binary.
FST_LEVERS_TOKENS$bio  <- c(FST_LEVERS_TOKENS$bio,  BioOnXJP = "on_xjp")
# A FOURTH bioenergy level: as BioOnXJP, but Japan is exempted from the DEDICATED
# ramp only - its residue demand follows the global scenario. Identical cfg to
# BioOnXJP; the two differ in the MODEL SOURCE, so they must never be pooled.
FST_LEVERS_TOKENS$bio  <- c(FST_LEVERS_TOKENS$bio,  BioOnXJPded = "on_xjp_ded")

FSTL2_DESIGN <- do.call(rbind, lapply(
  setdiff(names(FST_LEVERS_SCENARIOS), "BAU"),
  function(scen) {
    d <- parseCellName(sub("^FSTL[234]_", "", scen))
    d$scenario <- scen
    d
  }))

assertNoDuplicateSwitches()
