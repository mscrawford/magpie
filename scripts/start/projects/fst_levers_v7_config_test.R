# Assertions for the FSTL7 arm. Counted, so a block that silently iterated over
# nothing cannot pass.
#
# What this guards:
#   * THE BII INSTRUMENT IS NO NET LOSS, AND ONLY IN THE PROTECTION-ON CELLS.
#     c44_bii_decrease = 0 has no `s44_bii_target > 0` guard in module 44's
#     presolve, so it acts wherever it is set. Set in a protection-OFF cell it
#     would put the instrument on both sides of the contrast and the BII limb of
#     the protection effect would be zero while every run looked healthy.
#   * NO CELL CARRIES THE NUMERIC FLOOR. 0.78 by 2050 is unmet and penalised
#     (see the config header); it must not come back through an inherited block.
#   * THE START YEAR IS ON THE TIMESTEP GRID. Module 44 zeroes the bound for
#     m_year(t) < s44_start_year, and every earlier arm before FSTL5 lost its floor
#     to a start year off the grid.
#   * NOTHING BUT THE BII LIMB DIFFERS FROM FSTL6. Cell by cell, the switch lists
#     of FSTL7 and FSTL6 must differ in exactly s44_bii_target and
#     c44_bii_decrease, and only where protection is on.
#   * THE TAU PIN IS THIS ARM'S OWN BAU. BAU_TCendo (rev4.131 data) must not be in
#     the scenario list; BAU7 must be, with the base BAU switches.
#   * NO LIVE OR FINISHED RUN OF AN EARLIER ARM CAN BE DELETED (force_replace).
#   * No title collides with a run folder already on disk.

source("scripts/start/projects/fst_levers_v7_config.R")

EXPECTED_CHECKS <- 62L
n_checks <- 0L
n_fail   <- 0L
chk <- function(cond, label) {
  n_checks <<- n_checks + 1L
  if (!isTRUE(cond)) { n_fail <<- n_fail + 1L; cat("  FAIL: ", label, "\n", sep = "") }
  invisible(cond)
}

cells  <- setdiff(names(FST_LEVERS_SCENARIOS), FST_LEVERS_BAU)
protOn <- grep("_Prot_",   cells, value = TRUE)
protOf <- grep("_NoProt_", cells, value = TRUE)

# --- 1. inventory (6 checks) -------------------------------------------------
chk(length(FST_LEVERS_SCENARIOS) == 9L, "9 scenarios (BAU7 + 8 cells)")
chk(length(FST_LEVERS_TCBAU_SCENARIOS) == 8L, "8 TCbau scenarios")
chk(all(grepl("^FSTL7_", cells)), "every cell carries the FSTL7_ prefix")
chk(nrow(FSTL2_DESIGN) == 8L, "design table has 8 rows")
chk(length(protOn) == 4L, "exactly 4 protection-ON cells")
chk(length(protOf) == 4L, "exactly 4 protection-OFF cells")

# --- 2. the design is a full 2^3 of scenarios (2 checks) ---------------------
expected <- sort(as.vector(outer(
  c("BioOnXJPded", "BioNone"),
  as.vector(outer(c("Prot", "NoProt"), c("DietEL", "DietOff"),
                  function(p, d) paste0(p, "_", d))),
  function(b, pd) paste0("FSTL7_CPon_", b, "_", pd))))
chk(identical(sort(cells), expected), "cells are exactly the 2x2x2 bio x prot x diet set")
chk(!any(duplicated(cells)), "no duplicated cell name")

# --- 3. THE force_replace GUARD (3 checks) -----------------------------------
chk(!any(grepl("^FSTL[23456]_", names(FST_LEVERS_SCENARIOS))),
    "no FSTL2..6 cell appears in the scenario list (force_replace would delete it)")
chk(!any(grepl("^FSTL[23456]_", FST_LEVERS_TCBAU_SCENARIOS)),
    "no FSTL2..6 cell appears in the TCbau list")
chk(!"BAU" %in% names(FST_LEVERS_SCENARIOS),
    "the rev4.131 BAU is not in this arm's scenario list")

# --- 4. the tau pin is this arm's own BAU (3 checks) -------------------------
chk(identical(FST_LEVERS_BAU, "BAU7"), "FST_LEVERS_BAU names BAU7")
chk(FST_LEVERS_BAU %in% names(FST_LEVERS_SCENARIOS), "BAU7 is in the scenario list")
source("scripts/start/projects/fst_levers_config.R", local = (base <- new.env()))
chk(identical(FST_LEVERS_SCENARIOS[[FST_LEVERS_BAU]], base$FST_LEVERS_SCENARIOS$BAU),
    "BAU7 carries exactly the base config's BAU switches")

# --- 5. the BII instrument, per cell (4 x 4 + 4 x 3 = 28 checks) -------------
# 18 timesteps, 1995..2050 by 5 then 2055..2100. Hard-coded rather than read from a
# gdx so this runs before any model does.
TIMESTEPS <- c(seq(1995, 2050, 5), 2055, 2060, 2070, 2080, 2090, 2100)
for (s in protOn) {
  blk <- FST_LEVERS_SCENARIOS[[s]]
  chk(identical(blk$c44_bii_decrease, 0), paste0(s, ": no net loss (c44_bii_decrease = 0)"))
  chk(identical(blk$s44_bii_target, 0),   paste0(s, ": no numeric BII floor"))
  chk(blk$s44_start_year %in% TIMESTEPS && blk$s44_start_year > 2025,
      paste0(s, ": s44_start_year on the timestep grid and after sm_fix_SSP2 = 2025"))
  chk(identical(blk$c22_protect_scenario, "GSN_HalfEarth") &&
        identical(blk$s29_snv_shr, 0.2) && identical(blk$c42_env_flow_policy, "on"),
      paste0(s, ": the other three limbs of the bundle are on"))
}
for (s in protOf) {
  blk <- FST_LEVERS_SCENARIOS[[s]]
  chk(identical(blk$c44_bii_decrease, 1),
      paste0(s, ": BII may decrease (the no-net-loss branch has no target guard)"))
  chk(identical(blk$s44_bii_target, 0), paste0(s, ": no numeric BII floor"))
  chk(identical(blk$c22_protect_scenario, "none") &&
        identical(blk$s29_snv_shr, 0) && identical(blk$c42_env_flow_policy, "off"),
      paste0(s, ": the other three limbs of the bundle are off"))
}

# --- 6. nothing but the BII limb differs from FSTL6 (8 x 2 = 16 checks) ------
# .fstl6 is still in scope: the v7 config sources the v6 config.
for (s in cells) {
  new <- FST_LEVERS_SCENARIOS[[s]]
  old <- .fstl6[[sub("^FSTL7_", "FSTL6_", s)]]
  chk(setequal(names(new), names(old)), paste0(s, ": same switch names as its FSTL6 twin"))
  differs <- names(new)[!mapply(identical, new, old[names(new)])]
  want    <- if (s %in% protOn) c("c44_bii_decrease", "s44_bii_target") else character(0)
  chk(setequal(differs, want),
      paste0(s, ": differs from FSTL6 in exactly {", paste(want, collapse = ", "),
             "} (found: ", paste(differs, collapse = ", "), ")"))
}

# --- 7. no collision with anything on disk (2 checks) ------------------------
# A finished FSTL7 run is skipped by the orchestrator, so its folder is expected
# on a second pass; anything else under these titles would be deleted.
titles <- c(vapply(names(FST_LEVERS_SCENARIOS), tcRunName, character(1), "TCendo"),
            vapply(FST_LEVERS_TCBAU_SCENARIOS,  tcRunName, character(1), "TCbau"))
chk(length(titles) == 17L && !any(duplicated(titles)), "17 distinct run titles")
onDisk   <- intersect(titles, list.files("output"))
finished <- vapply(onDisk, function(t) {
  rs <- file.path("output", t, "runstatistics.rda")
  if (!file.exists(rs)) return(FALSE)
  e <- new.env(); load(rs, envir = e); !is.null(e$stats$modelstat)
}, logical(1))
chk(all(finished),
    paste0("every FSTL7 title already on disk is a FINISHED run (unfinished: ",
           paste(onDisk[!finished], collapse = ", "), ")"))

# --- 8. the BAU-only gate (2 checks) -----------------------------------------
# LAST on purpose: the nested source() calls of the config stack evaluate in the
# global environment, so this re-sourcing overwrites the globals used above.
Sys.setenv(FSTL7_BAU_ONLY = "1")
source("scripts/start/projects/fst_levers_v7_config.R", local = (gate <- new.env()))
Sys.unsetenv("FSTL7_BAU_ONLY")
chk(identical(names(gate$FST_LEVERS_SCENARIOS), "BAU7"), "FSTL7_BAU_ONLY leaves BAU7 alone")
chk(length(gate$FST_LEVERS_TCBAU_SCENARIOS) == 0L, "FSTL7_BAU_ONLY leaves no TCbau run")

cat("\nFSTL7 titles:\n  ", paste(titles, collapse = "\n  "), "\n\n", sep = "")
cat("checks run: ", n_checks, " (expected ", EXPECTED_CHECKS, "), failures: ", n_fail, "\n", sep = "")
if (n_checks != EXPECTED_CHECKS)
  stop("assertion COUNT mismatch: ran ", n_checks, ", expected ", EXPECTED_CHECKS)
if (n_fail > 0) stop(n_fail, " assertion(s) failed.")
cat("fst_levers v7 config OK.\n")
