# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# ----------------------------------------------------------
# description: Nitrogen Boundary Scenarios
# ----------------------------------------------------------

# Design record: docs/decisions/2026-09-16-v11-run-design.md and
# docs/decisions/2026-09-17-v12-macc-fader-start-2025.md (addenda 2026-09-24) in the Nitrogen-Boundaries
# repository (github.com/mscrawford/Nitrogen-Boundaries). The scenario switches are in
# config/projects/scenario_config_Nitrogen-Boundaries.csv.
# Lever timing: every policy lever first acts in the first time step after sm_fix_SSP2 (2030).
# GHG prices are muted until c56_mute_ghgprices_until = sm_fix_SSP2, the diet fader starts at
# s15_exo_foodscen_start = sm_fix_SSP2, fixed MACC steps (s57_maxmac_*) apply after sm_fix_SSP2
# and are phased in by the time-dependent MACC curves themselves; checkLeverTiming() enforces this.
# Set the environment variable NB_SCENARIOS (comma-separated scenario names) to run a subset.

library(gms)
source("scripts/start_functions.R")

version   <- "v12"
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

# All policy levers must first act in the same time step: the GHG-price mute, the diet fader start and
# the first year of fixed MACC steps (after sm_fix_SSP2) must coincide, and the module-56 price fader
# (which extends the mute to its own start year) must be off
checkLeverTiming <- function(cfg, scenario_name) {
    mute <- as.numeric(sub("^y", "", cfg$gms$c56_mute_ghgprices_until))
    years <- c(c56_mute_ghgprices_until = mute,
               s15_exo_foodscen_start   = as.numeric(cfg$gms$s15_exo_foodscen_start),
               sm_fix_SSP2              = as.numeric(cfg$gms$sm_fix_SSP2))
    if (anyNA(years) || length(unique(years)) != 1) {
        stop(scenario_name, ": policy levers do not start together: ",
             paste(names(years), years, sep = " = ", collapse = ", "))
    }
    if (as.numeric(cfg$gms$s56_ghgprice_fader) != 0) {
        stop(scenario_name, ": s56_ghgprice_fader must be 0 (it shifts the price start to s56_fader_start)")
    }
    invisible(TRUE)
}

configureScenario <- function(scenario_name) {
    source("config/default.cfg")

    s <- scenarios[[scenario_name]]

    cfg <- setScenario(cfg, s$standard)
    cfg <- setScenario(cfg, s$boundaries, scenario_config = "config/projects/scenario_config_Nitrogen-Boundaries.csv")
    cfg$title <- paste(version, scenario_name, sep = "_")
    cfg$info$designRecord <- "Nitrogen-Boundaries v12 runs: docs/decisions/2026-09-16-v11-run-design.md and 2026-09-17-v12-macc-fader-start-2025.md (github.com/mscrawford/Nitrogen-Boundaries)"
    cfg$recalibrate <- FALSE
    cfg$qos <- "standby_highMem"
    cfg$force_download <- TRUE
    cfg$output <- c("output_check", "extra/disaggregation", "rds_report", "extra/disaggregateNitrogen")

    checkLeverTiming(cfg, scenario_name)
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
