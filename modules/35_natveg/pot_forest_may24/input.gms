*** |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  MAgPIE License Exception, version 1.0 (see LICENSE file).
*** |  Contact: magpie@pik-potsdam.de

$setglobal c35_ad_policy  npi
$setglobal c35_aolc_policy  npi
$setglobal c35_shock_scenario  none

$setglobal c35_pot_forest_scenario  cc
*   options:  cc        (climate change)
*             nocc      (no climate change)
*             nocc_hist (no climate change after year defined by sm_fix_cc)

scalars
s35_hvarea Flag for harvested area and establishment (0=zero 1=exogenous 2=endogenous) / 2 /
s35_hvarea_secdforest annual secdforest harvest rate for s35_hvarea equals 1 (percent per year) / 0 /
s35_hvarea_primforest annual primforest harvest rate for s35_hvarea equals 1 (percent per year) / 0 /
s35_hvarea_other annual other land harvest rate for s35_hvarea equals 1 (percent per year) / 0 /
s35_timber_harvest_cost_secdforest   Cost for harvesting from secondary forest (USD17MER per ha) / 4920 /
s35_timber_harvest_cost_other        Cost for harvesting from other land (USD17MER per ha) / 6150 /
s35_timber_harvest_cost_primforest   Cost for harvesting from primary forest (USD17MER per ha) / 7380 /
s35_natveg_harvest_shr Constrains the allowed wood harvest from natural vegetation (1=unconstrained) (1) / 0.05 /
s35_secdf_distribution Flag for secdf initialization (0=all secondary forest in highest age class 1=Equal distribution among all age classes 2=Poulter distribution from MODIS satellite data) (1) / 2 /
s35_forest_damage Damage simulation in forests (0=none 1=shifting agriculture 2= Damage from shifting agriculture is faded out by c35_forest_damage_end 4= f35_forest_shock scenario) / 2 /
s35_forest_damage_end   Year of forest damage end  (1)              / 2050 /
s35_npi_ndc_reversal    Year in which NPI NDC reversal should take place (1) / Inf /
s35_edge_carbon         Switch for edge-effect carbon degradation (0=off 1=on) / 0 /
s35_edge_formula        Edge zone formula (0=step with cap 1=exponential decay) / 1 /
s35_edge_depth          Edge depth in km for step formula (km)                / 0.5 /
s35_edge_lambda         Exponential decay length in km for exp formula (km)   / 0.059 /
s35_edge_degrad         Fractional carbon loss in edge zone (1)                / 0.5 /
* Bodirsky closure: E = kappa_j * (1-p)^n * A^beta
* In log10: log10(E) = intercept_j + n*log10(1-p) + beta*log10(A)
* beta = fractal edge exponent (Koch snowflake=0.63, space-filling=1.0)
* n = saturation exponent (edge vanishes as p->1)
s35_edge_beta           Closure exponent on log10 forest area (1)              / 0.8286 /
s35_edge_n              Closure saturation exponent on log10 of 1 minus p (1)  / 0.7984 /
;

table f35_forest_lost_share(i,driver_source) Share of area damaged by forest fires (1)
$ondelim
$include "./modules/35_natveg/input/f35_forest_lost_share.cs3"
$offdelim
;

table f35_min_land_stock(t_all,j,pol35,pol_stock35) Avoided deforestation and land protection policies [minimum land stock] (Mha)
$ondelim
$include "./modules/35_natveg/input/npi_ndc_ad_aolc_pol.cs3"
$offdelim
;

table f35_forest_shock(t_all, shock_scen) Forest carbon shock scenarios (area share affected per year)
$ondelim
$include "./modules/35_natveg/input/f35_forest_shock.csv"
$offdelim
;

parameter f35_forest_disturbance_share(i) Share of area damaged by forest disturbances (1)
/
$ondelim
$include "./modules/35_natveg/input/f35_forest_disturbance_share.cs4"
$offdelim
/;

parameter f35_pot_forest_area(t_all,j) Potential forest area (mio. ha)
/
$ondelim
$include "./modules/35_natveg/input/pot_forest_area.cs2"
$offdelim
/;

$if "%c35_pot_forest_scenario%" == "nocc" f35_pot_forest_area(t_all,j) = f35_pot_forest_area("y1995",j);
$if "%c35_pot_forest_scenario%" == "nocc_hist" f35_pot_forest_area(t_all,j)$(m_year(t_all) > sm_fix_cc) = f35_pot_forest_area(t_all,j)$(m_year(t_all) = sm_fix_cc);
m_fillmissingyears(f35_pot_forest_area,"j");

parameter f35_edge_intercept(j) Bodirsky closure cluster fixed-effect intercept in log10 scale (1)
/
$ondelim
$include "./modules/35_natveg/input/f35_edge_intercept.csv"
$offdelim
/;
