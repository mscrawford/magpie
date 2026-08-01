# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# Pre-flight data gates for the fst_levers experiment. Run from the magpie repo
# root ON THE CLUSTER (it needs the downloaded input data):
#
#   Rscript scripts/start/projects/fst_levers_preflight.R
#
# Exits non-zero if any hard gate fails. Nothing should be launched until this
# passes.
#
# THE GATE THAT MATTERS MOST (gate 1): f22_consv_prio is a GAMS *table* read from
# consv_prio_areas.cs3. A set element declared in sets.gms but with no matching
# column in that file stays silently at 0 and behaves EXACTLY like "none". If the
# chosen protection scenario has no data, every Prot-ON run is really a Prot-OFF
# run, the protection factor is identically zero, and the entire batch is void
# while looking completely healthy. No error, no warning, no infeasibility.

source("scripts/start/projects/fst_levers_config.R")

PROT_LEVEL <- unique(vapply(FST_LEVERS_DESIGN$scenario[FST_LEVERS_DESIGN$prot == "on"],
                            function(s) FST_LEVERS_SCENARIOS[[s]]$c22_protect_scenario,
                            character(1)))
FALLBACKS <- c("BH_IFL", "IrrC_95pc_30by30", "30by30")

fails <- 0L
pass <- function(ok, label, detail = "") {
  if (!ok) fails <<- fails + 1L
  cat(sprintf("[%s] %s%s\n", if (ok) "PASS" else "FAIL", label,
              if (nzchar(detail)) paste0("\n         ", detail) else ""))
  invisible(ok)
}

cat("fst_levers pre-flight\n=====================\n")
cat("protection level under test: ", PROT_LEVEL, "\n\n", sep = "")

# ---- gate 0: is input data present at all? ---------------------------------
consv <- "modules/22_land_conservation/input/consv_prio_areas.cs3"
if (!file.exists(consv)) {
  cat("[SKIP] No input data in this checkout (", consv, " absent).\n",
      "       These gates only mean anything on the cluster. Run them there.\n", sep = "")
  quit(status = 3L)
}

# ---- gate 1: does the chosen protection scenario actually carry data? ------
readScenarioDim <- function(path) {
  x <- try(magclass::read.magpie(path), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)
  x
}
x <- readScenarioDim(consv)

if (is.null(x)) {
  # fall back to inspecting the header text
  hdr <- readLines(consv, n = 5)
  present <- vapply(c(PROT_LEVEL, FALLBACKS), function(s) any(grepl(s, hdr, fixed = TRUE)),
                    logical(1))
  pass(isTRUE(present[[PROT_LEVEL]]),
       paste0("'", PROT_LEVEL, "' appears in the header of consv_prio_areas.cs3"),
       paste("could not parse with read.magpie; header check only. Header:",
             paste(utils::head(hdr, 2), collapse = " | ")))
} else {
  # scenario labels are a SUBDIMENSION here ("GSN_HalfEarth.crop"): match on the
  # split subdim tokens and the extracted value, never the raw dotted dimnames
  # (that bug flagged present-with-data scenarios as absent).
  scen_tokens <- unique(unlist(strsplit(magclass::getNames(x), ".", fixed = TRUE)))
  sub <- try(x[, , PROT_LEVEL], silent = TRUE)
  okr <- !inherits(sub, "try-error") && length(sub) > 0
  tot <- if (okr) sum(sub, na.rm = TRUE) else NA_real_
  nz  <- if (okr) sum(sub != 0, na.rm = TRUE) else NA_integer_
  pass((PROT_LEVEL %in% scen_tokens) && !is.na(tot) && tot > 0,
       paste0("'", PROT_LEVEL, "' carries NON-ZERO area data"),
       if (!(PROT_LEVEL %in% scen_tokens)) "scenario token absent from consv_prio_areas.cs3"
       else if (is.na(tot)) "scenario present but not summable"
       else sprintf("total = %s over %s non-zero cells", format(tot), format(nz)))

  # what IS available, so a fallback can be chosen on evidence
  cand <- intersect(c(PROT_LEVEL, FALLBACKS), scen_tokens)
  cat("\n  of our candidate scenarios, present in this file: ",
      if (length(cand)) paste(cand, collapse = ", ") else "(none)", "\n\n", sep = "")

  if (fails > 0L) {
    ok_fb <- Filter(function(s) {
      v <- try(x[, , s], silent = TRUE)
      !inherits(v, "try-error") && length(v) > 0 && sum(v, na.rm = TRUE) > 0
    }, FALLBACKS)
    cat("  RECOMMENDATION: switch .prot_on$c22_protect_scenario (+ _noselect) in\n",
        "  scripts/start/projects/fst_levers_config.R to the first of: ",
        paste(ok_fb, collapse = " -> "), "\n",
        "  then re-run fst_levers_config_test.R and this script.\n\n", sep = "")
  }
}

# ---- gate 2: do the REMIND scenario tags carry data? -----------------------
checkTag <- function(path, tags, label) {
  if (!file.exists(path)) return(pass(FALSE, paste0(label, ": ", path, " absent")))
  y <- try(magclass::read.magpie(path), silent = TRUE)
  if (inherits(y, "try-error")) {
    hdr <- readLines(path, n = 5)
    ok <- all(vapply(tags, function(t) any(grepl(t, hdr, fixed = TRUE)), logical(1)))
    return(pass(ok, paste0(label, ": tags found in header"), "header check only"))
  }
  avail <- unique(unlist(strsplit(magclass::getNames(y), ".", fixed = TRUE)))
  miss  <- setdiff(tags, avail)
  pass(length(miss) == 0, paste0(label, ": both R34M410 tags present"),
       if (length(miss)) paste("missing:", paste(miss, collapse = ", ")) else "")
}
TAGS <- c("R34M410-SSP2-NPi2025", "R34M410-SSP2-PkBudg650")
checkTag("modules/56_ghg_policy/input/f56_pollutant_prices.cs3", TAGS, "carbon price (c56)")
checkTag("modules/60_bioenergy/input/f60_bioenergy_dem.cs3",     TAGS, "bioenergy demand (c60)")

# ---- gate 3: SNV input present (in the protection bundle) ------------------
snv <- "modules/29_cropland/input/avl_cropland_0.5.mz"
pass(file.exists(snv), "module 29 cropland availability input present",
     if (!file.exists(snv)) paste(snv, "absent -- SNV lever needs it") else "")

# ---- gate 4: env-flow water input present (M42, now in the bundle) ---------
# The env-flow limb of the protection factor needs f42_env_flows, loaded from
# lpj_envflow_grper.cs2 (42_water_demand/all_sectors_aug13/input.gms). Without it
# the ecosystem water demand vm_watdem.fx("ecosystem",..) has no data and the
# water lever is meaningless. Analogous to the M29 SNV gate above.
envflow <- "modules/42_water_demand/input/lpj_envflow_grper.cs2"
pass(file.exists(envflow), "module 42 environmental-flow water input present",
     if (!file.exists(envflow)) paste(envflow, "absent -- env-flow water lever needs it") else "")

# ---- verdict ---------------------------------------------------------------
cat("\n", if (fails == 0L) "PRE-FLIGHT PASSED - safe to launch\n"
     else sprintf("PRE-FLIGHT FAILED (%d gate(s)) - DO NOT LAUNCH\n", fails), sep = "")
quit(status = if (fails == 0L) 0L else 1L)
