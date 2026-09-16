# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# ----------------------------------------------------------
# description: Nitrogen Boundary Scenarios
# ----------------------------------------------------------

# Design record: docs/decisions/2026-09-16-v11-run-design.md in the Nitrogen-Boundaries
# repository (github.com/mscrawford/Nitrogen-Boundaries). The scenario switches are in
# config/projects/scenario_config_Nitrogen-Boundaries.csv; its input rows still name the
# rev4.131MSC-NB4 archives and are replaced with the MSC-NB5 archive names before the runs start.
# Set the environment variable NB_SCENARIOS (comma-separated scenario names) to run a subset.

library(gms)
source("scripts/start_functions.R")

version   <- "v11"
codeCheck <- FALSE

scenarios <- list(
    SSP3_RCP7p0_PolicyLow      = list(standard = c("cc", "SSP3", "rcp7p0"),                       boundaries = "SSP3_RCP7p0_PolicyLow"),      # SSP3 reference
    SSP5_RCP8p5_PolicyLow      = list(standard = c("cc", "SSP5", "rcp8p5"),                       boundaries = "SSP5_RCP8p5_PolicyLow"),      # Business-as-usual
    SSP2_RCP4p5_PolicyLow      = list(standard = c("cc", "SSP2", "rcp4p5"),                       boundaries = "SSP2_RCP4p5_PolicyLow"),      # Low N Regulation
    SSP2_RCP4p5_PolicyMed      = list(standard = c("cc", "SSP2", "rcp4p5"),                       boundaries = "SSP2_RCP4p5_PolicyMed"),      # Medium N Regulation
    SSP2_RCP4p5_PolicyHigh     = list(standard = c("cc", "SSP2", "rcp4p5"),                       boundaries = "SSP2_RCP4p5_PolicyHigh"),     # High N regulation
    SSP1_RCP4p5_PolicyHigh     = list(standard = c("cc", "SSP1", "rcp4p5"),                       boundaries = "SSP1_RCP4p5_PolicyHigh"),     # Best-case (no CO2/bio)
    SSP1_RCP2p6_PolicyHighBioenergy = list(standard = c("cc", "SSP1", "rcp2p6"),                  boundaries = "SSP1_RCP2p6_PolicyHighBioenergy"), # Bioenergy
    SSP1_RCP2p6_PolicyHighDiet = list(standard = c("cc", "SSP1", "rcp2p6", "eat_lancet_diet_v2"), boundaries = "SSP1_RCP2p6_PolicyHighDiet"), # Best-case+ with Diets
    SSP2_RCP4p5_PolicyLowDiet  = list(standard = c("cc", "SSP2", "rcp4p5", "eat_lancet_diet_v2"), boundaries = "SSP2_RCP4p5_PolicyLowDiet"),  # SSP2-Low + diet shift (isolates diet effect vs SSP2-Low null)
    SSP2_RCP4p5_SensitivityNUEhigh    = list(standard = c("cc", "SSP2", "rcp4p5"),                boundaries = "SSP2_RCP4p5_SensitivityNUEhigh"),   # Sensitivity - NUE MACCs High
    SSP2_RCP4p5_SensitivityNUEmedium  = list(standard = c("cc", "SSP2", "rcp4p5"),                boundaries = "SSP2_RCP4p5_SensitivityNUEmedium"), # Sensitivity - NUE MACCs Medium
    SSP2_RCP4p5_SensitivityAWMShigh   = list(standard = c("cc", "SSP2", "rcp4p5"),                boundaries = "SSP2_RCP4p5_SensitivityAWMShigh"),  # Sensitivity - AWMS MACCs High
    SSP2_RCP4p5_SensitivityAWMSmedium = list(standard = c("cc", "SSP2", "rcp4p5"),                boundaries = "SSP2_RCP4p5_SensitivityAWMSmedium") # Sensitivity - AWMS MACCs Medium
)

configureScenario <- function(scenario_name) {
    source("config/default.cfg")

    s <- scenarios[[scenario_name]]

    cfg <- setScenario(cfg, s$standard)
    cfg <- setScenario(cfg, s$boundaries, scenario_config = "config/projects/scenario_config_Nitrogen-Boundaries.csv")
    cfg$title <- paste(version, scenario_name, sep = "_")
    cfg$info$designRecord <- "Nitrogen-Boundaries v11 runs: docs/decisions/2026-09-16-v11-run-design.md (github.com/mscrawford/Nitrogen-Boundaries)"
    cfg$recalibrate <- FALSE
    cfg$qos <- "standby_highMem"
    cfg$force_download <- TRUE
    cfg$output <- c("output_check", "extra/disaggregation", "rds_report", "extra/disaggregateNitrogen")

    return(cfg)
}

# NB_SCENARIOS restricts the loop to the named scenarios; unset or empty runs all of them
selected <- names(scenarios)
subset <- Sys.getenv("NB_SCENARIOS", unset = "")
if (nzchar(subset)) {
    selected <- trimws(strsplit(subset, ",", fixed = TRUE)[[1]])
    unknown <- setdiff(selected, names(scenarios))
    if (length(unknown) > 0) {
        stop("NB_SCENARIOS names scenarios that do not exist: ", paste(unknown, collapse = ", "))
    }
}

for (scenario_name in selected) {
    cfg <- configureScenario(scenario_name)
    start_run(cfg = cfg, codeCheck = codeCheck)
}
