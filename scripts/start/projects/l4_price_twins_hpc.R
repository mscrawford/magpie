# |  L4 twins on the HPC (2026-09-20): the ALIGNED 2 x 2 price x diet cube under the design-B backdrop plus an M0/M1 ratchet pair,
# |  SSP2 / RCP4.5 host, all six cells L4 edge ON.
# |  Purpose: the carbon-price co-benefit on the committed-stock edge lines, measured twice - once with the design-B
# |  emission backdrop (so the price scope matches the SSP1 cube the paper will use) and once with the S6 ratchet on
# |  (so the co-benefit is bracketed from below, because L4 books edge recovery instantly and therefore hands the
# |  deficit back as soon as forest area regrows).
# |    pair 1 "allnosoil" : M0D0 / M1D0 with set_cube_backdrop() overlaid (c56_emis_policy all_nosoil,
# |                         c56_mute_ghgprices_until y2025, the five s57_maxmac_* pinned to -1), s35_degr_ratchet 0.
# |    pair 2 "ratchet"   : M0D0 / M1D0 on the BASE backdrop (the July SSP2base frame: reddnatveg_nosoil, y2030)
# |                         with s35_degr_ratchet = 1.
# |  Each pair is internally comparable (its two cells differ in the M keys only), so the price effect is a clean
# |  within-pair difference; the two pairs differ from each other in the backdrop AND the ratchet and are NOT a
# |  factorial - they are two separate readings of the same price lever.
# |  Host world: SSP2 at RCP4.5, inherited from the July SSP2base config (rev4.131 ssp245 cellular archive), exactly
# |  as l4_lever_pilot_pc.R / l4_gate_pair.R build it. The M atom therefore uses the SSP2 PkBudg650 column, which
# |  rev4.131 does carry in both f56_pollutant_prices and f60_bioenergy_dem (verified 2026-09-19); the design-B
# |  launcher's SSP1-only stop() is about the cube's design, not about the data.
# |  Reference corner: output/SSP2base_L4gate_ON_2026-09-19_14.25.45 (l4_gate_pair.R, arm ON) is the base this script
# |  reproduces; against its config.yml each cell here must differ in the backdrop keys, the ratchet key and the M
# |  keys ONLY (dry-run diff, see below).
# |
# |  Usage (HPC, slurm; one process submits all four):
# |    cd magpie && Rscript scripts/start/projects/l4_price_twins_hpc.R
# |  Subset:            L4TWIN_CELLS=ratchet_M0D0,ratchet_M1D0 Rscript scripts/start/projects/l4_price_twins_hpc.R
# |  Dry run (write the resolved configs, submit nothing):
# |    L4TWIN_DRYRUN=1 L4TWIN_DRYRUN_DIR=/tmp Rscript scripts/start/projects/l4_price_twins_hpc.R
# |  PC test (no scheduler, one cell at a time): MAGPIE_SEQUENTIAL=TRUE L4TWIN_CELLS=ratchet_M0D0 caffeinate -dimsu Rscript ...
# |  Env: L4TWIN_CELLS (default all four), L4TWIN_DRYRUN, L4TWIN_DRYRUN_DIR (default .), L4TWIN_SRC (glob of the July
# |       run overlaid; default the SSP2base gate source), L4TWIN_TITLE (prefix, default SSP2L4twin_),
# |       L4TWIN_QOS (slurm qos; unset = start_functions.R's educated guess, which is what
# |       scenario_suite_emissions_fragmentation.R relies on), MAGPIE_SEQUENTIAL.
# |  Afterwards: git checkout -- modules/35_natveg/pot_forest_may24/input.gms modules/32_forestry/dynamic_may24/input.gms
# |  (and any other module input.gms that start_run stamped: git status shows them).

source("scripts/start_functions.R")
source("config/default.cfg")            # the CURRENT schema (check_config refuses a cfg with missing keys)

# --- Base: the July SSP2base config overlaid on the current default.cfg, L4 edge ON (l4_lever_pilot_pc.R / l4_gate_pair.R) ---
src <- Sys.glob(Sys.getenv("L4TWIN_SRC", "output/SSP2base_bodirsky_ON_2026-07-01_*"))
stopifnot(length(src) == 1)
titlePrefix <- Sys.getenv("L4TWIN_TITLE", "SSP2L4twin_")
july <- gms::loadConfig(file.path(src, "config.yml"))
base <- cfg
dropped <- setdiff(names(july$gms), names(base$gms))
if (length(dropped) > 0) message("July switches unknown to the current default.cfg (dropped): ", paste(dropped, collapse = ", "))
for (k in intersect(names(july$gms), names(base$gms))) base$gms[[k]] <- july$gms[[k]]
base$input <- july$input
added <- setdiff(names(base$gms), names(july$gms))
message("switches new since July, taken from default.cfg: ", paste(added, collapse = ", "))
base$results_folder <- "output/:title::date:"
base$force_download <- FALSE
base$recalc_npi_ndc <- FALSE
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

# --- Factor D: off in every cell of this design, set EXPLICITLY in both arms (suite / pilot guard) ---
set_diet <- function(cfg, on) {
  cfg$gms$s15_exo_diet                 <- if (on) 3 else 0
  cfg$gms$c15_kcal_scen                <- "healthy_BMI"
  cfg$gms$s15_exo_foodscen_start       <- 2025
  cfg$gms$s15_exo_foodscen_target      <- 2050
  cfg$gms$s15_exo_foodscen_convergence <- 1
  cfg
}

# --- L4 edge ON arm (l4_gate_pair.R) ---
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon  <- 1
  cfg$gms$s32_edge_haircut <- 1
  cfg
}

# --- The six cells. "allnosoil" is the ALIGNED 2 x 2 (Mike, 2026-09-20): with the design-B backdrop the GHG price is live
# --- from 2030, the same step as the diet's first faded step and the price scenario's bioenergy demand; the PC pilot of
# --- 2026-09-19 had the price start five years after the diet (mute until y2030). "ratchet" stays an M0/M1 pair. ---
cellDefs <- list(
  allnosoil_M0D0 = list(pair = "allnosoil", M = FALSE, D = FALSE, backdrop = TRUE,  ratchet = 0),
  allnosoil_M1D0 = list(pair = "allnosoil", M = TRUE,  D = FALSE, backdrop = TRUE,  ratchet = 0),
  allnosoil_M0D1 = list(pair = "allnosoil", M = FALSE, D = TRUE,  backdrop = TRUE,  ratchet = 0),
  allnosoil_M1D1 = list(pair = "allnosoil", M = TRUE,  D = TRUE,  backdrop = TRUE,  ratchet = 0),
  ratchet_M0D0   = list(pair = "ratchet",   M = FALSE, D = FALSE, backdrop = FALSE, ratchet = 1),
  ratchet_M1D0   = list(pair = "ratchet",   M = TRUE,  D = FALSE, backdrop = FALSE, ratchet = 1))

cells <- Filter(nzchar, trimws(strsplit(Sys.getenv("L4TWIN_CELLS", paste(names(cellDefs), collapse = ",")), ",")[[1]]))
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
  cfg <- set_diet(cfg, on = isTRUE(d$D))
  cfg$gms$s35_degr_ratchet <- d$ratchet
  cfg$title <- paste0(titlePrefix, cell)
  if (dryrun) {
    out <- file.path(Sys.getenv("L4TWIN_DRYRUN_DIR", "."), paste0("l4twin_dryrun_config_", cell, ".yml"))
    # strip repository credentials before writing, as start_run does for the run's config.yml
    cfg$repositories <- setNames(vector("list", length(cfg$repositories)), names(cfg$repositories))
    gms::saveConfig(cfg, out)
    cat(sprintf("DRY RUN: %-14s title=%-30s emis=%-17s mute=%-6s c56=%-24s c60=%-24s ratchet=%s -> %s\n",
                cell, cfg$title, cfg$gms$c56_emis_policy, cfg$gms$c56_mute_ghgprices_until,
                cfg$gms$c56_pollutant_prices, cfg$gms$c60_2ndgen_biodem, cfg$gms$s35_degr_ratchet, out))
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
