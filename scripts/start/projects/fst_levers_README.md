# fst_levers experiment

How **ambitious land protection** competes with **2nd-generation bioenergy demand**
for land, whether **climate policy** changes that competition, and how much
endogenous **technological change** (TC) contributes in each case.

Sibling of the `yield_gap` experiment (TC vs diet); reuses its block-composition
config, two-phase orchestrator and tau-pinning machinery.

## Research question

Under a Food System Transformation (FST) backdrop of an EAT-Lancet diet plus
environmental-flow protection, three policy levers are toggled:

- **Climate policy**: 1.5C carbon price vs current policies.
- **Land protection**: Half-Earth area-based conservation plus a biodiversity
  target, vs neither.
- **Bioenergy demand**: 1.5C-consistent vs baseline 2nd-generation demand.

and TC's role is isolated by re-running each cell with tau pinned to BAU.

## Design: 4 binary factors, 13 runs

| Factor | ON | OFF |
|---|---|---|
| **A. climate policy** (Module 56) | `c56_pollutant_prices` (+ `_noselect`) = `R34M410-SSP2-PkBudg650` | `= R34M410-SSP2-NPi2025` |
| **B. bioenergy demand** (Module 60) | `c60_2ndgen_biodem` (+ `_noselect`) = `R34M410-SSP2-PkBudg650` | `= R34M410-SSP2-NPi2025` |
| **C. land protection** (Modules 22 + 44) | `c22_protect_scenario` (+ `_noselect`) = `GSN_HalfEarth`, 2025->2050, `s22_restore_land = 1`, **plus** `s44_bii_target = 0.78` (2025->2050) | `c22_protect_scenario` = `none`; `s44_bii_target = 0` |
| **D. TC state** (Module 13) | `tc = endo` | `tc = exo`, tau pinned to BAU |

**Constant across all 12 FST cells**: EAT-Lancet FLX 2500 kcal diet (2025->2050);
environmental flow protection (2025->2050); `c56_emis_policy = all_nosoil` and
`c56_mute_ghgprices_until = y2025`; all five non-CO2 MACC switches price-driven.

The **(CP off, Bio on)** combination is deliberately excluded: 1.5C-level
bioenergy demand without a carbon price is not a coherent scenario, since both
come from the same coupled REMIND run.

```
                       BioOn                 BioOff
  CP on   Protect      CPon_BioOn_Prot       CPon_BioOff_Prot
          NoProtect    CPon_BioOn_NoProt     CPon_BioOff_NoProt
  CP off  Protect          (excluded)        CPoff_BioOff_Prot
          NoProtect        (excluded)        CPoff_BioOff_NoProt

  each x {TCendo, TCbau}  = 12,  + BAU_TCendo  = 13 runs
```

`BAU_TCendo` is the `yield_gap` BAU, unchanged, so the tau pin stays comparable
across both experiments. It sits **outside** the design and appears only as a
context line, never as a decomposition corner. It is therefore asymmetric to the
FST cells on `c56_emis_policy` and `c56_mute_ghgprices_until`.

### What the design can and cannot identify

Excluding one (CP, Bio) combination makes this **two 2^3 cubes sharing a face**,
not a 2^4 factorial:

- **Cube A** (CP = on): Bio x Prot x TC. Reference `CPon_BioOff_NoProt_TCbau`.
  *Does protection compete with bioenergy under 1.5C policy, and does the tau
  regime change that?*
- **Cube B** (Bio = off): CP x Prot x TC. Reference `CPoff_BioOff_NoProt_TCbau`.
  *Does climate policy change protection's effect and TC's leverage?*
- Shared face: CPon x BioOff x Prot x TC. 8 + 8 - 4 = 12 distinct FST runs.

**Unidentifiable by construction**: every effect involving CP and Bio jointly
(`CP:Bio`, `CP:Bio:Prot`, `CP:Bio:TC`, the four-way). The bioenergy main effect
is therefore **conditional on CP being on** and must never be reported as a
marginal effect over the whole design.

## Methodology decisions

These are the non-obvious calls. Several correct problems in the earlier
3-factor version of this experiment.

**1. Land protection is a BUNDLE (Modules 22 + 44), not just the area target.**
`s44_bii_target` is itself a land-protection instrument: it constrains BII, which
is a linear function of the same `vm_land` pools Module 22 bounds, so a binding
BII floor forces natural-land retention even with `c22_protect_scenario = none`.
Leaving it in the backdrop would have made the area-based "main effect" a
residual on top of an already-binding biodiversity floor. Bundling them makes
"ambitious land protection" one coherent lever.

**2. Two protection instruments remain ON in BOTH arms** and are the floor this
contrast sits on top of, not part of the factor:
- WDPA baseline protection (`c22_base_protect = WDPA`), never gated on
  `c22_protect_scenario`;
- NPI avoided deforestation **and** avoided other-land conversion
  (`c35_ad_policy = npi`, inherited from `setScenario`). Note `c35_aolc_policy`
  is inert in the GAMS code; `c35_ad_policy` drives both floors.

So "no protection" is not "open season on forests", and the measured protection
effect is *incremental regulatory protection on top of that floor*.

**3. Every lever transitions on the same 2025->2050 schedule.** This required
moving the BII target off its defaults (`s44_start_year` 2030, `s44_target_year`
2100). At the defaults, biodiversity ambition would have ramped 50 years later
than every other lever and been only weakly binding before ~2060.

**4. Non-CO2 MACCs are price-driven, not forced to the maximum step.** The
earlier setting `s57_maxmac_n_* = 201` was internally contradictory: it severed
N abatement from the pollutant price, so a run honoured the REMIND carbon-price
scenario for CO2 while ignoring it for N2O. Step 201 is ~1222 USD17MER/tCO2eq,
against a PkBudg650 price of ~620-640 at 2050 (step ~103-106) - roughly twice the
abatement effort the 1.5C price justifies. It also split N from CH4, whose MACCs
were left price-driven, so the CP-off arm would have had maximal N abatement
alongside near-zero CH4 abatement. All five switches are now `-1`, and the model
derives the step from each cell's own REMIND price per region and timestep.
Intermediate steps are arbitrary parameterizations, so hand-picking a
"1.5C-equivalent" step would only substitute one arbitrary anchor for another.

*Consequence for the analysis*: nitrogen is no longer an independent FST atom.
The MACC channel is now part of Factor A, so climate policy's effect on N surplus
includes both the MACC step and the endogenous price response. N surplus must not
be read as an independent lever's outcome.

**5. The carbon-price factor toggles exactly one thing.** `c56_emis_policy` and
`c56_mute_ghgprices_until` are held constant across all 12 cells. The muting
switch is not only about when prices bite: it also gates the start of the
carbon-price-induced afforestation reward.

**6. Factor B is "policy-driven BECCS expansion", not "bioenergy vs none".**
Both arms are real demand trajectories from the same REMIND family. This is
simpler and safer than the earlier zero-demand arm, which needed four switches
set in concert to avoid demand leaking back in via the residue baseline or the
presolve floor. Note 1st-generation bioenergy is present in every scenario and
cannot be switched off (`c60_1stgen_biodem` has no `none`), so this axis is
strictly 2nd-generation.

**7. `CPon x BioOff` is a counterfactual, not a scenario.** The c56 and c60
`R34M410-*` tags come from the same coupled REMIND run, so pairing a PkBudg650
price with NPi bioenergy is internally inconsistent with any single energy-system
solution. Legitimate as a decomposition device; label it as such.

**8. BII is both a constraint and an outcome.** Under a binding floor, reported
BII is pinned near the target and carries little information. The analysis also
reports `ov44_bii_missing` (the per-biome shortfall, penalised at 1e6 USD/unit)
so "was the target met, and at what cost" is visible. The BII target is **soft**:
a run can solve feasibly while missing it.

**9. Trap: do not set `c44_bii_decrease = 0` globally.** That branch has no
`s44_bii_target > 0` guard, so it would impose a no-BII-decline constraint even
in the OFF arm where the target is 0, silently contaminating the control. It is
1 in both arms.

## Usage

From the magpie repo root:

```bash
# 1. validate without touching GAMS (all three run with no input data)
Rscript scripts/start/projects/fst_levers_config_test.R        # config assembly, 64 assertions
Rscript scripts/start/projects/fst_levers_orchestrator_test.R  # run-status helpers, 10 assertions
Rscript scripts/output/projects/fst_levers_decompose_test.R    # decomposition algebra, 24 assertions
FST_LEVERS_DRYRUN=1 Rscript scripts/start/projects/fst_levers.R  # show the 13 runs

# 2. launch (cluster). Run the ORCHESTRATOR ITSELF as a batch job or under
#    tmux/nohup: it polls for hours and a login-node process is reaped on logout.
FST_LEVERS_QOS=short Rscript scripts/start/projects/fst_levers.R

# 3. analysis, after runs finish
Rscript scripts/output/projects/fst_levers_plot.R
```

Environment knobs: `FST_LEVERS_QOS` (default `short`), `FST_LEVERS_DRYRUN`,
`FST_LEVERS_MAX_WAIT_HOURS` (default 30), `FST_LEVERS_STAGGER` (default 10),
`FST_LEVERS_TIMESTEPS` (default `coup2100`, 18 timesteps to 2100),
`FST_LEVERS_PARALLEL` (local runs only; unlimited under SLURM).

Idempotent: runs with a populated `runstatistics.rda` are skipped. Do **not**
re-launch while jobs are in flight - `cfg$results_folder` has no `:date:` and
`cfg$force_replace` is TRUE, so a relaunch deletes a live job's folder.

### Pre-flight gates (cluster, before launching)

1. **`GSN_HalfEarth` must have data.** `f22_consv_prio` is a GAMS table read from
   `consv_prio_areas.cs3`; a set element with no matching column stays silently
   at 0 and behaves exactly like `none`. If that column is missing, every
   Prot-ON run is a Prot-OFF run and the whole batch is void. Fall back to
   `PBL_HalfEarth`, then `IrrC_95pc_30by30`, then `30by30`.
2. `R34M410-SSP2-NPi2025` and `R34M410-SSP2-PkBudg650` must have data in both
   `f56_pollutant_prices.cs3` and `f60_bioenergy_dem.cs3`.
3. Input archives already downloaded (`config/default.cfg` `cfg$input`).

## Orchestration notes

`start_run()` takes the `sbatch` branch whenever `srun` exists and
`cfg$sequential` is FALSE, and returns as soon as the job is **queued**. Hence:

- **Concurrency is SLURM's job.** A whole phase is submitted at once with a small
  stagger. A submission cap would turn one wave into several sequential waves of
  (queue wait + solve) for no benefit; the cap only applies without SLURM.
- **Phase 2 waits for BAU alone**, not the whole of Phase 1: BAU's gdx is its
  only dependency.
- **Every run has a deadline.** A job killed by wall time, preemption or OOM
  never writes `modelstat`, so without one the poll loop would spin forever.
  An overdue run is reported and abandoned; the batch continues.
- **`cfg$qos` is set explicitly.** Left NULL, the auto-selector falls back to
  `standby`, which is preemptible.
- **`extra/disaggregation` is dropped** from `cfg$output`. It runs inside the
  SLURM job against the same wall-time and memory budget and produces gridded
  output this experiment does not use.
- **`f13_tau_scenario.csv` is safe to overwrite between launches**:
  `gms::singleGAMSfile()` inlines it into each run's own `full.gms` during prep,
  before `sbatch`.

## Analysis

`scripts/output/projects/fst_levers_decompose.R` holds the treatment-coded 2^k
decomposition (pure functions, no gdx), unit-tested by
`fst_levers_decompose_test.R` against cells constructed from known effects.

Effects are in the **natural direction** (positive = the factor increases the
outcome). `yield_gap` used the opposite convention; convert once at the reporting
boundary with `asReductionConvention()`, never ad hoc.

Deliverables, in order:

1. **Feasibility heatmap over all 13 runs, first, as a gate.**
   `CPon_BioOn_Prot_TCbau` (Half-Earth restoration forced by 2050, high BECCS
   demand, tau frozen at BAU) is the likeliest infeasible corner. Every effect
   whose inclusion-exclusion sum touches a missing cell is NA, surfaced, never
   zeroed. Main effects affected by a missing TCbau corner are recomputed on the
   fully-feasible TCendo sub-slice.
2. **Cube A: bioenergy x protection at TCendo** - the headline land-competition figure.
3. **Cube B: climate policy x protection at TCendo.**
4. **TC-isolation slice**: `dTC = Y(TCendo) - Y(TCbau)` per cell, 6 per outcome.
5. **Two 2^3 decompositions**, one per cube, to `marginal_contributions_{A,B}.csv`.
   Keep policy-factor effects visually separate from TC effects: TC is a
   counterfactual device, not a policy anyone chooses.
6. **Time series** reusing `yield_gap` styling; facet by (CP,Bio) column x
   protection row, colour by TC state (Okabe-Ito `TCbau #E69F00`, `TCendo #0072B2`).

**Outcomes (13)**: `yield_gap`'s 9 (cropland, pasture, total forest, LUCC CO2,
N surplus, water withdrawal, BII, production, food price index) plus 2nd-gen
bioenergy crop area (`croparea(gdx, products = "kbe60")`), total land CO2
(`Emissions|CO2|Land`), forestry area from `land()`, and `ov44_bii_missing`.

## Provenance

- Base: magpie `experiment/tc-marginal-pb` @ `24a8be63f` (develop merge,
  2026-06-19), version 4.14.0dev.
- Config assembly, the orchestrator's run-status helpers and the decomposition
  algebra are all unit-tested at the R level on a machine without input data.
  The GAMS solve and the 13-run batch run on the HPC.
