# ---- LINEAGE / STATUS -------------------------------------------------------
# RUN on 2026-10-06 as arm FSTL8 (21 runs at commit 44e0e322c). Since 2026-10-07 also the layer
# under fst_levers_v9_config.R (arm FSTL9). The config of the runs after arm FSTL7:
#     THIS FILE -> fst_levers_v7_config.R -> v6 -> v2 -> fst_levers_config.R
# See RIKEN/04-fst-levers/LINEAGE.md for which arm is current.
# -----------------------------------------------------------------------------
# fst_levers ARM 8 = ARM 7 with TWO changes: the BAU allows irrigated bioenergy too,
# and four runs are added for the partners' 2 x 2 (below, "THE PARTNER 2 x 2").
#
# WHY
# ---
# FSTL7 sets c30_bioen_water = "all" in its 16 transformation cells (the setting of
# F. Beier's EAT-Lancet 2.0 runs) and leaves its BAU, BAU7, at the SSP2 value
# "rainfed". Her own BAU runs carry "all". Mike, 2026-10-06: the difference between
# BAU and transformation "might be poorly aligned ... change it for the next runs".
#
# The BAU matters in two places: it is the context line beside the cube, and its
# tau trajectory is the pin of the eight frozen-tau runs. BAU7 grows 28 to 48 Mha
# of dedicated bioenergy crops (1.7 to 2.6 % of cropland), all rainfed. Where her runs
# allow irrigation the model uses it: 44 of 59 Mha irrigated in 2100 in her SSP2
# BAU (another model version and demand path, so a lead on the size, not a
# prediction). The effect of the switch on BAU tau has NOT been measured; BAU8
# against BAU7 is that measurement, and it says whether FSTL7's frozen-tau runs
# need repeating.
#
# The environmental-flow policy stays OFF in the BAU: it is a policy of the
# transformation, and the BAU is the current-policy world.
#
# The 16 cells are FSTL7's, switch for switch, under the prefix FSTL8. A new prefix
# and a new BAU name because the orchestrator skips finished runs by title and
# deletes unfinished ones (force_replace): this arm must not name any FSTL7 run.
#
# THE PARTNER 2 x 2
# -----------------
# The RIKEN partners' design for the 8 October 2026 meeting crosses technology
# (BAU tau against endogenous tau) with pressure on land:
#     high pressure = no dietary change + high bioenergy demand + full land
#                     protection + SSP3 interest rate
#     low pressure  = EAT-Lancet diet + low bioenergy demand + no land protection
#                     + SSP1 interest rate
# Three of the four ingredients are cube corners already:
#     high = BioOnXJPded_Prot_DietOff      low = BioNone_NoProt_DietEL
# ("low bioenergy demand" is this cube's lowest level: none from dedicated crops).
# The interest rate is not a factor of the cube. Mike, 2026-10-06: add four runs
# that carry it, and keep the cube corners without it, so its effect can be read
# separately (partner run minus its cube corner).
#
# Values: default.cfg's note on module 12, "formerly used for SSP runs": one global
# rate, SSP1 0.04 and SSP3 0.1 for the future. Set here as s12_interest_lic =
# s12_interest_hic (+ the _noselect twins). The HISTORICAL coefficients are left at
# the default (that note pairs the former SSP runs with 0.07): changing them would
# give the partner runs a different past from every other run in the project.
#
# WHAT THESE VALUES DO, measured in BAU7_TCendo (pm_interest) after an audit,
# 2026-10-06. Mike's decision the same day: keep the runs as designed and REPORT
# this beside any result from them.
#   * The default rate interpolates between 0.1 and 0.04 by each region's
#     development state, and under SSP2 income nearly every region counts as
#     developed. It is ALREADY 4.0 % from 2025 in CAZ, CHA, EUR, JPN, NEU and USA,
#     and by 2050 in IND; in 2050 it is 4.1 % in LAM and REF, 4.4 % in OAS, 4.9 % in
#     MEA and 6.8 % in SSA; 4.0 % everywhere by 2100.
#   * So "4 % everywhere" (low pressure) changes almost nothing: the two
#     FSTL8P_LowPressure runs are near-duplicates of their cube corner, differing
#     mostly in SSA for a few decades.
#   * And "10 % everywhere" (high pressure) is about +6 points in almost every
#     region. At 10 % the cost factor of raising tau, (1+r)^15 r/(1+r) in module 13,
#     is 0.380 against 0.069 at 4 %: technology is 5.5 times dearer. Land conversion,
#     irrigation expansion and one-off CO2 costs carry the annuity r/(1+r) and rise
#     2.4 times. The rate therefore taxes the tech breakthrough itself, and
#     FSTL8P_HighPressure_TCendo may end with LESS tau than the BAU path its
#     "no tech" twin is pinned to. Compare the two before any figure.
#   * The model fades from the historical to the future coefficients from 2025
#     (f12_interest_fader: 0.1 in 2025, 0.2 in 2030, 0.6 in 2040, 1 in 2050), so the
#     partner runs already differ a little in 2025, a step the other levers leave
#     untouched. Module 12 has no start-year switch.
#   * "SSP3" and "SSP1" are the legacy names of these two values. Today's SSP runs
#     (F. Beier's SSP1, SSP2 and SSP3 alike) carry the default coefficients, and the
#     SSP difference comes through income.
#
# The interest rate enters every annuity in the model, so it also moves the
# frozen-tau runs (module 13's exo realization charges the pinned tau path at the
# run's own rate). The tau pin of all four frozen-tau partner runs is BAU8's, at the
# default rate: "BAU tau" means the same trajectory in both rows.
#
# Titles: FSTL8P_HighPressure_TCbau / _TCendo, FSTL8P_LowPressure_TCbau / _TCendo.
# The prefix is FSTL8P, not FSTL8, on purpose: the cube's analysis selects "^FSTL8_"
# and must not pick these up as cells.
#
# FSTL8_BAU_ONLY=1 restricts the arm to BAU8 alone.

source(Sys.getenv("FST_LEVERS_V7_CONFIG", "scripts/start/projects/fst_levers_v7_config.R"))
if (nzchar(Sys.getenv("FSTL7_BAU_ONLY")))
  stop("FSTL7_BAU_ONLY is set: the v7 layer would hand this arm a cube without cells. Unset it.")

FST_LEVERS_BAU <- "BAU8"
.bau8  <- stats::setNames(list(c(.bau7[[1]], list(c30_bioen_water = "all"))), FST_LEVERS_BAU)
.fstl8 <- stats::setNames(.fstl7, sub("^FSTL7_", "FSTL8_", names(.fstl7)))

.interest <- function(rate) list(
  s12_interest_lic          = rate, s12_interest_hic          = rate,
  s12_interest_lic_noselect = rate, s12_interest_hic_noselect = rate
)
.partner <- list(
  FSTL8P_HighPressure = c(.fstl8$FSTL8_CPon_BioOnXJPded_Prot_DietOff, .interest("0.1")),
  FSTL8P_LowPressure  = c(.fstl8$FSTL8_CPon_BioNone_NoProt_DietEL,    .interest("0.04"))
)
stopifnot(!vapply(.partner, function(b) is.null(b$c56_pollutant_prices), logical(1)))

FST_LEVERS_SCENARIOS       <- c(.bau8, .fstl8, .partner)
FST_LEVERS_TCBAU_SCENARIOS <- c(names(.fstl8), names(.partner))

if (nzchar(Sys.getenv("FSTL8_BAU_ONLY"))) {
  FST_LEVERS_SCENARIOS       <- .bau8
  FST_LEVERS_TCBAU_SCENARIOS <- character(0)
}

# The design table is the CUBE's; the partner runs are named, not parsed.
FSTL2_DESIGN <- do.call(rbind, lapply(
  intersect(names(FST_LEVERS_SCENARIOS), names(.fstl8)),
  function(scen) {
    d <- parseCellName(sub("^FSTL[2345678]_", "", scen))
    d$scenario <- scen
    d
  }))

assertNoDuplicateSwitches()
