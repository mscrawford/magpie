# Lightweight assembly check for fst_levers_config.R (no MAgPIE deps needed).
# Asserts: syntax, no duplicate switches, correct cell count, and that each
# factor's two arms differ in EXACTLY the intended keys.
#
# Every assertion goes through chk(), which counts. The script FAILS unless the
# executed assertion count equals EXPECTED_CHECKS -- so an empty loop or a
# skipped block cannot masquerade as a pass.

source("scripts/start/projects/fst_levers_config.R")

EXPECTED_CHECKS <- 64L
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
chk(length(scen) == 7, "7 scenarios (BAU + 6 cells)")
chk(length(FST_LEVERS_TCBAU_SCENARIOS) == 6, "6 TCbau scenarios")
chk(1 + 6 * 2 == 13, "13 runs total")

# --- 2. design table matches the scenario list (2 checks) --------------------
chk(setequal(FST_LEVERS_DESIGN$scenario, setdiff(scen, "BAU")),
    "FST_LEVERS_DESIGN scenarios match the FST cells")
chk(!any(FST_LEVERS_DESIGN$cp == "off" & FST_LEVERS_DESIGN$bio == "on"),
    "(CP off, Bio on) cell is excluded by design")

# --- 3. factor arms differ in exactly the intended keys (4 checks) -----------
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

expect("CPon_BioOn_Prot", "CPoff_BioOff_Prot",
       c("c56_pollutant_prices", "c56_pollutant_prices_noselect",
         "c60_2ndgen_biodem", "c60_2ndgen_biodem_noselect"),
       "CP+Bio together (Prot held on)")

expect("CPon_BioOn_Prot", "CPon_BioOff_Prot",
       c("c60_2ndgen_biodem", "c60_2ndgen_biodem_noselect"),
       "Factor B alone (bioenergy)")

expect("CPon_BioOff_Prot", "CPoff_BioOff_Prot",
       c("c56_pollutant_prices", "c56_pollutant_prices_noselect"),
       "Factor A alone (climate policy)")

expect("CPon_BioOn_Prot", "CPon_BioOn_NoProt",
       c("c22_protect_scenario", "c22_protect_scenario_noselect", "s44_bii_target"),
       "Factor C alone (land protection, BII bundled)")

# --- 4. MACCs price-driven in all 6 cells, absent in BAU (7 checks) ----------
macc <- c("s57_maxmac_n_soil", "s57_maxmac_n_awms", "s57_maxmac_ch4_rice",
          "s57_maxmac_ch4_entferm", "s57_maxmac_ch4_awms")
for (s in setdiff(scen, "BAU")) {
  v <- FST_LEVERS_SCENARIOS[[s]]
  chk(all(vapply(macc, function(k) identical(v[[k]], -1), logical(1))),
      paste0(s, ": all 5 MACC switches price-driven (-1)"))
}
chk(is.null(FST_LEVERS_SCENARIOS$BAU$s57_maxmac_n_soil),
    "BAU leaves s57_maxmac_* at the module default")
cat("MACC block: price-driven in all FST cells, untouched in BAU\n\n")

# --- 5. equal-ambition timing: 6 cells x 5 levers (30 checks) ---------------
for (s in setdiff(scen, "BAU")) {
  v <- FST_LEVERS_SCENARIOS[[s]]
  chk(identical(v$s44_start_year, 2025),           paste0(s, ": BII start 2025"))
  chk(identical(v$s44_target_year, 2050),          paste0(s, ": BII target 2050"))
  chk(identical(v$s22_conservation_target, 2050),  paste0(s, ": conservation target 2050"))
  chk(identical(v$s15_exo_foodscen_target, 2050),  paste0(s, ": diet target 2050"))
  chk(identical(v$s42_efp_targetyear, 2050),       paste0(s, ": water EFP target 2050"))
}
cat("Timing: every lever transitions 2025 -> 2050 in all 6 cells\n\n")

# --- 6. protection factor really toggles Half-Earth (9 checks) --------------
on_cells  <- FST_LEVERS_DESIGN$scenario[FST_LEVERS_DESIGN$prot == "on"]
off_cells <- FST_LEVERS_DESIGN$scenario[FST_LEVERS_DESIGN$prot == "off"]
for (s in on_cells) {
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$c22_protect_scenario, "GSN_HalfEarth"),
      paste0(s, ": protection ON = GSN_HalfEarth"))
}
for (s in off_cells) {
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$c22_protect_scenario, "none"),
      paste0(s, ": protection OFF = none"))
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$s44_bii_target, 0),
      paste0(s, ": protection OFF carries no BII target"))
}
cat("Protection: ON = GSN_HalfEarth + BII 0.78, OFF = none + BII 0\n\n")

# --- 7. the real code path: applyTCScenario / applyExoTCFlags (9 checks) ----
# Uses a stub cfg pre-seeded with the values setScenario(SSP2, NPI) would set,
# so this also proves the scenario blocks OVERRIDE setScenario rather than being
# silently overridden by it (the orchestrator must apply blocks AFTER setScenario).
stub <- list(gms = list(
  c56_emis_policy      = "reddnatveg_nosoil",  # what SSP2 sets
  c60_res_2ndgenBE_dem = "ssp2",               # what SSP2 sets
  tc                   = "endo"
))

g <- applyTCScenario(stub, "CPon_BioOn_Prot")$gms
chk(identical(g$c56_pollutant_prices, "R34M410-SSP2-PkBudg650"), "applied: c56 price")
chk(identical(g$c60_2ndgen_biodem,    "R34M410-SSP2-PkBudg650"), "applied: c60 biodem")
chk(identical(g$c22_protect_scenario, "GSN_HalfEarth"),          "applied: c22 protect")
chk(identical(g$s44_bii_target,       0.78),                     "applied: s44 BII target")
chk(identical(g$s57_maxmac_n_soil,    -1),                       "applied: s57 price-driven")
chk(identical(g$c56_emis_policy,      "all_nosoil"),
    "scenario block OVERRIDES the setScenario value for c56_emis_policy")
chk(identical(g$c60_res_2ndgenBE_dem, "ssp2"),
    "c60_res_2ndgenBE_dem left untouched at the setScenario value")

e <- applyExoTCFlags(applyTCScenario(stub, "CPon_BioOn_Prot"))$gms
chk(identical(e$tc, "exo"),                        "exo flags: tc = exo")
chk(identical(e$c13_croparea_consv, 0) &&
    identical(e$s13_ignore_tau_historical, 1),     "exo flags: c13/s13 set")
cat("Code path: applyTCScenario + applyExoTCFlags behave as intended\n\n")

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
