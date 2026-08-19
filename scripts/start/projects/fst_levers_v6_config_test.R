# Assertions for the FSTL6 arm. Counted, so a block that silently iterated over
# nothing cannot pass.
#
# What this guards:
#   * THE BIOENERGY FACTOR IS A REAL FACTOR. Exactly four cells zero the dedicated
#     2nd-gen demand and exactly four keep FSTL5's 1.5C ramp. A config in which all
#     eight cells agree would look healthy and answer nothing.
#   * THE ZERO IS ACTUALLY ZERO. c60_2ndgen_biodem = "none" alone is NOT zero:
#     presolve.gms:64 floors i60_bioenergy_dem at s60_2ndgen_bioenergy_dem_min
#     (default 1 mio GJ per region). The floor must be lowered on exactly the
#     BioNone cells. This is the same class of bug as the inert BII target - a
#     switch that is set, looks right, and does nothing.
#   * THE BIO-ON FACE IS STILL FSTL5. Those four cells are the regression check
#     against the FSTL5 deliverable, so they must carry FSTL5's switches exactly,
#     including leaving s60_2ndgen_bioenergy_dem_min at its default.
#   * THE BII TARGET IS STILL LIVE. Inherited from FSTL5 via .prot_on; re-asserted
#     here because this arm's whole protection limb depends on it.
#   * NO LIVE RUN CAN BE DELETED. cfg$force_replace is TRUE and the orchestrator
#     skips only COMPLETE runs, so naming a still-solving run destroys it. This
#     arm's scenario list must contain no FSTL2/3/4/5 cell at all.
#   * No title collides with a run folder already on disk.
#   * BioNone is a NEW token, not a reuse of BioOff (which means NPi2025, not zero).

source("scripts/start/projects/fst_levers_v6_config.R")

EXPECTED_CHECKS <- 52L
n_checks <- 0L
n_fail   <- 0L
chk <- function(cond, label) {
  n_checks <<- n_checks + 1L
  if (!isTRUE(cond)) { n_fail <<- n_fail + 1L; cat("  FAIL: ", label, "\n", sep = "") }
  invisible(cond)
}

cells   <- setdiff(names(FST_LEVERS_SCENARIOS), "BAU")
bioNone <- grep("_BioNone_",     cells, value = TRUE)
bioOn   <- grep("_BioOnXJPded_", cells, value = TRUE)

# --- 1. inventory (6 checks) -------------------------------------------------
chk(length(FST_LEVERS_SCENARIOS) == 9L, "9 scenarios (BAU + 8 cells)")
chk(length(FST_LEVERS_TCBAU_SCENARIOS) == 8L, "8 TCbau scenarios")
chk(all(grepl("^FSTL6_", cells)), "every cell carries the FSTL6_ prefix")
chk(nrow(FSTL2_DESIGN) == 8L, "design table has 8 rows")
chk(length(bioNone) == 4L, "exactly 4 BioNone cells")
chk(length(bioOn) == 4L, "exactly 4 BioOnXJPded cells")

# --- 2. the design is a full 2^3 of scenarios (2 checks) ---------------------
# TC is crossed at run time by the orchestrator, so the config side is 2^3 and the
# realised cube is 2^4. Checked as a set comparison, not a count, so a duplicated
# cell cannot pass by arithmetic.
expected <- sort(as.vector(outer(
  c("BioOnXJPded", "BioNone"),
  as.vector(outer(c("Prot", "NoProt"), c("DietEL", "DietOff"),
                  function(p, d) paste0(p, "_", d))),
  function(b, pd) paste0("FSTL6_CPon_", b, "_", pd))))
chk(identical(sort(cells), expected), "cells are exactly the 2x2x2 bio x prot x diet set")
chk(!any(duplicated(cells)), "no duplicated cell name")

# --- 3. THE force_replace GUARD (2 checks) -----------------------------------
# FSTL5's eight runs are on disk and are the regression reference. Naming any of
# them here would delete them.
chk(!any(grepl("^FSTL[2345]_", names(FST_LEVERS_SCENARIOS))),
    "no FSTL2/3/4/5 cell appears in the scenario list (force_replace would delete it)")
chk(!any(grepl("^FSTL[2345]_", FST_LEVERS_TCBAU_SCENARIOS)),
    "no FSTL2/3/4/5 cell appears in the TCbau list")

# --- 4. the BII target is live (5 checks) ------------------------------------
# 18 timesteps, 1995..2050 by 5 then 2055..2100. Hard-coded rather than read from a
# gdx so this runs before any model does.
TIMESTEPS <- c(seq(1995, 2050, 5), 2055, 2060, 2070, 2080, 2090, 2100)
chk(identical(.prot_on$s44_bii_target, 0.78), "protection ON sets a 0.78 BII floor")
chk(identical(.prot_off$s44_bii_target, 0),   "protection OFF sets no BII floor")
chk(.prot_on$s44_start_year %in% TIMESTEPS,
    "s44_start_year is ON THE TIMESTEP GRID (else module 44's exact match never fires)")
chk(.prot_on$s44_start_year > 2025,
    "s44_start_year > sm_fix_SSP2 = 2025 (module 44 aborts otherwise)")
chk(identical(.prot_on$s44_start_year, .prot_off$s44_start_year),
    "both protection blocks share a start year, so the factor toggles the target alone")

# --- 5. the bio token is new, not a reuse (3 checks) -------------------------
chk(identical(unname(FST_LEVERS_TOKENS$bio["BioNone"]), "none"),
    "BioNone is registered in FST_LEVERS_TOKENS")
chk(identical(unname(FST_LEVERS_TOKENS$bio["BioOff"]), "off"),
    "BioOff still means 'off' (NPi2025 everywhere), untouched by this arm")
chk(!identical(unname(FST_LEVERS_TOKENS$bio["BioNone"]),
               unname(FST_LEVERS_TOKENS$bio["BioOff"])),
    "BioNone and BioOff are distinct levels (zero demand vs baseline demand)")

# --- 6. per-cell switches, all eight cells (8 checks) ------------------------
for (s in cells) {
  chk(identical(FST_LEVERS_SCENARIOS[[s]]$c56_pollutant_prices, "R34M410-SSP2-PkBudg650"),
      paste0(s, ": 1.5C carbon price (held across BOTH bio levels - the counterfactual)"))
}

# --- 7. the BioNone cells really zero the demand (12 checks) -----------------
for (s in bioNone) {
  blk <- FST_LEVERS_SCENARIOS[[s]]
  chk(identical(blk$c60_2ndgen_biodem, "none"),
      paste0(s, ": dedicated 2nd-gen demand switched off"))
  chk(identical(blk$s60_2ndgen_bioenergy_dem_min, 0),
      paste0(s, ": demand floor lowered to 0 (else presolve.gms:64 leaves 1 mio GJ/region)"))
  # "none" is not a member of scen2nd60, so it is only ever legal on the SELECTED
  # switch. On _noselect it would be an invalid set element, not a switch-off.
  chk(!identical(blk$c60_2ndgen_biodem_noselect, "none"),
      paste0(s, ": _noselect is a real scen2nd60 member, not 'none'"))
}

# --- 8. the BioOn face is byte-identical to FSTL5's switches (12 checks) -----
for (s in bioOn) {
  blk <- FST_LEVERS_SCENARIOS[[s]]
  chk(identical(blk$c60_2ndgen_biodem, "R34M410-SSP2-PkBudg650") &&
        identical(blk$c60_2ndgen_biodem_noselect, "R34M410-SSP2-NPi2025"),
      paste0(s, ": Japan exempt from the dedicated ramp (twins differ by design)"))
  chk(is.null(blk$s60_2ndgen_bioenergy_dem_min),
      paste0(s, ": demand floor left at its default, exactly as FSTL5 ran it"))
  chk(identical(blk$c60_res_2ndgenBE_dem, NULL),
      paste0(s, ": residue channel not set per-cell (stays ssp2 from the arm override)"))
}

# --- 9. no collision with anything on disk (2 checks) ------------------------
titles <- c(vapply(names(FST_LEVERS_SCENARIOS), tcRunName, character(1), "TCendo"),
            vapply(FST_LEVERS_TCBAU_SCENARIOS,  tcRunName, character(1), "TCbau"))
onDisk <- list.files("output")
clash  <- setdiff(intersect(titles, onDisk), tcRunName("BAU", "TCendo"))
chk(length(clash) == 0,
    paste0("no FSTL6 title collides with a folder on disk (found: ",
           paste(clash, collapse = ", "), ")"))
chk(tcRunName("BAU", "TCendo") %in% onDisk,
    "BAU_TCendo exists on disk, so it is skipped and reused as the Phase 2 tau pin")

cat("\nFSTL6 titles:\n  ", paste(titles, collapse = "\n  "), "\n\n", sep = "")
cat("checks run: ", n_checks, " (expected ", EXPECTED_CHECKS, "), failures: ", n_fail, "\n", sep = "")
if (n_checks != EXPECTED_CHECKS)
  stop("assertion COUNT mismatch: ran ", n_checks, ", expected ", EXPECTED_CHECKS)
if (n_fail > 0) stop(n_fail, " assertion(s) failed.")
cat("fst_levers v6 config OK.\n")
