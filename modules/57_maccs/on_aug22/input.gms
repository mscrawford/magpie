*** |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  MAgPIE License Exception, version 1.0 (see LICENSE file).
*** |  Contact: magpie@pik-potsdam.de

* option: PBL_2007, PBL_2019, PBL_2022
$setglobal c57_macc_version  PBL_2022
* option: Default, Optimistic, Pessimistic; only applicable for PBL_2022
$setglobal c57_macc_scenario  Default

scalars
  s57_maxmac_n_soil    fixed MACC step for soil N mitigation as a floor on the price-implied step (MACC step and -1 is price-driven) / -1 /
  s57_maxmac_n_awms    fixed MACC step for awms N mitigation as a floor on the price-implied step (MACC step and -1 is price-driven) / -1 /
  s57_maxmac_ch4_rice    fixed MACC step for rice CH4 mitigation as a floor on the price-implied step (MACC step and -1 is price-driven)/ -1 /
  s57_maxmac_ch4_entferm fixed MACC step for enteric fermentation CH4 mitigation as a floor on the price-implied step (MACC step and -1 is price-driven) / -1 /
  s57_maxmac_ch4_awms  fixed MACC step for awms CH4 mitigation as a floor on the price-implied step (MACC step and -1 is price-driven) / -1 /
  s57_maxmac_fader     phase-in of fixed MACC steps (0=none 1=as the GHG price of the pollutant in module 56 2=own ramp) / 1 /
  s57_fader_start      start year of the own phase-in of fixed MACC steps (1) / 2035 /
  s57_fader_end        end year of the own phase-in of fixed MACC steps (1) / 2050 /
  s57_fader_target     target value of the own phase-in of fixed MACC steps in the end year (1) / 1 /
  s57_fader_functional_form  functional form of the own phase-in of fixed MACC steps (1=linear 2=sigmoid) / 1 /
  s57_implicit_emis_factor emission factor for direct soil emissions implicit to MACC curves (tN2ON per tN) / 0.01 /
  s57_implicit_fert_cost fertilizer costs implicit to MACC curves (USD17MER per ton N) / 738 /
;

$onEmpty
table f57_maccs_n2o(t_all,i,maccs_n2o,maccs_steps)  N2O MACC from Image model (percent)
$ondelim
$if "%c57_macc_version%" == "PBL_2007" $include "./modules/57_maccs/input/f57_maccs_n2o.cs3"
$if "%c57_macc_version%" == "PBL_2019" $include "./modules/57_maccs/input/f57_maccs_n2o_2019.cs3"
$offdelim
;
$offEmpty

table f57_maccs_n2o_2022(t_all,i,maccs_n2o,scen57,maccs_steps)  N2O MACC from Image model (percent)
$ondelim
$include "./modules/57_maccs/input/f57_maccs_n2o_2022.cs3"
$offdelim
;
$if "%c57_macc_version%" == "PBL_2022" f57_maccs_n2o(t_all,i,maccs_n2o,maccs_steps) = f57_maccs_n2o_2022(t_all,i,maccs_n2o,"%c57_macc_scenario%",maccs_steps)


$onEmpty
table f57_maccs_ch4(t_all,i,maccs_ch4,maccs_steps)  CH4 MACC from Image model (percent)
$ondelim
$if "%c57_macc_version%" == "PBL_2007" $include "./modules/57_maccs/input/f57_maccs_ch4.cs3"
$if "%c57_macc_version%" == "PBL_2019" $include "./modules/57_maccs/input/f57_maccs_ch4_2019.cs3"
$offdelim
;
$offEmpty

table f57_maccs_ch4_2022(t_all,i,maccs_ch4,scen57,maccs_steps)  N2O MACC from Image model (percent)
$ondelim
$include "./modules/57_maccs/input/f57_maccs_ch4_2022.cs3"
$offdelim
;
$if "%c57_macc_version%" == "PBL_2022" f57_maccs_ch4(t_all,i,maccs_ch4,maccs_steps) = f57_maccs_ch4_2022(t_all,i,maccs_ch4,"%c57_macc_scenario%",maccs_steps)
