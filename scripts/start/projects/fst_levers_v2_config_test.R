# Lightweight assembly check for fst_levers_v2_config.R (no MAgPIE deps needed).
#
# Same discipline as fst_levers_config_test.R: every assertion goes through chk(),
# which counts, and the script FAILS unless the executed count equals
# EXPECTED_CHECKS -- so a loop that silently iterated over nothing cannot pass.
#
# What this guards, beyond assembly:
#   * The v2 run names cannot collide with the 41 runs of the 2026-08 batch
#     (cfg$force_replace is TRUE, so a collision would DELETE a finished run).
#   * The noselect COUPLING: narrowing scen_countries60 to switch Japan's residue
#     demand off also re-points Japan's DEDICATED 2nd-gen demand at the _noselect
#     scenario. That is harmless ONLY while both dedicated twins carry the same
#     tag. Asserted per cell; if anyone ever sets them differently, this fails.
#   * The arm-level keys are not silently overridden by a per-cell block.
#   * The country exclusion actually excludes something (negative control).
#
# EXPECTED_CHECKS derivation (nCells = 12: 4 at 1.5C + 4 at 2.0C + 4 at 1.5C with
# Japan exempted from the dedicated ramp; dietEL = 6):
#   inventory 4 + design 3 + diet 4 + climate tags (2*nCells) 24
#   + noselect coupling (2*nCells) 24 + base overrides 6                   = 65

source("scripts/start/projects/fst_levers_v2_config.R")

EXPECTED_CHECKS <- 65L
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

cells <- setdiff(names(FST_LEVERS_SCENARIOS), "BAU")

# --- 1. inventory + collision safety (4 checks) ------------------------------
cat("v2 scenarios (", length(names(FST_LEVERS_SCENARIOS)), "):\n  ",
    paste(names(FST_LEVERS_SCENARIOS), collapse = "\n  "), "\n\n", sep = "")

chk(length(names(FST_LEVERS_SCENARIOS)) == 13,
    "13 scenarios (BAU + 4 at 1.5C + 4 at 2.0C + 4 with Japan off the dedicated ramp)")
chk(length(FST_LEVERS_TCBAU_SCENARIOS) == 12, "12 TCbau scenarios")
chk(all(grepl("^FSTL[23]_", cells)), "every cell carries an FSTL2_ or FSTL3_ prefix")

# The base config's names, re-read in a throwaway env so this file's own globals
# are not clobbered by re-sourcing it.
.base_env <- new.env()
sys.source("scripts/start/projects/fst_levers_config.R", envir = .base_env)
.base_titles <- c(
  vapply(names(.base_env$FST_LEVERS_SCENARIOS), tcRunName, character(1), "TCendo"),
  vapply(.base_env$FST_LEVERS_TCBAU_SCENARIOS,  tcRunName, character(1), "TCbau"))
.v2_titles <- c(
  vapply(cells, tcRunName, character(1), "TCendo"),
  vapply(FST_LEVERS_TCBAU_SCENARIOS, tcRunName, character(1), "TCbau"))
chk(length(intersect(.base_titles, .v2_titles)) == 0,
    "no v2 run title collides with a 2026-08 batch run title")

# --- 2. design table (3 checks) ----------------------------------------------
chk(nrow(FSTL2_DESIGN) == 12, "design table has 12 rows")
# Every cell is a COHERENT climate/bioenergy pairing at the same ambition as its
# price: 1.5C = PkBudg650 both sides, 2.0C = PkBudg1000 both sides. `on_xjp` is the
# 1.5C ramp with Japan alone held at baseline, so it pairs with the 1.5C price too.
chk(all(FSTL2_DESIGN$cp %in% c("on", "20")) && all(FSTL2_DESIGN$bio %in% c("on", "on_xjp")),
    "every cell is a coherent bio-on corner at 1.5C or 2.0C")
chk(sum(FSTL2_DESIGN$diet == "el") == 6L && sum(FSTL2_DESIGN$diet == "off") == 6L,
    "diet levels split 6 EL / 6 off")

# --- 3. the diet lever (4 checks) --------------------------------------------
el_cells <- cells[grepl("DietEL$", cells)]

chk(all(vapply(el_cells, function(s) identical(FST_LEVERS_SCENARIOS[[s]]$s15_exo_diet, 3),
               logical(1))),
    "DietEL cells set s15_exo_diet = 3 (MAgPIE's own EAT-Lancet realization)")
chk(all(vapply(el_cells, function(s) is.null(FST_LEVERS_SCENARIOS[[s]]$c15_EAT_scen),
               logical(1))),
    "DietEL cells do NOT set c15_EAT_scen (inert under s15_exo_diet = 3)")
chk(all(vapply(el_cells, function(s) identical(FST_LEVERS_SCENARIOS[[s]]$c15_kcal_scen,
                                               "healthy_BMI"), logical(1))),
    "DietEL cells use c15_kcal_scen = healthy_BMI, NOT the 2500kcal trap")

diffKeys <- function(a, b) {
  A <- FST_LEVERS_SCENARIOS[[a]]; B <- FST_LEVERS_SCENARIOS[[b]]
  keys <- union(names(A), names(B))
  sort(keys[vapply(keys, function(k) !identical(A[[k]], B[[k]]), logical(1))])
}
got <- diffKeys("FSTL2_CPon_BioOn_Prot_DietEL", "FSTL2_CPon_BioOn_Prot_DietOff")
cat("Diet factor (EL vs off):\n  ", paste(got, collapse = "\n  "), "\n\n", sep = "")
chk(identical(got, sort(c("s15_exo_diet", "c15_kcal_scen", "s15_exo_foodscen_start",
                          "s15_exo_foodscen_target", "s15_exo_foodscen_convergence"))),
    "diet factor flips exactly the intended keys")

# --- 4. climate tags, and the c56/c60 pairing rule (16 checks) ---------------
# The price and the bioenergy demand are the two images of ONE energy-system
# solution, so they must carry the SAME tag; a PkBudg1000 price against PkBudg650
# demand is the two-halves-of-two-scenarios defect the design hole exists to avoid.
expected_tag <- function(s) {
  if (grepl("_CP20_", s)) "R34M410-SSP2-PkBudg1000" else "R34M410-SSP2-PkBudg650"
}
for (s in cells) {
  tag <- expected_tag(s)
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$c56_pollutant_prices, tag),
      paste0(s, ": carbon price = ", tag))
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$c60_2ndgen_biodem, tag),
      paste0(s, ": bioenergy demand = ", tag, " (paired with the price)"))
}

# --- 5. the noselect coupling + arm-level keys (8 checks) --------------------
arm_keys <- c("scen_countries60", "c60_res_2ndgenBE_dem", "c60_res_2ndgenBE_dem_noselect")
for (s in cells) {
  blk <- FST_LEVERS_SCENARIOS[[s]]
  if (grepl("^FSTL3_", s)) {
    # The FSTL3 arm EXEMPTS Japan from the dedicated ramp on purpose, so here the
    # twins must DIFFER - selected countries ramp to PkBudg650, the de-selected
    # one (Japan) stays on the NPi2025 baseline. Asserted explicitly rather than
    # relaxed, so a typo that accidentally re-equalises them still fails.
    chk(identical(blk$c60_2ndgen_biodem, "R34M410-SSP2-PkBudg650") &&
          identical(blk$c60_2ndgen_biodem_noselect, "R34M410-SSP2-NPi2025"),
        paste0(s, ": Japan is exempted from the dedicated ramp (twins differ by design)"))
  } else {
    chk(identical(blk$c60_2ndgen_biodem, blk$c60_2ndgen_biodem_noselect),
        paste0(s, ": dedicated 2nd-gen twins are equal, so narrowing scen_countries60 ",
               "cannot change Japan's DEDICATED demand"))
  }
  chk(!any(arm_keys %in% names(blk)),
      paste0(s, ": does not override the arm-level residue/country keys"))
}

# --- 6. fstLeversBaseOverrides (6 checks) ------------------------------------
# Synthetic list first: exercises the mechanism without config/default.cfg.
local({
  all_iso_countries <<- "ABW, JPN, DEU"
  out <- fstLeversBaseOverrides(list(gms = list()))
  chk(identical(out$gms$scen_countries60, "ABW,DEU"), "JPN dropped from scen_countries60")
  chk(identical(out$gms$c60_res_2ndgenBE_dem, "ssp2"),
      "selected countries keep the SSP2 residue demand")
  chk(identical(out$gms$c60_res_2ndgenBE_dem_noselect, "off"),
      "de-selected country (Japan) gets residue demand off")
})

# NEGATIVE CONTROL: if the country to exclude is not in the list, the switch-off
# would be a silent no-op, so it must abort rather than launch 8 useless runs.
local({
  all_iso_countries <<- "ABW, DEU"
  err <- try(fstLeversBaseOverrides(list(gms = list())), silent = TRUE)
  chk(inherits(err, "try-error"), "aborts when the excluded country is absent (no-op guard)")
})

# Real list, read out of config/default.cfg without executing the rest of it.
local({
  real <- NULL
  for (e in parse("config/default.cfg")) {
    if (is.call(e) && identical(as.character(e[[1]]), "<-") &&
        identical(as.character(e[[2]]), "all_iso_countries")) real <- eval(e[[3]])
  }
  all_iso_countries <<- real
  iso <- strsplit(gsub("[[:space:]]", "", real), ",", fixed = TRUE)[[1]]
  iso <- iso[nzchar(iso)]
  out <- fstLeversBaseOverrides(list(gms = list()))
  kept <- strsplit(out$gms$scen_countries60, ",", fixed = TRUE)[[1]]
  cat("all_iso_countries: ", length(iso), " -> kept ", length(kept), "\n\n", sep = "")
  chk(length(kept) == length(iso) - 1L, "exactly one country removed from the real list")
  chk(!("JPN" %in% kept), "JPN is not among the kept countries")
})

# --- report ------------------------------------------------------------------
cat("checks run: ", n_checks, " (expected ", EXPECTED_CHECKS, "), failures: ",
    n_fail, "\n", sep = "")
if (n_checks != EXPECTED_CHECKS) {
  stop("assertion COUNT mismatch: ran ", n_checks, ", expected ", EXPECTED_CHECKS,
       " -- a block was skipped or a loop iterated over nothing.")
}
if (n_fail > 0) stop(n_fail, " assertion(s) failed.")
cat("fst_levers v2 config OK.\n")
