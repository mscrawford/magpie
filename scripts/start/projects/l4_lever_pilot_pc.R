# |  L4 lever pilot on the PC (2026-09-19 night): a 2 x 2 mitigation x diet cube on the SSP2 / RCP4.5 host, all cells L4 edge ON.
# |  Purpose: a first look at what the carbon price and the EAT-Lancet diet do to the committed-stock edge lines (S, E, F, G, T)
# |  BEFORE the design-B suite (SSP1 / RCP2.6, HPC) exists. The PC holds only the rev4.131 ssp245 cellular archive, so the host
# |  world is SSP2 at RCP4.5, not design B's SSP1 at RCP2.6; the factor algebra is the same (fixed climate inside the cube).
# |  Cells and construction:
# |    M0D0 = the existing gate run SSP2base_L4gate_ON_2026-09-19_14.25.45 (l4_gate_pair.R, arm ON) - NOT re-run; this script
# |           reproduces its config bit for bit (dry-run check below) so the three lever cells differ from it in the lever keys only.
# |    M1D0, M0D1, M1D1 = the same base with the design-B lever atoms (scenario_suite_emissions_fragmentation.R, set_mitigation /
# |           set_diet, RIKEN canonical switches) overlaid:
# |      M on : c56_pollutant_prices(+_noselect) and c60_2ndgen_biodem(+_noselect) = R34M410-SSP2-PkBudg650 - the 1.5C price and
# |             the paired bioenergy demand of ONE REMIND solution. The design-B launcher asserts PkBudg650 exists for SSP1 only;
# |             in rev4.131 the SSP2 column EXISTS in both tables (f56 co2_c LAM 525 USD17MER/tC in 2030, 2350 from 2050; f60 LAM
# |             9884 mio GJ in 2050 vs 331 under NPi2025), read from the compiled full.gms of the gate run. M off = NPi2025 (base).
# |      D on : s15_exo_diet 3 (c15_kcal_scen healthy_BMI, fade 2025->2050, convergence 1 already in the base). D off = 0 (base).
# |  Backdrop: the BASE's own (default.cfg + July SSP2base overlay): c56_emis_policy reddnatveg_nosoil, c56_mute_ghgprices_until
# |    y2030, MACCs price-driven, s56_c_price_induced_aff 1. Deliberately NOT the design-B backdrop (all_nosoil, y2025), so the
# |    existing gate run is the M0D0 corner and the pilot costs three runs, not four. Constant across the cube, so the factorial
# |    holds; the M effect here is 'the fork's default price scope at the 1.5C level, from 2035'.
# |  Usage (PC, one process per cell, stagger the starts by a minute; start_run holds the model lock through the config stamping):
# |    cd libraries/magpie && L4PILOT_CELLS=M1D0 MAGPIE_SEQUENTIAL=TRUE caffeinate -dimsu Rscript scripts/start/projects/l4_lever_pilot_pc.R
# |  Dry run (write the resolved configs, start nothing): L4PILOT_DRYRUN=1 L4PILOT_CELLS=M0D0,M1D0,M0D1,M1D1 Rscript scripts/start/projects/l4_lever_pilot_pc.R
# |  Env: L4PILOT_SRC (glob of the July run overlaid; default the SSP2base gate source), L4PILOT_TITLE (prefix, default SSP2L4pilot_),
# |       L4PILOT_DRYRUN_DIR (where dry-run configs go, default .).
# |  Afterwards: git checkout -- modules/35_natveg/pot_forest_may24/input.gms modules/32_forestry/dynamic_may24/input.gms (and any other
# |  module input.gms that start_run stamped: git status shows them).

source("scripts/start_functions.R")
source("config/default.cfg")            # the CURRENT schema (check_config refuses a cfg with missing keys)

src <- Sys.glob(Sys.getenv("L4PILOT_SRC", "output/SSP2base_bodirsky_ON_2026-07-01_*"))
stopifnot(length(src) == 1)
titlePrefix <- Sys.getenv("L4PILOT_TITLE", "SSP2L4pilot_")
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
base$sequential     <- Sys.getenv("MAGPIE_SEQUENTIAL", "FALSE") == "TRUE"
base$output         <- c("output_check", "rds_report")
# the L4 edge-ON arm of l4_gate_pair.R
base$gms$s35_edge_carbon  <- 1
base$gms$s32_edge_haircut <- 1

# --- the two lever atoms, copied from scenario_suite_emissions_fragmentation.R (design B) with the SSP2 PkBudg650 column ---
set_mitigation <- function(cfg, on) {
  scen <- paste0("R34M410-SSP2-", if (on) "PkBudg650" else "NPi2025")
  cfg$gms$c56_pollutant_prices          <- scen
  cfg$gms$c56_pollutant_prices_noselect <- scen
  cfg$gms$c60_2ndgen_biodem             <- scen
  cfg$gms$c60_2ndgen_biodem_noselect    <- scen
  cfg
}
set_diet <- function(cfg, on) {
  cfg$gms$s15_exo_diet                 <- if (on) 3 else 0
  cfg$gms$c15_kcal_scen                <- "healthy_BMI"
  cfg$gms$s15_exo_foodscen_start       <- 2025
  cfg$gms$s15_exo_foodscen_target      <- 2050
  cfg$gms$s15_exo_foodscen_convergence <- 1
  cfg
}

cells <- strsplit(Sys.getenv("L4PILOT_CELLS", "M1D0,M0D1,M1D1"), ",")[[1]]
stopifnot(all(grepl("^M[01]D[01]$", cells)))
dryrun <- Sys.getenv("L4PILOT_DRYRUN", "0") == "1"

folders <- c()
for (cell in cells) {
  cfg <- base
  cfg <- set_mitigation(cfg, on = substr(cell, 2, 2) == "1")
  cfg <- set_diet(cfg, on = substr(cell, 4, 4) == "1")
  cfg$title <- paste0(titlePrefix, cell)
  if (dryrun) {
    out <- file.path(Sys.getenv("L4PILOT_DRYRUN_DIR", "."), paste0("l4pilot_dryrun_config_", cell, ".yml"))
    # strip repository credentials before writing, as start_run does for the run's config.yml
    cfg$repositories <- setNames(vector("list", length(cfg$repositories)), names(cfg$repositories))
    gms::saveConfig(cfg, out)
    cat(sprintf("DRY RUN: resolved config for cell %s written to %s\n", cell, out))
    next
  }
  if (cell == "M0D0") stop("M0D0 is the existing gate run SSP2base_L4gate_ON_2026-09-19_14.25.45; dry-run only for this cell")
  cat(sprintf("\n===== Starting: %s =====\n", cfg$title))
  folders <- c(folders, start_run(cfg, codeCheck = FALSE))
}
if (!dryrun) {
  cat(sprintf("\n========== %d L4 PILOT RUN(S) LAUNCHED ==========\n", length(folders)))
  for (f in folders) cat(sprintf("  %s\n", f))
}
