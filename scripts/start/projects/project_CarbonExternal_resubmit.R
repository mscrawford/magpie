# Resubmit ALL CarbonExternal runs with relaxed solver tolerances

library(lucode2)
library(gms)

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$info$flag <- "CarbonExt"
cfg$qos <- "short"
cfg$results_folder <- "output/:title:"
cfg$force_replace <- TRUE

.title <- function(...) paste("CarbonExt", ..., sep = "_")

basePath <- "/p/projects/rd3mod/inputdata/output_1.27"
regionalInput <- "rev4.126_h12_magpie.tgz"
validationInput <- "rev4.126_h12_validation.tgz"

# ALL runs
externalInputs <- list(
  # JSBACH3 (6 runs)
  "JSBACH3-IPSL-ssp126" = "rev4.126crawford-2026-01-23T163901_h12_d3c29a99_cellularmagpie_c200_IPSL-CM6A-LR-ssp126_lpjml-8e6c5eb1_carbon-JSBACH3-IPSL-ssp126.tgz",
  "JSBACH3-IPSL-ssp370" = "rev4.126crawford-2026-01-23T163904_h12_25463b82_cellularmagpie_c200_IPSL-CM6A-LR-ssp370_lpjml-8e6c5eb1_carbon-JSBACH3-IPSL-ssp370.tgz",
  "JSBACH3-MPI-ssp126"  = "rev4.126crawford-2026-01-23T163907_h12_bb73ace7_cellularmagpie_c200_MPI-ESM1-2-HR-ssp126_lpjml-8e6c5eb1_carbon-JSBACH3-MPI-ssp126.tgz",
  "JSBACH3-MPI-ssp370"  = "rev4.126crawford-2026-01-23T163910_h12_808ebbd5_cellularmagpie_c200_MPI-ESM1-2-HR-ssp370_lpjml-8e6c5eb1_carbon-JSBACH3-MPI-ssp370.tgz",
  "JSBACH3-UKESM-ssp126" = "rev4.126crawford-2026-01-23T163914_h12_c6061c7c_cellularmagpie_c200_UKESM1-0-LL-ssp126_lpjml-8e6c5eb1_carbon-JSBACH3-UKESM-ssp126.tgz",
  "JSBACH3-UKESM-ssp370" = "rev4.126crawford-2026-01-23T163917_h12_c090de3b_cellularmagpie_c200_UKESM1-0-LL-ssp370_lpjml-8e6c5eb1_carbon-JSBACH3-UKESM-ssp370.tgz",
  
  # JULES (9 runs)
  "JULES-IPSL-ssp126" = "rev4.126crawford-2026-01-23T163920_h12_b7dfe2c1_cellularmagpie_c200_IPSL-CM6A-LR-ssp126_lpjml-8e6c5eb1_carbon-JULES-IPSL-ssp126.tgz",
  "JULES-IPSL-ssp370" = "rev4.126crawford-2026-01-23T163923_h12_ed146a40_cellularmagpie_c200_IPSL-CM6A-LR-ssp370_lpjml-8e6c5eb1_carbon-JULES-IPSL-ssp370.tgz",
  "JULES-IPSL-ssp585" = "rev4.126crawford-2026-01-23T163926_h12_c09ea1ad_cellularmagpie_c200_IPSL-CM6A-LR-ssp585_lpjml-8e6c5eb1_carbon-JULES-IPSL-ssp585.tgz",
  "JULES-MPI-ssp126"  = "rev4.126crawford-2026-01-23T163929_h12_36738474_cellularmagpie_c200_MPI-ESM1-2-HR-ssp126_lpjml-8e6c5eb1_carbon-JULES-MPI-ssp126.tgz",
  "JULES-MPI-ssp370"  = "rev4.126crawford-2026-01-23T163932_h12_2dd89ee4_cellularmagpie_c200_MPI-ESM1-2-HR-ssp370_lpjml-8e6c5eb1_carbon-JULES-MPI-ssp370.tgz",
  "JULES-MPI-ssp585"  = "rev4.126crawford-2026-01-23T163935_h12_54dec300_cellularmagpie_c200_MPI-ESM1-2-HR-ssp585_lpjml-8e6c5eb1_carbon-JULES-MPI-ssp585.tgz",
  "JULES-UKESM-ssp126" = "rev4.126crawford-2026-01-23T163938_h12_041f43ea_cellularmagpie_c200_UKESM1-0-LL-ssp126_lpjml-8e6c5eb1_carbon-JULES-UKESM-ssp126.tgz",
  "JULES-UKESM-ssp370" = "rev4.126crawford-2026-01-23T163942_h12_df9eae95_cellularmagpie_c200_UKESM1-0-LL-ssp370_lpjml-8e6c5eb1_carbon-JULES-UKESM-ssp370.tgz",
  "JULES-UKESM-ssp585" = "rev4.126crawford-2026-01-23T163945_h12_44789193_cellularmagpie_c200_UKESM1-0-LL-ssp585_lpjml-8e6c5eb1_carbon-JULES-UKESM-ssp585.tgz"
)

localRepo <- paste0("file://", basePath)
cfg$repositories <- append(setNames(list(NULL), localRepo), cfg$repositories)

cfg$input["regional"] <- regionalInput
cfg$input["validation"] <- validationInput
cfg$recalibrate <- FALSE
cfg$recalibrate_landconversion_cost <- FALSE

# RELAXED SOLVER TOLERANCE (default is 1e-08)
cfg$gms$s80_toloptimal <- 1e-06

cat("\n========================================\n")
cat("Submitting ALL runs with relaxed tolerances (1e-06)\n")
cat("========================================\n")

for (runName in names(externalInputs)) {
  cfg$title <- .title(runName)
  cfg$input["cellular"] <- externalInputs[[runName]]
  
  cat("\nSubmitting:", cfg$title, "\n")
  start_run(cfg = cfg, codeCheck = FALSE)
}

cat("\n========================================\n")
cat("All 15 runs submitted!\n")
cat("========================================\n")
