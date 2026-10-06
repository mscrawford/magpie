# |  L4 twins on the HPC (2026-09-20): the ALIGNED price x diet cube under the design-B backdrop, plus an M0/M1 pair
# |  with the S6 ratchet on the SAME backdrop (a third factor, not a separate frame). SSP2 / RCP4.5 host, every cell L4 edge ON.
# |  2026-10-01 (Mike): protection P added as a third cube factor -> 2^3 = 8 cube cells + the ratchet pair = 10 cells.
# |    allnosoil_M{0,1}P{0,1}D{0,1}: set_cube_backdrop() (c56_emis_policy all_nosoil, c56_mute_ghgprices_until y2025, MACCs pinned) so
# |      the GHG price is live from 2030, the same step as the diet's first faded step and the price scenario's bioenergy demand
# |      (the PC pilot of 2026-09-19 had the price start in 2035); M = R34M410-SSP2-PkBudg650 price + bioenergy, D = s15_exo_diet 3,
# |      P = design B's bundle (GSN_HalfEarth + BII as NO NET LOSS from 2030 + SNV 0.2 + env flows to 2050; until 2026-10-06 the BII
# |      instrument was RIKEN's floor of 0.78 by 2050 with decrease allowed, which the twins of 2026-10-01 and 10-05 ran: L4TWIN_BII below), set
# |      EXPLICITLY in both arms. HalfEarth is the SSP1 narrative target, chosen here so the P effect is comparable with design B's
# |      SSP1 cube (Mike, 2026-10-01); it is off-narrative for SSP2 (30x30). The bundle moves land through BII, SNV and water as well
# |      as protected area, so a P effect on the edge stock is not attributable to forest protection alone.
# |      P-off vs the July base: only s44_target_year (2100 -> 2050) and s42_efp_targetyear (2040 -> 2050) change, both inert when
# |      their instrument is off (bii_target/presolve.gms guards on s44_bii_target > 0; p42_efp(t,"off") = 0 ignores the fader).
# |      c44_bii_decrease stays 1 in every cell WITHOUT the BII instrument: its 0 branch in presolve has no target guard.
# |    ratchet_M{0,1}P0D0: the same backdrop with s35_degr_ratchet = 1 (the applied deficit can only rise): ratchet_M1P0D0 -
# |      ratchet_M0P0D0 is the lower bound of the price co-benefit that allnosoil_M1P0D0 - allnosoil_M0P0D0 measures with instant recovery.
# |    The pre-P cell names (allnosoil_M{0,1}D{0,1}, ratchet_M{0,1}D0) are accepted in L4TWIN_CELLS as aliases of their P0 cells.
# |    inst_area / inst_area_norestore / inst_snv / inst_envflow (2026-10-01): the P bundle split by instrument at M0D0, each cell
# |      allnosoil_M0P0D0 with one instrument on (inst_area vs inst_area_norestore isolates restoration). Launched only when
# |      named in L4TWIN_CELLS; the default set stays the ten cube + ratchet cells.
# |    inst_bii / inst_nobii (2026-10-05, Mike): the BII instrument alone, and the bundle without it. With allnosoil_M0P1D0 (bundle)
# |      and allnosoil_M0P0D0 these close the split: the instrument's interaction with the rest = bundle - inst_nobii - inst_bii
# |      (each as a difference from M0P0D0).
# |  Base construction as l4_lever_pilot_pc.R: the July SSP2base config overlaid on the current default.cfg, edge ON.
# |  Usage (HPC, slurm through start_run; one process submits all selected cells):
# |    cd libraries/magpie && Rscript scripts/start/projects/l4_price_twins_hpc.R
# |  Subset:  L4TWIN_CELLS=ratchet_M0P0D0,ratchet_M1P0D0 Rscript scripts/start/projects/l4_price_twins_hpc.R
# |  Dry run: L4TWIN_DRYRUN=1 L4TWIN_DRYRUN_DIR=<dir> Rscript ... (writes the resolved configs, credentials stripped, starts nothing)
# |  Env: L4TWIN_CELLS (default all ten), L4TWIN_SRC (glob of the July run), L4TWIN_TITLE (prefix, default SSP2L4twin_),
# |       L4TWIN_QOS (optional; unset = start_functions' load-based choice), MAGPIE_SEQUENTIAL=TRUE for a PC test one cell at a time
# |       (WITHOUT it, on a machine without slurm, start_run launches every selected cell at once).
# |  NB the design-B suite launcher's SSP1-only stop() is about the cube's design; rev4.131 carries the SSP2 PkBudg650 column.

source("scripts/start_functions.R")
source("config/default.cfg")            # the CURRENT schema (check_config refuses a cfg with missing keys)

# --- Base: the July SSP2base config overlaid on the current default.cfg, L4 edge ON (l4_lever_pilot_pc.R / l4_gate_pair.R) ---
src <- Sys.glob(Sys.getenv("L4TWIN_SRC", "output/SSP2base_bodirsky_ON_2026-07-01_*"))
if (length(src) != 1) stop("L4TWIN_SRC matched ", length(src), " run dir(s); expected exactly one (default glob output/SSP2base_bodirsky_ON_2026-07-01_*)")
titlePrefix <- Sys.getenv("L4TWIN_TITLE", "SSP2L4twin_")
july <- gms::loadConfig(file.path(src, "config.yml"))
base <- cfg
dropped <- setdiff(names(july$gms), names(base$gms))
if (length(dropped) > 0) message("July switches unknown to the current default.cfg (dropped): ", paste(dropped, collapse = ", "))
for (k in intersect(names(july$gms), names(base$gms))) base$gms[[k]] <- july$gms[[k]]
base$input <- july$input
if (!identical(unname(base$input), unname(cfg$input)))
  stop("this launcher overlays the config of a July 2026 run, including its input revision (", base$input[["regional"]],
       "), on code whose default.cfg names ", cfg$input[["regional"]], ". The code after the develop merge of 2026-10 reads input files ",
       "the old revision lacks, and the old runs carried all-zero NPI / NDC tables (recalc_npi_ndc = FALSE). Use ",
       "scenario_suite_emissions_fragmentation.R (builds from default.cfg), or port this launcher first.")
added <- setdiff(names(base$gms), names(july$gms))
message("switches new since July, taken from default.cfg: ", paste(added, collapse = ", "))
base$results_folder <- "output/:title::date:"
base$force_download <- FALSE
base$recalc_npi_ndc <- "ifneeded"   # was FALSE until 2026-10-05: runs then read the all-zero placeholder NPI tables (merge audit)
base$output         <- c("output_check", "rds_report")

# --- HPC submission, as scenario_suite_emissions_fragmentation.R does it ---
# sequential FALSE = parallel GAMS solves, i.e. one sbatch per run (start_functions.R submits submit_<qos>.sh);
# MAGPIE_SEQUENTIAL=TRUE forces a local sequential run for a PC test. The suite script sets NO qos and lets
# start_functions.R pick one from the cluster load (config/default.cfg: cfg$qos <- NULL); L4TWIN_QOS overrides that.
base$sequential <- Sys.getenv("MAGPIE_SEQUENTIAL", "FALSE") == "TRUE"
qos <- Sys.getenv("L4TWIN_QOS", "")
if (nzchar(qos)) base$qos <- qos
# Per-RCP LPJmL cellular inputs are in the local madrat pool on /p/projects, not on the public download server
# (suite script). Registered here so the July run's ssp245 cellular tgz resolves on the cluster; on the PC the
# archive is already unpacked in input/ and force_download is FALSE, so the entry is inert.
base$repositories <- append(base$repositories,
                            list("file:///p/projects/rd3mod/inputdata/output_1.27" = NULL))

# --- Design-B cube backdrop, copied verbatim from scenario_suite_emissions_fragmentation.R (RIKEN FST_BACKDROP) ---
set_cube_backdrop <- function(cfg) {
  cfg$gms$c56_emis_policy          <- "all_nosoil"
  cfg$gms$c56_mute_ghgprices_until <- "y2025"
  for (k in c("s57_maxmac_n_soil", "s57_maxmac_n_awms", "s57_maxmac_ch4_rice", "s57_maxmac_ch4_entferm", "s57_maxmac_ch4_awms"))
    cfg$gms[[k]] <- -1                                     # MACC price-driven, pinned (setScenario never touches s57_*)
  cfg
}

# --- Factor M: the 1.5C price and the co-moving 2nd-gen bioenergy demand of ONE REMIND solution, SSP2 column ---
set_mitigation <- function(cfg, on) {
  scen <- paste0("R34M410-SSP2-", if (on) "PkBudg650" else "NPi2025")
  cfg$gms$c56_pollutant_prices          <- scen
  cfg$gms$c56_pollutant_prices_noselect <- scen
  cfg$gms$c60_2ndgen_biodem             <- scen
  cfg$gms$c60_2ndgen_biodem_noselect    <- scen
  cfg
}

# --- Factor D (EAT-Lancet diet), design-B atom, set EXPLICITLY in both arms (suite / pilot guard) ---
set_diet <- function(cfg, on) {
  cfg$gms$s15_exo_diet                 <- if (on) 3 else 0
  cfg$gms$c15_kcal_scen                <- "healthy_BMI"
  cfg$gms$s15_exo_foodscen_start       <- 2025
  cfg$gms$s15_exo_foodscen_target      <- 2050
  cfg$gms$s15_exo_foodscen_convergence <- 1
  cfg
}

# --- Factor P: land + water protection as ONE bundle, copied verbatim from scenario_suite_emissions_fragmentation.R
# --- (RIKEN .prot_on / .prot_off), every instrument on the 2025->2050 schedule, set EXPLICITLY in both arms ---
# set_protection_parts() sets each instrument separately (2026-10-01, Mike: split the bundle after the P cell lowered natural
# forest in the most-protected clusters); set_protection(on) is the bundle and reproduces the earlier cells' configs exactly.
# The BII instrument. DECIDED by Mike on 2026-10-06 ("use the No Net Loss BII configuration rather than a BII floor"): no net loss
# from 2030 as scripts/start/projects/paper_healthyLscps.R (P. v. Jeetze) sets it, c44_bii_decrease 0 and no target value. The floor
# of 0.78 by 2050 is not met in the model and is penalised (fragmentation repo, L4_BUILD 18.17 to 18.24). A numeric floor is named as
#   L4TWIN_BII=<target>,<target year>,<decrease 0|1>     e.g. L4TWIN_BII=0.78,2050,1 reproduces the twins of 2026-10-01 and 10-05
BII <- Sys.getenv("L4TWIN_BII", "")
if (nzchar(BII)) {
  BII <- suppressWarnings(as.numeric(trimws(strsplit(BII, ",")[[1]])))
  if (length(BII) != 3 || anyNA(BII) || BII[1] < 0 || BII[1] >= 1 || BII[2] <= 2030 || BII[2] > 2100 || !BII[3] %in% c(0, 1) || (BII[1] == 0 && BII[3] == 1))
    stop("L4TWIN_BII must be <target in [0,1)>,<target year in (2030,2100]>,<decrease 0 or 1>; a target of 0 needs decrease 0 (no net loss)")
} else BII <- c(0, 2050, 0)                                   # no net loss from 2030 (paper_healthyLscps.R)
bii_tag <- function(g) if (g$s44_bii_target == 0 && g$c44_bii_decrease == 1) "off" else if (g$s44_bii_target == 0) "nnl" else sprintf("%.2fby%d/dec%d", g$s44_bii_target, g$s44_target_year, g$c44_bii_decrease)
set_protection_parts <- function(cfg, area, restore = TRUE, bii, snv, envflow) {
  scen <- if (area) "GSN_HalfEarth" else "none"
  cfg$gms$c22_protect_scenario          <- scen
  cfg$gms$c22_protect_scenario_noselect <- scen
  cfg$gms$s22_conservation_start  <- 2025
  cfg$gms$s22_conservation_target <- 2050
  cfg$gms$s22_restore_land        <- if (restore) 1 else 0   # 1 in both bundle levels, as RIKEN
  cfg$gms$s44_bii_target    <- if (bii) BII[1] else 0       # BII instrument (module 44); target 0 with decrease 0 = no net loss
  cfg$gms$s44_start_year    <- 2030                          # MUST be a timestep > sm_fix_SSP2 (2025), else the instrument never fires
  cfg$gms$s44_target_year   <- if (bii) BII[2] else 2050    # inert without a target value
  cfg$gms$c44_bii_decrease  <- if (bii) BII[3] else 1       # 1 without the instrument: the 0 branch in presolve has no target guard
  cfg$gms$s29_snv_shr          <- if (snv) 0.2 else 0       # semi-natural vegetation share of cropland (module 29)
  cfg$gms$s29_snv_shr_noselect <- if (snv) 0.2 else 0
  cfg$gms$s29_snv_scenario_start  <- 2025
  cfg$gms$s29_snv_scenario_target <- 2050
  cfg$gms$c42_env_flow_policy   <- if (envflow) "on" else "off"  # environmental flows (module 42)
  cfg$gms$s42_env_flow_scenario <- 2
  cfg$gms$s42_efp_startyear     <- 2025
  cfg$gms$s42_efp_targetyear    <- 2050
  cfg
}
set_protection <- function(cfg, on) set_protection_parts(cfg, area = on, restore = TRUE, bii = on, snv = on, envflow = on)

# --- L4 edge ON arm (l4_gate_pair.R) ---
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon  <- 1
  cfg$gms$s32_edge_haircut <- 1
  cfg
}

# --- The ten cells. "allnosoil" is the ALIGNED cube (Mike, 2026-09-20; P added 2026-10-01): with the design-B backdrop the GHG
# --- price is live from 2030, the same step as the diet's first faded step and the price scenario's bioenergy demand; the PC
# --- pilot of 2026-09-19 had the price start five years after the diet (mute until y2030). "ratchet" stays an M0/M1 pair at P0D0. ---
cellDefs <- list()
for (P in 0:1) for (D in 0:1) for (M in 0:1)
  cellDefs[[sprintf("allnosoil_M%dP%dD%d", M, P, D)]] <- list(pair = "allnosoil", M = M == 1, P = P == 1, D = D == 1,
                                                              backdrop = TRUE, ratchet = 0)
for (M in 0:1)
  cellDefs[[sprintf("ratchet_M%dP0D0", M)]] <- list(pair = "ratchet", M = M == 1, P = FALSE, D = FALSE, backdrop = TRUE, ratchet = 1)
# Instrument split of P at M0D0 (2026-10-01): each cell = allnosoil_M0P0D0 with ONE instrument on (pv = the parts list);
# inst_area vs inst_area_norestore isolates restoration. inst_bii = the BII floor alone; inst_nobii = the bundle without it
# (2026-10-05), so bundle - inst_nobii - inst_bii is the floor's interaction. Not launched by default: select with L4TWIN_CELLS.
instDefs <- list(
  inst_area           = list(area = TRUE,  restore = TRUE,  bii = FALSE, snv = FALSE, envflow = FALSE),
  inst_area_norestore = list(area = TRUE,  restore = FALSE, bii = FALSE, snv = FALSE, envflow = FALSE),
  inst_snv            = list(area = FALSE, restore = TRUE,  bii = FALSE, snv = TRUE,  envflow = FALSE),
  inst_envflow        = list(area = FALSE, restore = TRUE,  bii = FALSE, snv = FALSE, envflow = TRUE),
  inst_bii            = list(area = FALSE, restore = TRUE,  bii = TRUE,  snv = FALSE, envflow = FALSE),
  inst_nobii          = list(area = TRUE,  restore = TRUE,  bii = FALSE, snv = TRUE,  envflow = TRUE))
for (nm in names(instDefs))
  cellDefs[[nm]] <- list(pair = "inst", M = FALSE, P = FALSE, D = FALSE, backdrop = TRUE, ratchet = 0, pv = instDefs[[nm]])
# pre-P names (2026-09-20 launcher, HPC brief) -> their P0 cells
cellAlias <- c(allnosoil_M0D0 = "allnosoil_M0P0D0", allnosoil_M1D0 = "allnosoil_M1P0D0",
               allnosoil_M0D1 = "allnosoil_M0P0D1", allnosoil_M1D1 = "allnosoil_M1P0D1",
               ratchet_M0D0   = "ratchet_M0P0D0",   ratchet_M1D0   = "ratchet_M1P0D0")

defaultCells <- names(cellDefs)[!startsWith(names(cellDefs), "inst_")]   # the ten cube + ratchet cells
cells <- Filter(nzchar, trimws(strsplit(Sys.getenv("L4TWIN_CELLS", paste(defaultCells, collapse = ",")), ",")[[1]]))
aliased <- intersect(cells, names(cellAlias))
if (length(aliased) > 0) message("L4TWIN_CELLS: pre-P names mapped to their P0 cells: ",
                                 paste(aliased, "->", cellAlias[aliased], collapse = ", "))
cells <- unique(ifelse(cells %in% names(cellAlias), cellAlias[cells], cells))
unknown <- setdiff(cells, names(cellDefs))
if (length(unknown) > 0) stop("unknown L4TWIN_CELLS: ", paste(unknown, collapse = ", "),
                              " (available: ", paste(names(cellDefs), collapse = ", "), ")")
dryrun <- Sys.getenv("L4TWIN_DRYRUN", "0") == "1"

folders <- c()
for (cell in cells) {
  d   <- cellDefs[[cell]]
  cfg <- base
  cfg <- set_edge_on(cfg)
  if (isTRUE(d$backdrop)) cfg <- set_cube_backdrop(cfg)
  cfg <- set_mitigation(cfg, on = isTRUE(d$M))
  cfg <- if (is.null(d$pv)) set_protection(cfg, on = isTRUE(d$P)) else do.call(set_protection_parts, c(list(cfg = cfg), d$pv))
  cfg <- set_diet(cfg, on = isTRUE(d$D))
  cfg$gms$s35_degr_ratchet <- d$ratchet
  cfg$title <- paste0(titlePrefix, cell)
  if (dryrun) {
    out <- file.path(Sys.getenv("L4TWIN_DRYRUN_DIR", "."), paste0("l4twin_dryrun_config_", cell, ".yml"))
    # strip repository credentials before writing, as start_run does for the run's config.yml
    cfg$repositories <- setNames(vector("list", length(cfg$repositories)), names(cfg$repositories))
    gms::saveConfig(cfg, out)
    cat(sprintf("DRY RUN: %-16s title=%-32s emis=%-17s mute=%-6s c56=%-24s c60=%-24s c22=%-13s bii=%s snv=%.1f efp=%-3s diet=%s ratchet=%s -> %s\n",
                cell, cfg$title, cfg$gms$c56_emis_policy, cfg$gms$c56_mute_ghgprices_until,
                cfg$gms$c56_pollutant_prices, cfg$gms$c60_2ndgen_biodem, cfg$gms$c22_protect_scenario,
                bii_tag(cfg$gms), cfg$gms$s29_snv_shr, cfg$gms$c42_env_flow_policy, cfg$gms$s15_exo_diet,
                cfg$gms$s35_degr_ratchet, out))
    next
  }
  cat(sprintf("\n===== Starting: %s =====\n", cfg$title))
  folders <- c(folders, start_run(cfg, codeCheck = FALSE))
}
if (!dryrun) {
  cat(sprintf("\n========== %d L4 PRICE-TWIN RUN(S) LAUNCHED ==========\n", length(folders)))
  for (f in folders) cat(sprintf("  %s\n", f))
  cat("\nMonitor:\n  ls output/SSP2L4twin_*/report.rds\n")
}
