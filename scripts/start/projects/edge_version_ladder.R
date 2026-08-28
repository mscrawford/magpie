# |  Edge model-version ladder: one-lever-at-a-time attribution runs (2026-08-28).
# |  Plan: ~/.claude/plans/hi-please-update-the-resilient-snowglobe.md (Parts 1-2); report in
# |  <fragmentation>/audit/edge_version_ladder/.
# |
# |  Rungs (switch values; a 0 executes the ORIGINAL statements verbatim, so L0b must equal L0a):
# |    L0a  s32_edge_haircut 0                        (pre-2.1 code)  -> merge regression vs the
# |                                                    2026-07-01 canonical SSP2base ON run
# |    L0b  haircut 0, agb_only 0, gate 0            (final code)     -> must equal L0a
# |    L1   haircut 1, agb_only 0, gate 0            -> the 2026-08-21 forestry-haircut split alone
# |    L2   haircut 1, agb_only 1, gate 0            -> + aboveground-only edge factor (item A / M7)
# |    L3   haircut 1, agb_only 1, gate 1            -> + forest-weighted tropical gate (M6);
# |                                                    candidate new canonical
# |    OFF  s35_edge_carbon 0                        (final code)     -> must equal the 07-01 OFF run
# |  Scenarios: SSP2base (canonical source of truth, RCP4.5 NPi) and SSP1mitig (PkBudg650 price +
# |  2nd-gen bioenergy at RCP2.6; the sign-fragile edge sink).
# |
# |  Lever + edge functions are copied VERBATIM from scenario_suite_emissions_fragmentation.R (the
# |  2026-07-01 suite), so a rung differs from the canonical run ONLY in the listed switches.
# |  Titles <tag>_<rung>_bodirsky_<ON|OFF>: the underscore before the rung keeps ladder runs OUT of
# |  the canonical run_pattern ^([A-Za-z0-9]+)_bodirsky_ (config.R), while `_bodirsky_` keeps the
# |  anchored find_latest grammar intact.
# |
# |  Every gms override is checked against the module input.gms scalars BEFORE launch: an unknown
# |  setting is a SILENT no-op in manipulateConfig (the run looks healthy with the lever missing).
# |  After the run, confirm in <run>/full.gms that each scalar carries the intended value.
# |
# |  Usage (from the magpie root, renv active):
# |    LADDER_RUNGS=L0a LADDER_SCEN=SSP2base Rscript scripts/start/projects/edge_version_ladder.R
# |    LADDER_RUNGS=L0b,L1,L2,L3 LADDER_SCEN=SSP2base,SSP1mitig Rscript ...
# |    LADDER_DRYRUN=1 ...   prints each run's wired config and exits without submitting.

source("scripts/start_functions.R")
source("config/default.cfg")

cfg$gms$c_timesteps <- "coup2100"
cfg$output          <- c("output_check", "rds_report")
cfg$force_download  <- FALSE
cfg$recalc_npi_ndc  <- FALSE
cfg$sequential      <- FALSE  # parallel GAMS solves (one SLURM job per run)

# Per-RCP LPJmL cellular inputs live in the local madrat pool (as in the suite launcher).
cfg$repositories <- append(cfg$repositories,
                           list("file:///p/projects/rd3mod/inputdata/output_1.27" = NULL))

DRYRUN <- identical(Sys.getenv("LADDER_DRYRUN"), "1")
RUNGS  <- strsplit(Sys.getenv("LADDER_RUNGS", "L0a"), ",")[[1]]
SCENS  <- strsplit(Sys.getenv("LADDER_SCEN",  "SSP2base"), ",")[[1]]

# ---------------------------------------------------------------------------
# VERBATIM from scenario_suite_emissions_fragmentation.R (2026-07-01) --------
labor_rcp <- function(rcp) if (rcp %in% c("rcp6p0", "rcp7p0", "rcp8p5")) "rcp585" else "rcp119"

set_ssp_base <- function(cfg, ssp, rcp) {
  cfg <- gms::setScenario(cfg, c(ssp, "NPI", rcp))
  cfg$gms$c37_labor_rcp <- labor_rcp(rcp)   # setScenario does NOT set this; bracket manually
  price <- paste0("R34M410-", ssp, "-NPi2025")
  cfg$gms$c56_pollutant_prices          <- price
  cfg$gms$c56_pollutant_prices_noselect <- price
  cfg$gms$c60_2ndgen_biodem             <- price
  cfg$gms$c60_2ndgen_biodem_noselect    <- price
  cfg$gms$c22_protect_scenario          <- "none"
  cfg$gms$c22_protect_scenario_noselect <- "none"
  cfg$gms$s15_exo_diet                  <- 0
  cfg
}
set_price_high <- function(cfg, ssp, budget) {
  price <- paste0("R34M410-", ssp, "-", budget)
  cfg$gms$c56_pollutant_prices          <- price
  cfg$gms$c56_pollutant_prices_noselect <- price
  cfg
}
set_bioenergy_high <- function(cfg, ssp, budget) {
  bioe <- paste0("R34M410-", ssp, "-", budget)
  cfg$gms$c60_2ndgen_biodem          <- bioe
  cfg$gms$c60_2ndgen_biodem_noselect <- bioe
  cfg
}
set_edge_off <- function(cfg) { cfg$gms$s35_edge_carbon <- 0; cfg }
set_edge_on <- function(cfg) {
  cfg$gms$s35_edge_carbon  <- 1
  cfg$gms$s35_edge_formula <- 1      # exponential decay
  cfg$gms$s35_edge_lambda  <- 0.059  # ~59 m penetration depth (default)
  cfg$gms$s35_edge_degrad  <- 0.50
  cfg$gms$s35_edge_beta    <- 0.8286
  cfg$gms$s35_edge_n       <- 0.7984
  cfg
}
build_policy <- function(cfg, p) {
  cfg <- set_ssp_base(cfg, p$ssp, p$rcp)
  if (isTRUE(p$price_high)) cfg <- set_price_high(cfg, p$ssp, p$budget)
  if (isTRUE(p$bioe_high))  cfg <- set_bioenergy_high(cfg, p$ssp, p$budget)
  cfg
}
# END verbatim block -----------------------------------------------------------

policies <- list(
  SSP2base  = list(tag = "SSP2base",  ssp = "SSP2", rcp = "rcp4p5"),
  SSP1mitig = list(tag = "SSP1mitig", ssp = "SSP1", rcp = "rcp2p6", budget = "PkBudg650",
                   price_high = TRUE, bioe_high = TRUE)
)

rungs <- list(
  L0a = list(edge = "ON",  gms = list(s32_edge_haircut = 0)),
  L0b = list(edge = "ON",  gms = list(s32_edge_haircut = 0, s35_edge_agb_only = 0, s35_edge_gate = 0)),
  L1  = list(edge = "ON",  gms = list(s32_edge_haircut = 1, s35_edge_agb_only = 0, s35_edge_gate = 0)),
  L2  = list(edge = "ON",  gms = list(s32_edge_haircut = 1, s35_edge_agb_only = 1, s35_edge_gate = 0)),
  L3  = list(edge = "ON",  gms = list(s32_edge_haircut = 1, s35_edge_agb_only = 1, s35_edge_gate = 1)),
  OFF = list(edge = "OFF", gms = list())
)

unknown <- setdiff(RUNGS, names(rungs)); if (length(unknown)) stop("unknown rung(s): ", paste(unknown, collapse = ","))
unknown <- setdiff(SCENS, names(policies)); if (length(unknown)) stop("unknown scenario(s): ", paste(unknown, collapse = ","))

# --- guard: every override must be a declared scalar in some module input.gms -----------------
input_gms <- list.files("modules", pattern = "^input\\.gms$", recursive = TRUE, full.names = TRUE)
declared  <- unlist(lapply(input_gms, readLines, warn = FALSE))
for (r in RUNGS) for (nm in names(rungs[[r]]$gms)) {
  if (!any(grepl(paste0("^\\s*", nm, "\\s"), declared)))
    stop(sprintf("rung %s: switch '%s' is NOT declared in any modules/*/*/input.gms - would be a silent no-op", r, nm))
}

# ---------------------------------------------------------------------------
folders <- c(); n <- 0L
launch <- function(cfg_i, title) {
  cfg_i$title <- title; n <<- n + 1L
  if (DRYRUN) {
    sw <- cfg_i$gms[intersect(names(cfg_i$gms), c("s35_edge_carbon", "s35_edge_lambda", "s32_edge_haircut",
                                                    "s35_edge_agb_only", "s35_edge_gate"))]
    cat(sprintf("[dry] %-30s cellular=%-56s c52=%-6s c37=%-7s c56=%-24s c60=%-24s\n      switches: %s\n",
                title, basename(cfg_i$input[["cellular"]]),
                cfg_i$gms$c52_land_carbon_sink_rcp, cfg_i$gms$c37_labor_rcp,
                cfg_i$gms$c56_pollutant_prices, cfg_i$gms$c60_2ndgen_biodem,
                paste(names(sw), unlist(sw), sep = "=", collapse = "  ")))
    return(invisible(NULL))
  }
  cat(sprintf("\n===== %s (%d) =====\n", title, n))
  folders <<- c(folders, start_run(cfg_i, codeCheck = FALSE))
}

for (s in SCENS) for (r in RUNGS) {
  p <- policies[[s]]; rg <- rungs[[r]]
  cfg_i <- build_policy(cfg, p)
  cfg_i <- if (rg$edge == "ON") set_edge_on(cfg_i) else set_edge_off(cfg_i)
  for (nm in names(rg$gms)) cfg_i$gms[[nm]] <- rg$gms[[nm]]
  launch(cfg_i, paste0(p$tag, "_", r, "_bodirsky_", rg$edge))
}

if (DRYRUN) { cat(sprintf("\n[dry] %d configs built, none submitted.\n", n)); quit(save = "no") }
cat(sprintf("\n========== %d LADDER RUN(S) LAUNCHED ==========\n", length(folders)))
for (f in folders) cat(sprintf("  %s\n", f))
cat("\nVerify the switches reached GAMS:  grep -n 's32_edge_haircut\\|s35_edge_agb_only\\|s35_edge_gate' <run>/full.gms\n")
