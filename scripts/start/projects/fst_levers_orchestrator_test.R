# Unit tests for the fst_levers.R run-status helpers.
#
# Extracts the REAL function definitions out of fst_levers.R by parsing it and
# evaluating only the `name <- function(...)` top-level assignments, so these
# tests cannot drift from the shipped code the way copy-pasted ones would.
# (Sourcing the whole file is impossible here: it sources default.cfg, loads
# magpie4/gdx2 and submits runs.)
#
# Covers the two correctness-critical fixes:
#   * runFeasible must NOT drop modelstat zeros (a truncated run is not feasible)
#   * waitForAny must ABANDON an overdue run instead of spinning forever

ORCH <- normalizePath(file.path(getwd(), "scripts/start/projects/fst_levers.R"))
stopifnot(file.exists(ORCH))

want <- c("runCompleted", "runFeasible", "feasLabel", "waitForAny")
env  <- new.env()
for (e in parse(ORCH)) {
  if (is.call(e) && length(e) == 3L &&
      as.character(e[[1]]) %in% c("<-", "=") &&
      is.name(e[[2]]) && as.character(e[[2]]) %in% want &&
      is.call(e[[3]]) && identical(as.character(e[[3]][[1]]), "function")) {
    eval(e, envir = env)
  }
}
missing <- setdiff(want, ls(env))
if (length(missing)) stop("could not extract: ", paste(missing, collapse = ", "))
cat("extracted from source:", paste(ls(env), collapse = ", "), "\n\n")

# scope the helpers need
env$MAX_WAIT_HOURS <- 1 / 3600   # 1 second, so the overdue path is testable
env$POLL_SECONDS   <- 1L
env$magpie4        <- NULL

EXPECTED_CHECKS <- 10L
n_checks <- 0L; n_fail <- 0L
chk <- function(cond, label) {
  n_checks <<- n_checks + 1L
  status <- if (isTRUE(cond)) "ok  " else { n_fail <<- n_fail + 1L; "FAIL" }
  cat("  [", status, "] ", label, "\n", sep = "")
}

# fake run tree
tmp <- file.path(tempdir(), "fstl_test"); unlink(tmp, recursive = TRUE)
dir.create(file.path(tmp, "output"), recursive = TRUE)
old <- setwd(tmp); on.exit(setwd(old), add = TRUE)

mkRun <- function(title, modelstat = NULL) {
  d <- file.path("output", title); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  stats <- list(timePrepareStart = Sys.time(), timePrepareEnd = Sys.time())
  if (!is.null(modelstat)) stats$modelstat <- modelstat
  save(stats, file = file.path(d, "runstatistics.rda"))
}

mkRun("all_feasible",  c(2, 2, 2, 2))
mkRun("mixed_2_7",     c(2, 7, 2))
mkRun("truncated",     c(2, 2, 0, 0))   # killed mid-loop: unsolved steps read 0
mkRun("infeasible",    c(2, 4, 2))
mkRun("no_modelstat")                   # job killed before submit.R wrote it

cat("runCompleted:\n")
chk(env$runCompleted("all_feasible") == TRUE,  "completed run -> TRUE")
chk(env$runCompleted("no_modelstat") == FALSE, "killed run (no modelstat) -> FALSE")
chk(env$runCompleted("does_not_exist") == FALSE, "absent run -> FALSE")

cat("\nrunFeasible:\n")
chk(env$runFeasible("all_feasible") == TRUE, "all modelstat 2 -> TRUE")
chk(env$runFeasible("mixed_2_7") == TRUE,    "modelstat 2 and 7 -> TRUE")
chk(env$runFeasible("truncated") == FALSE,
    "REGRESSION: truncated run with zeros -> FALSE (old code filtered zeros -> TRUE)")
chk(env$runFeasible("infeasible") == FALSE,  "modelstat 4 present -> FALSE")
chk(is.na(env$runFeasible("does_not_exist")), "no rda and no gdx -> NA")

cat("\nwaitForAny:\n")
w <- env$waitForAny("all_feasible", list(all_feasible = Sys.time()))
chk(identical(w$pending, character(0)), "completed run is removed from pending")

# the hang guard: a run that never writes modelstat, already past its deadline
started <- list(no_modelstat = Sys.time() - 3600)
t0 <- Sys.time()
w2 <- suppressWarnings(env$waitForAny("no_modelstat", started))
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
chk(length(w2$pending) == 0 && elapsed < 30,
    sprintf("REGRESSION: overdue run abandoned in %.1fs, not spun on forever", elapsed))

cat("\nassertions executed: ", n_checks, " (expected ", EXPECTED_CHECKS, "), failures: ",
    n_fail, "\n", sep = "")
setwd(old); unlink(tmp, recursive = TRUE)
if (n_checks != EXPECTED_CHECKS) { cat("INVALID: assertion count mismatch\n"); quit(status = 2L) }
cat(if (n_fail == 0L) "ALL CHECKS PASSED\n" else "THERE WERE FAILURES\n")
quit(status = if (n_fail == 0L) 0L else 1L)
