# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# ----------------------------------------------------------
# description: marginal impact of TC in achieving food system transformation
# position: 5
# ----------------------------------------------------------
#
# Experimental design (see plan i-d-like-to-make-vast-toucan.md):
#
# Phase 1: 3 endogenous-TC reference runs (BAU, Energy, Full)
# Phase 2: 6 fixed-TC sweep runs ({Energy, Full} x f in {0, 1/2, 3/4})
#          with tau blended between BAU and the matching endogenous reference.
#
# Local execution model:
#   cfg$sequential <- FALSE   -> Rscript submit.R launches GAMS in background,
#                                 start_run() returns once prep is done.
#   start_run() prep is serialized via gms::model_lock; only one prep at a time.
#   singleGAMSfile() embeds the contents of f13_tau_scenario.csv into the
#     run's own full.gms, so subsequent runs can safely overwrite the CSV.
#
# We launch up to MAX_PARALLEL GAMS jobs concurrently, polling for completion
# via magpie4::modelstat() reads of fulldata.gdx.

suppressMessages({
  library(lucode2)
  library(gms)
  library(gdx2)
  library(magpie4)
  library(magclass)
})

source("scripts/start_functions.R")
source("scripts/start/projects/tc_vs_landuse_config.R")
source("scripts/output/extra/blend_tau.R")

# ---- knobs ------------------------------------------------------------------

# Override via env var TC_VS_LANDUSE_PARALLEL=N if you want a different cap.
MAX_PARALLEL <- as.integer(Sys.getenv("TC_VS_LANDUSE_PARALLEL", "4"))

# Override via env var TC_VS_LANDUSE_TIMESTEPS for the real runs.
# Default "coup2100" matches the MAgPIE default (17 timesteps to 2100).
# Use "5year2050" for faster turnaround (12 timesteps to 2050).
TIMESTEPS <- Sys.getenv("TC_VS_LANDUSE_TIMESTEPS", "coup2100")

# Override via env var TC_VS_LANDUSE_SMOKE=1 to run a single BAU at low
# resolution and then exit (validates the stack without burning compute).
SMOKE_ONLY <- Sys.getenv("TC_VS_LANDUSE_SMOKE", "0") == "1"

# Polling interval and per-run wall-clock budget for the wait loop.
POLL_SECONDS    <- 60L
MAX_WAIT_HOURS  <- 24L

# ---- base cfg ---------------------------------------------------------------

source("config/default.cfg")

cfg$info$flag         <- "TC"
cfg$results_folder    <- "output/:title:"
cfg$force_replace     <- TRUE
cfg$force_download    <- FALSE
cfg$sequential        <- FALSE  # background GAMS execution; start_run returns after prep

# Use the standard 5-year-to-2100 sets unless overridden
cfg$gms$c_timesteps   <- TIMESTEPS

# SSP2 + NPI baseline; transition scenarios override carbon-price / diet on top
cfg <- gms::setScenario(cfg, c("SSP2", "NPI"))

# ---- helpers ----------------------------------------------------------------

#' Has a run finished GAMS solving? Uses runstatistics.rda's `modelstat`
#' field, which submit.R populates at line 79-84 immediately after GAMS
#' returns, BEFORE postprocessing (output_check, disaggregation, etc.)
#' starts. Using modelstat (not timeGAMSEnd, which is set after
#' postprocessing) lets us free a parallel slot as soon as the heavyweight
#' GAMS solve is done. Note: fulldata.gdx is written incrementally per
#' timestep by core/calculations.gms, so its existence alone does NOT
#' imply the run is done -- the runstatistics-based check is canonical.
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
#' Reads modelstat from runstatistics.rda first (set by submit.R after GAMS
#' exits) and falls back to the GDX.
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
  # Ignore 0-valued slots (unused timesteps in the modelstat parameter array)
  ms_num <- ms_num[ms_num != 0]
  if (length(ms_num) == 0) return(NA)
  all(ms_num %in% c(2, 7))
}

#' Wait for a batch of in-flight runs to drop below `cap`, polling every
#' POLL_SECONDS. Returns the still-in-flight titles.
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
    # Watchdog: warn if any individual run has been in flight too long
    for (t in names(started_at)) {
      if (t %in% in_flight && difftime(Sys.time(), started_at[[t]], units = "hours") > MAX_WAIT_HOURS) {
        warning("Run ", t, " has been in-flight for >",
                MAX_WAIT_HOURS, "h; manual inspection recommended")
      }
    }
    Sys.sleep(POLL_SECONDS)
  }
}

#' Block until all in-flight runs complete.
waitForAll <- function(in_flight, started_at) {
  while (length(in_flight) > 0) {
    in_flight <- waitForSlot(in_flight, cap = 1, started_at = started_at)
  }
}

#' Launch one run; returns the run title.
launchRun <- function(cfg, title) {
  cfg$title <- title
  message(sprintf("[%s] LAUNCH: %s", format(Sys.time()), title))
  # lock_timeout in gms::model_lock is in minutes; 60 = 1h, plenty of slack
  start_run(cfg, codeCheck = FALSE, lock_timeout = 60)
  title
}

# ---- smoke test path --------------------------------------------------------

if (SMOKE_ONLY) {
  message("SMOKE_ONLY=1 -> running a single BAU at minimum resolution (3 timesteps)")
  smoke_cfg <- applyTCScenario(cfg, "BAU")
  smoke_cfg$gms$c_timesteps <- "quicktest"   # y1995, y2010, y2025 only
  smoke_cfg$sequential <- TRUE               # foreground/blocking so we see errors immediately
  title <- launchRun(smoke_cfg, "TC_BAU_smoke")
  if (!runCompleted(title)) {
    stop("Smoke test failed: ", title, " did not produce a readable fulldata.gdx")
  }
  message(sprintf("Smoke test OK. Feasible: %s", runFeasible(title)))
  quit(save = "no", status = 0)
}

# ---- Phase 1: endogenous-TC references --------------------------------------

message("\n========== Phase 1: endogenous-TC reference runs ==========")
scen_names_p1 <- names(TC_VS_LANDUSE_SCENARIOS)  # BAU, Energy, Full

in_flight  <- character(0)
started_at <- list()

for (scen in scen_names_p1) {
  in_flight <- waitForSlot(in_flight, MAX_PARALLEL, started_at)
  run_cfg <- applyTCScenario(cfg, scen)
  title <- tcRunName(scen)  # e.g. "TC_BAU_endo"
  launchRun(run_cfg, title)
  in_flight        <- c(in_flight, title)
  started_at[[title]] <- Sys.time()
}

waitForAll(in_flight, started_at)

# Sanity-check that the BAU and TS references produced usable taus
for (scen in scen_names_p1) {
  title <- tcRunName(scen)
  if (!isTRUE(runFeasible(title))) {
    stop("Phase 1 baseline ", title, " did not solve feasibly; ",
         "cannot continue to Phase 2.")
  }
}

bau_gdx     <- file.path("output", tcRunName("BAU"),    "fulldata.gdx")
ts_gdx_map  <- setNames(
  lapply(TC_VS_LANDUSE_SWEEP_SCENARIOS, function(s) file.path("output", tcRunName(s), "fulldata.gdx")),
  TC_VS_LANDUSE_SWEEP_SCENARIOS
)

# ---- Phase 2: fixed-TC sweep ------------------------------------------------

message("\n========== Phase 2: fixed-TC sweep ==========")

# Enumerate sweep jobs (scenario x f). We serialise tau-staging across jobs
# (the CSV is a shared input) but the GAMS solves run in parallel up to
# MAX_PARALLEL because start_run() embeds the CSV contents into the run's
# own full.gms before returning.
sweep_jobs <- do.call(rbind, lapply(TC_VS_LANDUSE_SWEEP_SCENARIOS, function(scen) {
  data.frame(scenario = scen, f = TC_VS_LANDUSE_FRACTIONS, stringsAsFactors = FALSE)
}))

in_flight  <- character(0)
started_at <- list()

for (i in seq_len(nrow(sweep_jobs))) {
  scen <- sweep_jobs$scenario[i]
  f    <- sweep_jobs$f[i]
  title <- tcRunName(scen, f)

  in_flight <- waitForSlot(in_flight, MAX_PARALLEL, started_at)

  # Stage this run's tau just before launch (start_run will embed it
  # synchronously into full.gms during prep, so the next iteration can
  # safely overwrite the CSV).
  blendTau(bau_gdx, ts_gdx_map[[scen]], f)

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

for (scen in names(TC_VS_LANDUSE_SCENARIOS)) {
  title <- tcRunName(scen)
  summary_rows[[length(summary_rows) + 1]] <- data.frame(
    scenario = scen, f = "endo (f=1)", title = title,
    feasible = runFeasible(title), stringsAsFactors = FALSE)
}
for (i in seq_len(nrow(sweep_jobs))) {
  scen <- sweep_jobs$scenario[i]
  f    <- sweep_jobs$f[i]
  title <- tcRunName(scen, f)
  summary_rows[[length(summary_rows) + 1]] <- data.frame(
    scenario = scen, f = sprintf("%.3f", f), title = title,
    feasible = runFeasible(title), stringsAsFactors = FALSE)
}

summary_df <- do.call(rbind, summary_rows)
print(summary_df, row.names = FALSE)

# Persist summary for the plotter
saveRDS(summary_df, "output/tc_vs_landuse_summary.rds")

message("\nDone. Run scripts/output/projects/tc_vs_landuse_plot.R to generate plots.")
