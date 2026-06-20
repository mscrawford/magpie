# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# fst_levers_verify_switches.R
#
# Verify that the Module 22 (forest protection) and Module 60 (2nd-gen
# bioenergy) config switches actually took effect in each solved run's
# fulldata.gdx. Derived from a realization-code audit of area_based_apr22 (M22)
# and 1st2ndgen_priced_feb24 (M60). Run after the batch from the clone root:
#   Rscript scripts/output/projects/fst_levers_verify_switches.R
#
# Symbols (all plain parameters; carry the full t trajectory; in fulldata.gdx):
#   i60_bioenergy_dem(t,i)       mio GJ/yr  exogenous 2nd-gen DEDICATED demand floor
#   i60_res_2ndgenBE_dem(t,i)    mio GJ/yr  residue-BE demand floor (separate lever)
#   pm_land_conservation(t,j,land,consv_type)  mio ha  operative protection interface
#   p35_min_forest(t,j)          mio ha     c35 NPI avoided-deforestation min forest
#
# Nuances baked into the checks (from the audit):
#  - BioOff zeros i60_bioenergy_dem only in FUTURE years (t > 2025); fixed years
#    (<= 2025) carry the SSP2-NPi2025 harmonization in BOTH arms. So the "~0"
#    test is on FUTURE years (>= 2030): BioOff ~0 vs BioOn >> 0. A nonzero BioOff
#    future demand means the floor s60_2ndgen_bioenergy_dem_min leaked back in.
#  - Protection discriminator = pm_land_conservation[,,"protect"] summed over the
#    natveg pools {primforest, secdforest, other}: Protect RAMPS 2025->2050,
#    NoProtect is flat after 2025 (WDPA baseline only). p22_add_consv["30by30"]
#    is populated in ALL arms (computed pre-selection) so it is NOT a discriminator.
#  - p35_min_forest must be ~equal across arms (NPI avoided-deforestation stays on
#    in both; the contrast is specifically the 30by30 area lever).

suppressMessages({ library(gdx2); library(magclass) })

OUT     <- "output"
NATVEG  <- c("primforest", "secdforest", "other")
TOL_GJ  <- 1.0     # mio GJ/yr: "~0" threshold for future dedicated/residue demand
TOL_MHA <- 50.0    # mio ha: separates WDPA-baseline drift (a few Mha) from the
                   #         30by30 future ramp (~1370 Mha). Protection is read
                   #         from the SOLVED conservation area, so only feasible
                   #         runs are asserted (infeasible runs collapse to 0).

# global-per-year vector (sum over all dims except temporal), robust to set names
gloByYear <- function(x) {
  if (is.null(x)) return(NULL)
  keep_t <- 2L  # magclass temporal dim
  drop   <- setdiff(seq_along(dim(x)), keep_t)
  v <- as.numeric(dimSums(x, dim = drop))
  setNames(v, getYears(x, as.integer = TRUE))
}
atYear <- function(v, y) if (is.null(v) || !as.character(y) %in% names(v)) NA_real_ else v[[as.character(y)]]
futMax <- function(v, y0 = 2030) if (is.null(v)) NA_real_ else max(v[as.integer(names(v)) >= y0], na.rm = TRUE)
futSum <- function(v, y0 = 2030) if (is.null(v)) NA_real_ else sum(v[as.integer(names(v)) >= y0], na.rm = TRUE)

readParam <- function(gdx, name) tryCatch(gdx2::readGDX(gdx, name, react = "silent"),
                                          error = function(e) NULL)

metricsForRun <- function(gdx) {
  bd  <- readParam(gdx, "i60_bioenergy_dem")
  res <- readParam(gdx, "i60_res_2ndgenBE_dem")
  con <- readParam(gdx, "pm_land_conservation")
  mnf <- readParam(gdx, "p35_min_forest")

  ded_glo <- gloByYear(bd)
  res_glo <- gloByYear(res)
  # protection: subset consv_type "protect" and the natveg pools, then global/year
  prot_glo <- NULL
  if (!is.null(con)) {
    sub <- tryCatch(con[, , "protect"][, , NATVEG], error = function(e) NULL)
    prot_glo <- gloByYear(sub)
  }
  npi_glo <- gloByYear(mnf)

  list(
    ded_fut_max   = futMax(ded_glo),
    ded_fut_sum   = futSum(ded_glo),
    res_max       = if (is.null(res_glo)) NA_real_ else max(res_glo, na.rm = TRUE),
    prot_2025     = atYear(prot_glo, 2025),
    prot_2050     = atYear(prot_glo, 2050),
    prot_ramp     = atYear(prot_glo, 2050) - atYear(prot_glo, 2025),
    npi_2050      = atYear(npi_glo, 2050))
}

# ---- discover runs ----------------------------------------------------------
cube <- expand.grid(protection = c("Protect", "NoProtect"),
                    bioenergy  = c("BioOn", "BioOff"),
                    diet       = c("DietOn", "DietOff"),
                    tc         = c("TCendo", "TCbau"),
                    stringsAsFactors = FALSE)
cube$title <- sprintf("%s_%s_%s_%s", cube$protection, cube$bioenergy, cube$diet, cube$tc)
runs <- rbind(
  data.frame(title = "BAU_TCendo", protection = "BAU", bioenergy = "BAU", diet = "BAU",
             tc = "TCendo", stringsAsFactors = FALSE),
  cube[, c("title", "protection", "bioenergy", "diet", "tc")])
runs$gdx    <- file.path(OUT, runs$title, "fulldata.gdx")
runs$exists <- file.exists(runs$gdx)

# feasibility per run (from the orchestrator summary); protection is read from the
# solved conservation area, so infeasible runs (degenerate solution) are skipped.
feas <- tryCatch(readRDS(file.path(OUT, "fst_levers_summary.rds")), error = function(e) NULL)
isFeas <- function(title) {
  if (is.null(feas)) return(NA)
  f <- feas$feasible[feas$title == title]
  if (length(f) == 0) NA else isTRUE(f)
}

cat("fst_levers switch verification\n")
cat(sprintf("found %d / %d run gdx\n\n", sum(runs$exists), nrow(runs)))

rows <- list()
for (i in seq_len(nrow(runs))) {
  if (!runs$exists[i]) { cat(sprintf("  MISSING gdx: %s\n", runs$title[i])); next }
  m <- metricsForRun(runs$gdx[i])
  rows[[length(rows) + 1]] <- cbind(runs[i, c("title", "protection", "bioenergy", "diet", "tc")], as.data.frame(m))
}
res <- do.call(rbind, rows)
print(res, row.names = FALSE, digits = 4)

# ---- assertions on the cube cells (BAU excluded; it is a different baseline) -
cells <- res[res$protection != "BAU", ]
fail <- 0L
flag <- function(cond, msg) { cat(if (isTRUE(cond)) "  PASS" else "  FAIL", "|", msg, "\n"); if (!isTRUE(cond)) fail <<- fail + 1L }

cat("\n-- bioenergy switch --\n")
for (i in seq_len(nrow(cells))) {
  r <- cells[i, ]
  if (r$bioenergy == "BioOff") {
    flag(!is.na(r$ded_fut_max) && r$ded_fut_max < TOL_GJ,
         sprintf("%s: dedicated demand ~0 in future (max=%.3g)", r$title, r$ded_fut_max))
    flag(!is.na(r$res_max) && r$res_max < TOL_GJ,
         sprintf("%s: residue demand ~0 (max=%.3g)", r$title, r$res_max))
  } else {
    flag(!is.na(r$ded_fut_sum) && r$ded_fut_sum > TOL_GJ,
         sprintf("%s: dedicated demand present in future (sum=%.4g)", r$title, r$ded_fut_sum))
  }
}

cat("\n-- protection switch (feasible runs only; infeasible solutions are degenerate) --\n")
for (i in seq_len(nrow(cells))) {
  r <- cells[i, ]
  if (!isTRUE(isFeas(r$title))) { cat("  SKIP (infeasible):", r$title, "\n"); next }
  if (r$protection == "Protect") {
    flag(!is.na(r$prot_ramp) && r$prot_ramp > TOL_MHA,
         sprintf("%s: 30by30 ramp 2025->2050 present (%.4g Mha)", r$title, r$prot_ramp))
  } else {
    flag(!is.na(r$prot_ramp) && abs(r$prot_ramp) < TOL_MHA,
         sprintf("%s: no 30by30 ramp (flat, %.4g Mha)", r$title, r$prot_ramp))
  }
}

cat("\n-- NPI avoided-deforestation constant across arms (cross-check) --\n")
npi <- cells$npi_2050[is.finite(cells$npi_2050)]
if (length(npi) >= 2) {
  spread <- (max(npi) - min(npi)) / mean(npi)
  flag(spread < 0.05, sprintf("p35_min_forest(2050) ~equal across arms (rel. spread %.2f%%)", 100 * spread))
} else cat("  (insufficient data for NPI cross-check)\n")

cat(sprintf("\n%s\n", if (fail == 0L) "ALL SWITCH CHECKS PASSED" else sprintf("%d SWITCH CHECK(S) FAILED", fail)))
