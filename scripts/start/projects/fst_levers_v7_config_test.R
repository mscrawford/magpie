# Assertions for the FSTL7 arm. Counted, so a block that silently iterated over
# nothing cannot pass.
#
# What this guards:
#   * THE PROTECTION LEVER IS THE BIOS BUNDLE of paper_healthyLscps.R, instrument by
#     instrument, with the one stated translation (start year 2025 for his 2020).
#     The reference values are typed here from that script, not read from the
#     config under test.
#   * NO NET LOSS ONLY WHERE PROTECTION IS ON. c44_bii_decrease = 0 has no
#     `s44_bii_target > 0` guard in module 44's presolve, so it acts wherever it is
#     set. Set in a protection-OFF cell it would put the instrument on both sides
#     of the contrast and the BII limb of the protection effect would be zero while
#     every run looked healthy.
#   * NOTHING OF THE EARLIER BUNDLE COMES THROUGH: no numeric BII floor, no
#     GSN_HalfEarth, no 2050 target year, no environmental-flow key in any cell.
#   * EVERY START AND TARGET YEAR IS ON THE TIMESTEP GRID, and the two protection
#     blocks agree on all of them, so the factor toggles instruments, not timing.
#   * OUTSIDE THE PROTECTION BLOCK EVERY CELL EQUALS ITS FSTL6 TWIN.
#   * THE TAU PIN IS THIS ARM'S OWN BAU. BAU_TCendo (rev4.131 data) must not be in
#     the scenario list; BAU7 must be, with the base BAU switches.
#   * NO LIVE OR FINISHED RUN OF AN EARLIER ARM CAN BE DELETED (force_replace).
#   * No title collides with a run folder already on disk.

source("scripts/start/projects/fst_levers_v7_config.R")

EXPECTED_CHECKS <- 66L
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

# --- 5. the bundle, per cell (4 x 6 + 4 x 4 = 40 checks) ----------------------
# 18 timesteps, 1995..2050 by 5 then 2055..2100. Hard-coded rather than read from a
# gdx so this runs before any model does.
TIMESTEPS <- c(seq(1995, 2050, 5), 2055, 2060, 2070, 2080, 2090, 2100)
# paper_healthyLscps.R, actions BIOS (lines 139-156 at upstream/develop dfe14e834),
# with s22_conservation_start and s29_snv_scenario_start moved from his 2020 to 2025
# (the fix_2025 column of config/projects/scenario_config_year_fix.csv).
BIOS <- list(c22_protect_scenario = "30by30", s22_conservation_start = 2025,
             s22_conservation_target = 2030, c44_bii_decrease = 0, s44_start_year = 2030,
             s29_snv_shr = 0.2, s29_snv_scenario_start = 2025, s29_snv_scenario_target = 2030)
YEARS <- c("s22_conservation_start", "s22_conservation_target", "s44_start_year",
           "s29_snv_scenario_start", "s29_snv_scenario_target")
OLD   <- c("c42_env_flow_policy", "s42_env_flow_scenario", "s42_efp_startyear",
           "s42_efp_targetyear", "s44_target_year")
for (s in protOn) {
  blk <- FST_LEVERS_SCENARIOS[[s]]
  chk(all(mapply(identical, blk[names(BIOS)], BIOS)),
      paste0(s, ": every BIOS instrument at its value (differs: ",
             paste(names(BIOS)[!mapply(identical, blk[names(BIOS)], BIOS)], collapse = ", "), ")"))
  chk(identical(blk$s44_bii_target, 0), paste0(s, ": no numeric BII floor"))
  chk(identical(blk$c22_protect_scenario_noselect, blk$c22_protect_scenario) &&
        identical(blk$s29_snv_shr_noselect, blk$s29_snv_shr),
      paste0(s, ": the _noselect twins equal the selected values"))
  chk(all(unlist(blk[YEARS]) %in% TIMESTEPS) && blk$s44_start_year > 2025,
      paste0(s, ": every start and target year on the timestep grid; BII start after 2025"))
  chk(!any(OLD %in% names(blk)),
      paste0(s, ": no environmental-flow key and no BII target year (found: ",
             paste(intersect(OLD, names(blk)), collapse = ", "), ")"))
  chk(identical(blk$s22_restore_land, 1), paste0(s, ": restoration at the default, 1"))
}
for (s in protOf) {
  blk <- FST_LEVERS_SCENARIOS[[s]]
  chk(identical(blk$c44_bii_decrease, 1),
      paste0(s, ": BII may decrease (the no-net-loss branch has no target guard)"))
  chk(identical(blk$c22_protect_scenario, "none") && identical(blk$s29_snv_shr, 0) &&
        identical(blk$s44_bii_target, 0),
      paste0(s, ": no conservation scenario, no SNV share, no BII floor"))
  chk(!any(OLD %in% names(blk)), paste0(s, ": no environmental-flow key and no BII target year"))
  on <- FST_LEVERS_SCENARIOS[[sub("_NoProt_", "_Prot_", s)]]
  toggled <- names(blk)[!mapply(identical, blk, on[names(blk)])]
  chk(setequal(names(blk), names(on)) &&
        setequal(toggled, c("c22_protect_scenario", "c22_protect_scenario_noselect",
                            "c44_bii_decrease", "s29_snv_shr", "s29_snv_shr_noselect")),
      paste0(s, ": differs from its protection-ON twin in the five toggles only (found: ",
             paste(toggled, collapse = ", "), ")"))
}

# --- 6. outside the protection block every cell is its FSTL6 twin (8 checks) --
# .fstl6 is still in scope: the v7 config sources the v6 config.
PROT_KEYS <- union(names(.prot_on), names(.prot_on_v7))
for (s in cells) {
  new <- FST_LEVERS_SCENARIOS[[s]]
  old <- .fstl6[[sub("^FSTL7_", "FSTL6_", s)]]
  rest <- setdiff(union(names(new), names(old)), PROT_KEYS)
  chk(length(rest) > 0 && all(mapply(identical, new[rest], old[rest])),
      paste0(s, ": identical to its FSTL6 twin on all ", length(rest), " keys outside the protection block"))
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
