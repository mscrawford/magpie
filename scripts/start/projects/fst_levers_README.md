> **STATUS: PARTLY SUPERSEDED** | written for the 5-factor / 25-run iteration (2026-08-02) | as of 2026-08-18 | authority: `RIKEN/04-fst-levers/LINEAGE.md`
>
> The METHODS here (block-composition config, the two-phase tau-pinned orchestrator, the
> 2^k decomposition algebra, the SLURM hazards) are still correct and still canonical.
> The DESIGN description is not: the experiment has since moved to the round-2 arms, and
> the current arm is FSTL5, a 2^3 protection x diet x TC at 1.5C. Two claims in here are
> retracted - "TC is a prerequisite for 1.5C bioenergy" (a Japan-region artifact), and any
> description of the protection bundle as including a BII floor (it was inert before FSTL5).

# fst_levers experiment

As a **Food System Transformation** (FST) is assembled from its levers, how do
**ambitious land-and-water protection**, **2nd-generation bioenergy demand**, a
**dietary shift** and **climate policy** interact in reshaping land use, and how
much does endogenous **technological change** (TC) contribute in each case?

Sibling of the `yield_gap` experiment (TC vs diet); reuses its block-composition
config, two-phase orchestrator and tau-pinning machinery.

## Research question

Five policy/technology levers are toggled and their interactions decomposed:

- **Climate policy**: 1.5C carbon price vs current policies.
- **Bioenergy demand**: 1.5C-consistent vs baseline 2nd-generation demand.
- **Land+water protection**: Half-Earth area conservation + a biodiversity target
  + semi-natural vegetation + environmental-flow water protection, vs none of them.
- **Diet**: an exogenous EAT-Lancet FLX shift vs the endogenous diet.
- **TC state**: endogenous TC vs tau pinned to BAU.

## Design: 5 binary factors, 25 runs

This version is a **5-factor** design. Two structural changes vs the earlier
4-factor version: **diet is now a factor** (it used to be a constant backdrop),
and **environmental-flow water protection is folded into the protection bundle**
(it used to be a separate always-on backdrop line). The constant backdrop
therefore shrinks to just the non-CO2 MACC block and the GHG-policy frame.

| Factor | ON | OFF |
|---|---|---|
| **1. TC state** (Module 13) | `tc = endo` | `tc = exo`, tau pinned to BAU |
| **2. climate policy** (Module 56) | `c56_pollutant_prices` (+ `_noselect`) = `R34M410-SSP2-PkBudg650` | `= R34M410-SSP2-NPi2025` |
| **3. bioenergy demand** (Module 60) | `c60_2ndgen_biodem` (+ `_noselect`) = `R34M410-SSP2-PkBudg650` | `= R34M410-SSP2-NPi2025` |
| **4. land+water protection** (Modules 22 + 44 + 29 + 42) | `c22_protect_scenario` (+ `_noselect`) = `GSN_HalfEarth`, `s22_restore_land = 1`; `s44_bii_target = 0.78`; `s29_snv_shr` (+ `_noselect`) = 0.2; `c42_env_flow_policy = on`, `s42_env_flow_scenario = 2`. All 2025->2050 | `c22_protect_scenario = none`; `s44_bii_target = 0`; `s29_snv_shr = 0`; `c42_env_flow_policy = off` |
| **5. diet** (Module 15) | `s15_exo_diet = 1`, `c15_EAT_scen = FLX`, `c15_kcal_scen = 2500kcal`, converging 2025->2050 | `s15_exo_diet = 0` (endogenous diet) |

**Constant backdrop (identical in all 12 FST cells)**: `c56_emis_policy =
all_nosoil` and `c56_mute_ghgprices_until = y2025`; all five non-CO2 MACC switches
price-driven (`-1`). That is the whole backdrop now - diet and water have left it.
Always on and never toggled: the WDPA baseline protection, the NPI avoided
deforestation, and the base 5% environmental-flow reservation
(`s42_env_flow_base_fraction`), which applies to the non-EFP share of every region
regardless of the water switch.

**Every policy lever transitions on the same 2025->2050 schedule** - diet, the
four protection instruments (area, BII, SNV, env-flows), and the carbon price's
approach to ~$300/tC. This is the operational meaning of "equally ambitious"
here; there is no common metric across a $/tC price, an area target, a BII index
level, a cropland share and a water-reservation fraction, so timing plus
same-source-scenario is what can actually be held equal.

### The hole and the kept counterfactual

The **(climate off, bio on)** cell is a **HOLE, excluded**: 1.5C-level bioenergy
demand without a carbon price is not a coherent scenario, because the c56 price
and the c60 demand come from the SAME coupled REMIND run.

The **(climate on, bio off)** cell is the **mirror** of the hole - a PkBudg650
price paired with NPi bioenergy demand. It is *also* two uncoupled REMIND runs and
so is *also* not a believed scenario. Unlike the hole, we **KEEP** it, as a
labelled **decomposition device**: it is the only way to read a bioenergy main
effect at all (Cube A varies bioenergy with climate policy held on). A future
coupled REMIND-MAgPIE run would resolve the inconsistency; at this exploratory
stage the decomposition value is worth it, provided the cell is never quoted as a
standalone scenario.

That leaves **3 coherent (climate, bio) combinations** - (on,on), (on,off),
(off,off) - each crossed with 2 protection x 2 diet = **12 policy cells**, each run
at TCendo and TCbau, **plus BAU** (TCendo only) = **25 runs**.

```
  climate  bio    protection  diet     cell
  -------  ---    ----------  ----     ----
  on       on     Prot        DietOn   CPon_BioOn_Prot_DietOn
  on       on     Prot        DietOff  CPon_BioOn_Prot_DietOff
  on       on     NoProt      DietOn   CPon_BioOn_NoProt_DietOn
  on       on     NoProt      DietOff  CPon_BioOn_NoProt_DietOff
  on       off    Prot        DietOn   CPon_BioOff_Prot_DietOn      <- kept counterfactual face
  on       off    Prot        DietOff  CPon_BioOff_Prot_DietOff     <-  (climate on, bio off)
  on       off    NoProt      DietOn   CPon_BioOff_NoProt_DietOn    <-
  on       off    NoProt      DietOff  CPon_BioOff_NoProt_DietOff   <-
  off      off    Prot        DietOn   CPoff_BioOff_Prot_DietOn
  off      off    Prot        DietOff  CPoff_BioOff_Prot_DietOff
  off      off    NoProt      DietOn   CPoff_BioOff_NoProt_DietOn
  off      off    NoProt      DietOff  CPoff_BioOff_NoProt_DietOff
  (climate off, bio on)  x  {Prot,NoProt} x {DietOn,DietOff}  = HOLE, excluded

  each cell x {TCendo, TCbau}  = 24,  + BAU_TCendo  = 25 runs
```

`BAU_TCendo` is the `yield_gap` BAU, unchanged, so the tau pin stays comparable
across both experiments. It sits **outside** the design and appears only as a
context line, never as a decomposition corner. It is therefore asymmetric to the
FST cells on `c56_emis_policy` and `c56_mute_ghgprices_until`, and it runs the
endogenous diet.

### What the design can and cannot identify

Excluding the one (climate, bio) combination makes this **two 2^4 cubes sharing a
2^3 face**, not a full 2^5 factorial:

- **Cube A** (climate = on): Bio x Prot x Diet x TC. Reference
  `CPon_BioOff_NoProt_DietOff`. *Does protection compete with bioenergy under 1.5C
  policy, does diet ease that competition, and does the tau regime change it?*
- **Cube B** (bio = off): Climate x Prot x Diet x TC. Reference
  `CPoff_BioOff_NoProt_DietOff`. *Does climate policy change protection's and
  diet's effects and TC's leverage?*
- Shared face: (climate on, bio off) x Prot x Diet x TC. Each cube is 2^4 = 16
  runs; they share 8 runs on that face, so 16 + 16 - 8 = 24 distinct FST runs
  (+ BAU = 25).

**Unidentifiable by construction**: every effect involving climate and bioenergy
jointly (`Climate:Bio` and every higher interaction that contains both). The
bioenergy main effect is therefore **conditional on climate policy being on** and
must never be reported as a marginal effect over the whole design.

## Methodology decisions

These are the non-obvious calls. Several correct problems in earlier versions of
this experiment.

**1. Protection is a BUNDLE of FOUR instruments (Modules 22 + 44 + 29 + 42), land
AND water.** The land part (area conservation + a biodiversity constraint + SNV on
cropland) mirrors the "ecosystem stewardship" bundle in `paper_healthyLscps.R`.
Water (environmental-flow protection) is added so the lever is land AND water, not
land alone.

- `s44_bii_target` is itself a land-protection instrument: BII is a linear
  function of the same `vm_land` pools Module 22 bounds, so a binding floor forces
  natural-land retention even with `c22_protect_scenario = none`. Left in the
  backdrop it would have made the area-based "main effect" a residual on top of an
  already-binding floor.
- SNV (`s29_snv_shr`) is already coupled to Module 22 inside the model:
  `q29_land_snv` adds the conserved area on top of the SNV requirement, so the two
  enter one constraint. Splitting them would be a distinction the model does not
  make.
- Environmental-flow water protection (Module 42) is the water limb of the same
  "protect ecosystems" ambition. As a separate always-on backdrop line its
  land-competition cost was hidden inside every cell; in the bundle it is
  attributed to the protection factor. `c42_env_flow_policy = off` sets the fader
  parameter `p42_efp(t,"off")` to identically 0, so "water off" is the base 5%
  reservation only, not zero environmental water.

**1b. Protection level: `GSN_HalfEarth`, GATED ON A DATA CHECK.** No pre-existing
start script in this repo uses it. Since `f22_consv_prio` is a GAMS table, an
element with no column in `consv_prio_areas.cs3` silently stays at 0 and behaves
like `none`. Run `fst_levers_preflight.R` before launching. Fallback order:
`BH_IFL` (precedented, and structurally unable to no-op because
`presolve_ini.gms` hard-codes protection of all remaining primary forest for
`IFL`/`BH_IFL`), then `IrrC_95pc_30by30`, then `30by30`.

**1c. "30by30 by 2050" was never internally consistent.** The year is in the name.
This experiment uses a target whose name carries no year, on the common 2025->2050
schedule; if the fallback chain lands on `30by30`, the timing must be revisited.

**2. Two protection instruments remain ON in BOTH arms** and are the floor this
contrast sits on top of, not part of the factor:
- WDPA baseline protection (`c22_base_protect = WDPA`), never gated on
  `c22_protect_scenario`;
- NPI avoided deforestation **and** avoided other-land conversion (`c35_ad_policy
  = npi`, inherited from `setScenario`). Note `c35_aolc_policy` is inert in the
  GAMS code; `c35_ad_policy` drives both floors.

So "no protection" is not "open season on forests"; the measured protection effect
is *incremental regulatory protection on top of that floor*.

**3. Every lever transitions on the same 2025->2050 schedule.** This required
moving the BII target off its defaults (`s44_start_year` 2030, `s44_target_year`
2100), and forcing `s44_start_year = 2026` even when `s44_bii_target = 0`:
`bii_target/preloop.gms` aborts if `s44_start_year <= sm_fix_SSP2` (= 2025)
*regardless of the target value*, so the OFF arm keeps 2026 too.

**4. Non-CO2 MACCs are price-driven, not forced to the maximum step.** The earlier
setting `s57_maxmac_n_* = 201` severed N abatement from the pollutant price, so a
run honoured the REMIND carbon-price scenario for CO2 while ignoring it for N2O.
Step 201 is ~1222 USD17MER/tCO2eq, against a PkBudg650 price of ~620-640 at 2050
(step ~103-106). All five switches are now `-1`, and the model derives the step
from each cell's own REMIND price per region and timestep.

**4b. Nitrogen now has TWO channels in this design, not one.**

- *Climate channel*: the MACC setting is part of Factor 2 (climate policy). The
  climate price sets the abatement step and the endogenous price response, so
  climate policy's effect on N surplus already contains the MACC channel.
- *Diet channel*: Factor 5 (diet) moves N through **food demand**. An EAT-Lancet
  shift lowers livestock demand and therefore manure and fertiliser N.

N surplus must be attributed to **both** factors (and their interaction), never
read as a single lever's outcome. This is a change from the 4-factor version,
where diet was constant and N had only the climate channel.

**5. The carbon-price factor toggles exactly one thing.** `c56_emis_policy` and
`c56_mute_ghgprices_until` are held constant across all 12 cells. The muting
switch is not only about when prices bite: it also gates the start of the
carbon-price-induced afforestation reward.

**6. The bioenergy factor is "policy-driven BECCS expansion", not "bioenergy vs
none".** Both arms are real demand trajectories from the same REMIND family. Note
1st-generation bioenergy is present in every scenario and cannot be switched off
(`c60_1stgen_biodem` has no `none`), so this axis is strictly 2nd-generation.

**7. The diet factor is exogenous-vs-endogenous, not two exogenous diets.** ON is
the EAT-Lancet FLX 2500 kcal transition; OFF is the diet MAgPIE derives from income
and prices (`s15_exo_diet = 0`). The OFF arm sets only that one switch: with the
exogenous-diet path off, the `c15_*` and convergence scalars have no effect.

**8. `CPon x BioOff` is a counterfactual, not a scenario.** See "The hole and the
kept counterfactual" above. Legitimate as a decomposition device; label it as such
in every figure and never quote it as a standalone outcome.

**9. BII is both a constraint and an outcome.** Under a binding floor, reported BII
is pinned near the target and carries little information. The analysis also reports
`ov44_bii_missing` (the per-biome shortfall, penalised at 1e6 USD/unit) so "was the
target met, and at what cost" is visible. The BII target is **soft**: a run can
solve feasibly while missing it.

**10. `c44_bii_decrease = 0` is a legitimate instrument, but not usable here.** It
has no `s44_bii_target > 0` guard, so setting it would impose a no-BII-decline
constraint on the OFF arm too. It stays at 1 in both arms.

## Usage

From the magpie repo root:

```bash
# 1. validate without touching GAMS (all run with no input data)
Rscript scripts/start/projects/fst_levers_config_test.R        # config assembly, 160 assertions
Rscript scripts/start/projects/fst_levers_orchestrator_test.R  # run-status helpers, 10 assertions
Rscript scripts/output/projects/fst_levers_decompose_test.R    # decomposition algebra, 30 assertions
FST_LEVERS_DRYRUN=1 Rscript scripts/start/projects/fst_levers.R  # show the 25 runs

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

One command, exits non-zero if any gate fails:

```bash
Rscript scripts/start/projects/fst_levers_preflight.R
```

It checks:

1. **The protection scenario must carry non-zero data.** `f22_consv_prio` is a
   GAMS table read from `consv_prio_areas.cs3`; a set element with no matching
   column stays silently at 0 and behaves exactly like `none`. If that happens,
   every Prot-ON run is really a Prot-OFF run, the protection factor is
   identically zero, and the batch is void while looking completely healthy - no
   error, no warning, no infeasibility. On failure the script prints which
   fallback scenarios do have data. (The check matches on split subdim tokens plus
   the extracted value, not the raw dotted dimnames.)
2. `R34M410-SSP2-NPi2025` and `R34M410-SSP2-PkBudg650` have data in both
   `f56_pollutant_prices.cs3` and `f60_bioenergy_dem.cs3`.
3. The Module 29 cropland-availability input the SNV lever needs is present.
4. The Module 42 environmental-flow water input (`lpj_envflow_grper.cs2`) the
   env-flow water lever needs is present.

Exit 3 means "no input data in this checkout" - the gates are cluster-only.

## Orchestration notes

`start_run()` takes the `sbatch` branch whenever `srun` exists and
`cfg$sequential` is FALSE, and returns as soon as the job is **queued**. Hence:

- **Concurrency is SLURM's job.** A whole phase is submitted at once with a small
  stagger. A submission cap would turn one wave into several sequential waves of
  (queue wait + solve) for no benefit; the cap only applies without SLURM.
- **Phase 2 waits for BAU alone**, not the whole of Phase 1: BAU's gdx is its only
  dependency.
- **Every run has a deadline.** A job killed by wall time, preemption or OOM never
  writes `modelstat`, so without one the poll loop would spin forever. An overdue
  run is reported and abandoned; the batch continues.
- **`cfg$qos` is set explicitly.** Left NULL, the auto-selector falls back to
  `standby`, which is preemptible.
- **`extra/disaggregation` is dropped** from `cfg$output`. It runs inside the SLURM
  job against the same wall-time and memory budget and produces gridded output this
  experiment does not use.
- **`f13_tau_scenario.csv` is safe to overwrite between launches**:
  `gms::singleGAMSfile()` inlines it into each run's own `full.gms` during prep,
  before `sbatch`.
- **Run counts are derived from the config**, not hard-coded: `fst_levers.R`
  iterates `names(FST_LEVERS_SCENARIOS)` (Phase 1) and `FST_LEVERS_TCBAU_SCENARIOS`
  (Phase 2), so a change in the factor design needs no edit to the orchestrator.

## Analysis

`scripts/output/projects/fst_levers_decompose.R` holds the treatment-coded 2^k
decomposition (pure functions, no gdx), unit-tested by `fst_levers_decompose_test.R`
against cells constructed from known effects. The functions are **general 2^k**
(they take the factor vector as an argument); the test covers both a 2^3 cube and
a full 2^4 cube, which is what each of this design's two cubes is.

Effects are in the **natural direction** (positive = the factor increases the
outcome). `yield_gap` used the opposite convention; convert once at the reporting
boundary with `asReductionConvention()`, never ad hoc.

Deliverables, in order:

1. **Feasibility heatmap over all 25 runs, first, as a gate.** The Half-Earth
   restoration + high BECCS + tau-frozen corners are the likeliest infeasible.
   Every effect whose inclusion-exclusion sum touches a missing cell is NA,
   surfaced, never zeroed. Main effects affected by a missing TCbau corner are
   recomputed on the fully-feasible TCendo sub-slice.
2. **Cube A: bioenergy x protection x diet at TCendo** - the headline
   land-competition figure.
3. **Cube B: climate policy x protection x diet at TCendo.**
4. **TC-isolation slice**: `dTC = Y(TCendo) - Y(TCbau)` per cell, 12 per outcome.
5. **Two 2^4 decompositions**, one per cube, to `marginal_contributions_{A,B}.csv`.
   Keep policy-factor effects visually separate from TC effects: TC is a
   counterfactual device, not a policy anyone chooses.
6. **Time series** reusing `yield_gap` styling; facet by (climate,bio) column x
   protection row (and diet), colour by TC state (Okabe-Ito `TCbau #E69F00`,
   `TCendo #0072B2`).

**Outcomes (13)**: `yield_gap`'s 9 (cropland, pasture, total forest, LUCC CO2,
N surplus, water withdrawal, BII, production, food price index) plus 2nd-gen
bioenergy crop area (`croparea(gdx, products = "kbe60")`), total land CO2
(`Emissions|CO2|Land`), forestry area from `land()`, and `ov44_bii_missing`. Note
N surplus and water withdrawal now respond to more than one factor (N: climate +
diet; water: protection via env-flows + diet + climate).

## Provenance

- Base: magpie `experiment/fst-levers`, version 4.14.0dev.
- Config assembly, the orchestrator's run-status helpers and the decomposition
  algebra are all unit-tested at the R level on a machine without input data.
  The GAMS solve and the 25-run batch run on the HPC.
