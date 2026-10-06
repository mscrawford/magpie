# ---- LINEAGE / STATUS -------------------------------------------------------
# CURRENT ENTRY POINT (as of 2026-10-06). Top of the stack:
#     THIS FILE -> fst_levers_v6_config.R -> fst_levers_v2_config.R -> fst_levers_config.R
# All four are live. Run the orchestrator against this file.
# See RIKEN/04-fst-levers/LINEAGE.md for which arm is current.
# -----------------------------------------------------------------------------
# fst_levers ARM 7: FSTL6's 2^4 cube, with the protection lever set as the author
# of the conservation and biodiversity modules sets it, and the model on
# upstream/develop of 2026-10-05.
#
# WHAT THIS ARM CHANGES
# ---------------------
# 1. THE PROTECTION LEVER (Mike, 2026-10-06: parameterise it after the people who
#    know the process; take P. v. Jeetze's most recent bundle).
#
#    FSTL5 and FSTL6 carried a bundle assembled here: GSN_HalfEarth with restoration,
#    a BII floor of 0.78 by 2050, 20 % semi-natural vegetation and environmental
#    flows, all on a 2025 -> 2050 schedule. The floor's target year had been moved
#    from the default 2100 for schedule symmetry and nobody tested whether it can be
#    met. It cannot: in the eight FSTL6 protection-ON runs the penalty for the
#    missing BII is 582 to 1,725 bn USD/yr in 2050, 7 to 10 % of the cost total
#    (report.mif, World), and no upstream script sets a 2050 BII target year or
#    GSN_HalfEarth.
#
#    This arm uses the "BIOS" bundle of scripts/start/projects/paper_healthyLscps.R
#    (P. v. Jeetze, 2024-09-18), his most recent script that combines several
#    protection instruments:
#
#      instrument              paper_healthyLscps.R              here
#      area-based conservation 30by30, 2020 -> 2030             30by30, 2025 -> 2030
#      BII                     no net loss: c44_bii_decrease 0, the same
#                              s44_start_year 2030, no target
#      semi-natural vegetation s29_snv_shr 0.2, 2020 -> 2030     0.2, 2025 -> 2030
#      SNV land types          secdforest, other                the same (the default)
#      restoration             not set (default 1)              1
#      environmental flows     not set (default off)            not set (default off)
#
#    The ONE translation is the start year. His script fixes history to 2020
#    (setScenario "fix_2020", config/projects/scenario_config_year_fix.csv) and
#    starts every instrument there; this experiment runs on the model's default,
#    history fixed to 2025, and that file's own "fix_2025" column starts the same
#    instruments in 2025. The target year, 2030, is his. So the instruments are
#    still at zero in 2025 and at full strength in 2030, the first step in which
#    any lever of this cube acts; the dietary shift ramps to 2050.
#
#    NOT taken from that script: its run set-up (no climate change impacts, its
#    own calibration, sticky factor costs, marginal-land and yield-calibration
#    switches). Those describe his paper's baseline, not the protection lever.
#
#    His more recent script, paper_MitiConsv.R (2025-07-01), has a single area
#    instrument (c22_protect_scenario BH or KBA) and no BII or SNV instrument. It
#    is a narrower lever than this experiment's "protection", so it was not taken.
#
#    ENVIRONMENTAL FLOWS LEAVE THE LEVER. They are not part of his bundle, so
#    protection no longer acts on water withdrawals directly.
#
# 2. THE MODEL. Merged upstream/develop dfe14e834: input data rev4.131 -> rev4.136,
#    a new land conversion cost calibration (cropland and pasture), observation-based
#    forest growth curves, GAMI age classes, grassland-corrected potential forest,
#    NPI/NDC bounds that follow their targets. Module 44 is unchanged; module 22
#    gained three IPLC scenario names; module 29's tree-cover carbon density now reads
#    the calibrated growth curves.
#
# Both change at once, so FSTL7 against FSTL6 does NOT isolate either. Mike chose
# this over a pinned-code twin of the eight protection-ON runs (2026-10-06).
#
# HOW THE BII LIMB ACTS
# ---------------------
# It is toggled by c44_bii_decrease (0 vs 1); s44_bii_target is 0 in both arms.
# With the switch at 0, module 44's presolve sets each region-biome's lower bound
# to its own BII of the previous timestep, from s44_start_year on:
#     if(c44_bii_decrease = 0,
#       p44_bii_target(t,i,biome44)$(v44_bii.l(i,biome44) >= p44_bii_target(t,i,biome44))
#         = v44_bii.l(i,biome44); );
# That branch has NO `s44_bii_target > 0` guard, so the switch must stay 1 where
# protection is off. It is a per-step ratchet (default.cfg describes a start-year
# bound; the difference is one of two code points raised with the module author on
# 2026-10-06, and module 44 is not to be patched here without him). The bound is
# soft: a shortfall is priced through v44_bii_missing at s44_cost_bii_missing.
# READ ov44_bii_missing AND ov_cost_bv_loss FIRST in these runs;
# analysis/verify_fstl7.R gates on both.
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

# ---- Factor 2, v7 level: the BIOS bundle ------------------------------------
# Written out in full, not derived from .prot_on, so that nothing of the earlier
# bundle can come through by inheritance. Both blocks set the SAME keys; the
# factor toggles the scenario, the SNV share and the BII switch, and nothing else.
# No c42 key in either block: environmental flows stay at the default, off.
# _noselect twins as in the base config (zero weight while all countries are
# selected, load-bearing the moment anyone narrows the country set).
.prot_on_v7 <- list(
  c22_protect_scenario          = "30by30",
  c22_protect_scenario_noselect = "30by30",
  s22_conservation_start        = 2025,
  s22_conservation_target       = 2030,
  s22_restore_land              = 1,
  s44_bii_target                = 0,
  s44_start_year                = 2030,
  c44_bii_decrease              = 0,
  s29_snv_shr                   = 0.2,
  s29_snv_shr_noselect          = 0.2,
  s29_snv_scenario_start        = 2025,
  s29_snv_scenario_target       = 2030
)

.prot_off_v7 <- list(
  c22_protect_scenario          = "none",
  c22_protect_scenario_noselect = "none",
  s22_conservation_start        = 2025,
  s22_conservation_target       = 2030,
  s22_restore_land              = 1,
  s44_bii_target                = 0,
  s44_start_year                = 2030,
  c44_bii_decrease              = 1,
  s29_snv_shr                   = 0,
  s29_snv_shr_noselect          = 0,
  s29_snv_scenario_start        = 2025,
  s29_snv_scenario_target       = 2030
)

.fstl7 <- list(
  FSTL7_CPon_BioOnXJPded_Prot_DietEL    = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on_v7,  .diet_el),
  FSTL7_CPon_BioOnXJPded_Prot_DietOff   = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on_v7,  .diet_off),
  FSTL7_CPon_BioOnXJPded_NoProt_DietEL  = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off_v7, .diet_el),
  FSTL7_CPon_BioOnXJPded_NoProt_DietOff = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off_v7, .diet_off),
  FSTL7_CPon_BioNone_Prot_DietEL        = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_on_v7,  .diet_el),
  FSTL7_CPon_BioNone_Prot_DietOff       = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_on_v7,  .diet_off),
  FSTL7_CPon_BioNone_NoProt_DietEL      = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_off_v7, .diet_el),
  FSTL7_CPon_BioNone_NoProt_DietOff     = c(FST_BACKDROP, .cp_on, .bio_none,   .prot_off_v7, .diet_off)
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
