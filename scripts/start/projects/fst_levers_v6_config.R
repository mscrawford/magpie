# ---- LINEAGE / STATUS -------------------------------------------------------
# CURRENT ENTRY POINT (as of 2026-08-18). Top of the stack:
#     THIS FILE -> fst_levers_v2_config.R -> fst_levers_config.R
# All three are live. Run the orchestrator against this file.
# See RIKEN/04-fst-levers/LINEAGE.md for which arm is current.
# -----------------------------------------------------------------------------
# fst_levers ARM 6: the hydrogen counterfactual. FSTL5 plus a bioenergy face.
#
# WHAT THIS ARM ADDS
# ------------------
# FSTL5 is a 2^3 {protection x diet x TC} cube at 1.5C in which the 2nd-generation
# bioenergy demand is a HELD-CONSTANT BACKDROP. This arm promotes it to a binary
# factor and so completes the 2^4 cube:
#
#     bioenergy {BioOnXJPded, BioNone} x protection x diet x TC = 16 runs
#
# WP4 motivation: energy-side innovation (cheaper hydrogen) that meets the energy
# system's bioenergy service some other way, so the land system is never asked to
# supply it. BioNone is that world; BioOnXJPded is FSTL5's world, unchanged.
#
# The factor is large. Measured in FSTL5_CPon_BioOnXJPded_Prot_DietOff_TCbau
# (report.mif, World): dedicated bioenergy croparea 32 Mha (2030) -> 329 Mha (2050)
# -> 350 Mha (2100), against a total cropland of 1531 / 1754 / 2127 Mha. Bioenergy
# is 19% of global cropland in 2050, so this is very likely the largest single land
# pressure in the cube.
#
# WHAT THIS ARM IS NOT: A SELF-CONSISTENT SCENARIO
# ------------------------------------------------
# c56_pollutant_prices and c60_2ndgen_biodem are the price-side and land-side
# images of ONE coupled REMIND solution, and the base config (Factor 3 header)
# makes pairing them mandatory. This arm BREAKS that pair ON PURPOSE: the 1.5C
# carbon price is held at R34M410-SSP2-PkBudg650 while the bioenergy ask goes to
# zero. MAgPIE cannot check that the energy system still reaches 1.5C without that
# bioenergy - in REMIND the missing BECCS would move the price path - so the WP4
# substitution is ASSUMED here, not tested.
#
# These runs therefore answer "what is the land-side burden of the bioenergy ask,
# at a 1.5C carbon price", NOT "1.5C is achievable without bioenergy". Endogenising
# it belongs in the coupled REMIND work. Precedent: the 25-run design already KEPT
# (climate-on, bio-off) as a labelled counterfactual for exactly this reason.
#
# WHY IT IS A SEPARATE FILE, NOT A FIFTH BLOCK IN THE v5 CONFIG
# -------------------------------------------------------------
# Same reason v5 was: the orchestrator sets cfg$force_replace = TRUE and skips only
# runs that are COMPLETE (runstatistics.rda carrying a modelstat). A run that is
# still SOLVING looks incomplete, so relaunching a config that names it would DELETE
# its live folder. Restricting FST_LEVERS_SCENARIOS to BAU plus this arm's own eight
# cells makes that impossible by construction rather than by remembering to care.
#
# BAU is carried over byte-identical so the orchestrator resolves and SKIPS the
# existing BAU_TCendo run and reuses its gdx as the Phase 2 tau pin.
#
# NO MODEL CODE CHANGES. Every switch below is stock MAgPIE. The clone is on the
# same model code FSTL5 ran against, which is what makes this arm's BioOnXJPded
# face a valid regression check against the FSTL5 deliverable.

source(Sys.getenv("FST_LEVERS_V2_CONFIG", "scripts/start/projects/fst_levers_v2_config.R"))

# ---- Factor 3, v6 level: the land system supplies no dedicated bioenergy ----
#
# "none" is a COMPILE-TIME branch, modules/60_bioenergy/1st2ndgen_priced_feb24/
# preloop.gms:23-24, which sets i60_bioenergy_dem(t,i) = 0 and then re-harmonizes
# t <= sm_fix_SSP2 (= 2025) back to R34M410-SSP2-NPi2025. So HISTORY IS UNCHANGED
# and only the future is zeroed. That is why this level is comparable with every
# other run in the project, and it is the reason the residue channel is NOT part
# of this factor: c60_res_2ndgenBE_dem = "off" would zero the historical period too
# (presolve.gms:31-34, "set the residue demand to off for the whole period"), which
# would make the two bioenergy levels differ in 1995-2025.
#
# Scope of the factor, stated so nobody has to re-derive it:
#   * dedicated 2nd-gen (betr, begr) - ZEROED here. ~98 of the ~116 EJ/yr of 2nd-gen
#     demand at 2050, and ALL 329 Mha of the bioenergy cropland.
#   * residues (kres) - unchanged at "ssp2". ~18 EJ/yr, essentially no land, a
#     byproduct of food crops already grown.
#   * 1st generation (oils, ethanol) - unchanged. c60_1stgen_biodem has no "none"
#     value at all; even "phaseout2020" only reaches zero in 2070.
#
# The "none" branch keys on the SELECTED switch ONLY, so _noselect and
# scen_countries60 are both bypassed and the Japan carve-out is vacuous here (there
# is no demand anywhere to exempt Japan from). _noselect is still set, to the same
# value .bio_on_xjp uses, so the two bio atoms diff in exactly the switches that
# act. It must stay a real member of scen2nd60: "none" is NOT one, and putting it
# here would be an invalid set element rather than a switch-off.
#
# s60_2ndgen_bioenergy_dem_min MUST go to 0. presolve.gms:64 floors
# i60_bioenergy_dem at 1 mio GJ per region ("to avoid zero prices"), so "none" on
# its own leaves ~12 mio GJ/yr globally rather than zero. Precedent for zeroing it:
# scripts/start/extra/emulator.R, GENIE_2_bm-priced.R, GENIE_3_bm-demand.R.
.bio_none <- list(
  c60_2ndgen_biodem             = "none",
  c60_2ndgen_biodem_noselect    = "R34M410-SSP2-NPi2025",
  s60_2ndgen_bioenergy_dem_min  = 0
)

# The BioOnXJPded cells are FSTL5's four cells with only the prefix changed, so
# they must reproduce the FSTL5 deliverable exactly. They are the regression check
# on this arm, not filler. Note they deliberately do NOT set
# s60_2ndgen_bioenergy_dem_min: it stays at its default of 1, which is what FSTL5
# ran with and is inert against ~98 EJ/yr. The asymmetry with .bio_none is the
# point - it keeps this face switch-identical to FSTL5.
.fstl6 <- list(
  FSTL6_CPon_BioOnXJPded_Prot_DietEL    = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on,  .diet_el),
  FSTL6_CPon_BioOnXJPded_Prot_DietOff   = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on,  .diet_off),
  FSTL6_CPon_BioOnXJPded_NoProt_DietEL  = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off, .diet_el),
  FSTL6_CPon_BioOnXJPded_NoProt_DietOff = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off, .diet_off),
  FSTL6_CPon_BioNone_Prot_DietEL        = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_on,  .diet_el),
  FSTL6_CPon_BioNone_Prot_DietOff       = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_on,  .diet_off),
  FSTL6_CPon_BioNone_NoProt_DietEL      = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_off, .diet_el),
  FSTL6_CPon_BioNone_NoProt_DietOff     = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_off, .diet_off)
)

# A NEW bio token, not a reuse. BioOff is already registered in the base config and
# means "NPi2025 everywhere" - a baseline demand, not zero. Conflating the two would
# silently pool this arm with iteration 1 and 2 runs that mean something else.
FST_LEVERS_TOKENS$bio <- c(FST_LEVERS_TOKENS$bio, BioNone = "none")

FST_LEVERS_SCENARIOS       <- c(list(BAU = FST_LEVERS_SCENARIOS$BAU), .fstl6)
FST_LEVERS_TCBAU_SCENARIOS <- names(.fstl6)

FSTL2_DESIGN <- do.call(rbind, lapply(
  setdiff(names(FST_LEVERS_SCENARIOS), "BAU"),
  function(scen) {
    d <- parseCellName(sub("^FSTL[23456]_", "", scen))
    d$scenario <- scen
    d
  }))

assertNoDuplicateSwitches()
