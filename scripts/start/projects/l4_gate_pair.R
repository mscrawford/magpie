# |  L4 gate pair (COMMITTED_STOCK_ACCOUNTING.md section 6, test 1 and 2): SSP2base edge ON and edge OFF on the L4 code.
# |  Both arms take the 07-01 SSP2base_bodirsky_ON config (levers, prices, input revision, July edge settings) overlaid on
# |  the current default.cfg - exactly the construction of the L3 reference run SSP2base_shr1_bodirsky_ON_2026-09-09
# |  (counterfactual_cliff_stamps.R, arm shr1; the four natveg switches are default.cfg values since 8f7f15184) - so the
# |  ON arm differs from the reference in NOTHING but the code (L4 exports + the two new tau switches at 0) and the title.
# |    ON  : s35_edge_carbon = 1, s32_edge_haircut = 1   (R0a inertness vs the L3 reference; the L4 exports)
# |    OFF : s35_edge_carbon = 0, s32_edge_haircut = 0   (the twin for the stock identity, spec test 2)
# |  Usage (PC, no scheduler; sequential): cd libraries/magpie && MAGPIE_SEQUENTIAL=TRUE caffeinate -dimsu Rscript scripts/start/projects/l4_gate_pair.R
# |  Dry run (write the resolved configs, start nothing): L4GATE_DRYRUN=1 Rscript scripts/start/projects/l4_gate_pair.R
# |  Arms: L4GATE_ARMS=ON,OFF (default both, ON first).
# |  Source run and title: L4GATE_SRC=<glob> L4GATE_TITLE=<prefix> (2026-09-19: the SSP1all priced pair for the aff export path).
# |  Afterwards: git checkout -- modules/35_natveg/pot_forest_may24/input.gms modules/32_forestry/dynamic_may24/input.gms
# |  (start_run stamps the last arm's switch values; default.cfg re-stamps them on any later run anyway).

source("scripts/start_functions.R")

source("config/default.cfg")            # the CURRENT schema (check_config refuses a cfg with missing keys)
# L4GATE_SRC: glob of the July run whose config is overlaid (default the SSP2base gate reference; e.g. "output/SSP1all_bodirsky_ON_2026-07-01_*"
# for the priced arm with natural-curve afforestation, the aff export path). L4GATE_TITLE: run-title prefix.
src <- Sys.glob(Sys.getenv("L4GATE_SRC", "output/SSP2base_bodirsky_ON_2026-07-01_*"))
stopifnot(length(src) == 1)
titlePrefix <- Sys.getenv("L4GATE_TITLE", "SSP2base_L4gate_")
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

arms <- list(
  ON  = list(s35_edge_carbon = 1, s32_edge_haircut = 1),
  OFF = list(s35_edge_carbon = 0, s32_edge_haircut = 0))
wanted <- strsplit(Sys.getenv("L4GATE_ARMS", "ON,OFF"), ",")[[1]]
stopifnot(all(wanted %in% names(arms)))
dryrun <- Sys.getenv("L4GATE_DRYRUN", "0") == "1"

folders <- c()
for (a in wanted) {
  cfg <- base
  for (k in names(arms[[a]])) cfg$gms[[k]] <- arms[[a]][[k]]
  cfg$title <- paste0(titlePrefix, a)
  if (dryrun) {
    out <- file.path(Sys.getenv("L4GATE_DRYRUN_DIR", "."), paste0("l4gate_dryrun_config_", a, ".yml"))
    # strip repository credentials before writing, as start_run does for the run's config.yml
    cfg$repositories <- setNames(vector("list", length(cfg$repositories)), names(cfg$repositories))
    gms::saveConfig(cfg, out)
    cat(sprintf("DRY RUN: resolved config for arm %s written to %s\n", a, out))
    next
  }
  cat(sprintf("\n===== Starting: %s =====\n", cfg$title))
  folders <- c(folders, start_run(cfg, codeCheck = FALSE))
}
if (!dryrun) {
  cat(sprintf("\n========== %d L4 GATE RUN(S) LAUNCHED ==========\n", length(folders)))
  for (f in folders) cat(sprintf("  %s\n", f))
  cat("\nGate: Rscript <frag>/audit/edge_version_ladder/09_l4_gate.R <L3 reference run dir> <ON run dir> [<OFF run dir>]\n")
}
