# Lightweight assembly check for fst_levers_config.R (no MAgPIE deps needed).
# Asserts: syntax, no duplicate switches, correct cell count, and that each of the
# FIVE factors' two arms differ in EXACTLY the intended keys.
#
# Every assertion goes through chk(), which counts. The script FAILS unless the
# executed assertion count equals EXPECTED_CHECKS -- so an empty loop or a
# skipped block cannot masquerade as a pass.
#
# Design under test (5 factors): TC, climate(56), bioenergy(60),
# land+water protection(22+44+29+42), diet(15). The hole is (climate off, bio
# on); the KEPT counterfactuals are (climate on, bio off) and (climate 2.0C, bio
# off). Climate is THREE-level since 2026-08-03 (NPi2025 / PkBudg1000 /
# PkBudg650), so 20 policy cells + BAU = 21 scenarios, 20 of them with a TCbau
# twin -> 41 runs.
#
# EXPECTED_CHECKS derivation (nCells = 20, dietOn = protOn = 10):
#   inventory 3 + design 2 + factor arms 5 + MACC (nCells+1) 21
#   + timing (4*nCells + dietOn + protOn) 100
#   + protection (3*protOn + 4*protOff) 70 + diet (3*dietOn + dietOff) 40
#   + applyTCScenario 11 + c56/c60 coupling (2*nCells + 3) 43            = 295
# Keep this a LITERAL, not a formula over the object under test: the point of the
# guard is to catch a loop that silently iterated over nothing.

source("scripts/start/projects/fst_levers_config.R")

EXPECTED_CHECKS <- 295L
n_checks <- 0L
n_fail   <- 0L

chk <- function(cond, label) {
  n_checks <<- n_checks + 1L
  if (!isTRUE(cond)) {
    n_fail <<- n_fail + 1L
    cat("  FAIL: ", label, "\n", sep = "")
  }
  invisible(cond)
}

# --- 1. inventory (3 checks) -------------------------------------------------
scen <- names(FST_LEVERS_SCENARIOS)
cat("Scenarios (", length(scen), "):\n  ", paste(scen, collapse = "\n  "), "\n\n", sep = "")
chk(length(scen) == 21, "21 scenarios (BAU + 20 cells)")
chk(length(FST_LEVERS_TCBAU_SCENARIOS) == 20, "20 TCbau scenarios")
chk(1 + 20 * 2 == 41, "41 runs total")

# --- 2. design table matches the scenario list (2 checks) --------------------
chk(setequal(FST_LEVERS_DESIGN$scenario, setdiff(scen, "BAU")),
    "FST_LEVERS_DESIGN scenarios match the 12 FST cells")
chk(!any(FST_LEVERS_DESIGN$cp == "off" & FST_LEVERS_DESIGN$bio == "on"),
    "the hole (climate off, bio on) is excluded by design")

# --- 3. factor arms differ in exactly the intended keys (5 checks) -----------
# Reference cell for the single-factor contrasts: everything else held at
# (bio on where relevant, prot on, diet on). Each contrast flips ONE factor.
diffKeys <- function(a, b) {
  A <- FST_LEVERS_SCENARIOS[[a]]; B <- FST_LEVERS_SCENARIOS[[b]]
  keys <- union(names(A), names(B))
  sort(keys[vapply(keys, function(k) !identical(A[[k]], B[[k]]), logical(1))])
}

expect <- function(a, b, want, label) {
  got <- diffKeys(a, b)
  cat(label, ":\n  ", paste(got, collapse = "\n  "), "\n\n", sep = "")
  chk(identical(got, sort(want)), paste0(label, " -- diff set"))
}

# Climate + bio together are unidentifiable jointly (the hole): flipping both at
# once (bio off, climate off vs bio on, climate on) touches exactly the 4 keys.
expect("CPon_BioOn_Prot_DietOn", "CPoff_BioOff_Prot_DietOn",
       c("c56_pollutant_prices", "c56_pollutant_prices_noselect",
         "c60_2ndgen_biodem", "c60_2ndgen_biodem_noselect"),
       "Climate+Bio together (Prot on, Diet on held)")

expect("CPon_BioOn_Prot_DietOn", "CPon_BioOff_Prot_DietOn",
       c("c60_2ndgen_biodem", "c60_2ndgen_biodem_noselect"),
       "Factor 3 alone (bioenergy)")

expect("CPon_BioOff_Prot_DietOn", "CPoff_BioOff_Prot_DietOn",
       c("c56_pollutant_prices", "c56_pollutant_prices_noselect"),
       "Factor 2 alone (climate policy)")

# Protection now bundles area (22) + BII (44) + SNV (29) + env-flow water (42).
# The OFF arm omits the three s42 timing scalars (inert when the policy is off),
# so they appear in the diff alongside the four core keys.
expect("CPon_BioOn_Prot_DietOn", "CPon_BioOn_NoProt_DietOn",
       c("c22_protect_scenario", "c22_protect_scenario_noselect",
         "s44_bii_target", "s29_snv_shr", "s29_snv_shr_noselect",
         "c42_env_flow_policy", "s42_env_flow_scenario",
         "s42_efp_startyear", "s42_efp_targetyear"),
       "Factor 4 alone (land+water protection: area + BII + SNV + env-flows)")

# Diet is a factor again. The OFF arm sets only s15_exo_diet = 0; the ON arm's
# other diet scalars are inert when the switch is off, so they appear in the diff.
expect("CPon_BioOn_Prot_DietOn", "CPon_BioOn_Prot_DietOff",
       c("s15_exo_diet", "c15_EAT_scen", "c15_kcal_scen",
         "s15_exo_foodscen_start", "s15_exo_foodscen_target",
         "s15_exo_foodscen_convergence"),
       "Factor 5 alone (diet)")

# --- 4. MACCs price-driven in all 12 cells, absent in BAU (13 checks) --------
macc <- c("s57_maxmac_n_soil", "s57_maxmac_n_awms", "s57_maxmac_ch4_rice",
          "s57_maxmac_ch4_entferm", "s57_maxmac_ch4_awms")
for (s in setdiff(scen, "BAU")) {
  v <- FST_LEVERS_SCENARIOS[[s]]
  chk(all(vapply(macc, function(k) identical(v[[k]], -1), logical(1))),
      paste0(s, ": all 5 MACC switches price-driven (-1)"))
}
chk(is.null(FST_LEVERS_SCENARIOS$BAU$s57_maxmac_n_soil),
    "BAU leaves s57_maxmac_* at the module default")
cat("MACC block: price-driven in all 12 FST cells, untouched in BAU\n\n")

# --- 5. equal-ambition timing (60 checks) ------------------------------------
# The land-protection timing quartet is set in BOTH protection arms, so it holds
# in all 12 cells. Diet and water timing exist only in their ON arms, so those
# are checked on the relevant cells only.
cells    <- setdiff(scen, "BAU")
dietOn   <- FST_LEVERS_DESIGN$scenario[FST_LEVERS_DESIGN$diet == "on"]
protOn   <- FST_LEVERS_DESIGN$scenario[FST_LEVERS_DESIGN$prot == "on"]
for (s in cells) {
  v <- FST_LEVERS_SCENARIOS[[s]]
  chk(identical(v$s44_start_year, 2026),          paste0(s, ": BII start 2026 (model requires >sm_fix_SSP2)"))
  chk(identical(v$s44_target_year, 2050),         paste0(s, ": BII target 2050"))
  chk(identical(v$s22_conservation_target, 2050), paste0(s, ": conservation target 2050"))
  chk(identical(v$s29_snv_scenario_target, 2050), paste0(s, ": SNV target 2050"))
}
for (s in dietOn) {
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$s15_exo_foodscen_target, 2050),
      paste0(s, ": diet target 2050 (DietOn arm)"))
}
for (s in protOn) {
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$s42_efp_targetyear, 2050),
      paste0(s, ": water EFP target 2050 (Prot arm)"))
}
cat("Timing: levers transition 2025 -> 2050; BII start forced to 2026 (>sm_fix_SSP2)\n\n")

# --- 6. protection factor toggles Half-Earth + env-flow water (42 checks) ----
on_cells  <- FST_LEVERS_DESIGN$scenario[FST_LEVERS_DESIGN$prot == "on"]
off_cells <- FST_LEVERS_DESIGN$scenario[FST_LEVERS_DESIGN$prot == "off"]
PROT_LEVEL <- "GSN_HalfEarth"   # gated on fst_levers_preflight.R; fallback BH_IFL
for (s in on_cells) {
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$c22_protect_scenario, PROT_LEVEL),
      paste0(s, ": protection ON area target = ", PROT_LEVEL))
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$s29_snv_shr, 0.2) &&
      identical(FST_LEVERS_SCENARIOS[[s]]$s29_snv_shr_noselect, 0.2),
      paste0(s, ": protection ON carries SNV 0.2 (both select and noselect)"))
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$c42_env_flow_policy, "on"),
      paste0(s, ": protection ON carries env-flow water policy = on"))
}
for (s in off_cells) {
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$c22_protect_scenario, "none"),
      paste0(s, ": protection OFF area = none"))
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$s44_bii_target, 0),
      paste0(s, ": protection OFF carries no BII target"))
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$s29_snv_shr, 0) &&
      identical(FST_LEVERS_SCENARIOS[[s]]$s29_snv_shr_noselect, 0),
      paste0(s, ": protection OFF carries no SNV requirement"))
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$c42_env_flow_policy, "off"),
      paste0(s, ": protection OFF carries env-flow water policy = off"))
}
cat("Protection bundle: ON = ", PROT_LEVEL, " + BII 0.78 + SNV 0.2 + water on; OFF = none + 0 + 0 + water off\n\n", sep = "")

# --- 7. diet factor toggles the EAT-Lancet transition (18 checks) ------------
diet_on_cells  <- FST_LEVERS_DESIGN$scenario[FST_LEVERS_DESIGN$diet == "on"]
diet_off_cells <- FST_LEVERS_DESIGN$scenario[FST_LEVERS_DESIGN$diet == "off"]
for (s in diet_on_cells) {
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$s15_exo_diet, 1),
      paste0(s, ": diet ON = exogenous diet enabled"))
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$c15_EAT_scen, "FLX"),
      paste0(s, ": diet ON = EAT-Lancet FLX"))
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$c15_kcal_scen, "2500kcal"),
      paste0(s, ": diet ON = 2500 kcal"))
}
for (s in diet_off_cells) {
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$s15_exo_diet, 0),
      paste0(s, ": diet OFF = endogenous diet"))
}
cat("Diet factor: ON = EAT-Lancet FLX 2500kcal; OFF = endogenous (s15_exo_diet = 0)\n\n")

# --- 8. the real code path: applyTCScenario / applyExoTCFlags (11 checks) ----
# Uses a stub cfg pre-seeded with the values setScenario(SSP2, NPI) would set,
# so this also proves the scenario blocks OVERRIDE setScenario rather than being
# silently overridden by it (the orchestrator must apply blocks AFTER setScenario).
stub <- list(gms = list(
  c56_emis_policy      = "reddnatveg_nosoil",  # what SSP2 sets
  c60_res_2ndgenBE_dem = "ssp2",               # what SSP2 sets
  s15_exo_diet         = 0,                     # SSP2/NPI default: endogenous diet
  tc                   = "endo"
))

g <- applyTCScenario(stub, "CPon_BioOn_Prot_DietOn")$gms
chk(identical(g$c56_pollutant_prices, "R34M410-SSP2-PkBudg650"), "applied: c56 price")
chk(identical(g$c60_2ndgen_biodem,    "R34M410-SSP2-PkBudg650"), "applied: c60 biodem")
chk(identical(g$c22_protect_scenario, "GSN_HalfEarth"),          "applied: c22 protect")
chk(identical(g$s44_bii_target,       0.78),                     "applied: s44 BII target")
chk(identical(g$c42_env_flow_policy,  "on"),                     "applied: c42 env-flow water on")
chk(identical(g$s15_exo_diet,         1),                        "applied: s15 exo diet on (overrides setScenario 0)")
chk(identical(g$c15_EAT_scen,         "FLX"),                    "applied: c15 EAT-Lancet FLX")
chk(identical(g$s57_maxmac_n_soil,    -1),                       "applied: s57 price-driven")
chk(identical(g$c56_emis_policy,      "all_nosoil"),
    "scenario block OVERRIDES the setScenario value for c56_emis_policy")
chk(identical(g$c60_res_2ndgenBE_dem, "ssp2"),
    "c60_res_2ndgenBE_dem left untouched at the setScenario value")

e <- applyExoTCFlags(applyTCScenario(stub, "CPon_BioOn_Prot_DietOn"))$gms
chk(identical(e$tc, "exo") &&
    identical(e$c13_croparea_consv, 0) &&
    identical(e$s13_ignore_tau_historical, 1),     "exo flags: tc = exo, c13/s13 set")
cat("Code path: applyTCScenario + applyExoTCFlags behave as intended\n\n")

# --- 9. the c56/c60 coupling invariant (2*20 + 3 = 43 checks) ----------------
# The carbon price and the 2nd-gen bioenergy demand are the price-side and
# land-side images of ONE energy-system solution. Every cell must therefore carry
# ONE REMIND tag across both switch families -- except the two DECLARED
# counterfactuals, which pair a policy price with baseline bioenergy on purpose
# and are the only cells allowed to be inconsistent.
#
# This is the check that would have caught the yield_gap defect: it set a
# PkBudg650 price and left c60 at its NPi default, and nothing anywhere noticed.
COUPLED <- c(CPon_BioOn   = "R34M410-SSP2-PkBudg650",
             CP20_BioOn   = "R34M410-SSP2-PkBudg1000",
             CPoff_BioOff = "R34M410-SSP2-NPi2025")
COUNTERFACTUAL <- c(CPon_BioOff = "R34M410-SSP2-PkBudg650",
                    CP20_BioOff = "R34M410-SSP2-PkBudg1000")
BASELINE_BIO <- "R34M410-SSP2-NPi2025"

unclassified <- character(0)
for (s in cells) {
  v   <- FST_LEVERS_SCENARIOS[[s]]
  arm <- paste(strsplit(s, "_", fixed = TRUE)[[1]][1:2], collapse = "_")
  if (arm %in% names(COUPLED)) {
    want <- COUPLED[[arm]]
    chk(identical(v$c56_pollutant_prices, want) &&
        identical(v$c56_pollutant_prices_noselect, want),
        paste0(s, ": c56 pair = ", want))
    chk(identical(v$c60_2ndgen_biodem, want) &&
        identical(v$c60_2ndgen_biodem_noselect, want),
        paste0(s, ": c60 pair = ", want, " (coupled to the price)"))
  } else if (arm %in% names(COUNTERFACTUAL)) {
    want <- COUNTERFACTUAL[[arm]]
    chk(identical(v$c56_pollutant_prices, want) &&
        identical(v$c56_pollutant_prices_noselect, want),
        paste0(s, ": c56 pair = ", want))
    chk(identical(v$c60_2ndgen_biodem, BASELINE_BIO) &&
        identical(v$c60_2ndgen_biodem_noselect, BASELINE_BIO),
        paste0(s, ": c60 pair = ", BASELINE_BIO, " (DECLARED counterfactual)"))
  } else {
    unclassified <- c(unclassified, arm)
  }
}
chk(length(unclassified) == 0,
    paste0("every (climate,bio) arm is classified as coupled or counterfactual",
           if (length(unclassified)) paste0(" -- unclassified: ",
                                            paste(unique(unclassified), collapse = ", ")) else ""))

# The three-level climate factor must not leak into the binary 2^k machinery.
chk(identical(FST_LEVERS_CUBES$B$levels$cp, c("off", "on")),
    "Cube B pins cp to the two binary levels (excludes the 2.0C arm)")
chk(identical(unname(FST_LEVERS_CUBES$A$fixed), "on") &&
    identical(names(FST_LEVERS_CUBES$A$fixed), "cp"),
    "Cube A fixes cp = on, which already excludes the 2.0C arm")
cat("Coupling: c56 and c60 carry one REMIND tag per cell; the 2 declared\n",
    "counterfactuals (CPon_BioOff, CP20_BioOff) are the only exceptions\n\n", sep = "")

# --- run titles --------------------------------------------------------------
cat("Run titles (", 1 + 2 * length(FST_LEVERS_TCBAU_SCENARIOS), "):\n", sep = "")
cat("  ", tcRunName("BAU", "TCendo"), "\n", sep = "")
for (s in FST_LEVERS_TCBAU_SCENARIOS) {
  cat("  ", tcRunName(s, "TCendo"), "\n  ", tcRunName(s, "TCbau"), "\n", sep = "")
}

# --- verdict: assertion count must match, or the pass is meaningless --------
cat("\nassertions executed: ", n_checks, " (expected ", EXPECTED_CHECKS, "), failures: ",
    n_fail, "\n", sep = "")
if (n_checks != EXPECTED_CHECKS) {
  cat("INVALID: assertion count mismatch - some checks did not run\n")
  quit(status = 2L)
}
cat(if (n_fail == 0L) "ALL CHECKS PASSED\n" else "THERE WERE FAILURES\n")
quit(status = if (n_fail == 0L) 0L else 1L)
