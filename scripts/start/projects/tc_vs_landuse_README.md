# TC's importance for enabling food-system transformations

## Question

**How important is endogenous TC (`tau` in module 13_tc) for enabling food-system transformations, and how does its marginal value compare to a dietary shift?**

In a world pursuing other goals (carbon pricing, 30by30, biodiversity, N abatement, water protection), how much does TC headroom matter for both **land outcomes** (cropland, forest) and **societal outcomes** (consumer food prices, production)? Does TC matter more when a dietary shift is also in play?

## Design

Three scenarios, each describing one transformation package:

| Scenario      | Display label         | Composition |
|---------------|-----------------------|-------------|
| `BAU`         | "BAU"                 | Default config: `R34M410-SSP2-NPi2025` carbon price (~0), default conservation, endogenous diet. |
| `TransNoDiet` | "Transition - Diet"   | 5 of 6 FST atoms: 1.5C carbon price (`R34M410-SSP2-PkBudg650`, `c56_emis_policy=all_nosoil`); 30by30 land conservation (`c22_protect_scenario=30by30`, 2025-2050); biodiversity target (`s44_bii_target=0.78`, Module 44 BII); N MACCs at max (`s57_maxmac_n_soil=201`, `s57_maxmac_n_awms=201`); water EFP (`c42_env_flow_policy="on"`, `s42_env_flow_scenario=2`, Smakhtin gridcell-specific, 2025-2050). No diet transition. |
| `TransDiet`   | "Transition + Diet"   | All 6 FST atoms: `TransNoDiet` + EAT-Lancet FLX diet (`s15_exo_diet=1`, `c15_EAT_scen=FLX`, `c15_kcal_scen=2500kcal`, 2025-2050). |

SSP2 + NPI base for all scenarios. `coup2100` timesteps. h12 regions. Base NUE trajectory (`c50_scen_neff`) unchanged - all N abatement comes via the Module 57 MACCs. Base water-demand scenarios unchanged - water protection comes via the Module 42 environmental flow policy.

Each transition scenario is run twice:

- **`TCendo`**: tau is endogenous (`cfg$gms$tc = "endo"`, the model finds its own optimal tau).
- **`TCbau`**: tau is exogenously pinned to BAU's trajectory (`cfg$gms$tc = "exo"`, `c13_croparea_consv=0`, `s13_ignore_tau_historical=1`); `scripts/output/extra/pin_bau_tau.R` writes BAU's `ov13_tau_core` to `modules/13_tc/input/f13_tau_scenario.csv`.

BAU runs only with endogenous TC; its own tau IS the TCbau pin target. Total: **5 runs** (BAU + 2 transitions x 2 TC states), all feasible (modelstat 2 throughout).

## The 2x2

| | Diet OFF (`TransNoDiet`) | Diet ON (`TransDiet`) |
|--|--------------------------|------------------------|
| **TCbau**  | `TransNoDiet_TCbau`  | `TransDiet_TCbau`  |
| **TCendo** | `TransNoDiet_TCendo` | `TransDiet_TCendo` |

`Y_ref = Y(TransNoDiet, TCbau)`: full FST minus diet, TC pinned at BAU level. Most-constrained feasible cell.

Sign convention: **positive `delta` = lever REDUCES the outcome.** Negative synergy = substitutes.

## Results

### Endogenous tau in 2100 (crop, mean across superregions)

| Scenario     | tau_crop | vs BAU |
|--------------|----------|--------|
| BAU          | 1.85     | -      |
| TransNoDiet (TCendo) | **2.82** | +52% |
| TransDiet   (TCendo) | 2.43     | +31% |

The full FST backdrop *minus* the diet forces maximum intensification (tau +52% over BAU). Adding the diet shift relieves some of that pressure (tau back to +31%), because lower kcal demand reduces the cropland needed.

### Global cropland in 2100 (Mha)

| Run                  | Cropland | TC marginal (TCbau -> TCendo) |
|----------------------|----------|-------------------------------|
| BAU                  | 1923     | -                             |
| TransNoDiet TCbau    | 1872     | -                             |
| TransNoDiet TCendo   | 1251     | **-620**                      |
| TransDiet TCbau      | 1430     | -                             |
| TransDiet TCendo     | 1158     | **-272**                      |

### Global consumer food price index in 2100 (Laspeyres, baseyear 2005)

| Run                  | Food price idx |
|----------------------|----------------|
| BAU                  | 83             |
| TransNoDiet TCbau    | 289            |
| TransNoDiet TCendo   | 190            |
| TransDiet TCbau      | 207            |
| TransDiet TCendo     | 177            |

**Metric note:** `magpie4::priceIndexFood()` returns a Laspeyres index of **consumer prices** (producer prices + marketing margins + value-added, pulled from Module 15's `FoodDemandModuleConsumerPrices` -- not the producer-side `prices(type="producer")`). Baseyear 2005 = index 100; BAU drifts down to ~83 by 2100 as productivity grows faster than demand.

The transition backdrop without TC and without diet (TransNoDiet TCbau, the reference cell) raises the consumer food price index to 289 -- 3.5x BAU. Either lever brings it down (TCendo alone: 190; Diet alone: 207); both together: 177.

## Marginal-contribution decomposition (TC vs Diet)

From `output/tc_vs_landuse_plots/marginal_contributions.csv` (year = 2100):

| Outcome             | Y_ref | delta_TC | delta_Diet | delta_Both | synergy  | TC share | Diet share |
|---------------------|-------|----------|------------|------------|----------|----------|------------|
| Cropland (Mha)      | 1872  | 620      | 441        | **714**    | **-348** | 87%      | 62%        |
| Food price idx      | 289   | 99       | 82         | **112**    | **-69**  | 88%      | 73%        |
| Secdforest (Mha)*   | 2415  | -100     | -90        | -117       | +73      | -        | -          |

*Secdforest entries are negative (the levers grow secdforest, not reduce it); reported here for completeness.

### Headline findings

**1. TC and diet are strong substitutes on the cropland frontier.**
Synergy = -348 Mha cropland: the levers' deltas (620 + 441 = 1061) sum to 49% more than their combined effect (714). They reduce the same scarcity (land needed to meet food demand) from opposite sides -- TC from the supply side (yield per ha), diet from the demand side (kcal demand). Either alone gets you most of the way: TC alone delivers 87% of the combined cropland savings; diet alone delivers 62%.

**2. TC is the dominant lever for food affordability under the full transition backdrop.**
TC alone reduces the 2100 consumer food price index by 99 points (289 -> 190); diet alone by 82 points (289 -> 207); combined by 112 points. TC's share of the combined effect is 88%; diet's is 73%; synergy is -69 (substitutes). The transition constraints (biodiv + N + water on top of carbon price + 30by30) raise the cost of producing the same food enormously; TC's intensification relieves that cost pressure more efficiently than diet's demand reduction does.

**3. `TransNoDiet TCbau` is the most-constrained feasible scenario.**
Food price 289 (3.5x BAU's 83); cropland 1872 Mha (nearly BAU's 1923). Translation: imposing the full FST backdrop (1.5C carbon price + 30by30 + biodiv + max N MACCs + water EFP) WITHOUT TC headroom AND WITHOUT a diet shift is feasible -- the model still solves -- but food becomes ~3.5x more expensive than BAU. Both TC and diet are needed to bring the price back to ~177 (`TransDiet TCendo`).

**4. Endogenous tau scales with constraint tightness.**
BAU 1.85; `TransNoDiet TCendo` 2.82 (highest -- transition minus diet forces maximal intensification); `TransDiet TCendo` 2.43 (diet partly relieves it). Intensification demand is roughly proportional to how much demand-side flexibility is taken away.

## Outstanding analysis

- **Per-atom TC sensitivity** (tabled, not currently run): one run per individual FST atom (30by30, Diet, Biodiv, N, Water, Energy) on top of BAU, at TCbau and TCendo, to isolate which single policy creates the most demand for TC headroom. ~10 runs.
- **Wider output variables** (no new runs needed): extract from existing GDX files -- LULUCF CO2, CH4, N2O, N pollution (Module 51), water use, achieved BII (Module 44), per-commodity production, kcal per capita, agricultural employment (Module 36), system costs.

## Limitations

- TCbau "pins tau to BAU's trajectory," not "no TC at all." The model's BAU trajectory itself includes endogenous productivity growth; TCbau means "no extra TC beyond BAU."
- "Feasibility" is GAMS modelstat 2/7. Climate policy is implemented as price signals (Module 56), not hard emission caps. The hard constraints in the transition backdrop are 30by30 (Module 22), the BII lower bound (Module 44), the N MACC max step (Module 57), and the water EFP (Module 42). All 5 cells of the design solve feasibly.
- The decomposition lives entirely within the full transition backdrop. It does not decompose BAU -> full transition into per-atom contributions; that would require additional per-atom runs (see "Outstanding analysis").
- Carbon-price coverage is `all_nosoil` (excludes soil C).

## Files

- Branch: `experiment/tc-marginal-pb` on `mscrawford/magpie`
  - https://github.com/mscrawford/magpie/tree/experiment/tc-marginal-pb
- Orchestrator: `scripts/start/projects/tc_vs_landuse.R`
- Scenario definitions: `scripts/start/projects/tc_vs_landuse_config.R`
- Tau-pinning utility: `scripts/output/extra/pin_bau_tau.R` (replaces the older `blend_tau.R`; the blend formula is gone since only TCbau and TCendo states are needed)
- Plotting: `scripts/output/projects/tc_vs_landuse_plot.R`
- Run outputs: `output/{BAU_TCendo, TransNoDiet_{TCbau,TCendo}, TransDiet_{TCbau,TCendo}}/`
- Plots: `output/tc_vs_landuse_plots/0{1..8}_*.pdf`
  - `02_land_allocation_grid.pdf` is the headline land-use visual (scenario rows x TC-state columns)
  - `04_tau_trajectory.pdf` shows the per-scenario tau ranges
  - `07_food_price_index.pdf` shows the global food price index over time
  - `08_marginal_contributions.pdf` shows the TC vs Diet decomposition (2100)
- Decomposition CSV: `output/tc_vs_landuse_plots/marginal_contributions.csv`
