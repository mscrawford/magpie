# ---- LINEAGE / STATUS -------------------------------------------------------
# CURRENT ENTRY POINT (as of 2026-08-18). Top of the stack:
#     THIS FILE -> fst_levers_v2_config.R -> fst_levers_config.R
# All three are live. Run the orchestrator against this file.
# See RIKEN/04-fst-levers/LINEAGE.md for which arm is current.
# -----------------------------------------------------------------------------
# fst_levers ARM 5: the first arm in which the BII target actually works.
#
# WHY THIS ARM EXISTS
# -------------------
# Every run before 2026-08-18 carried s44_start_year = 2026. Module 44 builds its
# target inside
#     if (m_year(t) = s44_start_year AND s44_bii_target > 0, ... )
# an EXACT timestep match. 2026 satisfies the module's abort guard
# (s44_start_year > sm_fix_SSP2 = 2025) but is not on the timestep grid
# (...2020, 2025, 2030...), so the block never fired. Measured in the FSTL3 gdx:
# p44_bii_target nonzero in 0 of 15336 entries, total shortfall exactly 0.0000,
# vm_cost_bv_loss never accrued. The BII floor in the "protection" bundle was
# INERT, so protection meant GSN Half-Earth + 20% SNV + environmental flows and
# nothing else. The base config now sets 2030 (a timestep AND > 2025), verified
# against the old batch where 2030 gives 1540 nonzero entries and a 0.76 shortfall.
#
# Every other lever already started in 2030 and is unchanged. Their 2025 values are
# interpolation ANCHORS where the fader is zero, not first-effect years; measured
# first divergence is 2030 for the carbon price (3.67 -> 750.0 USD/tC), the diet
# (-24.3 kcal) and protection (+5.69 Mha cropland).
#
# WHY IT IS A SEPARATE FILE, NOT A FIFTH BLOCK IN THE v2 CONFIG
# -------------------------------------------------------------
# The orchestrator sets cfg$force_replace = TRUE and skips only runs that are
# COMPLETE (runstatistics.rda carrying a modelstat). A run that is still SOLVING
# looks incomplete, so relaunching a config that names it would DELETE its live
# folder. FSTL4 was still solving when this arm was launched. Restricting
# FST_LEVERS_SCENARIOS to BAU plus this arm's own four cells makes that impossible
# by construction rather than by remembering to be careful.
#
# BAU is carried over byte-identical so the orchestrator resolves and SKIPS the
# existing BAU_TCendo run and reuses its gdx as the Phase 2 tau pin.

source(Sys.getenv("FST_LEVERS_V2_CONFIG", "scripts/start/projects/fst_levers_v2_config.R"))

# Same 2^3 design and the same switches as FSTL4 (stock model, Japan exempted from
# the DEDICATED bioenergy ramp only, MAgPIE's own EAT-Lancet diet). The ONLY
# difference is that .prot_on now carries a working BII target, which comes from
# the base config rather than from anything set here.
.fstl5 <- list(
  FSTL5_CPon_BioOnXJPded_Prot_DietEL    = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on,  .diet_el),
  FSTL5_CPon_BioOnXJPded_Prot_DietOff   = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_on,  .diet_off),
  FSTL5_CPon_BioOnXJPded_NoProt_DietEL  = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off, .diet_el),
  FSTL5_CPon_BioOnXJPded_NoProt_DietOff = c(FST_BACKDROP, .cp_on, .bio_on_xjp, .prot_off, .diet_off)
)

FST_LEVERS_SCENARIOS       <- c(list(BAU = FST_LEVERS_SCENARIOS$BAU), .fstl5)
FST_LEVERS_TCBAU_SCENARIOS <- names(.fstl5)

FSTL2_DESIGN <- do.call(rbind, lapply(
  setdiff(names(FST_LEVERS_SCENARIOS), "BAU"),
  function(scen) {
    d <- parseCellName(sub("^FSTL[2345]_", "", scen))
    d$scenario <- scen
    d
  }))

assertNoDuplicateSwitches()
