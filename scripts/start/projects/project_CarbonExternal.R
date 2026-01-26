# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# ----------------------------------------------------------
# description: ESM2025 CarbonExternal - JSBACH3/JULES carbon densities with SSP scenarios
# position: 5
# ----------------------------------------------------------

## Load libraries
library(lucode2)
library(gms)

# Load start_run(cfg) function
source("scripts/start_functions.R")

# Source default cfg
source("config/default.cfg")

################################################################################
#### Project settings
################################################################################

cfg$info$flag <- "CarbonExt"
cfg$qos <- "short"
cfg$results_folder <- "output/:title:"
cfg$force_replace <- TRUE

# Title helper
.title <- function(...) paste("CarbonExt", ..., sep = "_")

################################################################################
#### SSP and Carbon Price Configuration
################################################################################
# 
# Climate scenario → SSP mapping:
#   ssp126 → SSP1 (sustainability) + medium-high carbon price
#   ssp370 → SSP2 (middle road) + no carbon price  
#   ssp585 → SSP5 (fossil-fueled) + no carbon price
#
# Carbon prices (USD2017/tCO2):
#   SSP1 + PkBudg1000: $137 (2050), $284 (2100)
#   SSP2/SSP5 + NPi:   $0 (no carbon price)
#
sspConfig <- list(
  "ssp126" = list(
    ssp = "SSP1",
    carbonPrice = "R34M410-SSP1-PkBudg1000",  # Medium-high: ~$137-284/tCO2
    priceSuffix = "medC"
  ),
  "ssp370" = list(
    ssp = "SSP2", 
    carbonPrice = "R34M410-SSP2-NPi2025",     # No carbon price
    priceSuffix = "noC"
  ),
  "ssp585" = list(
    ssp = "SSP5",
    carbonPrice = "R34M410-SSP2-NPi2025",     # No carbon price
    priceSuffix = "noC"
  )
)

################################################################################
#### Input data paths
################################################################################

# Base path for preprocessed inputs (rd3mod output folder)
basePath <- "/p/projects/rd3mod/inputdata/output_1.27"

# Regional and validation inputs (rev4.126 H12, matching MAgPIE v4.13.0)
regionalInput <- "rev4.126_h12_magpie.tgz"
validationInput <- "rev4.126_h12_validation.tgz"

# External carbon cellular inputs - rev4.126 from 2026-01-24T2031* preprocessing
# (with topsoil carbon bug fix - uses consistent topsoil from external DGVMs with proper area weighting)
externalInputs <- list(
  # JSBACH3 (6 runs: 3 GCMs × 2 SSPs - no ssp585)
  "JSBACH3-IPSL-ssp126"  = "rev4.126crawford-2026-01-24T203146_h12_d3c29a99_cellularmagpie_c200_IPSL-CM6A-LR-ssp126_lpjml-8e6c5eb1_carbon-JSBACH3-IPSL-ssp126.tgz",
  "JSBACH3-IPSL-ssp370"  = "rev4.126crawford-2026-01-24T203150_h12_25463b82_cellularmagpie_c200_IPSL-CM6A-LR-ssp370_lpjml-8e6c5eb1_carbon-JSBACH3-IPSL-ssp370.tgz",
  "JSBACH3-MPI-ssp126"   = "rev4.126crawford-2026-01-24T203153_h12_bb73ace7_cellularmagpie_c200_MPI-ESM1-2-HR-ssp126_lpjml-8e6c5eb1_carbon-JSBACH3-MPI-ssp126.tgz",
  "JSBACH3-MPI-ssp370"   = "rev4.126crawford-2026-01-24T203156_h12_808ebbd5_cellularmagpie_c200_MPI-ESM1-2-HR-ssp370_lpjml-8e6c5eb1_carbon-JSBACH3-MPI-ssp370.tgz",
  "JSBACH3-UKESM-ssp126" = "rev4.126crawford-2026-01-24T203159_h12_c6061c7c_cellularmagpie_c200_UKESM1-0-LL-ssp126_lpjml-8e6c5eb1_carbon-JSBACH3-UKESM-ssp126.tgz",
  "JSBACH3-UKESM-ssp370" = "rev4.126crawford-2026-01-24T203203_h12_c090de3b_cellularmagpie_c200_UKESM1-0-LL-ssp370_lpjml-8e6c5eb1_carbon-JSBACH3-UKESM-ssp370.tgz",
  
  # JULES (9 runs: 3 GCMs × 3 SSPs)
  "JULES-IPSL-ssp126"  = "rev4.126crawford-2026-01-24T203206_h12_b7dfe2c1_cellularmagpie_c200_IPSL-CM6A-LR-ssp126_lpjml-8e6c5eb1_carbon-JULES-IPSL-ssp126.tgz",
  "JULES-IPSL-ssp370"  = "rev4.126crawford-2026-01-24T203209_h12_ed146a40_cellularmagpie_c200_IPSL-CM6A-LR-ssp370_lpjml-8e6c5eb1_carbon-JULES-IPSL-ssp370.tgz",
  "JULES-IPSL-ssp585"  = "rev4.126crawford-2026-01-24T203212_h12_c09ea1ad_cellularmagpie_c200_IPSL-CM6A-LR-ssp585_lpjml-8e6c5eb1_carbon-JULES-IPSL-ssp585.tgz",
  "JULES-MPI-ssp126"   = "rev4.126crawford-2026-01-24T203215_h12_36738474_cellularmagpie_c200_MPI-ESM1-2-HR-ssp126_lpjml-8e6c5eb1_carbon-JULES-MPI-ssp126.tgz",
  "JULES-MPI-ssp370"   = "rev4.126crawford-2026-01-24T203218_h12_2dd89ee4_cellularmagpie_c200_MPI-ESM1-2-HR-ssp370_lpjml-8e6c5eb1_carbon-JULES-MPI-ssp370.tgz",
  "JULES-MPI-ssp585"   = "rev4.126crawford-2026-01-24T203221_h12_54dec300_cellularmagpie_c200_MPI-ESM1-2-HR-ssp585_lpjml-8e6c5eb1_carbon-JULES-MPI-ssp585.tgz",
  "JULES-UKESM-ssp126" = "rev4.126crawford-2026-01-24T203224_h12_041f43ea_cellularmagpie_c200_UKESM1-0-LL-ssp126_lpjml-8e6c5eb1_carbon-JULES-UKESM-ssp126.tgz",
  "JULES-UKESM-ssp370" = "rev4.126crawford-2026-01-24T203227_h12_df9eae95_cellularmagpie_c200_UKESM1-0-LL-ssp370_lpjml-8e6c5eb1_carbon-JULES-UKESM-ssp370.tgz",
  "JULES-UKESM-ssp585" = "rev4.126crawford-2026-01-24T203230_h12_44789193_cellularmagpie_c200_UKESM1-0-LL-ssp585_lpjml-8e6c5eb1_carbon-JULES-UKESM-ssp585.tgz"
)

# LPJmL control inputs - same GCMs/SSPs as external runs for comparison
lpjmlInputs <- list(
  # IPSL (3 SSPs)
  "LPJmL-IPSL-ssp126"  = "rev4.126crawford-2026-01-24T184322_h12_eea0ea09_cellularmagpie_c200_IPSL-CM6A-LR-ssp126_lpjml-8e6c5eb1.tgz",
  "LPJmL-IPSL-ssp370"  = "rev4.126crawford-2026-01-24T184325_h12_86ae09f1_cellularmagpie_c200_IPSL-CM6A-LR-ssp370_lpjml-8e6c5eb1.tgz",
  "LPJmL-IPSL-ssp585"  = "rev4.126crawford-2026-01-24T184328_h12_9103a4b5_cellularmagpie_c200_IPSL-CM6A-LR-ssp585_lpjml-8e6c5eb1.tgz",
  
  # MPI (3 SSPs)
  "LPJmL-MPI-ssp126"   = "rev4.126crawford-2026-01-24T184331_h12_efc26e20_cellularmagpie_c200_MPI-ESM1-2-HR-ssp126_lpjml-8e6c5eb1.tgz",
  "LPJmL-MPI-ssp370"   = "rev4.126crawford-2026-01-24T184334_h12_f432cf22_cellularmagpie_c200_MPI-ESM1-2-HR-ssp370_lpjml-8e6c5eb1.tgz",
  "LPJmL-MPI-ssp585"   = "rev4.126crawford-2026-01-24T184337_h12_b26ecd24_cellularmagpie_c200_MPI-ESM1-2-HR-ssp585_lpjml-8e6c5eb1.tgz",
  
  # UKESM (3 SSPs)
  "LPJmL-UKESM-ssp126" = "rev4.126crawford-2026-01-24T184340_h12_b53ced4d_cellularmagpie_c200_UKESM1-0-LL-ssp126_lpjml-8e6c5eb1.tgz",
  "LPJmL-UKESM-ssp370" = "rev4.126crawford-2026-01-24T184343_h12_5ce935d7_cellularmagpie_c200_UKESM1-0-LL-ssp370_lpjml-8e6c5eb1.tgz",
  "LPJmL-UKESM-ssp585" = "rev4.126crawford-2026-01-24T184346_h12_6c64d883_cellularmagpie_c200_UKESM1-0-LL-ssp585_lpjml-8e6c5eb1.tgz"
)

################################################################################
#### Add local repository for preprocessed inputs
################################################################################

# Add the preprocessed folder as a file-based repository
localRepo <- paste0("file://", basePath)
cfg$repositories <- append(
  setNames(list(NULL), localRepo),
  cfg$repositories
)

################################################################################
#### Common settings for all runs
################################################################################

# Use rev4.126 inputs
cfg$input["regional"] <- regionalInput
cfg$input["validation"] <- validationInput

# Skip recalibration (use existing calibration)
cfg$recalibrate <- FALSE
cfg$recalibrate_landconversion_cost <- FALSE

################################################################################
#### Helper function to configure and submit a run
################################################################################

submitRun <- function(cfg, dgvm, gcm, climateScen, cellularInput) {
  # Get SSP configuration for this climate scenario
  sspCfg <- sspConfig[[climateScen]]
  if (is.null(sspCfg)) {
    stop("Unknown climate scenario: ", climateScen)
  }
  
  # Reset to default config then apply SSP scenario
  source("config/default.cfg")
  cfg <- setScenario(cfg, sspCfg$ssp)
  
  # Set carbon price
  cfg$gms$c56_pollutant_prices <- sspCfg$carbonPrice
  cfg$gms$c56_pollutant_prices_noselect <- sspCfg$carbonPrice
  
  # Re-apply project settings (overwritten by setScenario)
  cfg$info$flag <- "CarbonExt"
  cfg$qos <- "short"
  cfg$results_folder <- "output/:title:"
  cfg$force_replace <- TRUE
  
  # Re-add local repository
  localRepo <- paste0("file://", basePath)
  cfg$repositories <- append(
    setNames(list(NULL), localRepo),
    cfg$repositories
  )
  
  # Set inputs
  cfg$input["regional"] <- regionalInput
  cfg$input["validation"] <- validationInput
  cfg$input["cellular"] <- cellularInput
  
  # Skip recalibration
  cfg$recalibrate <- FALSE
  cfg$recalibrate_landconversion_cost <- FALSE
  
  # Set title: DGVM-GCM-SSP-carbonPrice
  cfg$title <- .title(dgvm, gcm, sspCfg$ssp, sspCfg$priceSuffix)
  
  cat("\nSubmitting:", cfg$title)
  cat("\n  SSP:", sspCfg$ssp, "| Carbon price:", sspCfg$carbonPrice, "\n")
  
  start_run(cfg = cfg, codeCheck = FALSE)
}

################################################################################
#### Run External Carbon runs (JSBACH3 and JULES)
################################################################################

cat("\n========================================\n")
cat("Starting External Carbon runs with SSP scenarios\n")
cat("========================================\n")
cat("\nConfiguration:\n")
cat("  ssp126 → SSP1 + medium carbon price ($137-284/tCO2)\n")
cat("  ssp370 → SSP2 + no carbon price\n")
cat("  ssp585 → SSP5 + no carbon price\n")
cat("========================================\n")

for (runName in names(externalInputs)) {
  # Parse run name: DGVM-GCM-climateScen
  parts <- strsplit(runName, "-")[[1]]
  dgvm <- parts[1]
  gcm <- parts[2]
  climateScen <- parts[3]
  
  submitRun(cfg, dgvm, gcm, climateScen, externalInputs[[runName]])
}

################################################################################
#### Run LPJmL Control runs
################################################################################

cat("\n========================================\n")
cat("Starting LPJmL Control runs with SSP scenarios\n")
cat("========================================\n")

for (runName in names(lpjmlInputs)) {
  # Parse run name: LPJmL-GCM-climateScen
  parts <- strsplit(runName, "-")[[1]]
  dgvm <- parts[1]
  gcm <- parts[2]
  climateScen <- parts[3]
  
  submitRun(cfg, dgvm, gcm, climateScen, lpjmlInputs[[runName]])
}

################################################################################
#### Summary
################################################################################

cat("\n========================================\n")
cat("All runs submitted!\n")
cat("========================================\n")
cat("JSBACH3 runs: 6 (3 GCMs × 2 climate scenarios)\n")
cat("JULES runs: 9 (3 GCMs × 3 climate scenarios)\n")
cat("LPJmL control runs: 9 (3 GCMs × 3 climate scenarios)\n")
cat("Total: 24 runs\n")
cat("\nSSP/Carbon Price Configuration:\n")
cat("  ssp126 → SSP1 + R34M410-SSP1-PkBudg1000 (~$137-284/tCO2)\n")
cat("  ssp370 → SSP2 + R34M410-SSP2-NPi2025 ($0)\n")
cat("  ssp585 → SSP5 + R34M410-SSP2-NPi2025 ($0)\n")
cat("========================================\n")
