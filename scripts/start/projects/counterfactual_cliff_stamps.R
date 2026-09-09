# |  Counterfactual A/B on the four calibration-cliff-test stamps (s35_natveg_harvest_shr, natveg timber harvest costs).
# |  Both arms take the 07-01 SSP2base_bodirsky_ON config (levers, prices, input revision, July edge settings) overlaid on
# |  the current default.cfg (switches added since July keep their current defaults in both arms) and run
# |  on THIS branch's code, so the only difference between them is the four values:
# |    stamp005 : the values every 07-01 run carried (shr 0.05; costs 4920/6150/7380)
# |    shr1     : the upstream defaults restored on this branch (shr 1; costs 2460/3075/3690)
# |  The 07-01 run itself differs from arm stamp005 only by the fork commits since 2026-07-01 (haircut split etc.).
# |  Usage: cd libraries/magpie && Rscript scripts/start/projects/counterfactual_cliff_stamps.R
# |         on the PC (no scheduler): MAGPIE_SEQUENTIAL=TRUE caffeinate -dimsu Rscript scripts/start/projects/counterfactual_cliff_stamps.R
# |  Afterwards: git checkout -- modules/35_natveg/pot_forest_may24/input.gms   (start_run stamps the last arm's values;
# |  since 8f7f15184 config/default.cfg registers the four switches, so any later run re-stamps the upstream values anyway)

source("scripts/start_functions.R")

source("config/default.cfg")            # the CURRENT schema (check_config refuses a cfg with missing keys)
src <- Sys.glob("output/SSP2base_bodirsky_ON_2026-07-01_*")
stopifnot(length(src) == 1)
july <- gms::loadConfig(file.path(src, "config.yml"))
# Overlay every July value onto the current defaults: levers, prices, edge settings and the input revision are the
# July ones; switches that did not exist in July (s32_edge_haircut, s35_edge_depth/_forestry_buffer/_agb_only/_gate)
# keep their current default.cfg values, identically in both arms. July keys the current schema no longer knows are
# dropped with a message.
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
base$sequential     <- Sys.getenv("MAGPIE_SEQUENTIAL", "FALSE") == "TRUE"   # TRUE on a machine without a scheduler (PC): runs block one after the other
base$output         <- c("output_check", "rds_report")

arms <- list(
  stamp005 = list(s35_natveg_harvest_shr = 0.05, s35_timber_harvest_cost_secdforest = 4920,
                  s35_timber_harvest_cost_other = 6150, s35_timber_harvest_cost_primforest = 7380),
  shr1     = list(s35_natveg_harvest_shr = 1,    s35_timber_harvest_cost_secdforest = 2460,
                  s35_timber_harvest_cost_other = 3075, s35_timber_harvest_cost_primforest = 3690))

folders <- c()
for (a in names(arms)) {
  cfg <- base
  for (k in names(arms[[a]])) cfg$gms[[k]] <- arms[[a]][[k]]
  cfg$title <- paste0("SSP2base_", a, "_bodirsky_ON")
  cat(sprintf("\n===== Starting: %s =====\n", cfg$title))
  folders <- c(folders, start_run(cfg, codeCheck = FALSE))
}
cat("\n========== 2 COUNTERFACTUAL RUNS LAUNCHED ==========\n")
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nCompare: Emissions|CO2|Land|Land-use Change|+|Deforestation, |+|Other land conversion, |+|Wood Harvest,\n")
cat("Resources|Land Cover|Forest|+|Natural Forest and the edge lines, 2015-2050, arm shr1 vs stamp005 vs the 07-01 run.\n")
