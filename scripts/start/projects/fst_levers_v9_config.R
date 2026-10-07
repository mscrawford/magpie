# ---- LINEAGE / STATUS -------------------------------------------------------
# The config of arm FSTL9 (written 2026-10-07):
#     THIS FILE -> fst_levers_v8_config.R -> v7 -> v6 -> v2 -> fst_levers_config.R
# See RIKEN/04-fst-levers/LINEAGE.md for which arm is current.
# -----------------------------------------------------------------------------
# fst_levers ARM 9 = ARM 8 with ONE change: the protection of environmental flows
# moves from the backdrop into the protection lever.
#
# WHY
# ---
# Mike, 2026-10-07: "Environmental Flows should be in the high pressure half, not
# low pressure." In FSTL7 and FSTL8 c42_env_flow_policy = "on" was backdrop in all
# 16 cells (the water setting of F. Beier's EAT-Lancet 2.0 runs), so both rows of
# the partners' 2 x 2 carried it. Protecting flows takes water from irrigation and
# so adds pressure on land, like land protection: it belongs to the row that has
# the protection. Asked how far the correction should reach, he chose the whole
# cube: the lever, not only the two low-pressure scenarios.
#
# WHAT CHANGES
# ------------
#   protection ON  : c42_env_flow_policy = "on"   (as in FSTL8: these cells are FSTL8's)
#   protection OFF : c42_env_flow_policy = "off"  (FSTL8: "on")
# c30_bioen_water = "all" stays backdrop in all cells and in the baseline. The s42
# years and fractions are still not set (defaults). The baseline is BAU8, unchanged:
# it never set the policy, and its tau path stays the pin.
#
# WHICH RUNS ARE NEW
# ------------------
# Ten: the four protection-OFF cells and FSTL9P_LowPressure, each with endogenous
# and with frozen tau. The other ten titles of this arm (the four protection-ON
# cells and FSTL9P_HighPressure) have, switch for switch, the config of their FSTL8
# namesakes. They are NOT solved again: RIKEN's analysis/link_fstl9_reused_runs.sh
# links output/FSTL9*_<...> to the finished FSTL8 folders, and the orchestrator
# skips a title whose run is complete. The test of this file checks both halves.
#
# NEVER launch this file without those links in place: the orchestrator would then
# solve the ten unchanged runs as well.

source(Sys.getenv("FST_LEVERS_V8_CONFIG", "scripts/start/projects/fst_levers_v8_config.R"))
if (nzchar(Sys.getenv("FSTL8_BAU_ONLY")) || nzchar(Sys.getenv("FSTL7_BAU_ONLY")))
  stop("a BAU_ONLY switch of an earlier layer is set: this arm would get a cube without cells. Unset it.")

# The key is REPLACED where the v7 backdrop put it, never appended: one key, one value.
.with_flows <- function(block, policy) {
  stopifnot("c42_env_flow_policy" %in% names(block), sum(names(block) == "c42_env_flow_policy") == 1L)
  block$c42_env_flow_policy <- policy
  block
}
.prot9 <- grepl("_Prot_", names(.fstl8))
stopifnot(sum(.prot9) == 4L, sum(grepl("_NoProt_", names(.fstl8))) == 4L)
.fstl9 <- stats::setNames(
  Map(function(block, on) .with_flows(block, if (on) "on" else "off"), .fstl8, .prot9),
  sub("^FSTL8_", "FSTL9_", names(.fstl8)))

.partner9 <- list(
  FSTL9P_HighPressure = c(.fstl9$FSTL9_CPon_BioOnXJPded_Prot_DietOff, .interest("0.1")),
  FSTL9P_LowPressure  = c(.fstl9$FSTL9_CPon_BioNone_NoProt_DietEL,    .interest("0.04"))
)
stopifnot(!vapply(.partner9, function(b) is.null(b$c56_pollutant_prices), logical(1)))

FST_LEVERS_BAU             <- "BAU8"
FST_LEVERS_SCENARIOS       <- c(.bau8, .fstl9, .partner9)
FST_LEVERS_TCBAU_SCENARIOS <- c(names(.fstl9), names(.partner9))

# The design table is the CUBE's; the partner runs are named, not parsed.
FSTL2_DESIGN <- do.call(rbind, lapply(
  names(.fstl9),
  function(scen) {
    d <- parseCellName(sub("^FSTL[2-9]_", "", scen))
    d$scenario <- scen
    d
  }))

assertNoDuplicateSwitches()
