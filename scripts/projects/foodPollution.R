 # |  (C) 2008-2023 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

################################################################################
# Define internal functions
################################################################################

foodPollutionScenario <- function(scenario) {

  source("config/default.cfg")

  # Version number
  v <- "v1_foodPollution"

  x <- list(c_BAU                = list(standard = c("cc", "SSP2", "NDC", "ForestryEndo")),
            
            # single transformations
            a_NoUnderweight      = list(standard = c("cc", "SSP2", "NDC", "ForestryEndo"),
                                        foodPollution = c("noUnderweight")),
            a_HalfOverweight     = list(standard = c("cc", "SSP2", "NDC", "ForestryEndo"),
                                        foodPollution = c("halfOverweight")),
            a_DietVegFruitsNutsSeeds  = list(standard = c("cc", "SSP2", "NDC", "ForestryEndo"),
                                        foodPollution = c("fruitsNutsVegSeeds")),
            a_DietMonogastrics   = list(standard = c("cc", "SSP2", "NDC", "ForestryEndo"),
                                        foodPollution = c("monogastrics")),
            a_DietRuminants      = list(standard = c("cc", "SSP2", "NDC", "ForestryEndo"),
                                        foodPollution = c("ruminants")),
            a_DietLegumes        = list(standard = c("cc", "SSP2", "NDC", "ForestryEndo"),
                                        foodPollution = c("pulses")),
            a_DietEmptyCals      = list(standard = c("cc", "SSP2", "NDC", "ForestryEndo"),
                                        foodPollution = c("processed")),
            a_DietFish           = list(standard = c("cc", "SSP2", "NDC", "ForestryEndo"),
                                        foodPollution = c("fish")),
            a_LessFoodWaste      = list(standard = c("cc", "SSP2", "NDC", "ForestryEndo"),
                                        foodPollution = c("waste")),
            
            # combined dietary transofmration
            b_Diet                = list(standard = c("cc", "SSP2", "NDC", "ForestryEndo"),
                                         foodPollution = c("allDietAndWaste"))
            )
  # Assign selected scenario to cfg
  cfg <- setScenario(cfg, x[[scenario]]$standard)
  cfg <- setScenario(cfg, x[[scenario]]$foodPollution, scenario_config = "config/scenario_foodPollution.csv")

  # general
  cfg$title       <- paste(v, scenario, sep = "")
  cfg$recalibrate <- FALSE
  cfg$output      <- c("extra/disaggregation",
                       "rds_report_iso",
                       "rds_report")
  cfg$force_download  <- TRUE
  cfg$gms$s80_optfile <- 1

  return(cfg)
}
