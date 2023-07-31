# |  (C) 2008-2023 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# ----------------------------------------------------------
# description: Scenarios for food's regional pollution
# ----------------------------------------------------------

library(gms)
source("scripts/start_functions.R")
source("scripts/projects/foodPollution.R")

codeCheck <- FALSE

for (scenarioName in c(
  # Single transformation runs
  "a_NoUnderweight", "a_HalfOverweight", "a_DietVegFruitsNutsSeeds", "a_DietLegumes",
  "a_DietMonogastrics", "a_DietRuminants", "a_DietEmptyCals", "a_LessFoodWaste",
  "b_Diet",
  "c_BAU"
)) {

    # Start runs
    cfg <- foodPollutionScenario(scenario = scenarioName)
    start_run(cfg = cfg, codeCheck = codeCheck)
}
