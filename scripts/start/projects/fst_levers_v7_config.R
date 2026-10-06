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
#      BII                     no net loss: c44_bii_decrease 0, no net loss from 2030,
#                              no target, from HIS first free    THIS experiment's first
#                              step, 2020 (see below)            free step
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
#    any lever of this cube acts (his ramp over two steps); the dietary shift
#    ramps to 2050.
#
#    CORRECTED 2026-10-06 (audit): his script writes s44_start_year <- 2030, but
#    the setScenario("fix_2020") call AFTER that line resets it to 2020, so his
#    no-net-loss bound applies from 2020, his first free step. This arm's 2030 is
#    its own first free step (module 44 aborts on a start year <= 2025), so the
#    behaviour matches; "the same start year" would not be a true description.
#
#    NOT taken from that script: its run set-up (no climate change impacts, its
#    own calibration, sticky factor costs, marginal-land and yield-calibration
#    switches). Those describe his paper's baseline, not the protection lever.
#
#    His more recent script, paper_MitiConsv.R (2025-07-01), has a single area
#    instrument (c22_protect_scenario BH or KBA) and no BII or SNV instrument. It
#    is a narrower lever than this experiment's "protection", so it was not taken.
#
#    ENVIRONMENTAL FLOWS LEAVE THE LEVER; see 2.
#
# 2. WATER IN THE TRANSFORMATION BACKDROP (Mike, 2026-10-06: in the transformation
#    scenario, environmental flow protection on and irrigated bioenergy allowed,
#    aligned with F. Beier's EAT-Lancet 2.0 SSP1 runs).
#
#    Her runs never set these per scenario: the environmental-flow policy comes from
#    the SSP column of config/scenario_config.csv ("on" for SSP1, "off" for SSP2) and
#    c30_bioen_water = "all" from her project preset, in every run. Read from the 81
#    run configs of her Deep Dive release (January 2025,
#    /p/projects/magpie/users/beier/EL2_DeepDive_release_v3/magpie/output), the SSP1
#    runs carry
#        c42_env_flow_policy on, s42_efp_startyear 2025, s42_efp_targetyear 2040,
#        s42_env_flow_scenario 2, s42_env_flow_fraction 0.2,
#        s42_env_flow_base_fraction 0.05, c30_bioen_water all,
#    and all but the first and the last are this model's defaults. So ALL 16 cells
#    here set c42_env_flow_policy = "on" and c30_bioen_water = "all" and no s42 key;
#    the policy fades in from 2025 and is complete in 2040 (FSTL5 and FSTL6 had it
#    inside the protection lever, complete in 2050).
#
#    Consequences to keep in view:
#      * it is BACKDROP: on in protection-ON and protection-OFF cells alike, so the
#        protection effect contains no water instrument;
#      * BAU7 keeps the SSP2 values (policy off, bioenergy rainfed). Her own BAU runs
#        carry c30_bioen_water = "all" as well; here BAU7 was already solving when
#        this was decided, and Mike's instruction named the transformation scenario;
#      * irrigated bioenergy is now allowed in the bioenergy-ON cells (inert where
#        the dedicated demand is zero), which FSTL6 did not allow;
#      * NOT taken: s42_watdem_nonagr_scenario = 1, the other value in which her SSP1
#        runs differ from her SSP2 runs. It is SSP1's non-agricultural water demand,
#        a socio-economic driver, and this experiment is SSP2 throughout.
#
# 3. THE MODEL. Merged upstream/develop dfe14e834: input data rev4.131 -> rev4.136,
#    a new land conversion cost calibration (cropland and pasture), observation-based
#    forest growth curves, GAMI age classes, grassland-corrected potential forest,
#    NPI/NDC bounds that follow their targets. Module 44 is unchanged; module 22
#    gained three IPLC scenario names; module 29's tree-cover carbon density reads
#    the renamed growth-curve parameter.
#    The audit of 2026-10-06 read the rest of the merge (its reading, not re-derived
#    here): NPI forest floors now FALL after the last observed year (the floor under
#    the BAU and every protection-OFF cell); one observation-based forest growth
#    curve, faster in the first decades, which moves afforestation against bioenergy
#    under the carbon price; potential forest about 27 % smaller; part of forestry
#    becomes a harvestable "other planted" pool, whose cutting lowers BII and so
#    meets the no-net-loss bound; pasture expansion dearer in seven regions; a
#    sticky cost on timber harvest; soil-carbon emission variables not comparable
#    across the merge; a 900 s limit per solve (main.gms reslim), after which a step
#    can end at solver status 7.
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
# analysis/verify_arm.R gates on both.
#
# MEASURED IN THIS ARM (2026-10-06, while it was solving): the bound is NOT fully
# met here either. In FSTL7_CPon_BioOnXJPded_Prot_DietEL_TCendo the penalty is 5.5
# bn USD/yr in 2050 and 71 bn in 2070 (1.1 % of total cost; 21 of 140 region-biomes
# short, two European ones most), against 582 to 1,725 bn in 2050 under the August
# floor. And because the bound restarts each step from the level just reached, a
# shortfall once paid is not made up later. Numbers and Mike's decision:
# RIKEN/04-fst-levers/LINEAGE.md.
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

# ---- Backdrop, v7 level: water as in the EAT-Lancet 2.0 SSP1 runs ------------
# In every cell. The s42 years and fractions are deliberately not set: the
# defaults are her values, and a key set here could drift from them.
.water_el2 <- list(
  c42_env_flow_policy = "on",
  c30_bioen_water     = "all"
)
FST_BACKDROP_V7 <- c(FST_BACKDROP, .water_el2)

# ---- Factor 2, v7 level: the BIOS bundle ------------------------------------
# Written out in full, not derived from .prot_on, so that nothing of the earlier
# bundle can come through by inheritance. Both blocks set the SAME keys; the
# factor toggles the scenario, the SNV share and the BII switch, and nothing else.
# No c42 key in either block: environmental flows are backdrop (above), not lever.
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
  FSTL7_CPon_BioOnXJPded_Prot_DietEL    = c(FST_BACKDROP_V7, .cp_on, .bio_on_xjp, .prot_on_v7,  .diet_el),
  FSTL7_CPon_BioOnXJPded_Prot_DietOff   = c(FST_BACKDROP_V7, .cp_on, .bio_on_xjp, .prot_on_v7,  .diet_off),
  FSTL7_CPon_BioOnXJPded_NoProt_DietEL  = c(FST_BACKDROP_V7, .cp_on, .bio_on_xjp, .prot_off_v7, .diet_el),
  FSTL7_CPon_BioOnXJPded_NoProt_DietOff = c(FST_BACKDROP_V7, .cp_on, .bio_on_xjp, .prot_off_v7, .diet_off),
  FSTL7_CPon_BioNone_Prot_DietEL        = c(FST_BACKDROP_V7, .cp_on, .bio_none,   .prot_on_v7,  .diet_el),
  FSTL7_CPon_BioNone_Prot_DietOff       = c(FST_BACKDROP_V7, .cp_on, .bio_none,   .prot_on_v7,  .diet_off),
  FSTL7_CPon_BioNone_NoProt_DietEL      = c(FST_BACKDROP_V7, .cp_on, .bio_none,   .prot_off_v7, .diet_el),
  FSTL7_CPon_BioNone_NoProt_DietOff     = c(FST_BACKDROP_V7, .cp_on, .bio_none,   .prot_off_v7, .diet_off)
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
