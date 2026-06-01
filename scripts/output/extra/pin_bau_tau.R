# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# pin_bau_tau.R
#
# Utility for the yield-gap experiment (see
# scripts/start/projects/yield_gap.R).
#
# Extracts the endogenous land-use intensity (tau) trajectory from a
# completed BAU MAgPIE run and writes it to the Module 13 exo realization
# input file (modules/13_tc/input/f13_tau_scenario.csv). The downstream
# transition-scenario run, launched with cfg$gms$tc = "exo", then reads
# this CSV and is constrained to BAU's tau -- providing the "TC=BAU"
# counterfactual against which the scenario's endogenous-TC run (Phase 1)
# is compared.
#
# Reading ov13_tau_core directly (not magpie4::tau(type="both")) sidesteps
# the crop-only behaviour of magpie4::tau in current magpie4 (2.74.x).

suppressMessages({
  library(magclass)
  library(gdx2)
})

#' Extract the endogenous core tau trajectory from a MAgPIE GDX
#'
#' Returns a magclass object with dims (h, t, tautype) where tautype is
#' {crop, pastr}, suitable for direct writing to f13_tau_scenario.csv.
extractTau <- function(gdx_path) {
  if (!file.exists(gdx_path)) stop("GDX not found: ", gdx_path)
  x <- gdx2::readGDX(gdx_path, "ov13_tau_core", format = "first_found")
  if (is.null(x)) {
    stop("ov13_tau_core not found in ", gdx_path,
         " (this variable is only written by the endo_jan22 realization; ",
         "a run with tc='exo' will not have it)")
  }
  x <- x[, , "level"]
  magclass::collapseNames(x, collapsedim = "type")
}

#' Pin a transition scenario's tau to BAU's by writing BAU's tau to the
#' Module 13 exo input file.
#'
#' @param bau_gdx Path to BAU run's fulldata.gdx
#' @param out_csv Output path (default = the Module 13 exo realization input)
pinTauToBAU <- function(bau_gdx,
                        out_csv = "modules/13_tc/input/f13_tau_scenario.csv") {
  tau_bau <- extractTau(bau_gdx)
  dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
  write.magpie(tau_bau, out_csv)
  message(sprintf("Wrote BAU tau to %s", out_csv))
  invisible(tau_bau)
}
