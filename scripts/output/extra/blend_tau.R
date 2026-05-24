# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# blend_tau.R
#
# Utility for the "TC vs land-use change" experiment (see
# scripts/start/projects/tc_vs_landuse.R).
#
# Extracts the endogenous land-use intensity (tau) trajectories from two
# completed MAgPIE runs (BAU and a transition scenario), produces an
# elementwise blend
#
#   tau_blend(t, h, type) = tau_bau(t, h, type)
#                         + f * (tau_ts(t, h, type) - tau_bau(t, h, type))
#
# and writes the result to modules/13_tc/input/f13_tau_scenario.csv in the
# format expected by the Module 13 "exo" realization
# (modules/13_tc/exo/input.gms uses
#   table f13_tau_scenario(t_all, h, tautype) ).
#
# Reading ov13_tau_core directly (not magpie4::tau(type="both")) sidesteps the
# crop-only behaviour of magpie4::tau in current magpie4 (2.74.x).

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
  # ov13_tau_core(t,h,tautype,"type") -> subset to level slice
  x <- x[, , "level"]
  # Drop the "level" type label so dim 3 contains only {crop, pastr}
  magclass::collapseNames(x, collapsedim = "type")
}

#' Blend BAU and transition-scenario tau, and write the result to the Module
#' 13 exo input file.
#'
#' @param bau_gdx Path to BAU run's fulldata.gdx
#' @param ts_gdx  Path to transition-scenario run's fulldata.gdx
#' @param f       Blend fraction in [0,1]: 0 = pure BAU, 1 = pure TS
#' @param out_csv Output path (default = the Module 13 exo realization input)
blendTau <- function(bau_gdx, ts_gdx, f,
                     out_csv = "modules/13_tc/input/f13_tau_scenario.csv") {
  stopifnot(is.numeric(f), length(f) == 1, f >= 0, f <= 1)

  tau_bau <- extractTau(bau_gdx)
  tau_ts  <- extractTau(ts_gdx)

  # Shapes must match for elementwise blend
  if (!identical(dim(tau_bau), dim(tau_ts))) {
    stop("BAU and TS tau have different shapes: ",
         paste(dim(tau_bau), collapse = "x"), " vs ",
         paste(dim(tau_ts), collapse = "x"))
  }
  if (!identical(getYears(tau_bau), getYears(tau_ts))) {
    stop("BAU and TS tau have different year sets")
  }
  if (!identical(getRegions(tau_bau), getRegions(tau_ts))) {
    stop("BAU and TS tau have different region sets")
  }

  tau_out <- tau_bau + f * (tau_ts - tau_bau)

  # Round-trip sanity at the endpoints
  if (f == 0 && any(abs(tau_out - tau_bau) > 1e-9)) {
    stop("Blend round-trip failed at f=0 (should equal BAU)")
  }
  if (f == 1 && any(abs(tau_out - tau_ts) > 1e-9)) {
    stop("Blend round-trip failed at f=1 (should equal TS)")
  }

  # Ensure parent dir exists
  dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
  write.magpie(tau_out, out_csv)
  message(sprintf("Wrote blended tau (f = %.3f) to %s", f, out_csv))
  invisible(tau_out)
}
