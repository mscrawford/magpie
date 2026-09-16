*** |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  MAgPIE License Exception, version 1.0 (see LICENSE file).
*** |  Contact: magpie@pik-potsdam.de

*' @description Unlike the previous realization, this implementation allows for the possibility
*' that non-CO2 emissions can be reduced by technical mitigation at additional costs.
*' The following MACC data sets are available in this module:
*' @LUCAS200785 (PBL_2007) and @Harmsen2019 (PBL_2019).
*' The mitigation step of each source follows from the price of its pollutant. An exogenously
*' fixed step (`s57_maxmac_*` from 2 to 201) is a floor on that price-implied step and is by
*' default muted and phased in as module 56 mutes and phases in the GHG price of the pollutant;
*' an own ramp is available (`s57_maxmac_fader`).
*'
*' @limitations The data set PBL_2007 is outdated and only kept for backward compatibility

*####################### R SECTION START (PHASES) ##############################
$Ifi "%phase%" == "sets" $include "./modules/57_maccs/on_aug22/sets.gms"
$Ifi "%phase%" == "declarations" $include "./modules/57_maccs/on_aug22/declarations.gms"
$Ifi "%phase%" == "input" $include "./modules/57_maccs/on_aug22/input.gms"
$Ifi "%phase%" == "equations" $include "./modules/57_maccs/on_aug22/equations.gms"
$Ifi "%phase%" == "scaling" $include "./modules/57_maccs/on_aug22/scaling.gms"
$Ifi "%phase%" == "preloop" $include "./modules/57_maccs/on_aug22/preloop.gms"
$Ifi "%phase%" == "postsolve" $include "./modules/57_maccs/on_aug22/postsolve.gms"
*######################## R SECTION END (PHASES) ###############################
