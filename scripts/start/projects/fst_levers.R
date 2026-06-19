# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# ----------------------------------------------------------
# description: forest protection x bioenergy x TC under a food system transformation
# position: 6
# ----------------------------------------------------------
#
# Orchestrator for the fst_levers experiment. See
# scripts/start/projects/fst_levers_README.md for the methods writeup.
#
# Scenarios are defined in fst_levers_config.R. The experiment runs:
#   - Phase 1: one endogenous-TC run per scenario (<scen>_TCendo)
#   - Phase 2: for each FST cell, a run with tau pinned to BAU's
#              trajectory (<scen>_TCbau), via cfg$gms$tc = "exo" and the
#              Module 13 exo input file populated from BAU's GDX.
#
# Final inventory: 1 BAU + 4 FST cells x 2 TC states = 9 runs.
#
# Usage (local, from the magpie repo root):
#   FST_LEVERS_PARALLEL=3 Rscript scripts/start/projects/fst_levers.R
#
# Idempotent: runs that already have a runstatistics.rda with `modelstat`
# set are skipped. To force a re-run, delete the output/<title>/ folder.
#
# Local execution mechanics:
#   cfg$sequential <- FALSE   -> Rscript submit.R launches GAMS in background;
#                                start_run() returns once prep is done.
#   start_run() prep is serialised via gms::model_lock (one prep at a time).
#   gms::singleGAMSfile() embeds the contents of f13_tau_scenario.csv into
#     the run's own full.gms, so subsequent runs can safely overwrite the CSV.
#
# Up to MAX_PARALLEL GAMS jobs run concurrently, polled for completion via
# runstatistics.rda (canonical "GAMS exited" signal -- see runCompleted()).

suppressMessages({
  library(lucode2)
  library(gms)
  library(gdx2)
  library(magpie4)
  library(magclass)
})

source("scripts/start_functions.R")
source("scripts/start/projects/fst_levers_config.R")
source("scripts/output/extra/pin_bau_tau.R")

# ---- knobs ------------------------------------------------------------------

MAX_PARALLEL <- as.integer(Sys.getenv("FST_LEVERS_PARALLEL", "4"))

# Default "coup2100" matches the MAgPIE default (17 timesteps to 2100).
TIMESTEPS <- Sys.getenv("FST_LEVERS_TIMESTEPS", "coup2100")

POLL_SECONDS    <- 60L
MAX_WAIT_HOURS  <- 24L

# ---- base cfg ---------------------------------------------------------------

source("config/default.cfg")

cfg$info$flag         <- "FSTL"
cfg$results_folder    <- "output/:title:"
cfg$force_replace     <- TRUE
cfg$force_download    <- FALSE
cfg$sequential        <- FALSE  # background GAMS execution; start_run returns after prep

cfg$gms$c_timesteps   <- TIMESTEPS

cfg <- gms::setScenario(cfg, c("SSP2", "NPI"))

# ---- helpers ----------------------------------------------------------------

#' Has a run finished GAMS solving? Uses runstatistics.rda's `modelstat`
#' field, which submit.R populates immediately after GAMS returns, BEFORE
#' postprocessing starts. Using modelstat (not timeGAMSEnd) lets us free a
#' parallel slot as soon as the GAMS solve is done.
runCompleted <- function(title) {
  rs <- file.path("output", title, "runstatistics.rda")
  if (!file.exists(rs)) return(FALSE)
  e <- new.env()
  res <- try(load(rs, envir = e), silent = TRUE)
  if (inherits(res, "try-error")) return(FALSE)
  !is.null(e$stats$modelstat)
}

#' Did all timesteps of a completed run solve feasibly?
#' Returns TRUE / FALSE / NA (NA if no readable signal).
runFeasible <- function(title) {
  rs <- file.path("output", title, "runstatistics.rda")
  ms <- NULL
  if (file.exists(rs)) {
    e <- new.env()
    if (!inherits(try(load(rs, envir = e), silent = TRUE), "try-error")) {
      ms <- e$stats$modelstat
    }
  }
  if (is.null(ms)) {
    gdx <- file.path("output", title, "fulldata.gdx")
    if (!file.exists(gdx)) return(NA)
    ms <- try(magpie4::modelstat(gdx), silent = TRUE)
    if (!is.magpie(ms)) return(NA)
  }
  ms_num <- as.numeric(ms)
  ms_num <- ms_num[ms_num != 0]
  if (length(ms_num) == 0) return(NA)
  all(ms_num %in% c(2, 7))
}

waitForSlot <- function(in_flight, cap, started_at) {
  if (length(in_flight) < cap) return(in_flight)
  repeat {
    done <- vapply(in_flight, runCompleted, logical(1))
    if (any(done)) {
      for (t in in_flight[done]) {
        feas <- runFeasible(t)
        feas_str <- if (is.na(feas)) "UNKNOWN" else if (feas) "FEASIBLE" else "INFEASIBLE"
        message(sprintf("[%s] DONE: %s -> %s", format(Sys.time()), t, feas_str))
      }
      in_flight <- in_flight[!done]
      if (length(in_flight) < cap) return(in_flight)
    }
    for (t in names(started_at)) {
      if (t %in% in_flight && difftime(Sys.time(), started_at[[t]], units = "hours") > MAX_WAIT_HOURS) {
        warning("Run ", t, " has been in-flight for >",
                MAX_WAIT_HOURS, "h; manual inspection recommended")
      }
    }
    Sys.sleep(POLL_SECONDS)
  }
}

waitForAll <- function(in_flight, started_at) {
  while (length(in_flight) > 0) {
    in_flight <- waitForSlot(in_flight, cap = 1, started_at = started_at)
  }
}

launchRun <- function(cfg, title) {
  cfg$title <- title
  message(sprintf("[%s] LAUNCH: %s", format(Sys.time()), title))
  start_run(cfg, codeCheck = FALSE, lock_timeout = 60)
  title
}

# ---- Phase 1: endogenous-TC runs (TCendo) -----------------------------------

message("\n========== Phase 1: endogenous-TC runs (TCendo) ==========")
scen_names <- names(FST_LEVERS_SCENARIOS)

in_flight  <- character(0)
started_at <- list()

for (scen in scen_names) {
  title <- tcRunName(scen, "TCendo")
  if (runCompleted(title)) {
    message(sprintf("[%s] SKIP (already completed): %s", format(Sys.time()), title))
    next
  }
  in_flight <- waitForSlot(in_flight, MAX_PARALLEL, started_at)
  run_cfg <- applyTCScenario(cfg, scen)
  launchRun(run_cfg, title)
  in_flight        <- c(in_flight, title)
  started_at[[title]] <- Sys.time()
}

waitForAll(in_flight, started_at)

# Sanity check that BAU produced a usable tau (needed for Phase 2)
bau_title <- tcRunName("BAU", "TCendo")
if (!isTRUE(runFeasible(bau_title))) {
  stop("Phase 1 BAU run ", bau_title, " did not solve feasibly; ",
       "cannot continue to Phase 2 (BAU tau is the pin target).")
}
bau_gdx <- file.path("output", bau_title, "fulldata.gdx")

# ---- Phase 2: BAU-pinned TC runs (TCbau) ------------------------------------

message("\n========== Phase 2: BAU-pinned TC runs (TCbau) ==========")

# Phase 2 launches one TCbau run per transition scenario. We stage BAU's
# tau into modules/13_tc/input/f13_tau_scenario.csv just before each
# launch; start_run() then embeds the CSV into that run's full.gms during
# prep, so subsequent iterations can safely overwrite the CSV.

in_flight  <- character(0)
started_at <- list()

for (scen in FST_LEVERS_TCBAU_SCENARIOS) {
  title <- tcRunName(scen, "TCbau")

  if (runCompleted(title)) {
    message(sprintf("[%s] SKIP (already completed): %s", format(Sys.time()), title))
    next
  }

  in_flight <- waitForSlot(in_flight, MAX_PARALLEL, started_at)

  pinTauToBAU(bau_gdx)

  run_cfg <- applyTCScenario(cfg, scen)
  run_cfg <- applyExoTCFlags(run_cfg)
  launchRun(run_cfg, title)

  in_flight        <- c(in_flight, title)
  started_at[[title]] <- Sys.time()
}

waitForAll(in_flight, started_at)

# ---- Summary ----------------------------------------------------------------

message("\n========== Summary ==========")
summary_rows <- list()

for (scen in names(FST_LEVERS_SCENARIOS)) {
  title <- tcRunName(scen, "TCendo")
  summary_rows[[length(summary_rows) + 1]] <- data.frame(
    scenario = scen, tc_state = "TCendo", title = title,
    feasible = runFeasible(title), stringsAsFactors = FALSE)
}
for (scen in FST_LEVERS_TCBAU_SCENARIOS) {
  title <- tcRunName(scen, "TCbau")
  summary_rows[[length(summary_rows) + 1]] <- data.frame(
    scenario = scen, tc_state = "TCbau", title = title,
    feasible = runFeasible(title), stringsAsFactors = FALSE)
}

summary_df <- do.call(rbind, summary_rows)
print(summary_df, row.names = FALSE)

saveRDS(summary_df, "output/fst_levers_summary.rds")

message("\nDone. Run scripts/output/projects/fst_levers_plot.R to generate plots.")
