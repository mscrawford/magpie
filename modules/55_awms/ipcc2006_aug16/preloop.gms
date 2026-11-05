*** |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  MAgPIE License Exception, version 1.0 (see LICENSE file).
*** |  Contact: magpie@pik-potsdam.de



* Stop if a scenario that presolve reads has no data in the chosen AWMS data version
* (for example "transformation" with legacy, "GoodPractice" with targets, or a misspelled version).
abort$(sum((t_all,i,kli,awms_conf), f55_awms_shr(t_all,i,"ssp2",kli,awms_conf)) = 0)
  "f55_awms_shr has no data for ssp2 (used up to sm_fix_SSP2): check c55_awms_shr_version = %c55_awms_shr_version%";
abort$(sum((t_all,i,kli,awms_conf), f55_awms_shr(t_all,i,"%c55_scen_conf%",kli,awms_conf)) = 0)
  "c55_scen_conf = %c55_scen_conf% has no data in c55_awms_shr_version = %c55_awms_shr_version%";
abort$(sum((t_all,i,kli,awms_conf), f55_awms_shr(t_all,i,"%c55_scen_conf_noselect%",kli,awms_conf)) = 0)
  "c55_scen_conf_noselect = %c55_scen_conf_noselect% has no data in c55_awms_shr_version = %c55_awms_shr_version%";

i55_manure_recycling_share(i,kli,awms_conf,"nr")=f55_awms_recycling_share(i,kli,awms_conf);
* ASSUMPTION: no leaching or other losses for p and k.
i55_manure_recycling_share(i,kli,awms_conf,"p")=1;
i55_manure_recycling_share(i,kli,awms_conf,"k")=1;
