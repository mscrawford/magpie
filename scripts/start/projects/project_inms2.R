# |  (C) 2008-2021 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# ----------------------------------------------------------
# description: INMS simulations (nitrogen)
# ----------------------------------------------------------

library(gms)
source("scripts/start_functions.R")
source("scripts/performance_test.R")
source("config/default.cfg")

# Set defaults
codeCheck <- FALSE

input <- c(regional    = "rev4.67_MSC_INMS_6_Jun_2022_fc2ac2ad_magpie.tgz",
           cellular    = "rev4.67_MSC_INMS_6_Jun_2022_fc2ac2ad_fd712c0b_cellularmagpie_c200_MRI-ESM2-0-ssp370_lpjml-8e6c5eb1.tgz",
           validation  = "rev4.67_MSC_INMS_6_Jun_2022_fc2ac2ad_validation.tgz",
           additional  = "additional_data_rev4.08.tgz",
           calibration = "calibration_INMS_07Jun22.tgz")

# General settings
general_settings <- function(title) {
  source("config/default.cfg")
  cfg$input                  <- input
  cfg$title                  <- title
  cfg                        <- gms::setScenario(cfg, "cc")
  cfg$force_download         <- TRUE
  cfg$gms$c_timesteps        <- 12
  cfg$gms$som                <- "cellpool_aug16"
  cfg$gms$factor_costs       <- "sticky_feb18"
  cfg$gms$s15_elastic_demand <- 0
  cfg$gms$nitrogen           <- "rescaled_jan21"
  cfg$gms$maccs              <- "on_sep16"
  cfg$gms$c56_emis_policy    <- "maccs_excl_cropland_n2o"
  #cfg$calib_cropland        <- FALSE
  cfg$recalibrate            <- FALSE

  return(cfg)
}


# -----------------------------------------------------------------------------------------------------------------
# Scenario runs

### Business-as-usual
cfg <- general_settings(title = "SSP5_RCP8p5_PolicyLow")
# Development: fossil-fuel driven (SSP5)
# Land Use: medium regulation, high productivity
# Diet: meat and dairy-rich
cfg <- gms::setScenario(cfg, "SSP5")
# Climate: no mitigation (RCP8.5)
cfg$gms$c56_pollutant_prices  <- "SSPDB-SSP5-Ref-REMIND-MAGPIE"
cfg$gms$c60_2ndgen_biodem     <- "SSPDB-SSP5-Ref-REMIND-MAGPIE"
# N policy: low ambition
cfg$gms$c50_scen_neff         <- "constant"
cfg$gms$c50_scen_neff_pasture <- "constant"
cfg$gms$c70_feed_scen         <- "ssp2"    ##### or ssp5? or not necessary to specify when scenario config selected?
cfg$gms$c55_scen_conf         <- "ssp2"    ##### or ssp5? or not necessary to specify when scenario config selected?
start_run(cfg = cfg, codeCheck = codeCheck)


### Low N regulation
cfg <- general_settings(title = "SSP2_RCP4p5_PolicyLow")
# Development: historical trends (SSP2)
# Land Use: medium regulation, medium productivity
# Diet: medium meat and dairy
cfg <- gms::setScenario(cfg, "SSP2")
# Climate: moderate mitigation (RCP4.5)
cfg$gms$c56_pollutant_prices  <- "SSPDB-SSP2-45-REMIND-MAGPIE"
cfg$gms$c60_2ndgen_biodem     <- "SSPDB-SSP2-45-REMIND-MAGPIE"
# N policy: low ambition
cfg$gms$c50_scen_neff         <- "constant"
cfg$gms$c50_scen_neff_pasture <- "constant"
cfg$gms$c70_feed_scen         <- "ssp2"
cfg$gms$c55_scen_conf         <- "ssp2"
start_run(cfg = cfg, codeCheck = codeCheck)


### Medium N regulation
cfg <- general_settings(title = "SSP2_RCP4p5_PolicyMed")
# Development: historical trends (SSP2)
# Land Use: medium regulation, medium productivity
# Diet: medium meat and dairy
cfg <- gms::setScenario(cfg, "SSP2")
# Climate: moderate mitigation (RCP4.5)
cfg$gms$c56_pollutant_prices  <- "SSPDB-SSP2-45-REMIND-MAGPIE"
cfg$gms$c60_2ndgen_biodem     <- "SSPDB-SSP2-45-REMIND-MAGPIE"
# N policy: moderate ambition
cfg$gms$c50_scen_neff         <- "neff_ZhangBy2050_start2010"
cfg$gms$c50_scen_neff_pasture <- "constant"
cfg$gms$c70_feed_scen         <- "ssp1"
cfg$gms$c55_scen_conf         <- "ssp1"
start_run(cfg = cfg, codeCheck = codeCheck)


### High N regulation
cfg <- general_settings(title = "SSP2_RCP4p5_PolicyHigh")
# Development: historical trends (SSP2)
# Land Use: medium regulation, medium productivity
# Diet: medium meat and dairy
cfg <- gms::setScenario(cfg, "SSP2")
# Climate: moderate mitigation (RCP4.5)
cfg$gms$c56_pollutant_prices  <- "SSPDB-SSP2-45-REMIND-MAGPIE"
cfg$gms$c60_2ndgen_biodem     <- "SSPDB-SSP2-45-REMIND-MAGPIE"
# N policy: high ambition
cfg$gms$c50_scen_neff         <- "neff_ZhangBy2030_start2010"
cfg$gms$c50_scen_neff_pasture <- "constant"
cfg$gms$c70_feed_scen         <- "ssp1"
cfg$gms$c55_scen_conf         <- "GoodPractice"
start_run(cfg = cfg, codeCheck = codeCheck)


### Best-case
cfg <- general_settings(title = "SSP1_RCP4p5_PolicyHigh")
# Development: sustainable development (SSP1)
# Land Use: strong regulation, high productivity (SSP1)
# Diet: low meat and dairy
cfg <- gms::setScenario(cfg, "SSP1")
# Climate: moderate mitigation (RCP4.5)
cfg$gms$c56_pollutant_prices  <- "SSPDB-SSP1-45-REMIND-MAGPIE"
cfg$gms$c60_2ndgen_biodem     <- "SSPDB-SSP1-45-REMIND-MAGPIE"
# N policy: high ambition
cfg$gms$c50_scen_neff         <- "neff_ZhangBy2030_start2010"
cfg$gms$c50_scen_neff_pasture <- "constant"
cfg$gms$c70_feed_scen         <- "ssp1"
cfg$gms$c55_scen_conf         <- "GoodPractice"
start_run(cfg = cfg, codeCheck = codeCheck)


### Best-case+
cfg <- general_settings(title = "SSP1_RCP4p5_PolicyHighDiet")
# Development: sustainable development (SSP1)
# Land Use: strong regulation, high productivity (SSP1)
cfg <- gms::setScenario(cfg, "SSP1")
# Climate: moderate mitigation (RCP4.5)
cfg$gms$c56_pollutant_prices <- "SSPDB-SSP1-45-REMIND-MAGPIE"
cfg$gms$c60_2ndgen_biodem    <- "SSPDB-SSP1-45-REMIND-MAGPIE"
# Diet: ambitious diet shift and food loss/waste reductions (EATLancet)
cfg$gms$c15_food_scenario     <- "SSP1"
cfg$gms$s15_exo_waste         <- 1
cfg$gms$s15_waste_scen        <- 1.2
cfg$gms$s15_exo_diet          <- 1
cfg$gms$c15_kcal_scen         <- "healthy_BMI"
cfg$gms$c15_EAT_scen          <- "FLX"
# N policy: high ambition
cfg$gms$c50_scen_neff         <- "neff_ZhangBy2030_start2010"
cfg$gms$c50_scen_neff_pasture <- "constant"
cfg$gms$c70_feed_scen         <- "ssp1"
cfg$gms$c55_scen_conf         <- "GoodPractice"
start_run(cfg = cfg, codeCheck = codeCheck)


### Bioenergy
cfg <- general_settings(title = "SSP1_RCP2p6_PolicyHigh")
# Development: sustainable development (SSP1)
# Land Use: strong regulation, high productivity (SSP1)
# Diet: low meat and dairy
cfg <- gms::setScenario(cfg, "SSP1")
# Climate: high mitigation (RCP2.6)
cfg$gms$c56_pollutant_prices  <- "SSPDB-SSP1-26-REMIND-MAGPIE"
cfg$gms$c60_2ndgen_biodem     <- "SSPDB-SSP1-26-REMIND-MAGPIE"
# N policy: high ambition
cfg$gms$c50_scen_neff         <- "neff_ZhangBy2030_start2010"
cfg$gms$c50_scen_neff_pasture <- "constant"
cfg$gms$c70_feed_scen         <- "ssp1"
cfg$gms$c55_scen_conf         <- "GoodPractice"
start_run(cfg = cfg, codeCheck = codeCheck)


# -----------------------------------------------------------------------------------------------------------------
# Sensitivity runs

### Sensitivity 1: Only NUE (high ambition)
cfg <- general_settings(title = "SSP2_RCP4p5_SensitivityNUEhigh")
# Development: historical trends (SSP2)
# Land Use: medium regulation, medium productivity (SSP2)
# Diet: medium meat and dairy
cfg <- gms::setScenario(cfg, "SSP2")
# Climate: moderate mitigation (RCP4.5)
cfg$gms$c56_pollutant_prices  <- "SSPDB-SSP2-45-REMIND-MAGPIE"
cfg$gms$c60_2ndgen_biodem     <- "SSPDB-SSP2-45-REMIND-MAGPIE"
# N policy: Only NUE
cfg$gms$c50_scen_neff         <- "neff_ZhangBy2030_start2010"
cfg$gms$c50_scen_neff_pasture <- "constant"
start_run(cfg = cfg, codeCheck = codeCheck)


### Sensitivity 2: Only NUE (moderate ambition)
cfg <- general_settings(title = "SSP2_RCP4p5_SensitivityNUEmoderate")
# Development: historical trends (SSP2)
# Land Use: medium regulation, medium productivity (SSP2)
# Diet: medium meat and dairy
cfg <- gms::setScenario(cfg, "SSP2")
# Climate: moderate mitigation (RCP4.5)
cfg$gms$c56_pollutant_prices  <- "SSPDB-SSP2-45-REMIND-MAGPIE"
cfg$gms$c60_2ndgen_biodem     <- "SSPDB-SSP2-45-REMIND-MAGPIE"
# N policy: Only NUE
cfg$gms$c50_scen_neff         <- "neff_ZhangBy2050_start2010"
cfg$gms$c50_scen_neff_pasture <- "constant"
start_run(cfg = cfg, codeCheck = codeCheck)


### Sensitivity 3: Only AWS (high ambition)
cfg <- general_settings(title = "SSP2_RCP4p5_SensitivityAWShigh")
# Development: historical trends (SSP2)
# Land Use: medium regulation, medium productivity (SSP2)
cfg <- gms::setScenario(cfg, "SSP2")
# Climate: moderate mitigation (RCP4.5)
cfg$gms$c56_pollutant_prices <- "SSPDB-SSP2-45-REMIND-MAGPIE"
cfg$gms$c60_2ndgen_biodem    <- "SSPDB-SSP2-45-REMIND-MAGPIE"
# N policy: Best
cfg$gms$c70_feed_scen        <- "ssp1"
cfg$gms$c55_scen_conf        <- "GoodPractice"
start_run(cfg = cfg, codeCheck = codeCheck)


### Sensitivity 4: Only AWS (moderate ambition)
cfg <- general_settings(title = "SSP2_RCP4p5_SensitivityAWSmoderate")
# Development: historical trends (SSP2)
# Land Use: medium regulation, medium productivity (SSP2)
cfg <- gms::setScenario(cfg, "SSP2")
# Climate: moderate mitigation (RCP4.5)
cfg$gms$c56_pollutant_prices <- "SSPDB-SSP2-45-REMIND-MAGPIE"
cfg$gms$c60_2ndgen_biodem    <- "SSPDB-SSP2-45-REMIND-MAGPIE"
# N policy: Only AWS
cfg$gms$c70_feed_scen        <- "ssp1"
cfg$gms$c55_scen_conf        <- "ssp1"
start_run(cfg = cfg, codeCheck = codeCheck)
