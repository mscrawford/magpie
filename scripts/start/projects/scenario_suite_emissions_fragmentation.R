# |  Scenario suite: emissions + fragmentation futures. DESIGN B (Mike, 2026-09-09): a decomposable 2^3 lever cube on SSP1.
# |
# |  Canonical set (17 runs):
# |    SSP1 cube        : mitigation (M) x protection (P) x diet (D), each on/off, at ONE climate input (RCP2.6) for every
# |                       cell, so factor effects and interactions decompose cleanly (RIKEN fst_levers algebra applies).
# |                       8 cells, edge ON; the all-off corner also edge OFF.          -> 9 runs
# |    SSP2 / SSP3 base : context lines at their narrative climate (RCP4.5 / RCP7.0), edge OFF + ON.  -> 4 runs
# |    broad edge       : ~1 km penetration sensitivity on the SSP1 corners (all-off, all-on) and the two context bases. -> 4 runs
# |
# |  Factor atoms (the RIKEN fst_levers canonical switches, fst_levers_config.R / fst_levers_v2_config.R; Mike 2026-09-09:
# |  'use the switches canonically'; RIKEN found the earlier diet + protection programming wrong):
# |    M on : c56_pollutant_prices + c60_2ndgen_biodem (and _noselect twins) = R34M410-SSP1-PkBudg650 (1.5C, price and
# |           bioenergy are the two images of ONE REMIND solution and stay paired).  M off: R34M410-SSP1-NPi2025.
# |    P on : c22 30by30 2025->2050 (until 2026-10-06 GSN_HalfEarth; see the AREA note below) + s22_restore_land 1 + BII as NO NET LOSS from 2030 (c44_bii_decrease 0, no target
# |           value; start 2030 = first timestep > 2025) + SNV 0.2 2025->2050 + environmental flows on (scenario 2, 2025->2050).
# |           Until 2026-10-06 the BII instrument was a floor of 0.78 by 2050 with decrease allowed (see SUITE_BII below).
# |    P off: none of them, set EXPLICITLY (env flows OFF overrides the SSP1 scenario column, which sets them on).
# |    D on : s15_exo_diet 3 (MAgPIE's own EAT-Lancet realization, exodietmacro.gms:441), c15_kcal_scen healthy_BMI,
# |           fade 2025->2050, convergence 1; c15_EAT_scen deliberately NOT set (inert under mode 3; a non-BMI kcal
# |           target would route back to that dataset).  D off: s15_exo_diet 0.
# |    Backdrop, constant in all 8 cells (RIKEN FST_BACKDROP): c56_emis_policy all_nosoil, c56_mute_ghgprices_until y2025;
# |           MACC switches price-driven (-1, the fork default). The SSP2/SSP3 context bases keep the stock frame
# |           (reddnatveg_nosoil, y2030), as RIKEN's BAU does.
# |    Not ported: tau pinning / TC factor, the Japan bioenergy carve-out, the BioNone arm (RIKEN-specific).
# |  Third-party validation 2026-09-09 (03-magpie-integration/documents/SUITE_DESIGN_B_VALIDATION_2026-09-09.md): VALID with notes;
# |    guards added after it (diet keys in both arms, MACC + edge depth/buffer pinned, PkBudg650-for-SSP1-only assertion).
# |
# |  Cell tags are one alphanumeric token (run_pattern ^([A-Za-z0-9]+)_bodirsky_): SSP1M{0,1}P{0,1}D{0,1}; legacy names
# |  map onto corners (SSP1base = SSP1M0P0D0, SSP1mitig = M1P0D0, SSP1halfearth = M0P1D0, SSP1diet = M0P0D1, SSP1all = M1P1D1).
# |
# |  Climate per world: gms::setScenario(cfg, c(ssp,"NPI",rcp)) sets the LPJmL cellular input AND c52_land_carbon_sink_rcp;
# |  c37_labor_rcp is bracketed manually (module 37 offers rcp119 / rcp585). Per-RCP cellular inputs live in the local
# |  madrat pool registered below. One calibration is valid across RCPs of the same GCM + rev (sm_fix_cc = 2025).
# |  Edge model version L3 (2026-08-29): haircut split + AGB-only factor + forest-weighted gate, stated explicitly.
# |
# |  Usage: cd magpie && Rscript scripts/start/projects/scenario_suite_emissions_fragmentation.R
# |         SUITE_DRYRUN=1 Rscript ...                 prints each run's wired switches and exits
# |         SUITE_DRYRUN=1 SUITE_DUMP=<dir> Rscript ... additionally writes each run's resolved cfg$gms (+ input) as JSON
# |         SUITE_ONLY=<title>[,<title>] Rscript ...   launches (or dry-runs) only the named run titles, e.g. the pilot pair
# |                                                  SSP1M0P0D0_bodirsky_ON,SSP1M1P1D1_bodirsky_ON; configs are unchanged by the filter

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output          <- c("output_check", "rds_report")
# SUITE_OUTPUT: comma-separated output scripts to run at job end, or "none". Use "none" while the run library holds a
# magpie4 older than the model needs (job-end reports are provisional in any case, policy D7: read-outs are re-rendered).
if (nzchar(Sys.getenv("SUITE_OUTPUT"))) cfg$output <- if (Sys.getenv("SUITE_OUTPUT") == "none") character(0) else trimws(strsplit(Sys.getenv("SUITE_OUTPUT"), ",")[[1]])
cfg$force_download  <- FALSE
# NPI / NDC policy tables: "ifneeded" (the default.cfg value) recomputes them when the distributed files are the all-zero
# placeholders the input archives ship. This script set FALSE until 2026-10-05: every run launched after an input download
# then read all-zero tables, i.e. ran WITHOUT NPI afforestation targets and without the minimum forest / other-land stocks
# although its policy switches said npi (found by the merge audit of 2026-10-05; verified in the gdx of the 07-01 and
# 08-29 SSP2 bases, an 08-29 SSP1 run and the 10-01 twins). Never set FALSE here again.
cfg$recalc_npi_ndc  <- "ifneeded"
cfg$sequential      <- FALSE  # parallel GAMS solves

# Per-RCP LPJmL cellular inputs (ssp126 for rcp2p6, ssp245 for rcp4p5, ssp370 for rcp7p0) are in the local madrat
# pool, not on the public download server. Register it so setScenario's rcp token can resolve them.
cfg$repositories <- append(cfg$repositories,
                           list("file:///p/projects/rd3mod/inputdata/output_1.27" = NULL))

# Input patch (2026-10-05, Mike): the released f35_forest_lost_share carries the Curtis transcription defect (Africa 3 instead
# of 39 Mha: the SSA shifting-agriculture share is about 13x too low). Until an input revision built on the Sims et al.
# drivers exists, a one-file archive listed LAST in cfg$input replaces the column the model reads (shifting_agriculture) by
# the Sims-based share of the mrland PR #78 build. It lives in the fragmentation repo with a record of what it replaces
# (03-magpie-integration/input_patches/), is re-applied by every input download and is named in each run's info.txt.
# SUITE_INPUT_PATCH=none runs the released file; any other value is the path of another patch archive.
PATCH_DEFAULT <- "/p/projects/magpie/users/crawford/dev_fragmentation/03-magpie-integration/input_patches/patch_f35_shiftcult_sims_2026-10-05.tgz"
PATCH <- Sys.getenv("SUITE_INPUT_PATCH", PATCH_DEFAULT)
# A run on anything but the default patch says so in its title (audit 2026-10-05): "nopatch" for the released file, the
# part of the archive name after "patch_f35_shiftcult_" otherwise (e.g. curtisfix).
PATCHTAG <- if (PATCH == PATCH_DEFAULT) "" else if (PATCH == "none") "nopatch" else gsub("[^A-Za-z0-9]", "", sub("_[0-9]{4}-[0-9]{2}-[0-9]{2}\\.tgz$", "", sub("^patch_f35_shiftcult_", "", basename(PATCH))))
if (PATCH != PATCH_DEFAULT && !nzchar(PATCHTAG)) stop("cannot derive a title tag from the patch name ", basename(PATCH))
if (grepl("noNPI|geom[0-9]|ratchet|bii|fade|Broad", PATCHTAG)) stop("the patch name yields the title tag '", PATCHTAG, "', which contains a variant token; rename the archive")
if (PATCH != "none") {
  if (!file.exists(PATCH)) stop("input patch not found: ", PATCH, " (set SUITE_INPUT_PATCH=none to run the released inputs)")
  cfg$repositories <- append(setNames(list(NULL), dirname(normalizePath(PATCH))), cfg$repositories)
  cfg$input <- c(cfg$input, patch = basename(PATCH))
}

DRYRUN <- identical(Sys.getenv("SUITE_DRYRUN"), "1")
DUMP   <- Sys.getenv("SUITE_DUMP", "")
ONLY   <- Filter(nzchar, trimws(strsplit(Sys.getenv("SUITE_ONLY", ""), ",")[[1]]))   # empty = every run
# SUITE_NPI=none: the no-policy twin of any run (c32_aff_policy, c35_ad_policy, c35_aolc_policy = "none"), titled
# <tag>noNPI_bodirsky_<edge>. It reproduces by switch what the runs before 2026-10-05 did by accident (all-zero policy
# tables), so <tag> minus <tag>noNPI measures what the missing policies were worth. Default: policies as the scenario sets them.
NPI    <- Sys.getenv("SUITE_NPI", "")
if (!NPI %in% c("", "none")) stop("SUITE_NPI must be unset or 'none'")
# Pilot variants of any selected run (2026-10-05), each a labelled twin that differs from the plain run in ONE thing.
# They change the title tag (<tag><variant>_bodirsky_<edge>), so SUITE_ONLY must name the variant titles.
#   SUITE_GEOM=0     s35_edge_geometry 0: forest in the closure geometry by pool totals (the rule before 2026-10-05)  -> geom0
#   SUITE_GEOM=2     s35_edge_geometry 2: the maturation rule for forestry only, secondary forest in full              -> geom2
#   SUITE_RATCHET=1  s35_degr_ratchet 1: the applied edge deficit can only rise (lower bound of the co-benefit)       -> ratchet
#   SUITE_PROT=bii   protection cells carry the BII instrument ONLY;  SUITE_PROT=nobii  the bundle WITHOUT it             -> bii / nobii
GEOM    <- Sys.getenv("SUITE_GEOM", "")
RATCHET <- Sys.getenv("SUITE_RATCHET", "")
PROT    <- Sys.getenv("SUITE_PROT", "")
# The BII instrument of the protection lever. DECIDED by Mike on 2026-10-06 ("use the No Net Loss BII configuration rather than a BII
# floor"; fragmentation repo, L4_BUILD 18.17, 18.18, 18.20 to 18.24): NO NET LOSS from 2030, encoded as P. v. Jeetze does in
# scripts/start/projects/paper_healthyLscps.R: c44_bii_decrease 0 and NO target value, so each region-biome's BII may not fall below
# its level of the previous step. Why not the floor the suite of 2026-10-05 ran (0.78 by 2050, decrease allowed, RIKEN .prot_on): it
# is not met, carries a penalty of about half a trillion USD a year inside the cost total, moves about 1,600 Mha of pasture and
# cropland into other land and clears natural forest where a region-biome sits above the floor; on plain develop likewise. No net
# loss on develop: no penalty, no cluster cleared, about 200 Mha into other land by 2050. Patrick's own view is still to come.
# Upstream's default.cfg has the instrument off (target 0, start 2030, target year 2100, decrease allowed). A numeric floor is named as
#   SUITE_BII=<target>,<target year>,<decrease 0|1>     e.g. SUITE_BII=0.78,2050,1 reproduces the runs of 2026-10-05
# The target year is inert without a target value; it stays 2050 in every cell, so that a cell differs from its twin of 2026-10-05
# in s44_bii_target and c44_bii_decrease only.
AREA <- Sys.getenv("SUITE_AREA", "30by30")
if (!AREA %in% c("30by30", "GSN_HalfEarth", "BH", "BH_IFL", "KBA")) stop("SUITE_AREA must be one of 30by30 (default), GSN_HalfEarth, BH, BH_IFL, KBA")
BII <- Sys.getenv("SUITE_BII", "")
if (nzchar(BII)) {
  BII <- suppressWarnings(as.numeric(trimws(strsplit(BII, ",")[[1]])))
  if (length(BII) != 3 || anyNA(BII) || BII[1] < 0 || BII[1] >= 1 || BII[2] <= 2030 || BII[2] > 2100 || !BII[3] %in% c(0, 1) || (BII[1] == 0 && BII[3] == 1))
    stop("SUITE_BII must be <target in [0,1)>,<target year in (2030,2100]>,<decrease 0 or 1>; a target of 0 needs decrease 0 (no net loss)")
} else BII <- c(0, 2050, 0)                                   # no net loss from 2030 (paper_healthyLscps.R)
# how the instrument reads in the dry-run line: off | nnl (no net loss) | <target>by<year>/dec<0|1>
bii_tag <- function(g) if (g$s44_bii_target == 0 && g$c44_bii_decrease == 1) "off" else if (g$s44_bii_target == 0) "nnl" else sprintf("%.2fby%d/dec%d", g$s44_bii_target, g$s44_target_year, g$c44_bii_decrease)
if (!GEOM %in% c("", "0", "2") || !RATCHET %in% c("", "1") || !PROT %in% c("", "bii", "nobii")) stop("SUITE_GEOM must be unset, 0 or 2, SUITE_RATCHET unset or 1, SUITE_PROT unset, bii or nobii")
#   SUITE_TAG=<alphanumeric>  a free label appended to the tag, changing nothing else (e.g. to tell a rerun from an earlier run of the same cell)
TAG <- Sys.getenv("SUITE_TAG", "")
if (!grepl("^[A-Za-z0-9]*$", TAG)) stop("SUITE_TAG must be alphanumeric")
if (grepl("noNPI|geom[0-9]|ratchet|bii|nobii|fade|nopatch|curtisfix|Broad", TAG)) stop("SUITE_TAG must not contain a variant token (noNPI, geom<n>, ratchet, bii, nobii, fade, nopatch, curtisfix, Broad)")
#   SUITE_DAMAGE=fade  s35_forest_damage 2: shifting cultivation fades to zero by 2050 (the model default)                -> fade
# Default here (Mike, 2026-10-05: "Shifting cultivation stays on ... in baseline it should stay constant"): s35_forest_damage
# = 1, the constant rate in every run. Under geometry 1 resets by shifting cultivation leave the geometry, so a fade to zero
# would add a maturation-driven decline of the edge share to every baseline. The fork's default.cfg keeps the model default 2.
DAMAGE <- Sys.getenv("SUITE_DAMAGE", "")
if (!DAMAGE %in% c("", "fade")) stop("SUITE_DAMAGE must be unset or 'fade'")
VARIANT <- paste0(if (NPI == "none") "noNPI" else "", if (nzchar(GEOM)) paste0("geom", GEOM) else "", if (RATCHET == "1") "ratchet" else "", PROT, DAMAGE, PATCHTAG, TAG)
#   SUITE_SET=<key>=<value>[,<key>=<value>]  overrides of cfg$gms applied LAST to every selected run (review of 2026-10-05: the
#       threshold of the geometry rule, variants of the BII floor, a second solve). Needs SUITE_TAG, so that an overridden run
#       never carries a plain title; a key that the configuration does not hold stops the launcher (no silent typo); a value
#       that reads as a number is set as a number. The plain design is unchanged when the variable is unset.
SET <- Filter(nzchar, trimws(strsplit(Sys.getenv("SUITE_SET", ""), ",")[[1]]))
if (length(SET) && !nzchar(TAG)) stop("SUITE_SET needs SUITE_TAG: an overridden run must not carry a plain title")
if (length(SET) && !all(grepl("^[A-Za-z0-9_]+=[^=]+$", SET))) stop("SUITE_SET entries must read key=value")
apply_set <- function(cfg_i) {
  for (kv in SET) {
    k <- sub("=.*$", "", kv); v <- sub("^[^=]*=", "", kv)
    if (!k %in% names(cfg_i$gms)) stop("SUITE_SET: '", k, "' is not a key of cfg$gms")
    cfg_i$gms[[k]] <- if (!is.na(suppressWarnings(as.numeric(v)))) as.numeric(v) else v
  }
  cfg_i
}

# ---------------------------------------------------------------------------
# Labor-productivity RCP bracket: module 37 offers only rcp119 / rcp585 -> nearest to the run's forcing.
labor_rcp <- function(rcp) if (rcp %in% c("rcp6p0", "rcp7p0", "rcp8p5")) "rcp585" else "rcp119"

# World: socioeconomics + NPi policy + the world's climate input (each field set EXPLICITLY, every factor OFF).
set_world <- function(cfg, ssp, rcp) {
  cfg <- gms::setScenario(cfg, c(ssp, "NPI", rcp))
  cfg$gms$s35_forest_damage <- if (DAMAGE == "fade") 2 else 1   # shifting cultivation: constant rate (1) unless the fade variant
  cfg$gms$c37_labor_rcp <- labor_rcp(rcp)
  cfg <- set_mitigation(cfg, ssp, on = FALSE)
  cfg <- set_protection(cfg, on = FALSE)
  cfg <- set_diet(cfg, on = FALSE)
  cfg
}

# --- Backdrop of the cube (RIKEN FST_BACKDROP): constant in every cell, so no factor carries it ---
set_cube_backdrop <- function(cfg) {
  cfg$gms$c56_emis_policy          <- "all_nosoil"
  cfg$gms$c56_mute_ghgprices_until <- "y2025"
  for (k in c("s57_maxmac_n_soil", "s57_maxmac_n_awms", "s57_maxmac_ch4_rice", "s57_maxmac_ch4_entferm", "s57_maxmac_ch4_awms"))
    cfg$gms[[k]] <- -1                                     # MACC price-driven, pinned (RIKEN .macc_block; setScenario never touches s57_*)
  # NB (validation 2026-09-09): in input rev4.131 the NPi2025 price columns are all ZERO; preloop.gms floors co2_c at
  # s56_minimum_cprice (3.67 USD17MER/tC) AFTER muting, so in the M-off cells the only live GHG price is that floor and the
  # mute switch is inert. The backdrop is constant across the cube, so the factorial holds; the M effect = price level AND scope.
  cfg
}

# --- Factor M: mitigation = 1.5C carbon price AND the co-moving 2nd-gen bioenergy demand of the same REMIND run ---
set_mitigation <- function(cfg, ssp, on) {
  if (on && ssp != "SSP1") stop("the design-B cube runs on SSP1 by design; rev4.131 does also carry the SSP2 PkBudg650 column in f56_pollutant_prices and f60_bioenergy_dem (verified 2026-09-19, see l4_lever_pilot_pc.R / l4_price_twins_hpc.R) - for SSP3 there is none")
  scen <- paste0("R34M410-", ssp, "-", if (on) "PkBudg650" else "NPi2025")
  cfg$gms$c56_pollutant_prices          <- scen
  cfg$gms$c56_pollutant_prices_noselect <- scen
  cfg$gms$c60_2ndgen_biodem             <- scen
  cfg$gms$c60_2ndgen_biodem_noselect    <- scen
  cfg
}

# --- Factor P: land + water protection as ONE bundle (RIKEN .prot_on / .prot_off), every instrument on the 2025->2050 schedule ---
set_protection <- function(cfg, on) {
  bii  <- on && PROT != "nobii"                              # the BII instrument
  rest <- on && PROT != "bii"                                # protected area, SNV share, environmental flows
  # AREA target. DECIDED by Mike on 2026-10-06 ("Ours is too severe. I want to use the most recent default of Patrick's ... Go with
  # 30x30"): 30by30, the area target of P. v. Jeetze's own protection package (scripts/start/projects/paper_healthyLscps.R: 30by30 +
  # no net loss + SNV 20 %), on default.cfg's timing 2025 to 2050. GSN_HalfEarth (about half of the land surface; RIKEN, the runs of
  # 2026-10-01 and 10-05) is used by no upstream script or preset. SUITE_AREA=GSN_HalfEarth reproduces the earlier runs.
  scen <- if (rest) AREA else "none"
  cfg$gms$c22_protect_scenario          <- scen
  cfg$gms$c22_protect_scenario_noselect <- scen
  cfg$gms$s22_conservation_start  <- 2025
  cfg$gms$s22_conservation_target <- 2050
  cfg$gms$s22_restore_land        <- 1                       # in both levels, as RIKEN
  cfg$gms$s44_bii_target    <- if (bii) BII[1] else 0       # BII instrument (module 44); target 0 with decrease 0 = no net loss
  cfg$gms$s44_start_year    <- 2030                          # MUST be a timestep > sm_fix_SSP2 (2025), else the instrument never fires
  cfg$gms$s44_target_year   <- if (bii) BII[2] else 2050    # inert without a target value; 2050 as in every cell of 2026-10-05
  cfg$gms$c44_bii_decrease  <- if (bii) BII[3] else 1       # 1 in cells without the instrument: the 0 branch in presolve has no target guard
  cfg$gms$s29_snv_shr          <- if (rest) 0.2 else 0      # semi-natural vegetation share of cropland (module 29)
  cfg$gms$s29_snv_shr_noselect <- if (rest) 0.2 else 0
  cfg$gms$s29_snv_scenario_start  <- 2025
  cfg$gms$s29_snv_scenario_target <- 2050
  cfg$gms$c42_env_flow_policy   <- if (rest) "on" else "off"  # environmental flows (module 42); off overrides the SSP1 column
  cfg$gms$s42_env_flow_scenario <- 2
  cfg$gms$s42_efp_startyear     <- 2025
  cfg$gms$s42_efp_targetyear    <- 2050
  cfg
}

# --- Factor D: EAT-Lancet diet, RIKEN .diet_el ---
set_diet <- function(cfg, on) {
  cfg$gms$s15_exo_diet                 <- if (on) 3 else 0
  cfg$gms$c15_kcal_scen                <- "healthy_BMI"   # NOT 2500kcal; set in BOTH arms so the D pair differs in s15_exo_diet by construction
  cfg$gms$s15_exo_foodscen_start       <- 2025
  cfg$gms$s15_exo_foodscen_target      <- 2050
  cfg$gms$s15_exo_foodscen_convergence <- 1
  cfg
}

# --- Edge module OFF / ON (model version L3) and the broad ~1 km sensitivity ---
set_edge_off <- function(cfg) { cfg$gms$s35_edge_carbon <- 0; cfg }
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon  <- 1
  cfg$gms$s35_edge_formula <- 1      # exponential decay
  cfg$gms$s35_edge_lambda  <- 0.059  # ~59 m penetration depth (default)
  cfg$gms$s35_edge_degrad  <- 0.50
  cfg$gms$s35_edge_beta    <- 0.8286
  cfg$gms$s35_edge_n       <- 0.7984
  cfg$gms$s35_edge_depth   <- 0.5      # pinned (validation 2026-09-09): previously inherited from default.cfg
  cfg$gms$s35_edge_forestry_buffer <- 1
  cfg$gms$s35_edge_geometry   <- if (nzchar(GEOM)) as.numeric(GEOM) else 1   # 1 = forest in the geometry by the maturation rule, per age class (2026-10-05)
  cfg$gms$sm_edge_mature_vegc <- 20                          # its threshold = the model's secondary-forest maturation threshold
  cfg$gms$s35_degr_ratchet    <- if (RATCHET == "1") 1 else 0
  cfg$gms$s32_edge_haircut  <- 1     # forestry haircut split: ndc, natural-curve aff and other_planted carry the edge factor, plant exempt
  cfg$gms$s35_edge_agb_only <- 1     # edge factor on aboveground carbon only
  cfg$gms$s35_edge_gate     <- 1     # forest-weighted Koeppen-A tropical share per cluster; f35_edge_scale filled
  cfg
}
set_edge_broad <- function(cfg) { cfg <- set_edge_on(cfg); cfg$gms$s35_edge_lambda <- 1.0; cfg }

# ---------------------------------------------------------------------------
# The design: 8 cube cells on SSP1 (fixed RCP2.6, cube backdrop) + 2 context bases (stock frame).
cube <- list()
for (M in 0:1) for (P in 0:1) for (D in 0:1) {
  cube[[length(cube) + 1]] <- list(tag = sprintf("SSP1M%dP%dD%d", M, P, D), ssp = "SSP1", rcp = "rcp2p6",
                                   M = M == 1, P = P == 1, D = D == 1, cube = TRUE)
}
context <- list(list(tag = "SSP2base", ssp = "SSP2", rcp = "rcp4p5", cube = FALSE),
                list(tag = "SSP3base", ssp = "SSP3", rcp = "rcp7p0", cube = FALSE))
policies <- c(cube, context)

build_policy <- function(cfg, p) {
  cfg <- set_world(cfg, p$ssp, p$rcp)
  if (NPI == "none") for (k in c("c32_aff_policy", "c35_ad_policy", "c35_aolc_policy")) cfg$gms[[k]] <- "none"
  if (isTRUE(p$cube)) {
    cfg <- set_cube_backdrop(cfg)
    cfg <- set_mitigation(cfg, p$ssp, on = isTRUE(p$M))
    cfg <- set_protection(cfg, on = isTRUE(p$P))
    cfg <- set_diet(cfg, on = isTRUE(p$D))
  }
  cfg
}

edge_off_tags <- c("SSP1M0P0D0", "SSP2base", "SSP3base")               # edge OFF pairs
broad_tags    <- c("SSP1M0P0D0", "SSP1M1P1D1", "SSP2base", "SSP3base")  # ~1 km sensitivity

# ---------------------------------------------------------------------------
folders <- c(); n <- 0L
launch <- function(cfg_i, title) {
  if (length(ONLY) && !title %in% ONLY) return(invisible(NULL))
  cfg_i <- apply_set(cfg_i)
  cfg_i$title <- title; n <<- n + 1L
  if (DRYRUN) {
    lam <- if (is.null(cfg_i$gms$s35_edge_lambda)) NA_real_ else cfg_i$gms$s35_edge_lambda
    cat(sprintf("[dry] %-24s cellular=%-56s c52=%-6s c37=%-7s c56=%-24s c60=%-24s emis=%-17s mute=%s c22=%-14s bii=%s snv=%.1f efp=%-3s diet=%s edge=%s/%.3f\n",
                title, basename(cfg_i$input[["cellular"]]),
                cfg_i$gms$c52_land_carbon_sink_rcp, cfg_i$gms$c37_labor_rcp,
                cfg_i$gms$c56_pollutant_prices, cfg_i$gms$c60_2ndgen_biodem,
                cfg_i$gms$c56_emis_policy, cfg_i$gms$c56_mute_ghgprices_until, cfg_i$gms$c22_protect_scenario,
                bii_tag(cfg_i$gms), cfg_i$gms$s29_snv_shr, cfg_i$gms$c42_env_flow_policy,
                cfg_i$gms$s15_exo_diet, cfg_i$gms$s35_edge_carbon, lam))
    cat(sprintf("      %-24s npi: aff=%s ad=%s aolc=%s recalc=%s | geometry=%s ratchet=%s | regional=%s additional=%s calibration=%s\n", "", cfg_i$gms$c32_aff_policy,
                cfg_i$gms$c35_ad_policy, cfg_i$gms$c35_aolc_policy, cfg_i$recalc_npi_ndc, cfg_i$gms$s35_edge_geometry, cfg_i$gms$s35_degr_ratchet,
                cfg_i$input[["regional"]], cfg_i$input[["additional"]], cfg_i$input[["calibration"]]))
    cat(sprintf("      %-24s input patch: %s | shifting cultivation: %s\n", "", if ("patch" %in% names(cfg_i$input)) cfg_i$input[["patch"]] else "none",
                c("0" = "off", "1" = "constant", "2" = "fades to 2050")[as.character(cfg_i$gms$s35_forest_damage)]))
    if (nzchar(DUMP)) {
      dir.create(DUMP, showWarnings = FALSE, recursive = TRUE)
      jsonlite::write_json(list(title = title, input = as.list(cfg_i$input), recalc_npi_ndc = cfg_i$recalc_npi_ndc, output = cfg_i$output, gms = cfg_i$gms),
                           file.path(DUMP, paste0(title, ".json")), auto_unbox = TRUE, pretty = TRUE, digits = NA)
    }
    return(invisible(NULL))
  }
  cat(sprintf("\n===== %s (%d) =====\n", title, n))
  folders <<- c(folders, start_run(cfg_i, codeCheck = FALSE))
}

# 10 edge-ON + 3 edge-OFF = 13
for (p in policies) {
  if (nzchar(PROT) && !isTRUE(p$P)) next                                  # the BII split exists for protection cells only
  for (edge in if (p$tag %in% edge_off_tags) c("OFF", "ON") else "ON") {
    if (edge == "OFF" && (nzchar(GEOM) || RATCHET == "1")) next            # geometry and ratchet are edge-module settings
    cfg_i <- build_policy(cfg, p)
    cfg_i <- if (edge == "ON") set_edge_on(cfg_i) else set_edge_off(cfg_i)
    launch(cfg_i, paste0(p$tag, VARIANT, "_bodirsky_", edge))
  }
}
# broad-edge sensitivity = 4
# The broad arm belongs to the plain design only: no variant (geometry, ratchet, BII split) is launched on top of it.
for (p in policies) if (p$tag %in% broad_tags && !nzchar(GEOM) && RATCHET != "1" && !nzchar(PROT)) {
  launch(set_edge_broad(build_policy(cfg, p)), paste0(p$tag, VARIANT, "Broad_bodirsky_ON"))
}

if (length(ONLY)) { if (n < length(ONLY)) cat(sprintf("\n[warn] SUITE_ONLY named %d titles but %d matched; check spelling against the dry-run list\n", length(ONLY), n)) }
if (DRYRUN) { cat(sprintf("\n[dry] %d configs built, none submitted.\n", n)); quit(save = "no") }
cat(sprintf("\n========== ALL %d RUNS LAUNCHED ==========\n", length(folders)))
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nMonitor:\n  ls magpie/output/SSP*_bodirsky_*/report.rds\n")
