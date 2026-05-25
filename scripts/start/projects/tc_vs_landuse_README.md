# TC vs land-use change: marginal contribution to food-system transformation

## Question

How much of the cropland-sparing that MAgPIE achieves under an aggressive food-system transformation comes from endogenous TC (`tau` in module 13_tc) versus from land-use change alone? At what TC level does land-use change stop being able to substitute?

## Design

Five scenarios, additively layered:

| Scenario   | `c56_pollutant_prices`         | `c56_emis_policy` | `c22_protect_scenario` | `s15_exo_diet` | Bonus layers |
|------------|--------------------------------|-------------------|------------------------|----------------|--------------|
| BAU        | `R34M410-SSP2-NPi2025`         | `reddnatveg_nosoil` | `none`               | 0              | -            |
| Energy     | `R34M410-SSP2-PkBudg650` (1.5C)| `all_nosoil`      | `none`                 | 0              | -            |
| EnergyCons | `R34M410-SSP2-PkBudg650`       | `all_nosoil`      | `30by30` (2025-2050)   | 0              | -            |
| Full       | `R34M410-SSP2-PkBudg650`       | `all_nosoil`      | `30by30`               | 1; `c15_EAT_scen=FLX`, `c15_kcal_scen=2500kcal` (2025-2050) | - |
| FullPlus   | `R34M410-SSP2-PkBudg650`       | `all_nosoil`      | `30by30`               | 1; FLX 2500kcal | `s44_bii_target=0.78`; `s57_maxmac_n_soil=201`; `s57_maxmac_n_awms=201` |

SSP2 + NPI base for all scenarios. `coup2100` timesteps. h12 regions. The FullPlus "bonus" layers add a Module 44 BII target (0.78, "strong increase of BII") and Module 57 MACC step 201 for soil and animal-waste N abatement (max mitigation, base NUE trajectory unchanged).

For each non-BAU scenario, the run is repeated with tau fixed exogenously (`tc=exo`, `c13_croparea_consv=0`, `s13_ignore_tau_historical=1`) at the blend

```
tau_blend(t, h, type) = tau_BAU(t, h, type) + f * [tau_TS(t, h, type) - tau_BAU(t, h, type)]
```

for f in {0, 0.5, 0.75, 1}. f=1 reuses the endogenous reference. Total: 5 baselines + 12 sweeps = 17 runs at the default coup2100 resolution, executed locally 3-parallel. All feasible (modelstat 2 throughout).

## Results

### Endogenous tau in 2100 (crop, mean across superregions)

| Scenario   | tau_crop | vs BAU |
|------------|----------|--------|
| BAU        | 1.85     | -      |
| Energy     | 2.16     | +17%   |
| EnergyCons | 2.16     | +17%   |
| Full       | 1.85     |  0%    |
| FullPlus   | 2.40     | +30%   |

The EAT-Lancet diet brings endogenous tau back down to BAU levels: under reduced demand, the model no longer needs to intensify to meet food demand even at PkBudg650. But adding biodiv + N constraints on top (FullPlus) pushes endogenous tau to its highest value of any scenario - the tighter environmental constraints force intensification even when demand is diet-reduced.

### Global cropland in 2100, delta vs BAU (Mha)

| Scenario   | f=0   | f=0.5 | f=0.75 | f=1   | TC marginal (f=0 to f=1) |
|------------|-------|-------|--------|-------|--------------------------|
| Energy     | -13   | -215  | -295   | -362  | **-349**                 |
| EnergyCons | -18   | -214  | -292   | -359  | **-341**                 |
| Full       | -387  | -402  | -407   | -412  | **-25**                  |
| FullPlus   | -519  | -667  | -723   | -777  | **-258**                 |

### Global food price index in 2050 / 2100 (Laspeyres, baseyear 2005)

| Scenario   | f=0       | f=0.5     | f=0.75    | f=1       |
|------------|-----------|-----------|-----------|-----------|
| BAU        | 82 / 83   | -         | -         | -         |
| Energy     | 189 / 204 | 184 / 186 | 179 / 177 | 177 / 171 |
| EnergyCons | 191 / 205 | 188 / 185 | 182 / 177 | 179 / 170 |
| Full       | 159 / 146 | 160 / 147 | 159 / 145 | 158 / 144 |
| FullPlus   | 196 / 205 | 192 / 187 | 188 / 183 | 184 / 176 |

(values shown as `2050 / 2100`)

### Three headline findings

**1. TC and demand-side reduction are substitutes for land-sparing.**
Under the carbon price alone (Energy, EnergyCons), 96-97% of the cropland savings depend on TC headroom: at BAU TC the carbon price delivers essentially no cropland sparing (-13 to -18 Mha). With the EAT-Lancet diet added (Full), 94% of the sparing happens at BAU TC; further TC headroom adds only ~25 Mha. The diet transition substitutes for the TC requirement on the cropland frontier.

**2. 30by30 does not bind on the cropland frontier in this configuration.**
EnergyCons land allocation matches Energy within 5 Mha of cropland at every f. The constraint *is* active - it redistributes protection: primary forest is +47 Mha higher under EnergyCons (and secondary forest correspondingly lower) - but agricultural pressure is absorbed elsewhere on the global land budget, not transmitted to the cropland margin.

**3. Food prices are dominated by carbon pricing, partly buffered by TC, and substantially relieved by the diet transition.**
The 1.5C carbon price roughly doubles food prices over BAU by 2100 (Energy: 204 vs BAU 83 at f=0). TC headroom buys back ~15% (Energy f=0 -> f=1: 204 -> 171). The EAT-Lancet diet is the dominant lever: Full prices in 2100 land at 144-147 *regardless of TC blend* (~30% lower than Energy_f=1, ~30% lower than Energy_f=0). The same TC-substitution pattern from cropland appears here: in Full, demand-side reduction does the work that TC would have done in the carbon-price-only world.

**4. Adding biodiv + N (FullPlus) revives the TC story and partially reverses the affordability win.**
FullPlus saves another ~365 Mha cropland on top of Full at f=1 (1146 vs 1511 Mha global cropland in 2100), and ~565 Mha pasture. But food prices rebound: Full sits at 144 in 2100, FullPlus at 176 (similar level to EnergyCons at f=1, 170). The biodiversity + N constraints have an affordability cost that the diet transition alone did not impose. Critically, **TC matters again inside FullPlus**: prices drop ~30 pts from f=0 to f=1 (205 -> 176), compared to only 2 pts in Full. The biodiv + N constraints make intensification headroom valuable again - the substitutability of TC and diet (finding 1) is conditional on not stacking biodiv + N on top.

## Marginal contribution of TC vs diet vs both (decomposition)

Reference cell `Y_ref = Y(EnergyCons, f=0)` ("policies on, TC at BAU, no diet"). Effects sum if independent; negative synergy means substitutes; positive means complements. Sign convention: positive `delta` = lever REDUCES the outcome. From `output/tc_vs_landuse_plots/marginal_contributions.csv` (2100):

| Outcome        | Y_ref | delta_TC | delta_Diet | delta_Both | synergy | TC share | Diet share |
|----------------|-------|----------|------------|------------|---------|----------|------------|
| Cropland (Mha) | 1905  | 340      | 369        | 394        | **-315**| 86%      | 94%        |
| Food price idx | 205   | 35       | 59         | 61         | **-33** | 57%      | 97%        |
| Secdforest (Mha, growth) | 2447 | -49 | -47 | -54 | (substitution, sign flipped) | - | - |

**Read:** Across cropland and food prices, TC and the diet transition are strong substitutes. The diet alone gets you 94-97% of what TC + diet together get. Adding TC on top adds only ~6 percentage points of cropland savings and ~3 points of food-price relief. Conversely, TC alone gets you 86% (cropland) or 57% (food prices) of the combined effect - so in a world without diet change, TC is doing the heavy lifting; in a world with diet change, TC is largely redundant.

The mechanism is direct: EAT-Lancet flexitarian demand at 2500 kcal cuts food (especially livestock) demand enough that the model no longer needs to spare land via intensification. The two levers target the same scarcity (land needed to meet demand) from opposite sides.

This substitution does NOT hold in FullPlus (see finding 4 above): once biodiversity and N mitigation are also binding, TC headroom regains marginal value.

## Limitations

- The blend is a 1-D cut through (t x h x tautype) tau space. f=1 means "this scenario's own endogenous tau," not a global maximum across scenarios. For Full the gradient (BAU 1.85 -> Full_endo 1.85) is essentially flat, so Full's small TC sensitivity is partly by construction.
- "Feasibility" is GAMS modelstat 2/7. Climate policy is implemented as price signals (Module 56), not hard emission caps, so the model always finds an optimum - no infeasibility threshold appears.
- Conservation here is area protection (Module 22 `30by30`), not a biodiversity-target (Module 44 BII). Adding the BII constraint is a candidate follow-up.
- AFOLU pricing is `all_nosoil` (excludes soil C). Diet preset is FLX at 2500 kcal/cap/day - moderate EAT-Lancet, not the more aggressive VEG/VGN variants.

## Files

- Branch: `experiment/tc-marginal-pb` on `mscrawford/magpie`
  - https://github.com/mscrawford/magpie/tree/experiment/tc-marginal-pb
- Orchestrator: `scripts/start/projects/tc_vs_landuse.R`
- Scenario definitions: `scripts/start/projects/tc_vs_landuse_config.R`
- Tau-blending utility: `scripts/output/extra/blend_tau.R`
- Plotting: `scripts/output/projects/tc_vs_landuse_plot.R`
- Run outputs: `output/TC_{BAU,Energy,EnergyCons,Full}_{endo,f00,f50,f75}/`
- Plots: `output/tc_vs_landuse_plots/0{1..8}_*.pdf`
  - `02_land_allocation_grid.pdf` is the headline land-use visual
  - `04_tau_trajectory.pdf` shows the per-scenario tau ranges
  - `07_food_price_index.pdf` shows the global food price index over time
  - `08_marginal_contributions.pdf` shows the TC vs Diet decomposition (2100)
- Decomposition CSV: `output/tc_vs_landuse_plots/marginal_contributions.csv`
