# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# ----------------------------------------------------------
# description: climate x bioenergy x land+water protection x diet x TC under a food system transformation
# position: 6
# ----------------------------------------------------------
#
# Orchestrator for the fst_levers experiment. See
# scripts/start/projects/fst_levers_README.md for the methods writeup and
# scripts/start/projects/fst_levers_config.R for the scenario definitions.
#
#   Phase 1: one endogenous-TC run per scenario (<scen>_TCendo), 13 runs
#   Phase 2: for each FST cell, a run with tau pinned to BAU's trajectory
#            (<scen>_TCbau) via cfg$gms$tc = "exo" and the Module 13 exo input
#            file populated from BAU's GDX, 12 runs
#
# Final inventory: 1 BAU + 12 FST cells x 2 TC states = 25 runs.
#
# Run counts are DERIVED from the config (names(FST_LEVERS_SCENARIOS) and
# FST_LEVERS_TCBAU_SCENARIOS); nothing here is hard-coded to the factor design,
# so a change in the number of factors or cells needs no edit to this file.
#
# Usage:
#   FST_LEVERS_QOS=short Rscript scripts/start/projects/fst_levers.R
#   FST_LEVERS_DRYRUN=1  Rscript scripts/start/projects/fst_levers.R   # show, do not submit
#
#   FST_LEVERS_CONFIG   swap the scenario list (default: fst_levers_config.R).
#                       A config may also define fstLeversBaseOverrides(cfg) for
#                       arm-level settings; see fst_levers_v2_config.R.
#   FST_LEVERS_SUMMARY  where to write the summary rds (default:
#                       output/fst_levers_summary.rds). Set it for a second arm,
#                       or that arm's summary overwrites the main batch's.
#
# ON THE CLUSTER, run this script itself as a batch job (or under tmux/nohup):
# it polls for hours, and a foreground R process on a login node is reaped on
# logout. Submit it to a qos with no 24 h wall limit (e.g. "SLURM medium").
#
# Idempotent: runs that already have a runstatistics.rda with `modelstat`
# set are skipped. To force a re-run, delete the output/<title>/ folder.
# Do NOT re-launch while jobs are in flight: cfg$results_folder has no :date:
# and cfg$force_replace is TRUE, so a relaunch deletes a live job's folder.
#
# Execution mechanics:
#   * start_run() takes the sbatch branch whenever srun exists and
#     cfg$sequential is FALSE (scripts/start_functions.R), and returns as soon
#     as the job is QUEUED. It runs GAMS in a local background process only on a
#     machine without SLURM.
#   * Concurrency is therefore SLURM's job, not ours. We submit a whole phase at
#     once (with a small stagger) instead of throttling submissions: a
#     submission cap would turn one wave into several sequential waves of
#     (queue wait + solve) for no benefit. A cap still applies when running
#     locally without SLURM, where processes really do compete for the machine.
#   * start_run() prep is serialised via gms::model_lock (one prep at a time),
#     which is why the stagger exists.
#   * gms::singleGAMSfile() embeds the contents of f13_tau_scenario.csv into the
#     run's own full.gms during prep, BEFORE sbatch, so overwriting the shared
#     CSV between launches is safe under SLURM too.

suppressMessages({
  library(lucode2)
  library(gms)
  library(gdx2)
  library(magpie4)
  library(magclass)
})

source("scripts/start_functions.R")
# The scenario list is swappable so a second arm of the experiment can reuse this
# orchestrator without forking it. Defaults to the main config, so an unchanged
# invocation behaves exactly as before.
source(Sys.getenv("FST_LEVERS_CONFIG", "scripts/start/projects/fst_levers_config.R"))
source("scripts/output/extra/pin_bau_tau.R")

# ---- knobs ------------------------------------------------------------------

SLURM  <- lucode2::SystemCommandAvailable("srun")
DRYRUN <- nzchar(Sys.getenv("FST_LEVERS_DRYRUN"))

# Concurrency cap. Unlimited under SLURM (the scheduler is the throttle);
# a real cap only when GAMS processes share this machine.
MAX_PARALLEL <- if (SLURM) Inf else as.integer(Sys.getenv("FST_LEVERS_PARALLEL", "3"))

# Seconds between submissions. Prep is serialised by the model lock anyway;
# the stagger just keeps the lock queue orderly.
STAGGER_SECONDS <- as.integer(Sys.getenv("FST_LEVERS_STAGGER", "10"))

# "coup2100" = 18 timesteps to 2100 (core/sets.gms), the MAgPIE default.
TIMESTEPS <- Sys.getenv("FST_LEVERS_TIMESTEPS", "coup2100")

POLL_SECONDS   <- 60L
# Per-run deadline. A job killed by wall time, preemption or OOM never writes
# modelstat (submit.R stops before that), so without a deadline the poll loop
# would spin forever. Must exceed the submit script's own 24 h wall limit plus
# realistic queue time.
MAX_WAIT_HOURS <- as.numeric(Sys.getenv("FST_LEVERS_MAX_WAIT_HOURS", "30"))

# ---- base cfg ---------------------------------------------------------------

source("config/default.cfg")

cfg$info$flag         <- "FSTL"
cfg$results_folder    <- "output/:title:"
cfg$force_replace     <- TRUE
cfg$force_download    <- FALSE
cfg$sequential        <- FALSE

cfg$gms$c_timesteps   <- TIMESTEPS

# Explicit qos. Left NULL, start_run's auto-selector falls back to "standby",
# which is PREEMPTIBLE - wrong for a batch with a deadline. It also never picks
# a _highMem variant. Override with FST_LEVERS_QOS if memory or slots bite.
if (SLURM) cfg$qos <- Sys.getenv("FST_LEVERS_QOS", "short")

# Drop extra/disaggregation. It runs INSIDE the SLURM job, after GAMS, against
# the same wall-time and memory budget, and produces gridded output this
# experiment does not use (every outcome is a global or regional aggregate).
# Keeping it is the main OOM path, and an OOM kill triggers the no-modelstat
# hang the deadline above guards against.
cfg$output <- c("output_check", "rds_report")

# Scenario columns FIRST, experiment switches AFTER: applyTCScenario must win.
# (SSP2 sets c56_emis_policy and c60_res_2ndgenBE_dem; the config deliberately
# overrides the former and inherits the latter.) Do not reorder.
cfg <- gms::setScenario(cfg, c("SSP2", "NPI"))

# Arm-level base overrides, if the loaded config defines them. Deliberately AFTER
# setScenario (so an override wins over an SSP2 scenario column) and BEFORE
# applyTCScenario (so a per-cell block still wins over an arm-level default).
# The main config defines no such function, so this is inert for it.
if (exists("fstLeversBaseOverrides", mode = "function")) {
  message("Applying arm-level base overrides from the loaded scenario config.")
  cfg <- fstLeversBaseOverrides(cfg)
}

# ---- helpers ----------------------------------------------------------------

#' Has a run finished GAMS solving? Uses runstatistics.rda's `modelstat`, which
#' submit.R populates immediately after GAMS returns and BEFORE postprocessing,
#' so a slot frees as soon as the solve is done.
runCompleted <- function(title) {
  rs <- file.path("output", title, "runstatistics.rda")
  if (!file.exists(rs)) return(FALSE)
  e <- new.env()
  if (inherits(try(load(rs, envir = e), silent = TRUE), "try-error")) return(FALSE)
  !is.null(e$stats$modelstat)
}

#' Did ALL timesteps of a run solve feasibly? TRUE / FALSE / NA.
#'
#' Zeros are NOT filtered out. fulldata.gdx is written inside the timestep loop
#' (core/calculations.gms), so a killed run leaves a partial gdx whose unsolved
#' timesteps read as modelstat 0. Dropping them would report a truncated run as
#' FEASIBLE - and this function gates pinTauToBAU, so a truncated BAU would
#' silently become the pin target for all six TCbau runs.
runFeasible <- function(title) {
  rs <- file.path("output", title, "runstatistics.rda")
  ms <- NULL
  if (file.exists(rs)) {
    e <- new.env()
    if (!inherits(try(load(rs, envir = e), silent = TRUE), "try-error")) ms <- e$stats$modelstat
  }
  if (is.null(ms)) {
    gdx <- file.path("output", title, "fulldata.gdx")
    if (!file.exists(gdx)) return(NA)
    ms <- try(magpie4::modelstat(gdx), silent = TRUE)
    if (!is.magpie(ms)) return(NA)
  }
  ms_num <- as.numeric(ms)
  if (length(ms_num) == 0) return(NA)
  all(ms_num %in% c(2, 7))
}

feasLabel <- function(title) {
  f <- runFeasible(title)
  if (is.na(f)) "UNKNOWN" else if (f) "FEASIBLE" else "INFEASIBLE"
}

launchRun <- function(run_cfg, title) {
  run_cfg$title <- title
  if (DRYRUN) {
    message(sprintf("[DRYRUN] would launch: %s", title))
    return(title)
  }
  message(sprintf("[%s] LAUNCH: %s", format(Sys.time()), title))
  start_run(run_cfg, codeCheck = FALSE, lock_timeout = 1)  # lock_timeout is HOURS
  title
}

#' Submit a whole phase. `prelaunch` runs immediately before each start_run,
#' used by Phase 2 to stage BAU's tau into the Module 13 input CSV.
launchPhase <- function(scenarios, tc_state, exo = FALSE, prelaunch = NULL) {
  launched <- character(0)
  started  <- list()
  for (scen in scenarios) {
    title <- tcRunName(scen, tc_state)
    if (runCompleted(title)) {
      message(sprintf("[%s] SKIP (already completed): %s", format(Sys.time()), title))
      next
    }
    # Only relevant without SLURM; Inf under SLURM makes this a no-op.
    if (length(launched) >= MAX_PARALLEL) {
      w <- waitForAny(launched, started)
      launched <- w$pending; started <- w$started
    }
    if (is.function(prelaunch)) prelaunch()
    run_cfg <- applyTCScenario(cfg, scen)
    if (exo) run_cfg <- applyExoTCFlags(run_cfg)
    launchRun(run_cfg, title)
    launched        <- c(launched, title)
    started[[title]] <- Sys.time()
    if (!DRYRUN && STAGGER_SECONDS > 0) Sys.sleep(STAGGER_SECONDS)
  }
  list(pending = launched, started = started)
}

#' Poll until at least one pending run completes or passes its deadline.
#' Returns the still-pending set. A run past MAX_WAIT_HOURS is DROPPED from the
#' pending set (and reported), so the batch continues instead of hanging.
waitForAny <- function(pending, started) {
  if (length(pending) == 0) return(list(pending = pending, started = started))
  repeat {
    done <- vapply(pending, runCompleted, logical(1))
    if (any(done)) {
      for (t in pending[done]) {
        message(sprintf("[%s] DONE: %s -> %s", format(Sys.time()), t, feasLabel(t)))
      }
      return(list(pending = pending[!done], started = started))
    }
    overdue <- vapply(pending, function(t) {
      !is.null(started[[t]]) &&
        difftime(Sys.time(), started[[t]], units = "hours") > MAX_WAIT_HOURS
    }, logical(1))
    if (any(overdue)) {
      for (t in pending[overdue]) {
        warning("Run ", t, " exceeded ", MAX_WAIT_HOURS,
                "h with no modelstat (killed, preempted or OOM?); giving up on it.",
                call. = FALSE)
        message(sprintf("[%s] ABANDONED: %s", format(Sys.time()), t))
      }
      return(list(pending = pending[!overdue], started = started))
    }
    Sys.sleep(POLL_SECONDS)
  }
}

waitForAll <- function(pending, started) {
  while (length(pending) > 0) {
    w <- waitForAny(pending, started)
    pending <- w$pending; started <- w$started
  }
  invisible(TRUE)
}

#' Block until ONE specific run finishes (or its deadline passes).
waitForRun <- function(title, started) {
  pending <- title
  while (length(pending) > 0) {
    w <- waitForAny(pending, started)
    pending <- w$pending; started <- w$started
  }
  invisible(TRUE)
}

# ---- Phase 1: endogenous-TC runs (TCendo) -----------------------------------

message(sprintf("\n========== Phase 1: endogenous-TC runs (TCendo) ==========\n%s | qos=%s | cap=%s",
                if (SLURM) "SLURM detected: submitting whole phase" else "no SLURM: local background",
                if (SLURM) cfg$qos else "n/a",
                if (is.finite(MAX_PARALLEL)) MAX_PARALLEL else "unlimited"))

p1 <- launchPhase(names(FST_LEVERS_SCENARIOS), "TCendo")

bau_title <- tcRunName("BAU", "TCendo")

if (DRYRUN) {
  message("\n[DRYRUN] Phase 2 would launch: ",
          paste(vapply(FST_LEVERS_TCBAU_SCENARIOS, tcRunName, character(1), "TCbau"),
                collapse = ", "))
  quit(save = "no")
}

# Phase 2's ONLY dependency is BAU's gdx, so wait for BAU alone rather than for
# the whole phase. The other Phase-1 runs keep solving in parallel.
if (bau_title %in% p1$pending) {
  message(sprintf("\n[%s] Waiting for %s (Phase 2 pin target) ...", format(Sys.time()), bau_title))
  waitForRun(bau_title, p1$started)
  p1$pending <- setdiff(p1$pending, bau_title)
}

if (!isTRUE(runFeasible(bau_title))) {
  stop("Phase 1 BAU run ", bau_title, " did not solve feasibly (", feasLabel(bau_title),
       "); cannot continue to Phase 2 (BAU tau is the pin target).")
}
bau_gdx <- file.path("output", bau_title, "fulldata.gdx")

# ---- Phase 2: BAU-pinned TC runs (TCbau) ------------------------------------

message("\n========== Phase 2: BAU-pinned TC runs (TCbau) ==========")

p2 <- launchPhase(FST_LEVERS_TCBAU_SCENARIOS, "TCbau", exo = TRUE,
                  prelaunch = function() pinTauToBAU(bau_gdx))

# ---- wait for everything still in flight ------------------------------------

waitForAll(c(p1$pending, p2$pending), c(p1$started, p2$started))

# ---- Summary ----------------------------------------------------------------

message("\n========== Summary ==========")
summary_rows <- list()

addRow <- function(scen, tc_state) {
  title <- tcRunName(scen, tc_state)
  data.frame(scenario = scen, tc_state = tc_state, title = title,
             completed = runCompleted(title), feasible = runFeasible(title),
             stringsAsFactors = FALSE)
}
for (scen in names(FST_LEVERS_SCENARIOS)) {
  summary_rows[[length(summary_rows) + 1]] <- addRow(scen, "TCendo")
}
for (scen in FST_LEVERS_TCBAU_SCENARIOS) {
  summary_rows[[length(summary_rows) + 1]] <- addRow(scen, "TCbau")
}

summary_df <- do.call(rbind, summary_rows)
print(summary_df, row.names = FALSE)

# Per-arm summary path, so a second arm cannot overwrite the main batch's summary.
saveRDS(summary_df, Sys.getenv("FST_LEVERS_SUMMARY", "output/fst_levers_summary.rds"))

n_ok <- sum(summary_df$feasible %in% TRUE)  # %in% treats NA as no-match
message(sprintf("\n%d/%d runs feasible.", n_ok, nrow(summary_df)))
if (n_ok < nrow(summary_df)) {
  message("Missing or infeasible corners are EXPECTED to be surfaced, not dropped: ",
          "fst_levers_plot.R refuses to interpret any effect whose inclusion-exclusion ",
          "sum touches a missing cell.")
}
message("\nDone. Run scripts/output/projects/fst_levers_plot.R to generate plots.")
