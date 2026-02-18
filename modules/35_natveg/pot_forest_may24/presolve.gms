*** |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  MAgPIE License Exception, version 1.0 (see LICENSE file).
*** |  Contact: magpie@pik-potsdam.de

* ----------------------------------------------------
* Shift ageclasses due to shifting agriculture fires
* ----------------------------------------------------

* first calculate damages
if(s35_forest_damage=1,
  p35_disturbance_loss_secdf(t,j,ac_sub) = pc35_secdforest(j,ac_sub) * sum(cell(i,j),f35_forest_lost_share(i,"shifting_agriculture"))*m_timestep_length_forestry;
  p35_disturbance_loss_primf(t,j) = pcm_land(j,"primforest") * sum(cell(i,j),f35_forest_lost_share(i,"shifting_agriculture"))*m_timestep_length_forestry;
  );

* shifting cultivation is faded out
if(s35_forest_damage=2,
  p35_disturbance_loss_secdf(t,j,ac_sub) = pc35_secdforest(j,ac_sub) * sum(cell(i,j),f35_forest_lost_share(i,"shifting_agriculture"))*m_timestep_length_forestry*(1 - p35_damage_fader(t));
  p35_disturbance_loss_primf(t,j) = pcm_land(j,"primforest") * sum(cell(i,j),f35_forest_lost_share(i,"shifting_agriculture"))*m_timestep_length_forestry*(1 - p35_damage_fader(t));
  );

if(s35_forest_damage=3,
  p35_disturbance_loss_secdf(t,j,ac_sub) = pc35_secdforest(j,ac_sub) * sum((cell(i,j),combined_loss),f35_forest_lost_share(i,combined_loss))*m_timestep_length_forestry;
  p35_disturbance_loss_primf(t,j) = pcm_land(j,"primforest") * sum((cell(i,j),combined_loss),f35_forest_lost_share(i,combined_loss))*m_timestep_length_forestry;
  );

* generic disturbance scenarios
if(s35_forest_damage=4,
  p35_disturbance_loss_secdf(t,j,ac_sub) = pc35_secdforest(j,ac_sub) * f35_forest_shock(t,"%c35_shock_scenario%") * m_timestep_length;
  p35_disturbance_loss_primf(t,j) = pcm_land(j,"primforest") * f35_forest_shock(t,"%c35_shock_scenario%") * m_timestep_length;
  );

* Distribution of damages correctly
pc35_secdforest(j,ac_est) = pc35_secdforest(j,ac_est) + sum(ac_sub,p35_disturbance_loss_secdf(t,j,ac_sub))/card(ac_est2) + p35_disturbance_loss_primf(t,j)/card(ac_est2);

pc35_secdforest(j,ac_sub) = pc35_secdforest(j,ac_sub) - p35_disturbance_loss_secdf(t,j,ac_sub);
pcm_land(j,"primforest") = pcm_land(j,"primforest") - p35_disturbance_loss_primf(t,j);
vm_land.l(j,"primforest") = pcm_land(j,"primforest");


* -------------------------------------------------
* Calculate area of secondary forest recovery
* -------------------------------------------------

*** Calculate the upper boundary for secondary forest recovery
pc35_max_forest_recovery(j) = pm_max_forest_est(t,j) - sum(ac, pc35_land_other(j,"youngsecdf",ac));

*** Distribute forestry abandonement
* Abandoned forestry is directly shifted into p35_forest_recovery_area(t,j,ac_est) because it is
* assumed that forestry was located in areas suitable to grow forests.
p35_forest_recovery_area(t,j,ac_est) = vm_lu_transitions.l(j,"forestry","other")/card(ac_est2);
p35_forest_recovery_area(t,j,ac_est)$(sum(ac_est2, p35_forest_recovery_area(t,j,ac_est2)) > pc35_max_forest_recovery(j)) = pc35_max_forest_recovery(j)/card(ac_est2);

* The proportion of secondary forest recovery in total natveg
* recovery is derived from the remaining forest recovery area
pc35_forest_recovery_shr(j) = 0;
pc35_forest_recovery_shr(j)$((sum(land_ag, pcm_land(j,land_ag))+pcm_land(j,"urban")) > 0) = 
             (pc35_max_forest_recovery(j) - sum(ac_est, p35_forest_recovery_area(t,j,ac_est)))
            / (sum(land_ag, pcm_land(j,land_ag))+pcm_land(j,"urban"));
pc35_forest_recovery_shr(j)$(pc35_forest_recovery_shr(j) < 1e-6) = 0;
pc35_forest_recovery_shr(j)$(pc35_forest_recovery_shr(j) > 1) = 1;
* Abandoned land pc35_land_other(j,"othernat",ac_est) that has not yet been allocated to
* p35_forest_recovery_area(t,j,ac_est) is then distributed proportionally using the forest recovery share.
p35_forest_recovery_area(t,j,ac_est) = p35_forest_recovery_area(t,j,ac_est)
                                     + (pc35_land_other(j,"othernat",ac_est) - p35_forest_recovery_area(t,j,ac_est))
                                     * pc35_forest_recovery_shr(j);
p35_forest_recovery_area(t,j,ac_est)$(sum(ac_est2, p35_forest_recovery_area(t,j,ac_est2)) > pc35_max_forest_recovery(j)) = pc35_max_forest_recovery(j)/card(ac_est2);
p35_forest_recovery_area(t,j,ac_est)$(p35_forest_recovery_area(t,j,ac_est) > pc35_land_other(j,"othernat",ac_est)) = pc35_land_other(j,"othernat",ac_est);
p35_forest_recovery_area(t,j,ac_est)$(p35_forest_recovery_area(t,j,ac_est) < 1e-6) = 0;
pc35_land_other(j,"othernat",ac_est) = pc35_land_other(j,"othernat",ac_est) - p35_forest_recovery_area(t,j,ac_est);
pc35_land_other(j,"youngsecdf",ac_est) = pc35_land_other(j,"youngsecdf",ac_est) + p35_forest_recovery_area(t,j,ac_est);

* ------------------------------------------------
* Natural vegetation growth (age-class shift)
* ------------------------------------------------

* Regrowth of natural vegetation (natural succession) is modelled by shifting age-classes according to time step length.
s35_shift = m_timestep_length_forestry/5;
* example: ac10 in t = ac5 (ac10-1) in t-1 for a 5 yr time step (s35_shift = 1)
    p35_land_other(t,j,othertype35,ac)$(ord(ac) > s35_shift) = pc35_land_other(j,othertype35,ac-s35_shift);
* account for cases at the end of the age class set (s35_shift > 1) which are not shifted by the above calculation
    p35_land_other(t,j,othertype35,"acx") = p35_land_other(t,j,othertype35,"acx")
                  + sum(ac$(ord(ac) > card(ac)-s35_shift), pc35_land_other(j,othertype35,ac));

* Usual shift
* example: ac10 in t = ac5 (ac10-1) in t-1 for a 5 yr time step (s35_shift = 1)
    p35_secdforest(t,j,ac)$(ord(ac) > s35_shift) = pc35_secdforest(j,ac-s35_shift);
* account for cases at the end of the age class set (s35_shift > 1) which are not shifted by the above calculation
    p35_secdforest(t,j,"acx") = p35_secdforest(t,j,"acx")
                  + sum(ac$(ord(ac) > card(ac)-s35_shift), pc35_secdforest(j,ac));


* -------------------------------------------------------
* Carbon threshold for secondary forest maturation
* -------------------------------------------------------

*' @code
*' If the vegetation carbon density in a simulation unit due to regrowth
*' exceeds a threshold of 20 tC/ha the respective area is shifted from young secondary
*' forest, which is still considered other land, to secondary forest land.
p35_maturesecdf(t,j,ac)$(not sameas(ac,"acx")) =
      p35_land_other(t,j,"youngsecdf",ac)$(pm_carbon_density_secdforest_ac(t,j,ac,"vegc") > 20);
p35_land_other(t,j,"youngsecdf",ac) = p35_land_other(t,j,"youngsecdf",ac) - p35_maturesecdf(t,j,ac);
p35_secdforest(t,j,ac) = p35_secdforest(t,j,ac) + p35_maturesecdf(t,j,ac);
*' @stop

pc35_secdforest(j,ac) = p35_secdforest(t,j,ac);
v35_secdforest.l(j,ac) = pc35_secdforest(j,ac);
vm_land.l(j,"secdforest") = sum(ac, pc35_secdforest(j,ac));
pcm_land(j,"secdforest") = sum(ac, pc35_secdforest(j,ac));

pc35_land_other(j,othertype35,ac) = p35_land_other(t,j,othertype35,ac);
vm_land_other.l(j,othertype35,ac) = pc35_land_other(j,othertype35,ac);

vm_land.l(j,"other") = sum((othertype35,ac), pc35_land_other(j,othertype35,ac));
pcm_land(j,"other") = sum((othertype35,ac), pc35_land_other(j,othertype35,ac));

* -------------------------------------
* Set bounds based on land conservation
* -------------------------------------

* Within the optimization, primary forests can only decrease
* (e.g. due to cropland expansion).
* In contrast, other natural land can decrease and increase within the optimization.
* For instance, other natural land increases if agricultural land is abandoned.

* Correct land conservation for damage
pm_land_conservation(t,j,land_natveg,"protect")$(pm_land_conservation(t,j,land_natveg,"protect") > pcm_land(j,land_natveg)) = pcm_land(j,land_natveg);

** Setting bounds for only allowing s35_natveg_harvest_shr percentage of available forest to be harvested (highest age class)

* Primary forest

** Allowing selective logging only after historical period
if (sum(sameas(t_past,t),1) = 1,
vm_land.lo(j,"primforest") = 0;
else
vm_land.lo(j,"primforest") = (1-s35_natveg_harvest_shr) * pcm_land(j,"primforest");
);
* Primary forest conservation
vm_land.lo(j,"primforest")$(vm_land.lo(j,"primforest") < pm_land_conservation(t,j,"primforest","protect")) = pm_land_conservation(t,j,"primforest","protect");
vm_land.up(j,"primforest") = pcm_land(j,"primforest");

* Secondary forest

*reset bound
v35_secdforest.lo(j,ac) = 0;
v35_secdforest.up(j,ac) = Inf;

* Secondary forest conservation
p35_protection_dist(j,ac_sub) = 0;
p35_protection_dist(j,ac_sub)$(sum(ac_sub2,pc35_secdforest(j,ac_sub2)) > 0) = pc35_secdforest(j,ac_sub) / sum(ac_sub2,pc35_secdforest(j,ac_sub2));
pm_land_conservation(t,j,"secdforest","protect")$(pm_land_conservation(t,j,"secdforest","protect") > sum(ac_sub, pc35_secdforest(j,ac_sub))) = sum(ac_sub, pc35_secdforest(j,ac_sub));
if (sum(sameas(t_past,t),1) = 1,
v35_secdforest.lo(j,ac_sub) = pm_land_conservation(t,j,"secdforest","protect") * p35_protection_dist(j,ac_sub);
else
v35_secdforest.lo(j,ac_sub) = max((1-s35_natveg_harvest_shr) * pc35_secdforest(j,ac_sub), pm_land_conservation(t,j,"secdforest","protect") * p35_protection_dist(j,ac_sub));
);
* upper bound
v35_secdforest.up(j,ac_sub) = pc35_secdforest(j,ac_sub);
m_boundfix(v35_secdforest,(j,ac_sub),l,1e-6);

* set restoration target
p35_land_restoration(j,"secdforest") = pm_land_conservation(t,j,"secdforest","restore");
* Do not restore secdforest in areas where total natural
* land area meets the total natural land conservation target
p35_land_restoration(j,"secdforest")$(sum(land_natveg, pcm_land(j,land_natveg)) >= sum((land_natveg, consv_type), pm_land_conservation(t,j,land_natveg,consv_type))) = 0;

* Since forest restoration cannot be bigger than the potential area for secdforest recovery,
* any remaining restoration area is substracted and shifted to other land restoration.
p35_restoration_shift(j) = p35_land_restoration(j,"secdforest") - pc35_max_forest_recovery(j);
p35_restoration_shift(j)$(p35_restoration_shift(j) < 1e-6) = 0;
p35_restoration_shift(j)$(p35_restoration_shift(j) > p35_land_restoration(j,"secdforest")) = p35_land_restoration(j,"secdforest");
p35_land_restoration(j,"secdforest") = p35_land_restoration(j,"secdforest") - p35_restoration_shift(j);
pm_land_conservation(t,j,"secdforest","restore") = p35_land_restoration(j,"secdforest");
pm_land_conservation(t,j,"other","restore") = pm_land_conservation(t,j,"other","restore") + p35_restoration_shift(j);

* set conservation bound
vm_land.lo(j,"secdforest") = pm_land_conservation(t,j,"secdforest","protect") + p35_land_restoration(j,"secdforest");

** Other land

*reset bounds
vm_land_other.lo(j,"othernat",ac) = 0;
vm_land_other.up(j,"othernat",ac) = Inf;
vm_land_other.lo(j,"youngsecdf",ac) = 0;
*set upper bound
vm_land_other.up(j,"othernat",ac_sub) = pc35_land_other(j,"othernat",ac_sub);
vm_land_other.up(j,"youngsecdf",ac_sub) = pc35_land_other(j,"youngsecdf",ac_sub);
vm_land_other.fx(j,"youngsecdf",ac_est) = 0;
m_boundfix(vm_land_other,(j,othertype35,ac_sub),l,1e-6);

pm_max_forest_est(t,j)$(pm_max_forest_est(t,j) < sum(ac, pc35_land_other(j,"youngsecdf",ac))) = 
  sum(ac, pc35_land_other(j,"youngsecdf",ac));

* Other land conservation
* protection bound fix
pm_land_conservation(t,j,"other","protect")$(pm_land_conservation(t,j,"other","protect") > 
   sum((othertype35,ac_sub), pc35_land_other(j,othertype35,ac_sub))) = 
      sum((othertype35,ac_sub), pc35_land_other(j,othertype35,ac_sub));
* set restoration target
p35_land_restoration(j,"other") = pm_land_conservation(t,j,"other","restore");
* Do not restore other land in areas where total natural
* land area meets the total natural land conservation target
p35_land_restoration(j,"other")$(sum(land_natveg, pcm_land(j,land_natveg)) >= sum((land_natveg, consv_type), pm_land_conservation(t,j,land_natveg,consv_type))) = 0;
pm_land_conservation(t,j,"other","restore") = p35_land_restoration(j,"other");
* set conservation bound
vm_land.lo(j,"other") = pm_land_conservation(t,j,"other","protect") + p35_land_restoration(j,"other");

* boundfix for land_natveg
m_boundfix(vm_land,(j,land_natveg),up,1e-6);

* ----------------------------
* Calculate carbon density
* ------------------------------

p35_carbon_density_other(t,j,"othernat",ac,ag_pools) = pm_carbon_density_other_ac(t,j,ac,ag_pools);
p35_carbon_density_other(t,j,"youngsecdf",ac,ag_pools) = pm_carbon_density_secdforest_ac(t,j,ac,ag_pools);

* -------------------------------------------
* Edge-effect carbon density degradation
* -------------------------------------------
* Closure (Form 3b): log10(E) = alpha_j + beta*log10(A_km2) + gamma*p + gamma2*p^2
* Closure (Form 3d): log10(E) = alpha_j + beta*log10(A_km2) + (gamma+gamma_reg)*p
*                              + (gamma2+gamma2_reg)*p^2 + gamma3*p^3
* where E = edge length (km), A_km2 = forest area (km2), p = forest fraction
* MAgPIE land is in Mha; closure needs km2, so convert inline: 1 Mha = 10000 km2
*
* Edge zone formula (s35_edge_formula):
*   0 = Step function: f_edge = min(E * delta / A_km2, 1)
*   1 = Exponential decay: r = lambda * E / A_km2, f_eff = r * (1 - exp(-1/r))
*       Naturally handles strip overlap; no cap needed.
*
* carbon_factor = 1 - f_edge * d (d = degradation intensity in edge zone)
* Applied to vegc pool only for primforest, secdforest, youngsecdf
* s35_edge_form: 0 = Form 3b (global gamma), 1 = Form 3d (regional gamma + p^3)

if(s35_edge_carbon = 1,

* Initialize pipeline parameters (needed even when pipeline is off to avoid GAMS error 141)
  p35_edge_pipeline_release(t,j) = 0;
  if(ord(t) = 1,
    p35_edge_carbon_loss_prev(j) = 0;
    p35_edge_pipeline(j) = 0;
  );

* Total forest area (Mha)
  p35_forest_area(j) = pcm_land(j,"primforest") + pcm_land(j,"secdforest")
                      + pcm_land(j,"forestry");

* Forest fraction (dimensionless: forest Mha / total land Mha)
  p35_forest_fraction(j) = 0;
  p35_forest_fraction(j)$(sum(land, pcm_land(j,land)) > 0) =
    p35_forest_area(j) / sum(land, pcm_land(j,land));
  p35_forest_fraction(j)$(p35_forest_fraction(j) > 1) = 1;

* Edge fraction: closure predicts E(km) from A(km2) and p
* Convert A from Mha to km2 inline: A_km2 = p35_forest_area * 10000
* First compute edge ratio = E / A_km2, then apply step or exponential formula
  p35_edge_fraction(j) = 0;
  p35_edge_ratio(j) = 0;

  if(s35_edge_form = 0,
* Form 3b: compute E/A ratio from closure with global gamma coefficients
    p35_edge_ratio(j)$(p35_forest_area(j) > 1e-10 AND f35_edge_intercept(j) > 0) =
        10 ** (f35_edge_intercept(j)
             + s35_edge_beta * log10(p35_forest_area(j) * 10000)
             + s35_edge_gamma * p35_forest_fraction(j)
             + s35_edge_gamma2 * p35_forest_fraction(j) * p35_forest_fraction(j))
        / (p35_forest_area(j) * 10000);
  );

  if(s35_edge_form = 1,
* Form 3d: compute E/A ratio from closure with regional gamma + p^3
    p35_edge_ratio(j)$(p35_forest_area(j) > 1e-10 AND f35_edge_intercept_3d(j) > 0) =
        10 ** (f35_edge_intercept_3d(j)
             + s35_edge_beta * log10(p35_forest_area(j) * 10000)
             + (s35_edge_gamma + f35_edge_region_gamma(j)) * p35_forest_fraction(j)
             + (s35_edge_gamma2 + f35_edge_region_gamma2(j))
               * p35_forest_fraction(j) * p35_forest_fraction(j)
             + s35_edge_gamma3
               * p35_forest_fraction(j) * p35_forest_fraction(j) * p35_forest_fraction(j))
        / (p35_forest_area(j) * 10000);
  );

* Apply edge zone formula to convert E/A ratio into edge-affected fraction
  if(s35_edge_formula = 0,
* Step function: f_edge = min(E/A * depth, 1)
    p35_edge_fraction(j)$(p35_edge_ratio(j) > 0) =
      min(p35_edge_ratio(j) * s35_edge_depth, 1);
  );

  if(s35_edge_formula = 1,
* Exponential decay: r = lambda * E/A, f_eff = r * (1 - exp(-1/r))
* Naturally saturates at 1 for small fragments (no cap needed)
    p35_edge_fraction(j)$(p35_edge_ratio(j) > 0) =
      s35_edge_lambda * p35_edge_ratio(j)
      * (1 - exp(-1 / (s35_edge_lambda * p35_edge_ratio(j))));
  );

* Carbon edge factor: fraction of original carbon density retained
  p35_carbon_edge_factor(j) = 1 - p35_edge_fraction(j) * s35_edge_degrad;

* Calculate total carbon lost to edge effects BEFORE applying the factor
* Loss = (1 - factor) * sum over forest types of (density_vegc * area)
* Includes primforest, secdforest, and youngsecdf (young secondary forest < 20 tC/ha)
* NOTE: forestry (managed plantations) is included in p35_forest_area for the closure
*       but its carbon density is NOT edge-reduced (module 32 runs before module 35).
*       This is a known limitation; managed plantation edges may warrant separate treatment.
  p35_edge_carbon_loss(t,j) =
    (1 - p35_carbon_edge_factor(j))
    * (fm_carbon_density(t,j,"primforest","vegc") * pcm_land(j,"primforest")
     + sum(ac, pm_carbon_density_secdforest_ac(t,j,ac,"vegc") * pc35_secdforest(j,ac))
     + sum(ac, p35_carbon_density_other(t,j,"youngsecdf",ac,"vegc") * pc35_land_other(j,"youngsecdf",ac)));

* Apply to primforest vegc
  fm_carbon_density(t,j,"primforest","vegc") =
    fm_carbon_density(t,j,"primforest","vegc") * p35_carbon_edge_factor(j);

* Apply to secdforest vegc (all age classes)
  pm_carbon_density_secdforest_ac(t,j,ac,"vegc") =
    pm_carbon_density_secdforest_ac(t,j,ac,"vegc") * p35_carbon_edge_factor(j);

* Apply to youngsecdf via p35_carbon_density_other
  p35_carbon_density_other(t,j,"youngsecdf",ac,"vegc") =
    p35_carbon_density_other(t,j,"youngsecdf",ac,"vegc") * p35_carbon_edge_factor(j);

* --- Temporal pipeline for edge carbon emissions ---
* Instead of reporting edge carbon loss as an instantaneous stock change,
* spread the atmospheric release over time using an exponential decay
* with e-folding time tau (Brinck et al. 2017, Nature Comms).
*
* tau derivation:
*   Brinck (2017) fitted an exponential decay model to pantropical satellite
*   data of edge zone biomass loss: B(t) = B0 * exp(-t/tau), finding tau = 13 yr
*   (sensitivity range 10-20 yr). This is the only pantropical estimate;
*   field studies give 10-32 yr (Laurance 2011) and imply ~12 yr (Silva Junior 2020).
*   tau = 13 yr is used as default; future calibration against observed emission
*   trajectories is needed (see RESULTS.md open tasks).
*
* T_hist derivation:
*   T_hist = 41 yr is calibrated so that the pipeline at 1995 reproduces Brinck's
*   0.34 GtC/yr tropical edge flux. The realization fraction r(41,13) = 0.70 means
*   70% of equilibrium edge degradation has been realized by 1995.
*
* The pipeline is REPORTING-LAYER ONLY: the optimizer still sees instant stock
* reduction via p35_carbon_edge_factor. Only the emission flow reported by
* magpie4::reportEmissions is temporally spread.

  if(s35_edge_pipeline = 1,

    if(ord(t) = 1,
* Initialize pipeline at first timestep
* Realization fraction: r = 1 - (tau/T_hist) * (1 - exp(-T_hist/tau))
* Pipeline(1995) = edge_carbon_loss(1995) * (1 - r)
*                = edge_carbon_loss(1995) * (tau/T_hist) * (1 - exp(-T_hist/tau))
      p35_edge_pipeline(j) =
        p35_edge_carbon_loss(t,j)
        * (s35_edge_tau / s35_edge_thist)
        * (1 - exp(-s35_edge_thist / s35_edge_tau));

* First-period release from the legacy pipeline
      p35_edge_pipeline_release(t,j) =
        p35_edge_pipeline(j) * (1 - exp(-m_yeardiff(t) / s35_edge_tau));

      p35_edge_pipeline(j) =
        p35_edge_pipeline(j) - p35_edge_pipeline_release(t,j);

    else
* Subsequent timesteps: decay + add new committed + release
* new_committed = increase in edge carbon loss stock since previous period
      p35_edge_pipeline(j) =
        p35_edge_pipeline(j) * exp(-m_yeardiff(t) / s35_edge_tau)
        + max(0, p35_edge_carbon_loss(t,j) - p35_edge_carbon_loss_prev(j));

      p35_edge_pipeline_release(t,j) =
        p35_edge_pipeline(j) * (1 - exp(-m_yeardiff(t) / s35_edge_tau));

      p35_edge_pipeline(j) =
        p35_edge_pipeline(j) - p35_edge_pipeline_release(t,j);

    );

* Store current edge carbon loss for next period's delta calculation
    p35_edge_carbon_loss_prev(j) = p35_edge_carbon_loss(t,j);

  );

);

* ----------------------------
* NPI/NDC protection policy
* ----------------------------

p35_min_forest(t,j)$(p35_min_forest(t,j) > pcm_land(j,"primforest") + pcm_land(j,"secdforest") + pcm_land(j,"forestry"))
  = pcm_land(j,"primforest") + pcm_land(j,"secdforest") + pcm_land(j,"forestry");
p35_min_other(t,j)$(p35_min_other(t,j) > pcm_land(j,"other")) = pcm_land(j,"other");

* NPI / NDC reversal
if (m_year(t) >= s35_npi_ndc_reversal,
  p35_min_forest(t,j) = 0;
  p35_min_other(t,j) = 0;
);

** Youngest age classes are not allowed to be harvested
v35_hvarea_secdforest.fx(j,ac_est) = 0;
v35_hvarea_other.fx(j,othertype35,ac_est) = 0;
v35_secdforest_reduction.fx(j,ac_est) = 0;
v35_other_reduction.fx(j,othertype35,ac_est) = 0;

if(s35_hvarea = 0,
 v35_hvarea_secdforest.fx(j,ac_sub) = 0;
 v35_hvarea_primforest.fx(j) = 0;
 v35_hvarea_other.fx(j,othertype35,ac_sub) = 0;
elseif s35_hvarea = 1,
 v35_hvarea_secdforest.fx(j,ac_sub) = (v35_secdforest.l(j,ac_sub) - v35_secdforest.lo(j,ac_sub))*s35_hvarea_secdforest*m_timestep_length_forestry;
 v35_hvarea_primforest.fx(j) = (vm_land.l(j,"primforest") - vm_land.lo(j,"primforest"))*s35_hvarea_primforest*m_timestep_length_forestry;
 v35_hvarea_other.fx(j,othertype35,ac_sub) = (vm_land_other.l(j,othertype35,ac_sub) - vm_land_other.lo(j,othertype35,ac_sub))*s35_hvarea_other*m_timestep_length_forestry;
);

* Update biodiversity value
vm_bv.l(j,"primforest",potnatveg) = 
  pcm_land(j,"primforest") * fm_bii_coeff("primary",potnatveg) * fm_luh2_side_layers(j,potnatveg);

vm_bv.l(j,"secdforest",potnatveg) = 
  sum(bii_class_secd, sum(ac_to_bii_class_secd(ac,bii_class_secd), pc35_secdforest(j,ac)) *
  fm_bii_coeff(bii_class_secd,potnatveg)) * fm_luh2_side_layers(j,potnatveg);

vm_bv.l(j,"other",potnatveg) = 
  sum(bii_class_secd, sum(ac_to_bii_class_secd(ac,bii_class_secd), sum(othertype35, pc35_land_other(j,othertype35,ac))) *
  fm_bii_coeff(bii_class_secd,potnatveg)) * fm_luh2_side_layers(j,potnatveg);
