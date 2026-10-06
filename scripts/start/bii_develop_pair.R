# Plain-develop twin of the BII floor pair (Mike, 2026-10-06: "run one base and one floor on the develop").
# UNMODIFIED develop 47249fdc2, default.cfg, with the SCENARIO settings of the fragmentation suite's SSP1 base cell
# (SSP1M0P0D0, dry-run dump of 2026-10-05) for every key develop knows, and nothing of the fork: no edge module, no
# Sims shifting-cultivation patch, shifting cultivation at develop's default (s35_forest_damage 2, fades to 2050).
# Two runs that differ in s44_bii_target only (0 against 0.78; start 2030, target year 2050, decrease allowed).
# Record: dev_fragmentation L4_BUILD 18.21. Launch from this worktree: Rscript scripts/start/bii_develop_pair.R
source("scripts/start_functions.R")
source("config/default.cfg")
suite <- list(
  c09_gdp_scenario = "SSP1",
  c09_pal_scenario = "SSP1",
  c09_pop_scenario = "SSP1",
  c15_food_scenario = "SSP1",
  c21_trade_liberalization = "l908080r807070",
  c34_urban_scenario = "SSP1",
  c50_scen_neff = "baseeff_add3_add10_add20_max75",
  c52_land_carbon_sink_rcp = "RCP26",
  c55_scen_conf = "ssp1",
  c56_emis_policy = "all_nosoil",
  c56_mute_ghgprices_until = "y2025",
  c56_pollutant_prices = "R34M410-SSP1-NPi2025",
  c56_pollutant_prices_noselect = "R34M410-SSP1-NPi2025",
  c60_1stgen_biodem = "phaseout2020",
  c60_2ndgen_biodem = "R34M410-SSP1-NPi2025",
  c60_2ndgen_biodem_noselect = "R34M410-SSP1-NPi2025",
  c60_res_2ndgenBE_dem = "ssp1",
  c70_feed_scen = "ssp1",
  s21_flexBand_lib_factor = 2,
  s21_import_supply_scenario = 0.5,
  s42_efp_targetyear = 2050,
  s42_watdem_nonagr_scenario = 1,
  s44_target_year = 2050)
stopifnot(all(names(suite) %in% names(cfg$gms)), cfg$gms$s35_forest_damage == 2, cfg$gms$biodiversity == "bii_target",
          cfg$gms$s44_start_year == 2030, cfg$gms$c44_bii_decrease == 1, cfg$gms$s44_cost_bii_missing == 1e6)
for (k in names(suite)) cfg$gms[[k]] <- suite[[k]]
cfg$input[["cellular"]] <- "rev4.136_h12_6819938d_cellularmagpie_c200_MRI-ESM2-0-ssp126_lpjml-8e6c5eb1.tgz"
stopifnot(identical(unname(cfg$input[c("regional", "additional", "calibration")]),
                    c("rev4.136_h12_magpie.tgz", "additional_data_rev4.74.tgz", "calibration_H12_FAO_30Sep26.tgz")), length(cfg$input) == 5)
# local repositories first (compute nodes have no internet); the same order as the develop control of 2026-10-05
local <- c("/p/projects/rd3mod/inputdata/output", "/p/projects/rd3mod/inputdata/output_1.27",
           "/p/projects/landuse/data/input/archive", "/p/projects/landuse/data/input/calibration")
cfg$repositories <- c(setNames(rep(list(NULL), length(local)), local), cfg$repositories[setdiff(names(cfg$repositories), local)])
for (f in cfg$input) stopifnot(any(file.exists(file.path(local, f))))
cfg$output         <- character(0)       # read out from the gdx afterwards
cfg$recalc_npi_ndc <- "ifneeded"
cfg$sequential     <- FALSE
cfg$force_download <- FALSE
cat("== bii_develop_pair @", system("git rev-parse --short HEAD", intern = TRUE), "| tracked changes:", length(system("git status --short --untracked-files=no", intern = TRUE)), "==\n")
only <- trimws(strsplit(Sys.getenv("PAIR_ONLY"), ",")[[1]])
# base and floor ran at plain develop 47249fdc2 (detached). The two cells added the same day run from the branch
# experiment/bii-area-weight = develop + ONE commit: a weight in q44_cost behind s44_bii_area_weight (default 0 = develop).
#   ...areaW      the floor of the second cell with the penalty weighted by the area of each region-biome (weights average one)
#   ...noNetLoss  the floor as paper_healthyLscps.R (P. v. Jeetze) sets it: c44_bii_decrease 0 from 2030, no target value
cells <- list(list(title = "devBII_SSP1base",                target = 0,    decrease = 1, areaw = 0),
              list(title = "devBII_SSP1floor078by2050",      target = 0.78, decrease = 1, areaw = 0),
              list(title = "devBII_SSP1floor078by2050areaW", target = 0.78, decrease = 1, areaw = 1),
              list(title = "devBII_SSP1noNetLoss2030",       target = 0,    decrease = 0, areaw = 0))
titles <- vapply(cells, function(x) x$title, "")
stopifnot(all(only %in% titles))
for (cell in cells) {
  if (length(only) && !cell$title %in% only) next
  cfg_i <- cfg
  cfg_i$title <- cell$title
  cfg_i$gms$s44_bii_target   <- cell$target
  cfg_i$gms$c44_bii_decrease <- cell$decrease
  if (cell$areaw == 1) { stopifnot("s44_bii_area_weight" %in% names(cfg$gms)); cfg_i$gms$s44_bii_area_weight <- 1 }
  stopifnot(cfg_i$gms$s44_target_year == 2050, cfg_i$gms$s44_start_year == 2030)
  cat(sprintf("===== %s: s44_bii_target %s, start %s, target year %s, decrease %s, area weight %s | cellular %s =====\n", cell$title, cfg_i$gms$s44_bii_target,
              cfg_i$gms$s44_start_year, cfg_i$gms$s44_target_year, cfg_i$gms$c44_bii_decrease, cell$areaw, cfg_i$input[["cellular"]]))
  if (nzchar(Sys.getenv("PAIR_DRYRUN"))) next
  start_run(cfg_i, codeCheck = FALSE)
}
