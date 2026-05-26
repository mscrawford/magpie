# TC's importance for enabling food-system transformations

## Question

**How important is endogenous TC (`tau` in module 13_tc) for enabling food-system transformations, and how does TC's marginal value change across plausible transformation packages?**

Specifically: in a world that is also pursuing other goals (carbon pricing, 30by30, biodiversity, N abatement, water protection), how much does TC headroom matter for both **land outcomes** (cropland, forest, etc.) and **societal/welfare outcomes** (consumer food prices, production, calories, etc.)? Does TC matter more or less when a dietary shift is also in play? Are there individual policies (per FST atom) where TC's importance is unusually high?

Six FST atoms are treated symmetrically as policy levers: **Energy** (carbon price), **30by30** (land conservation), **Diet** (EAT-Lancet), **Biodiv** (BII target), **N MACCs**, **Water EFP**. None is privileged as an "always-on" backdrop in the design; BAU is the no-policy reference.

## Design

Three scenarios:

| Scenario   | `c56_pollutant_prices`         | `c56_emis_policy` | FST layers |
|------------|--------------------------------|-------------------|------------|
| BAU        | `R34M410-SSP2-NPi2025`         | `reddnatveg_nosoil` | none |
| Energy     | `R34M410-SSP2-PkBudg650` (1.5C)| `all_nosoil`      | none |
| EnergyFST  | `R34M410-SSP2-PkBudg650`       | `all_nosoil`      | `c22_protect_scenario=30by30` (2025-2050); `s15_exo_diet=1`, `c15_EAT_scen=FLX`, `c15_kcal_scen=2500kcal` (2025-2050); `s44_bii_target=0.78` (Module 44 BII); `s57_maxmac_n_soil=201`, `s57_maxmac_n_awms=201` (Module 57 N MACCs at max step); `c42_env_flow_policy="on"`, `s42_env_flow_scenario=2` (Module 42 environmental flow protection, Smakhtin gridcell-specific, 2025-2050) |

SSP2 + NPI base for all scenarios. `coup2100` timesteps. h12 regions. Base NUE trajectory (`c50_scen_neff`) unchanged - all N abatement comes via the Module 57 MACCs. Base water-demand scenarios unchanged - water protection comes via the Module 42 environmental flow policy.

(One additional scenario is used by the marginal-contribution decomposition: `EnergyConsBioN` = EnergyFST minus the diet transition. It populates the "Diet OFF" column of the 2x2.)

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

### Global consumer food price index in 2050 / 2100 (Laspeyres, baseyear 2005)

| Scenario  | f=0       | f=0.5     | f=0.75    | f=1       |
|-----------|-----------|-----------|-----------|-----------|
| BAU       | 82 / 83   | -         | -         | -         |
| Energy    | 189 / 204 | 184 / 186 | 179 / 177 | 177 / 171 |
| EnergyFST | 196 / 205 | 192 / 187 | 188 / 183 | 184 / 176 |

(values shown as `2050 / 2100`)

**Metric note:** `magpie4::priceIndexFood()` returns a Laspeyres index of **consumer prices** (producer prices + marketing margins + value-added, pulled from Module 15's `FoodDemandModuleConsumerPrices` -- not the producer-side `prices(type="producer")`). Baseyear 2005 = index 100; BAU drifts down to ~83 by 2100 as productivity grows faster than demand.

The 1.5C carbon price roughly doubles consumer food prices over BAU (Energy_f0: 204 vs BAU 83 in 2100). TC headroom inside Energy buys back ~15% (204 -> 171). The FST bundle does NOT reduce food prices: EnergyFST_f0 (205) sits essentially at Energy_f0 (204), and EnergyFST_f1 (176) is a few points ABOVE Energy_f1 (171). The diet's price-relieving effect is canceled by the price pressure from 30by30 + BII + N abatement.

## Marginal contribution of TC vs Diet vs both (within the full-FST package)

This is the **per-package** view of the headline question: when the full FST package is being implemented, how much does TC headroom matter relative to the dietary shift? It is NOT a decomposition of BAU -> FST into per-atom contributions -- that question requires per-atom scenarios (queued as next work; see "Outstanding analysis" at the end).

The decomposition lives entirely inside the **full FST backdrop**: 1.5C carbon price + 30by30 + biodiv (BII 0.78) + N MACCs (max step) + water EFP -- ALL on in every cell of the 2x2.

The 2x2:

|              | Diet OFF                      | Diet ON                       |
|--------------|-------------------------------|-------------------------------|
| TC at BAU    | EnergyConsBioN f=0            | FullPlus f=0                  |
| TC at endo   | EnergyConsBioN f=1            | FullPlus f=1                  |

Reference cell `Y_ref = Y(EnergyConsBioN, f=0)`: full FST minus the diet, TC stuck at BAU.
Treatment cell `Y(FullPlus, f=1)`: full FST with both TC and diet on.
Sign convention: positive `delta` = lever REDUCES the outcome. Negative synergy = substitutes.

From `output/tc_vs_landuse_plots/marginal_contributions.csv` (2100):

| Outcome        | Y_ref | delta_TC | delta_Diet | delta_Both | synergy | TC share | Diet share |
|----------------|-------|----------|------------|------------|---------|----------|------------|
| Cropland (Mha) | 1872  | 620      | 441        | **714**    | **-348**| 87%      | 62%        |
| Food price idx | 289   | 99       | 82         | **112**    | **-69** | 88%      | 73%        |
| Secdforest (Mha, growth) | 2382 | -100 | -90 | -117 | +73 (sign flipped for growth) | - | - |

### Headline findings

**1. TC and diet are strong substitutes on the cropland frontier.**
Synergy = -348 Mha cropland: the levers' deltas (620 + 441 = 1061) sum to 49% more than their combined effect (714). They reduce the same scarcity (land needed to meet food demand) from opposite sides -- TC from the supply side (yield per ha), diet from the demand side (kcal demand). Either one alone gets you most of the way: TC alone delivers 87% of the combined cropland savings, diet alone delivers 62%.

**2. TC is the dominant lever for food affordability under the full FST.**
TC alone reduces the 2100 consumer food price index by 99 points (289 -> 190); diet alone by 82 points (289 -> 207); combined by 112 points. TC's share of the combined effect is 88%; diet's is 73%; synergy is -69 (substitutes). The FST constraints (biodiv + N + water on top of carbon price + 30by30) raise the cost of producing the same food enormously; TC's intensification directly relieves that cost pressure, somewhat more efficiently than diet's demand reduction does.

**3. EnergyConsBioN at f=0 is the most-constrained feasible scenario.**
Food price 289 (3.5x BAU's 83); cropland 1872 Mha (nearly BAU's 1923). Translation: imposing the full FST (1.5C carbon price + 30by30 + biodiv + max N MACCs + water EFP) WITHOUT TC headroom AND WITHOUT a diet shift is feasible -- the model still solves -- but food becomes ~3.5x more expensive than BAU. Both TC and diet are needed to bring the price back to ~177 (FullPlus f=1).

**4. Endogenous tau scales with constraint tightness.**
BAU 1.85; Energy 2.16; EnergyConsBioN **2.82** (highest -- the full FST minus diet forces maximal intensification); FullPlus 2.43 (diet partly relieves it). The model's intensification demand is roughly proportional to how much demand-side flexibility is taken away by the FST constraints.

## Outstanding analysis (planned next)

- **Per-atom TC sensitivity**: run each of the 5 remaining FST atoms alone (30by30, Diet, Biodiv, N, Water) at f=0 and f=1, to ask "which single FST policy creates the most demand for TC headroom?" -- the per-package view (above) tells you TC's importance with/without diet, but doesn't isolate which other layer is binding hardest. 10 new runs at PkBudg650, ~5-6h on 3-parallel.
- **Wider output variables**: extract from the existing GDX files -- GHG emissions (LULUCF CO2, CH4, N2O), N pollution (Module 51), water use, achieved BII (Module 44), per-commodity production, kcal per capita, agricultural employment (Module 36), system costs. No new runs needed.

## Limitations

- The blend is a 1-D cut through (t x h x tautype) tau space. f=1 means "this scenario's own endogenous tau," not a global maximum across scenarios.
- "Feasibility" is GAMS modelstat 2/7. Climate policy is implemented as price signals (Module 56), not hard emission caps. The hard constraints in EnergyFST are 30by30 (Module 22), the BII lower bound (Module 44), the N MACC max step (Module 57), and the water EFP (Module 42). Together they still produce feasible solves at every f tested.
- The current decomposition is per-package (TC vs Diet, with the other FST layers always on). Per-atom TC sensitivity -- testing each FST atom alone with f=0 + f=1 -- is queued (see "Outstanding analysis").
- Carbon-price coverage is `all_nosoil` (excludes soil C).

## Files

- Branch: `experiment/tc-marginal-pb` on `mscrawford/magpie`
  - https://github.com/mscrawford/magpie/tree/experiment/tc-marginal-pb
- Orchestrator: `scripts/start/projects/tc_vs_landuse.R`
- Scenario definitions: `scripts/start/projects/tc_vs_landuse_config.R` (config defines BAU, Energy, EnergyCons, Full, FullPlus, EnergyConsBioN; the plotter displays BAU, Energy, FullPlus (relabeled EnergyFST) and uses EnergyConsBioN for the decomposition's "Diet OFF" cell)
- Tau-blending utility: `scripts/output/extra/blend_tau.R`
- Plotting: `scripts/output/projects/tc_vs_landuse_plot.R`
- Active run outputs: `output/TC_{BAU_endo, Energy_*, FullPlus_*, EnergyConsBioN_{endo,f00}}/`
- Plots: `output/tc_vs_landuse_plots/0{1..8}_*.pdf`
  - `02_land_allocation_grid.pdf` is the headline land-use visual
  - `04_tau_trajectory.pdf` shows the per-scenario tau ranges
  - `07_food_price_index.pdf` shows the global food price index over time
  - `08_marginal_contributions.pdf` shows the TC vs FST decomposition (2100)
- Decomposition CSV: `output/tc_vs_landuse_plots/marginal_contributions.csv`
