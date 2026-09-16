*** |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  MAgPIE License Exception, version 1.0 (see LICENSE file).
*** |  Contact: magpie@pik-potsdam.de

* inflated using USD05 --> USD17 MER rate: 5 * 1.23
$if "%c57_macc_version%" == "PBL_2007" s57_step_length = 6.15;
* inflated using USD10 --> USD17 MER rate: 20 * 1.12
$if "%c57_macc_version%" == "PBL_2019" s57_step_length = 22.4;
* inflated using USD10 --> USD17 MER rate: 20 * 1.12
$if "%c57_macc_version%" == "PBL_2022" s57_step_length = 22.4;

$ontext
Determine level of GHG emission abatement depending on GHG prices.
There are 201 abatement steps. Each step is 6.15 USD17MER per tC eq in case of PBL_2007 and
22.4 USD17MER per tC eq in case of PBL_2019.
Since the GHG prices are in USD per ton N and USD per ton CH4, conversion to USD per ton C eq is needed.
In this realization, the IPCC AR4 global warming potential factor for N2O (298) and CH4 (25) are used because
PBL used these parameters to convert USD per ton N2O and USD per ton CH4 into USD per ton C eq.
$offtext

i57_mac_step_n2o(t,i,emis_source) = min(201, ceil(im_pollutant_prices(t,i,"n2o_n_direct",emis_source)/298*28/44*44/12 / s57_step_length) + 1);
i57_mac_step_ch4(t,i,emis_source) = min(201, ceil(im_pollutant_prices(t,i,"ch4",emis_source)/25*44/12 / s57_step_length) + 1);


* Phase-in of exogenously fixed MACC steps (s57_maxmac_* >= 2):
*  s57_maxmac_fader = 1 (default): the fixed step is phased in with the same factor that module 56
*    applies to the GHG price of the respective pollutant (im_ghgprice_fader: 0 while the prices are
*    muted until c56_mute_ghgprices_until, then the fader if s56_ghgprice_fader is on and the pollutant
*    is in pollutants_fader, else 1), so that a change to the GHG-price muting or phase-in carries
*    over to the non-CO2 MACCs.
*  s57_maxmac_fader = 2: own ramp (s57_fader_start, s57_fader_end, s57_fader_target,
*    s57_fader_functional_form), e.g. one GHG price but technical mitigation on its own schedule.
*  s57_maxmac_fader = 0: no phase-in.
* The fixed step is a floor on the price-implied step and is capped at the last MACC step, so it
* never yields less technical mitigation than the price-implied step. s57_maxmac_* = 0 or 1 fix the
* step at 0 or 1, i.e. no technical mitigation, as before.
abort$(s57_maxmac_fader < 0 or s57_maxmac_fader > 2) "s57_maxmac_fader must be 0, 1 or 2";
abort$(s57_maxmac_fader = 2 and (s57_fader_functional_form < 1 or s57_fader_functional_form > 2)) "s57_fader_functional_form must be 1 or 2";
p57_fader(t_all) = 1;
if (s57_maxmac_fader = 2,
  if (s57_fader_functional_form = 1,
    m_linear_time_interpol(p57_fader,s57_fader_start,s57_fader_end,0,s57_fader_target);
  elseif s57_fader_functional_form = 2,
    m_sigmoid_time_interpol(p57_fader,s57_fader_start,s57_fader_end,0,s57_fader_target);
  );
);
p57_maxmac_fader(t_all,i,pollutants) = 1;
p57_maxmac_fader(t_all,i,pollutants)$(s57_maxmac_fader = 1) = im_ghgprice_fader(t_all,i,pollutants);
p57_maxmac_fader(t_all,i,pollutants)$(s57_maxmac_fader = 2) = p57_fader(t_all);

loop(t,

  if(m_year(t) > sm_fix_SSP2,

    if (s57_maxmac_n_soil >= 2, i57_mac_step_n2o(t,i,emis_source_inorg_fert_n2o) = min(card(maccs_steps), max(i57_mac_step_n2o(t,i,emis_source_inorg_fert_n2o), 1 + round((s57_maxmac_n_soil - 1) * p57_maxmac_fader(t,i,"n2o_n_direct")))));
    if (s57_maxmac_n_awms >= 2, i57_mac_step_n2o(t,i,emis_source_awms_n2o) = min(card(maccs_steps), max(i57_mac_step_n2o(t,i,emis_source_awms_n2o), 1 + round((s57_maxmac_n_awms - 1) * p57_maxmac_fader(t,i,"n2o_n_direct")))));
    if (s57_maxmac_ch4_rice >= 2, i57_mac_step_ch4(t,i,emis_source_rice_ch4) = min(card(maccs_steps), max(i57_mac_step_ch4(t,i,emis_source_rice_ch4), 1 + round((s57_maxmac_ch4_rice - 1) * p57_maxmac_fader(t,i,"ch4")))));
    if (s57_maxmac_ch4_entferm >= 2, i57_mac_step_ch4(t,i,emis_source_ent_ferm_ch4) = min(card(maccs_steps), max(i57_mac_step_ch4(t,i,emis_source_ent_ferm_ch4), 1 + round((s57_maxmac_ch4_entferm - 1) * p57_maxmac_fader(t,i,"ch4")))));
    if (s57_maxmac_ch4_awms >= 2, i57_mac_step_ch4(t,i,emis_source_awms_ch4) = min(card(maccs_steps), max(i57_mac_step_ch4(t,i,emis_source_awms_ch4), 1 + round((s57_maxmac_ch4_awms - 1) * p57_maxmac_fader(t,i,"ch4")))));

    if (s57_maxmac_n_soil >= 0 and s57_maxmac_n_soil <= 1, i57_mac_step_n2o(t,i,emis_source_inorg_fert_n2o) = s57_maxmac_n_soil);
    if (s57_maxmac_n_awms >= 0 and s57_maxmac_n_awms <= 1, i57_mac_step_n2o(t,i,emis_source_awms_n2o) = s57_maxmac_n_awms);
    if (s57_maxmac_ch4_rice >= 0 and s57_maxmac_ch4_rice <= 1, i57_mac_step_ch4(t,i,emis_source_rice_ch4) = s57_maxmac_ch4_rice);
    if (s57_maxmac_ch4_entferm >= 0 and s57_maxmac_ch4_entferm <= 1, i57_mac_step_ch4(t,i,emis_source_ent_ferm_ch4) = s57_maxmac_ch4_entferm);
    if (s57_maxmac_ch4_awms >= 0 and s57_maxmac_ch4_awms <= 1, i57_mac_step_ch4(t,i,emis_source_awms_ch4) = s57_maxmac_ch4_awms);

  );
);

*Calculate technical mitigation depending on i57_mac_step_n2o and i57_mac_step_ch4.
*At zero GHG prices i57_mac_step_n2o and i57_mac_step_ch4 are set to 1.
*Technical mitigation should be zero at zero GHG prices.
*There the following calculations are only executed for ord(maccs_steps) > 1

im_maccs_mitigation(t,i,emis_source,pollutants) = 0;

im_maccs_mitigation(t,i,emis_source_inorg_fert_n2o,"n2o_n_direct") =
        sum(maccs_steps$(ord(maccs_steps) eq i57_mac_step_n2o(t,i,emis_source_inorg_fert_n2o) AND ord(maccs_steps) > 1),
              f57_maccs_n2o(t,i,"inorg_fert_n2o",maccs_steps));

im_maccs_mitigation(t,i,emis_source_awms_n2o,"n2o_n_direct") =
        sum(maccs_steps$(ord(maccs_steps) eq i57_mac_step_n2o(t,i,emis_source_awms_n2o) AND ord(maccs_steps) > 1),
              f57_maccs_n2o(t,i,"awms_manure_n2o",maccs_steps));

im_maccs_mitigation(t,i,emis_source_rice_ch4,"ch4") =
        sum(maccs_steps$(ord(maccs_steps) eq i57_mac_step_ch4(t,i,emis_source_rice_ch4) AND ord(maccs_steps) > 1),
              f57_maccs_ch4(t,i,"rice_ch4",maccs_steps));

im_maccs_mitigation(t,i,emis_source_ent_ferm_ch4,"ch4") =
        sum(maccs_steps$(ord(maccs_steps) eq i57_mac_step_ch4(t,i,emis_source_ent_ferm_ch4) AND ord(maccs_steps) > 1),
              f57_maccs_ch4(t,i,"ent_ferm_ch4",maccs_steps));

im_maccs_mitigation(t,i,emis_source_awms_ch4,"ch4") =
        sum(maccs_steps$(ord(maccs_steps) eq i57_mac_step_ch4(t,i,emis_source_awms_ch4) AND ord(maccs_steps) > 1),
              f57_maccs_ch4(t,i,"awms_ch4",maccs_steps));

$ontext
The costs associated with technical abatement of GHG emissions are reflected by the area under the mac curve, i.e. the integral.
Abatement options at zero cost are in the first step. Therefore an offset of -1 is used.
Note that the emissions before mitigation, which need to be part of the integral calculation but are not available in preloop,
are multiplied with p57_maccs_costs_integral during optimization (see equations).

Illustrative example for CH4: Abatement is 0.14 percent at 0$/tC, 0.15 percent at 5 and 10 $/tC, and 0.16 percent at 15 $/tC.
Emissions before technical mitigation are assumed 1 t CH4.

step 1                      0 mio $   0 mio $
step 2  (0.15-0.14) * 1 tCH4 * 5$/tC*12/44*28   0.38 mio $  0.38 mio $
step 3  (0.15-0.15) * 1 tCH4 * 10$/tC*12/44*28  0 mio $   0.38 mio $
step 4  (0.16-0.15) * 1 tCH4 * 15$/tC*12/44*28  1.15 mio $  1.53 mio $

$offtext

p57_maccs_costs_integral(t,i,emis_source,pollutants) = 0;

loop(maccs_steps$(ord(maccs_steps) > 1),
    p57_maccs_costs_integral(t,i,emis_source_inorg_fert_n2o,"n2o_n_direct")$(ord(maccs_steps) <= i57_mac_step_n2o(t,i,emis_source_inorg_fert_n2o)) =
    p57_maccs_costs_integral(t,i,emis_source_inorg_fert_n2o,"n2o_n_direct") +
    (f57_maccs_n2o(t,i,"inorg_fert_n2o",maccs_steps) - f57_maccs_n2o(t,i,"inorg_fert_n2o",maccs_steps-1))*(ord(maccs_steps)-1)*s57_step_length;

    p57_maccs_costs_integral(t,i,emis_source_awms_n2o,"n2o_n_direct")$(ord(maccs_steps) <= i57_mac_step_n2o(t,i,emis_source_awms_n2o)) =
    p57_maccs_costs_integral(t,i,emis_source_awms_n2o,"n2o_n_direct") +
    (f57_maccs_n2o(t,i,"awms_manure_n2o",maccs_steps) - f57_maccs_n2o(t,i,"awms_manure_n2o",maccs_steps-1))*(ord(maccs_steps)-1)*s57_step_length;

    p57_maccs_costs_integral(t,i,emis_source_rice_ch4,"ch4")$(ord(maccs_steps) <= i57_mac_step_ch4(t,i,emis_source_rice_ch4)) =
    p57_maccs_costs_integral(t,i,emis_source_rice_ch4,"ch4") +
    (f57_maccs_ch4(t,i,"rice_ch4",maccs_steps) - f57_maccs_ch4(t,i,"rice_ch4",maccs_steps-1))*(ord(maccs_steps)-1)*s57_step_length;

    p57_maccs_costs_integral(t,i,emis_source_ent_ferm_ch4,"ch4")$(ord(maccs_steps) <= i57_mac_step_ch4(t,i,emis_source_ent_ferm_ch4)) =
    p57_maccs_costs_integral(t,i,emis_source_ent_ferm_ch4,"ch4") +
    (f57_maccs_ch4(t,i,"ent_ferm_ch4",maccs_steps) - f57_maccs_ch4(t,i,"ent_ferm_ch4",maccs_steps-1))*(ord(maccs_steps)-1)*s57_step_length;

    p57_maccs_costs_integral(t,i,emis_source_awms_ch4,"ch4")$(ord(maccs_steps) <= i57_mac_step_ch4(t,i,emis_source_awms_ch4)) =
    p57_maccs_costs_integral(t,i,emis_source_awms_ch4,"ch4") +
    (f57_maccs_ch4(t,i,"awms_ch4",maccs_steps) - f57_maccs_ch4(t,i,"awms_ch4",maccs_steps-1))*(ord(maccs_steps)-1)*s57_step_length;
);

*Conversion from USD per ton C to USD per ton N and USD per ton CH4, using the old IPCC AR4 GWP factors.
p57_maccs_costs_integral(t,i,emis_source,"n2o_n_direct") = p57_maccs_costs_integral(t,i,emis_source,"n2o_n_direct")*12/44*298*44/28;
p57_maccs_costs_integral(t,i,emis_source,"ch4") = p57_maccs_costs_integral(t,i,emis_source,"ch4")*12/44*25;
