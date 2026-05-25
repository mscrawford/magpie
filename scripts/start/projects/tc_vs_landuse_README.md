# TC vs land-use change: marginal contribution to food-system transformation

## Question

How much of the cropland-sparing and food-price relief that MAgPIE achieves under an aggressive 1.5C climate policy comes from endogenous TC (`tau` in module 13_tc) versus from food-system transformation (FST: diet shift + land protection + biodiversity target + N abatement)? At what TC level does land-use change stop being able to substitute?

## Design

Three scenarios:

| Scenario   | `c56_pollutant_prices`         | `c56_emis_policy` | FST layers |
|------------|--------------------------------|-------------------|------------|
| BAU        | `R34M410-SSP2-NPi2025`         | `reddnatveg_nosoil` | none |
| Energy     | `R34M410-SSP2-PkBudg650` (1.5C)| `all_nosoil`      | none |
| EnergyFST  | `R34M410-SSP2-PkBudg650`       | `all_nosoil`      | `c22_protect_scenario=30by30` (2025-2050); `s15_exo_diet=1`, `c15_EAT_scen=FLX`, `c15_kcal_scen=2500kcal` (2025-2050); `s44_bii_target=0.78` (Module 44 BII); `s57_maxmac_n_soil=201`, `s57_maxmac_n_awms=201` (Module 57 N MACCs at max step) |

SSP2 + NPI base for all scenarios. `coup2100` timesteps. h12 regions. Base NUE trajectory (`c50_scen_neff`) unchanged - all N abatement comes via the Module 57 MACCs.

(Two intermediate scenarios were run and dropped from the active analysis: `EnergyCons` (Energy + 30by30 alone) and `Full` (Energy + 30by30 + diet, no biodiv/N). Their run outputs remain on disk under `output/TC_EnergyCons_*` and `output/TC_Full_*` if needed.)

For each non-BAU scenario, the run is repeated with tau fixed exogenously (`tc=exo`, `c13_croparea_consv=0`, `s13_ignore_tau_historical=1`) at the blend

```
tau_blend(t, h, type) = tau_BAU(t, h, type) + f * [tau_TS(t, h, type) - tau_BAU(t, h, type)]
```

for f in {0, 0.5, 0.75, 1}. f=1 reuses the endogenous reference. Active analysis: 3 baselines + 6 sweeps = 9 runs at coup2100, 3-parallel local execution. All feasible (modelstat 2 throughout).

## Results

### Endogenous tau in 2100 (crop, mean across superregions)

| Scenario   | tau_crop | vs BAU |
|------------|----------|--------|
| BAU        | 1.85     | -      |
| Energy     | 2.16     | +17%   |
| EnergyFST  | 2.40     | +30%   |

The 1.5C carbon price pushes endogenous TC up 17% over BAU. Adding the full FST bundle (diet + land protection + biodiversity + N MACCs) pushes it further to +30% - the binding land/biodiversity/N constraints force more intensification on the cropland that remains, even though the diet transition reduces demand.

### Global cropland in 2100 (Mha)

| Scenario  | f=0   | f=0.5 | f=0.75 | f=1   | TC marginal (f=0 -> f=1) |
|-----------|-------|-------|--------|-------|--------------------------|
| BAU       | 1923  | -     | -      | -     | -                        |
| Energy    | 1910  | 1708  | 1628   | 1561  | **-349**                 |
| EnergyFST | 1404  | 1256  | 1200   | 1146  | **-258**                 |

Pasture follows the same pattern (BAU 3162 -> Energy_f1 2820 -> EnergyFST_f1 2109 Mha). Primary forest in 2100 is 1313 Mha under EnergyFST vs 1285 Mha under Energy_f1: 30by30 + BII jointly protect ~28 Mha more primary forest. Forestry grows from 338 (BAU) to 637 (Energy_f1) to 913 (EnergyFST_f1) Mha through carbon-price-induced afforestation that the FST bundle further amplifies.

### Global food price index in 2050 / 2100 (Laspeyres, baseyear 2005)

| Scenario  | f=0       | f=0.5     | f=0.75    | f=1       |
|-----------|-----------|-----------|-----------|-----------|
| BAU       | 82 / 83   | -         | -         | -         |
| Energy    | 189 / 204 | 184 / 186 | 179 / 177 | 177 / 171 |
| EnergyFST | 196 / 205 | 192 / 187 | 188 / 183 | 184 / 176 |

(values shown as `2050 / 2100`)

The 1.5C carbon price roughly doubles food prices over BAU (Energy_f0: 204 vs BAU 83 in 2100). TC headroom inside Energy buys back ~15% (204 -> 171). The FST bundle does NOT reduce food prices: EnergyFST_f0 (205) sits essentially at Energy_f0 (204), and EnergyFST_f1 (176) is a few points ABOVE Energy_f1 (171). The diet's price-relieving effect is canceled by the price pressure from 30by30 + BII + N abatement.

## Marginal contribution of TC vs FST vs both (decomposition)

Reference cell `Y_ref = Y(Energy, f=0)`: 1.5C carbon price active, TC at BAU level, no FST. Effects sum if independent; negative synergy means substitutes. Sign convention: positive `delta` = lever REDUCES the outcome. From `output/tc_vs_landuse_plots/marginal_contributions.csv` (2100):

| Outcome        | Y_ref | delta_TC | delta_FST | delta_Both | synergy | TC share | FST share |
|----------------|-------|----------|-----------|------------|---------|----------|-----------|
| Cropland (Mha) | 1910  | 349      | 506       | **764**    | -91     | 46%      | 66%       |
| Food price idx | 204   | 33       | -1        | **28**     | -4      | 118%     | -4%       |
| Primary forest (Mha, growth) | 1279 | -6 | -34 | -35 | (FST dominates) | - | - |

### Headline findings

**1. FST does most of the land-sparing; TC adds substantially on top; synergy is mild.**
Cropland sparing decomposes as TC 349 Mha (46% of combined), FST 506 Mha (66% of combined), combined 764 Mha. Synergy of -91 Mha means the two levers are partial substitutes (~12% over-attribution) but mostly complementary on land. The dominant FST lever within the bundle is the diet transition (~370 Mha at zero TC); 30by30 + biodiv + N add the rest via land conversion limits.

**2. TC is the dominant lever for food affordability; FST is neutral-to-slightly-negative.**
TC alone (Energy f=0 -> f=1) reduces the 2100 food price index by 33 points (204 -> 171). FST alone (Energy f=0 -> EnergyFST f=0) shifts it by -1 point - essentially neutral. Combined (EnergyFST f=1) gives 28 points of price relief, which is 5 points LESS than TC alone could deliver inside the Energy world. The biodiv + N + 30by30 constraints push food prices up enough to cancel the diet's price-reducing effect.

**3. EnergyFST achieves the strongest land outcomes but isn't the cheapest food.**
Cropland 1146 Mha (vs Energy_f1 1561 and BAU 1923); pasture 2109 (vs 2820, 3162); +28 Mha primary forest protected. Food price 176 vs Energy_f1's 171 - FST costs ~3% in food price for ~26% additional cropland sparing.

**4. TC headroom regains marginal value under FST.**
Inside Energy, TC reduces food prices by 33 pts (204 -> 171). Inside EnergyFST, TC reduces prices by 29 pts (205 -> 176) - nearly the same magnitude. So the binding FST constraints (30by30 + BII + N MACCs) keep TC's price-buffering value intact, in contrast with a diet-only "transformation" where TC would have been largely redundant on prices.

## Limitations

- The blend is a 1-D cut through (t x h x tautype) tau space. f=1 means "this scenario's own endogenous tau," not a global maximum across scenarios.
- "Feasibility" is GAMS modelstat 2/7. Climate policy is implemented as price signals (Module 56), not hard emission caps. The hard constraints in EnergyFST are 30by30 (Module 22), the BII lower bound (Module 44), and the N MACC max step (Module 57). All three together still produce feasible solves at every f tested.
- FST bundles four levers; the decomposition treats them collectively. To isolate diet, 30by30, biodiv, and N individually would require additional scenarios (the `EnergyCons` and `Full` runs on disk give partial coverage if needed).
- Carbon-price coverage is `all_nosoil` (excludes soil C).

## Files

- Branch: `experiment/tc-marginal-pb` on `mscrawford/magpie`
  - https://github.com/mscrawford/magpie/tree/experiment/tc-marginal-pb
- Orchestrator: `scripts/start/projects/tc_vs_landuse.R`
- Scenario definitions: `scripts/start/projects/tc_vs_landuse_config.R` (config still defines BAU, Energy, EnergyCons, Full, FullPlus; the plotter filters to BAU, Energy, FullPlus and relabels FullPlus -> EnergyFST in displays)
- Tau-blending utility: `scripts/output/extra/blend_tau.R`
- Plotting: `scripts/output/projects/tc_vs_landuse_plot.R`
- Active run outputs: `output/TC_{BAU,Energy,FullPlus}_{endo,f00,f50,f75}/`
- Dropped-from-analysis run outputs (still on disk): `output/TC_{EnergyCons,Full}_{endo,f00,f50,f75}/`
- Plots: `output/tc_vs_landuse_plots/0{1..8}_*.pdf`
  - `02_land_allocation_grid.pdf` is the headline land-use visual
  - `04_tau_trajectory.pdf` shows the per-scenario tau ranges
  - `07_food_price_index.pdf` shows the global food price index over time
  - `08_marginal_contributions.pdf` shows the TC vs FST decomposition (2100)
- Decomposition CSV: `output/tc_vs_landuse_plots/marginal_contributions.csv`
