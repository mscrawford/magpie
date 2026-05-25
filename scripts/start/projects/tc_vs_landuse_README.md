# TC vs land-use change: marginal contribution to food-system transformation

## Question

How much of the cropland-sparing and food-price relief that MAgPIE achieves under an aggressive 1.5C climate policy comes from endogenous TC (`tau` in module 13_tc) versus from food-system transformation (FST: diet shift + land protection + biodiversity target + N abatement)? At what TC level does land-use change stop being able to substitute?

## Design

Three scenarios:

| Scenario   | `c56_pollutant_prices`         | `c56_emis_policy` | FST layers |
|------------|--------------------------------|-------------------|------------|
| BAU        | `R34M410-SSP2-NPi2025`         | `reddnatveg_nosoil` | none |
| Energy     | `R34M410-SSP2-PkBudg650` (1.5C)| `all_nosoil`      | none |
| EnergyFST  | `R34M410-SSP2-PkBudg650`       | `all_nosoil`      | `c22_protect_scenario=30by30` (2025-2050); `s15_exo_diet=1`, `c15_EAT_scen=FLX`, `c15_kcal_scen=2500kcal` (2025-2050); `s44_bii_target=0.78` (Module 44 BII); `s57_maxmac_n_soil=201`, `s57_maxmac_n_awms=201` (Module 57 N MACCs at max step); `c42_env_flow_policy="on"`, `s42_env_flow_scenario=2` (Module 42 environmental flow protection, Smakhtin gridcell-specific, 2025-2050) |

SSP2 + NPI base for all scenarios. `coup2100` timesteps. h12 regions. Base NUE trajectory (`c50_scen_neff`) unchanged - all N abatement comes via the Module 57 MACCs. Base water-demand scenarios unchanged - water protection comes via the Module 42 environmental flow policy.

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

## Marginal contribution of TC vs Diet vs both (decomposition)

Reference cell `Y_ref = Y(EnergyCons, f=0)`: 1.5C carbon price + 30by30 active, TC at BAU level, no diet. Treatment cell `Y(Full, f=1)`: TC + diet both on (30by30 already in both cells). Effects sum if independent; negative synergy means substitutes. Sign convention: positive `delta` = lever REDUCES the outcome. From `output/tc_vs_landuse_plots/marginal_contributions.csv` (2100):

| Outcome        | Y_ref | delta_TC | delta_Diet | delta_Both | synergy | TC share | Diet share |
|----------------|-------|----------|------------|------------|---------|----------|------------|
| Cropland (Mha) | 1905  | 340      | 369        | **394**    | **-315**| 86%      | 94%        |
| Food price idx | 205   | 35       | 59         | **61**     | **-33** | 57%      | 97%        |
| Primary forest (Mha, growth) | 1310 | 0 | 0 | 0 | - | - | - |
| Secdforest (Mha, growth) | 2447 | -49 | -47 | -54 | +42 (substitution with flipped sign for growth) | - | - |

**Frame caveat:** This decomposition lives in the **Energy + 30by30 frame** -- it uses scenarios `EnergyCons` (= Energy + 30by30, no diet) and `Full` (= EnergyCons + diet). It does NOT include the biodiv + N MACCs that are part of EnergyFST. The 4-run `EnergyConsBioN` scenario currently in flight will let us run a parallel decomposition within the full-FST frame; until then, treat this decomposition as the clean TC-vs-diet question with the climate-policy and land-protection layers already in the reference.

### Headline findings

**1. TC and diet are strong substitutes on the cropland frontier.**
Diet alone delivers 94% of what TC + diet combined achieve; TC alone delivers 86%. Adding both together yields only ~6 percentage points more than diet alone. Synergy = -315 Mha (the levers' deltas sum to 180% of the combined effect). Mechanism: both levers reduce the same scarcity (land needed to meet food demand) -- TC from the supply side (yield per ha up), diet from the demand side (kcal demand down).

**2. Diet is the dominant lever for food affordability.**
Diet alone reduces the 2100 food price index by 59 points (205 -> 146); TC alone by 35; combined by 61. Diet captures 97% of the combined effect on prices. The mechanism is the same as for land -- reduced demand (especially livestock) lowers production cost.

**3. EnergyFST (carbon + 30by30 + diet + biodiv + N) achieves the strongest land outcomes but is NOT the cheapest food.**
Cropland 1146 Mha (vs Energy_f1 1561 and BAU 1923); pasture 2109 (vs 2820, 3162); +28 Mha primary forest protected. Food price 176 vs Energy_f1's 171 -- the biodiv + N constraints add price pressure that partly cancels the diet's price-reducing effect.

**4. TC headroom regains marginal value under the full FST bundle.**
Inside the simpler `Full` (no biodiv/N), going from f=0 to f=1 changes the 2100 food price index by only ~2 points (146 -> 144) -- TC is nearly redundant on prices when only diet is doing the demand-side work. Inside `EnergyFST` (with biodiv + N), going from f=0 to f=1 changes the food price by ~29 points (205 -> 176). The biodiv + N constraints make intensification headroom valuable again -- TC's substitutability with diet (findings 1-2) is conditional on not stacking biodiv + N on top.

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
