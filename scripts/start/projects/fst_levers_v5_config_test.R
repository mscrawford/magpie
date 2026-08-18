# Assertions for the FSTL5 arm. Counted, so a block that silently iterated over
# nothing cannot pass.
#
# What this guards:
#   * The BII TARGET IS ACTUALLY LIVE. s44_start_year must be a real timestep, or
#     module 44's exact-match guard leaves the whole floor inert, which is the bug
#     this arm exists to fix. Asserted as membership in the timestep grid, not as
#     "not 2026" - a different off-grid year would be just as broken.
#   * NO LIVE RUN CAN BE DELETED. cfg$force_replace is TRUE and the orchestrator
#     skips only COMPLETE runs, so naming a still-solving run destroys it. This
#     arm's scenario list must contain no FSTL2/3/4 cell at all.
#   * No title collides with a run folder already on disk.
#   * Japan stays exempt from the dedicated ramp (twins differ, by design).

source("scripts/start/projects/fst_levers_v5_config.R")

EXPECTED_CHECKS <- 21L
n_checks <- 0L
n_fail   <- 0L
chk <- function(cond, label) {
  n_checks <<- n_checks + 1L
  if (!isTRUE(cond)) { n_fail <<- n_fail + 1L; cat("  FAIL: ", label, "\n", sep = "") }
  invisible(cond)
}

cells <- setdiff(names(FST_LEVERS_SCENARIOS), "BAU")

# --- 1. inventory (4 checks) -------------------------------------------------
chk(length(FST_LEVERS_SCENARIOS) == 5L, "5 scenarios (BAU + 4 cells)")
chk(length(FST_LEVERS_TCBAU_SCENARIOS) == 4L, "4 TCbau scenarios")
chk(all(grepl("^FSTL5_", cells)), "every cell carries the FSTL5_ prefix")
chk(nrow(FSTL2_DESIGN) == 4L, "design table has 4 rows")

# --- 2. THE force_replace GUARD (2 checks) -----------------------------------
# The reason this arm is a separate file. FSTL4 was still solving at launch.
chk(!any(grepl("^FSTL[234]_", names(FST_LEVERS_SCENARIOS))),
    "no FSTL2/3/4 cell appears in the scenario list (force_replace would delete it)")
chk(!any(grepl("^FSTL[234]_", FST_LEVERS_TCBAU_SCENARIOS)),
    "no FSTL2/3/4 cell appears in the TCbau list")

# --- 3. the BII target is live (5 checks) ------------------------------------
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

# --- 4. per-cell switches (8 checks) -----------------------------------------
for (s in cells) {
  blk <- FST_LEVERS_SCENARIOS[[s]]
  chk(identical(blk$c56_pollutant_prices, "R34M410-SSP2-PkBudg650"),
      paste0(s, ": 1.5C carbon price"))
  chk(identical(blk$c60_2ndgen_biodem, "R34M410-SSP2-PkBudg650") &&
        identical(blk$c60_2ndgen_biodem_noselect, "R34M410-SSP2-NPi2025"),
      paste0(s, ": Japan exempt from the dedicated ramp (twins differ by design)"))
}

# --- 5. no collision with anything on disk (2 checks) ------------------------
titles <- c(vapply(names(FST_LEVERS_SCENARIOS), tcRunName, character(1), "TCendo"),
            vapply(FST_LEVERS_TCBAU_SCENARIOS,  tcRunName, character(1), "TCbau"))
onDisk <- list.files("output")
clash  <- setdiff(intersect(titles, onDisk), tcRunName("BAU", "TCendo"))
chk(length(clash) == 0,
    paste0("no FSTL5 title collides with a folder on disk (found: ",
           paste(clash, collapse = ", "), ")"))
chk(tcRunName("BAU", "TCendo") %in% onDisk,
    "BAU_TCendo exists on disk, so it is skipped and reused as the Phase 2 tau pin")

cat("\nFSTL5 titles:\n  ", paste(titles, collapse = "\n  "), "\n\n", sep = "")
cat("checks run: ", n_checks, " (expected ", EXPECTED_CHECKS, "), failures: ", n_fail, "\n", sep = "")
if (n_checks != EXPECTED_CHECKS)
  stop("assertion COUNT mismatch: ran ", n_checks, ", expected ", EXPECTED_CHECKS)
if (n_fail > 0) stop(n_fail, " assertion(s) failed.")
cat("fst_levers v5 config OK.\n")
