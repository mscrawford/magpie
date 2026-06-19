# fst_levers experiment

How area-based forest protection and 2nd-generation bioenergy demand reshape a
Food System Transformation (FST), and how much endogenous technological change
(TC) contributes under each policy combination.

A sibling of the `yield_gap` experiment (TC vs diet); it reuses the same
block-composition config + two-phase orchestrator + tau-pinning machinery.

## Research question

Under a fixed FST backdrop (1.5C carbon price + EAT-Lancet diet + biodiversity,
nitrogen and water targets), two land-competition levers are toggled:

- **Forest protection** (area-based): 30by30 conservation ON vs OFF.
- **Bioenergy demand** (2nd-gen): 1.5C-consistent demand ON vs OFF.

and the role of **technological change** is isolated by re-running each cell with
tau pinned to the BAU trajectory. The question: do protection and bioenergy
interact in achieving the transformation, and does either change how much TC
matters?

## Design: 3 binary factors + BAU

| Factor | ON | OFF |
|--------|-----|-----|
| A. forest protection (Module 22, area-based) | `c22_protect_scenario = 30by30` (+ noselect; s22 start 2025, target 2050, restore 1) | `c22_protect_scenario = none` (+ noselect) |
| B. 2nd-gen bioenergy demand (Module 60) | `c60_2ndgen_biodem = R34M410-SSP2-PkBudg650` (+ noselect) | `c60_2ndgen_biodem = none` (+ noselect) + `c60_res_2ndgenBE_dem = off` + `s60_2ndgen_bioenergy_dem_min = 0` |
| C. TC state (Module 13) | `tc = endo` (TCendo) | `tc = exo`, tau pinned to BAU (TCbau) |

Avoided deforestation (`c35_ad_policy = npi`) stays ON in both protection arms
(inherited from `setScenario(c("SSP2","NPI"))`); only the area-based 30by30 lever
is toggled. "Without protection" still carries the carbon-price incentive on
forest carbon, so the contrast is regulatory protection on top of carbon pricing.

**FST backdrop** (constant across all 4 cells; the `yield_gap` FST atoms minus the
protection atom, which is now Factor A):

- carbon price: `c56_pollutant_prices = R34M410-SSP2-PkBudg650` (1.5C, ~$300/tC by 2050), `c56_emis_policy = all_nosoil`
- diet: EAT-Lancet FLX 2500 kcal (`s15_exo_diet = 1`, `c15_EAT_scen = FLX`, `c15_kcal_scen = 2500kcal`), 2025->2050
- biodiversity: `s44_bii_target = 0.78`
- nitrogen: MACCs at max step (`s57_maxmac_n_soil = s57_maxmac_n_awms = 201`)
- water: environmental flow protection on (`c42_env_flow_policy = on`, scenario 2), 2025->2050

## Run inventory (9)

`BAU_TCendo` (the single tau-pin source) plus, for each of the 4 cells
{Protect, NoProtect} x {BioOn, BioOff}: a `_TCendo` and a `_TCbau` run.

```
                 BioOn                BioOff
  Protect    Protect_BioOn        Protect_BioOff      each x {TCendo, TCbau}
  NoProtect  NoProtect_BioOn      NoProtect_BioOff    each x {TCendo, TCbau}
  +  BAU_TCendo
```

BAU = the `yield_gap` BAU (NPi carbon, no future conservation, endogenous diet,
baseline NPi bioenergy). Its endogenous tau is pinned (via
`scripts/output/extra/pin_bau_tau.R::pinTauToBAU`, writing
`modules/13_tc/input/f13_tau_scenario.csv`) as the common intensity reference for
all 4 cells' TCbau runs. A single BAU pin (not per-cell) is required so the TC
counterfactual is a shared baseline and cross-cell deltas stay comparable.

## Usage

From the magpie repo root (model + experiment code in this clone):

```
FST_LEVERS_PARALLEL=3 Rscript scripts/start/projects/fst_levers.R     # launch the 9 runs
Rscript scripts/output/projects/fst_levers_plot.R                     # analysis (after runs finish)
```

Idempotent: runs with a populated `runstatistics.rda` are skipped. Heavy compute
belongs on the HPC; BAU must solve feasibly before Phase 2 (it is the pin target).

## Analysis design (implemented in `fst_levers_plot.R`)

The 8 FST runs form a 2x2x2 cube over (Protect, Bio, TC); `BAU_TCendo` sits
OUTSIDE the cube (different backdrop) and appears only as a context line.

1. **Feasibility heatmap** over all 9 runs first. The `Protect_BioOn_TCbau`
   corner (tau frozen at BAU, facing both conservation and high BECCS land
   demand) is the likeliest infeasible cell; missing corners are surfaced, not
   silently dropped, and interactions that reference a missing corner are not
   interpreted.
2. **Primary: protection x bioenergy 2x2** at TCendo (the realistic case) -
   cell deltas on the planetary-boundary outcomes.
3. **TC-isolation slice**: per cell, `dTC = Y(TCendo) - Y(TCbau)`, i.e. does
   protection or bioenergy change TC's leverage (4 numbers per outcome).
4. **Full 2^3 reference-delta decomposition** (backbone): 3 main effects + 3
   two-way + 1 three-way, reference = the all-OFF corner
   `NoProtect_BioOff_TCbau`. Generalizes `yield_gap`'s `synergy = d_Both -
   (d_TC + d_Diet)`. Written to `marginal_contributions.csv`.

**Outcomes**: the 9 from `yield_gap` (cropland, pasture, total forest, LUCC CO2,
N surplus, water withdrawal, BII, production, food price index) plus 3 the new
factors require:

- 2nd-gen bioenergy crop area (`croparea(gdx, products = "kbe60")`) - Factor B's land footprint
- total land / AFOLU CO2 (`Emissions|CO2|Land`, the parent of the LUCC line) - captures BECCS + afforestation sinks
- forestry / afforestation area (the `forestry` category already in `land()`) - Factor A's restoration response

## Provenance

- Base: magpie `experiment/tc-marginal-pb` @ post-develop-merge `24a8be63f`
  (newest develop as of 2026-06-19), version 4.14.0dev.
- Config + orchestrator validated at the R level (every cell assembles to the
  intended switches on the merged tree). The GAMS solve smoke test + the 9-run
  batch run on the HPC (this experiment's input data is not on the PC).
