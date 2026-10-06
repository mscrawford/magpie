# ---- LINEAGE / STATUS -------------------------------------------------------
# CURRENT ENTRY POINT (as of 2026-10-06). Top of the stack:
#     THIS FILE -> fst_levers_v6_config.R -> fst_levers_v2_config.R -> fst_levers_config.R
# All four are live. Run the orchestrator against this file.
# See RIKEN/04-fst-levers/LINEAGE.md for which arm is current.
# -----------------------------------------------------------------------------
# fst_levers ARM 7: FSTL6's 2^4 cube, with the protection lever's BII instrument
# reset and the model on upstream/develop of 2026-10-05.
#
# WHAT THIS ARM CHANGES
# ---------------------
# 1. THE BII INSTRUMENT. FSTL5 and FSTL6 carried a numeric floor, s44_bii_target
#    0.78 by 2050 with c44_bii_decrease 1. The target year had been moved from the
#    default 2100 to 2050 for schedule symmetry with the other levers, and nobody
#    tested whether the floor can be met. It cannot. Measured in the eight FSTL6
#    protection-ON runs (report.mif, World): the penalty for the missing BII is 582
#    to 1,725 bn USD/yr in 2050, 7 to 10 % of the cost total, and in
#    FSTL6_CPon_BioOnXJPded_Prot_DietOff_TCendo 46 region-biomes sit below the floor
#    in 2050 and 36 in 2100. Restored non-forest land scores 0.776, under 0.78, so a
#    non-forest region-biome cannot reach the floor by restoration at all.
#
#    This arm uses "no net nature loss from 2030" instead (Mike, 2026-10-06):
#    c44_bii_decrease = 0, s44_start_year = 2030, no target value. It is the setting
#    of the module author's own bundle in scripts/start/projects/paper_healthyLscps.R
#    (actions BIOS / noNatureLoss2030), which is built like this protection lever:
#    area-based conservation, no net loss, 20 % semi-natural vegetation.
#
# 2. THE MODEL. Merged upstream/develop dfe14e834: input data rev4.131 -> rev4.136,
#    a new land conversion cost calibration (cropland and pasture), observation-based
#    forest growth curves, GAMI age classes, grassland-corrected potential forest,
#    NPI/NDC bounds that follow their targets. Module 44 is unchanged by the merge.
#
# Both change at once, so FSTL7 against FSTL6 does NOT isolate either. Mike chose
# this over a pinned-code twin of the eight protection-ON runs (2026-10-06).
#
# WHAT THE LEVER TOGGLES NOW
# --------------------------
# The BII limb of the protection factor is c44_bii_decrease (0 vs 1), no longer
# s44_bii_target (which is 0 in both arms). With the switch at 0, module 44's
# presolve sets each region-biome's lower bound to its own BII of the previous
# timestep, from s44_start_year on:
#     if(c44_bii_decrease = 0,
#       p44_bii_target(t,i,biome44)$(v44_bii.l(i,biome44) >= p44_bii_target(t,i,biome44))
#         = v44_bii.l(i,biome44); );
# That is a per-step ratchet (default.cfg describes a start-year bound; the
# difference is one of two code points raised with the module author on
# 2026-10-06, and module 44 is not to be patched here without him). The bound is
# still soft: a shortfall is priced through v44_bii_missing at s44_cost_bii_missing.
# In the fragmentation project's develop pair (SSP1, one run) the penalty stayed
# under 1 bn USD/yr. READ ov44_bii_missing AND ov_cost_bv_loss FIRST in these runs;
# analysis/verify_fstl7.R gates on both.
#
# s44_target_year stays in both protection blocks and is INERT here: module 44 only
# reads it inside `if (m_year(t) = s44_start_year AND s44_bii_target > 0, ...)`.
#
# THE BAU TAU PIN IS NEW
# ----------------------
# Every earlier arm pinned the frozen-tau runs to BAU_TCendo of 2026-06-20, solved
# on rev4.131 data at 70be7fccf. That gdx is not a valid pin for runs on rev4.136:
# the calibration and the yields moved. This arm solves its own BAU, "BAU7", with
# the same switches, and names it in FST_LEVERS_BAU so the orchestrator pins to it.
# BAU_TCendo is deliberately NOT in this arm's scenario list.
#
# FSTL7_BAU_ONLY=1 restricts the arm to BAU7 alone. That is the revalidation gate
# after a develop merge: BAU must solve before sixteen runs are queued behind it.

source(Sys.getenv("FST_LEVERS_V6_CONFIG", "scripts/start/projects/fst_levers_v6_config.R"))

# ---- Factor 2, v7 level: the bundle with no net nature loss -----------------
# Everything but the BII limb is .prot_on, unchanged: GSN_HalfEarth with
# restoration, SNV 20 %, environmental flows, all on the 2025 -> 2050 schedule.
.prot_on_nnl <- utils::modifyList(.prot_on, list(
  s44_bii_target   = 0,
  c44_bii_decrease = 0
))

.fstl7 <- list(
  FSTL7_CPon_BioOnXJPded_Prot_DietEL    = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on_nnl, .diet_el),
  FSTL7_CPon_BioOnXJPded_Prot_DietOff   = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on_nnl, .diet_off),
  FSTL7_CPon_BioOnXJPded_NoProt_DietEL  = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off,    .diet_el),
  FSTL7_CPon_BioOnXJPded_NoProt_DietOff = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off,    .diet_off),
  FSTL7_CPon_BioNone_Prot_DietEL        = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_on_nnl, .diet_el),
  FSTL7_CPon_BioNone_Prot_DietOff       = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_on_nnl, .diet_off),
  FSTL7_CPon_BioNone_NoProt_DietEL      = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_off,    .diet_el),
  FSTL7_CPon_BioNone_NoProt_DietOff     = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_off,    .diet_off)
)

# The BAU switches are the base config's, carried over unchanged (v2 and v6 pass
# them through), under a new name so the run title is BAU7_TCendo.
FST_LEVERS_BAU <- "BAU7"
.bau7 <- stats::setNames(list(FST_LEVERS_SCENARIOS$BAU), FST_LEVERS_BAU)

FST_LEVERS_SCENARIOS       <- c(.bau7, .fstl7)
FST_LEVERS_TCBAU_SCENARIOS <- names(.fstl7)

if (nzchar(Sys.getenv("FSTL7_BAU_ONLY"))) {
  FST_LEVERS_SCENARIOS       <- .bau7
  FST_LEVERS_TCBAU_SCENARIOS <- character(0)
}

FSTL2_DESIGN <- do.call(rbind, lapply(
  setdiff(names(FST_LEVERS_SCENARIOS), FST_LEVERS_BAU),
  function(scen) {
    d <- parseCellName(sub("^FSTL[234567]_", "", scen))
    d$scenario <- scen
    d
  }))

assertNoDuplicateSwitches()
