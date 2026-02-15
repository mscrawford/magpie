# |  Edge-effect carbon degradation test runs
# |  Runs historical+near-future with/without edge effects

# ------------------------------------------------
# description: Test edge-effect carbon degradation (baseline OFF vs ON)
# position: 10
# ------------------------------------------------

source("scripts/start_functions.R")
source("config/default.cfg")

# Common config: short timesteps for testing
cfg$gms$c_timesteps <- "quicktest"

# --- Run 1: Baseline (edge effects OFF) ---
cfg$title <- "edge_test_OFF"
cfg$gms$s35_edge_carbon <- 0
start_run(cfg, codeCheck = FALSE)

# --- Run 2: Edge effects ON ---
cfg$title <- "edge_test_ON"
cfg$gms$s35_edge_carbon <- 1
start_run(cfg, codeCheck = FALSE)
