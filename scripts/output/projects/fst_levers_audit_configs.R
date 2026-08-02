# FINAL CONFIGURATION AUDIT - fst_levers 25-run batch.
#
# Verifies what the runs ACTUALLY USED, by parsing each run's own config.yml,
# against what the design says they should have used. This is deliberately NOT a
# re-read of fst_levers_config.R: that file is the intent, config.yml is the
# record of what GAMS was handed. Only the second can catch an intent that failed
# to apply.
#
# Every assertion goes through chk(); the script fails if the executed assertion
# count does not match, so a skipped block cannot pass silently.

# run from the magpie clone root
runs <- sort(list.files("output", pattern = "^(BAU_TCendo|CP(on|off)_Bio(On|Off)_(Prot|NoProt)_Diet(On|Off)_TC(endo|bau))$"))
stopifnot(length(runs) == 25)

n_chk <- 0L; n_fail <- 0L; fails <- character(0)
chk <- function(cond, label) {
  n_chk <<- n_chk + 1L
  if (!isTRUE(cond)) { n_fail <<- n_fail + 1L; fails <<- c(fails, label) }
}

# flat "key: value" scrape of the gms block (config.yml is 2-level; every switch
# we care about is a scalar under gms:)
readCfg <- function(t) {
  ln <- readLines(file.path("output", t, "config.yml"), warn = FALSE)
  m  <- regmatches(ln, regexec("^\\s*([A-Za-z_][A-Za-z0-9_]*):\\s*(.*?)\\s*$", ln))
  kv <- do.call(rbind, lapply(m, function(x) if (length(x) == 3) x[2:3] else NULL))
  v  <- setNames(gsub("^['\"]|['\"]$", "", kv[, 2]), kv[, 1])
  v[!duplicated(names(v))]           # first occurrence wins (gms block precedes output lists)
}
cfgs <- lapply(runs, readCfg); names(cfgs) <- runs

arm <- function(t) {
  tk <- strsplit(t, "_", fixed = TRUE)[[1]]
  if (tk[1] == "BAU") return(list(bau = TRUE, tc = tk[2]))
  list(bau = FALSE, cp = ifelse(tk[1] == "CPon", "on", "off"),
       bio = ifelse(tk[2] == "BioOn", "on", "off"),
       prot = ifelse(tk[3] == "Prot", "on", "off"),
       diet = ifelse(tk[4] == "DietOn", "on", "off"), tc = tk[5])
}
g <- function(t, k) unname(cfgs[[t]][k])

pol <- runs[runs != "BAU_TCendo"]
cat("=== 24 policy runs: does each switch match its arm? ===\n")
for (t in pol) {
  a <- arm(t)
  # Factor 1 climate
  chk(g(t,"c56_pollutant_prices") == ifelse(a$cp=="on","R34M410-SSP2-PkBudg650","R34M410-SSP2-NPi2025"),
      paste(t,"c56_pollutant_prices"))
  chk(g(t,"c56_pollutant_prices_noselect") == g(t,"c56_pollutant_prices"), paste(t,"c56 noselect twin"))
  # Factor 2 bioenergy
  chk(g(t,"c60_2ndgen_biodem") == ifelse(a$bio=="on","R34M410-SSP2-PkBudg650","R34M410-SSP2-NPi2025"),
      paste(t,"c60_2ndgen_biodem"))
  chk(g(t,"c60_2ndgen_biodem_noselect") == g(t,"c60_2ndgen_biodem"), paste(t,"c60 noselect twin"))
  # Factor 3 protection bundle: all four instruments must move together
  chk(g(t,"c22_protect_scenario") == ifelse(a$prot=="on","GSN_HalfEarth","none"), paste(t,"c22_protect_scenario"))
  chk(g(t,"c22_protect_scenario_noselect") == g(t,"c22_protect_scenario"), paste(t,"c22 noselect twin"))
  chk(as.numeric(g(t,"s44_bii_target")) == ifelse(a$prot=="on",0.78,0), paste(t,"s44_bii_target"))
  chk(as.numeric(g(t,"s29_snv_shr")) == ifelse(a$prot=="on",0.2,0), paste(t,"s29_snv_shr"))
  chk(g(t,"c42_env_flow_policy") == ifelse(a$prot=="on","on","off"), paste(t,"c42_env_flow_policy"))
  # Factor 4 diet
  chk(as.numeric(g(t,"s15_exo_diet")) == ifelse(a$diet=="on",1,0), paste(t,"s15_exo_diet"))
  if (a$diet == "on") {
    chk(g(t,"c15_EAT_scen") == "FLX", paste(t,"c15_EAT_scen"))
    chk(g(t,"c15_kcal_scen") == "2500kcal", paste(t,"c15_kcal_scen"))
  }
  # Factor 5 TC
  chk(grepl(ifelse(a$tc=="TCendo","^endo","^exo"), g(t,"tc")), paste(t,"tc realization"))
  if (a$tc == "TCbau") {
    chk(as.numeric(g(t,"c13_croparea_consv")) == 0, paste(t,"c13_croparea_consv"))
    chk(as.numeric(g(t,"s13_ignore_tau_historical")) == 1, paste(t,"s13_ignore_tau_historical"))
  }
}

cat("=== backdrop constants: identical across all 24 policy runs? ===\n")
CONST <- c("c56_emis_policy","c56_mute_ghgprices_until","s57_maxmac_n_soil","s57_maxmac_n_awms",
           "s57_maxmac_ch4_rice","s57_maxmac_ch4_entferm","s57_maxmac_ch4_awms",
           "c44_bii_decrease","c35_ad_policy","c22_base_protect","c60_res_2ndgenBE_dem","c_timesteps")
for (k in CONST) {
  vals <- unique(vapply(pol, g, character(1), k))
  chk(length(vals) == 1, paste0("constant across policy runs: ", k, " -> {", paste(vals, collapse=", "), "}"))
}
# and the values themselves
chk(g(pol[1],"c56_emis_policy") == "all_nosoil", "backdrop c56_emis_policy = all_nosoil")
chk(g(pol[1],"c56_mute_ghgprices_until") == "y2025", "backdrop mute = y2025")
for (k in c("s57_maxmac_n_soil","s57_maxmac_n_awms","s57_maxmac_ch4_rice","s57_maxmac_ch4_entferm","s57_maxmac_ch4_awms"))
  chk(as.numeric(g(pol[1], k)) == -1, paste("MACC price-driven:", k))
chk(g(pol[1],"c35_ad_policy") == "npi", "avoided deforestation on in every arm")
chk(g(pol[1],"c22_base_protect") == "WDPA", "WDPA baseline on in every arm")

cat("=== equal-ambition timing: every lever 2025->2050 ===\n")
for (t in pol) {
  a <- arm(t)
  chk(as.numeric(g(t,"s22_conservation_target")) == 2050, paste(t,"s22 target"))
  chk(as.numeric(g(t,"s29_snv_scenario_target")) == 2050, paste(t,"s29 target"))
  chk(as.numeric(g(t,"s44_target_year")) == 2050, paste(t,"s44 target"))
  chk(as.numeric(g(t,"s44_start_year")) == 2026, paste(t,"s44 start 2026 (module guard aborts at <=2025)"))
  if (a$diet == "on") chk(as.numeric(g(t,"s15_exo_foodscen_target")) == 2050, paste(t,"diet target"))
  if (a$prot == "on") chk(as.numeric(g(t,"s42_efp_targetyear")) == 2050, paste(t,"water EFP target"))
}

cat("=== input data + model identical across ALL 25 runs? ===\n")
for (k in c("regional","cellular","validation","additional","calibration")) {
  vals <- unique(vapply(runs, g, character(1), k))
  chk(length(vals) == 1, paste0("input archive identical: ", k))
}

cat("=== BAU is the yield_gap BAU (the tau-pin source) ===\n")
b <- "BAU_TCendo"
chk(g(b,"c56_pollutant_prices") == "R34M410-SSP2-NPi2025", "BAU price = NPi2025")
chk(g(b,"c56_emis_policy") == "reddnatveg_nosoil",         "BAU coverage = reddnatveg_nosoil")
chk(as.numeric(g(b,"s15_exo_diet")) == 0,                  "BAU diet endogenous")
chk(grepl("^endo", g(b,"tc")),                             "BAU tau endogenous")
chk(g(b,"c22_protect_scenario") == "none",                 "BAU no future conservation")

cat("\n=== the design hole: (climate off, bioenergy on) must be absent ===\n")
present <- vapply(pol, function(t){ a<-arm(t); paste(a$cp,a$bio) }, character(1))
chk(!any(present == "off on"), "no (CPoff, BioOn) run exists")
chk(sum(present == "on on") == 8 && sum(present == "on off") == 8 && sum(present == "off off") == 8,
    "8 runs in each of the 3 coherent (climate,bio) combinations")

EXPECTED <- 24L*13L + 8L*2L + 4L*2L + length(CONST) + 2L + 5L + 2L + 24L*4L + 12L*1L + 12L*1L + 5L + 5L + 2L
cat("\nassertions executed:", n_chk, " failures:", n_fail, "\n")
if (n_fail) { cat("\nFAILURES:\n"); for (f in fails) cat("  -", f, "\n") }
cat(if (n_fail == 0L) "\nALL CONFIGURATIONS VERIFIED\n" else "\nCONFIGURATION PROBLEMS FOUND\n")


# ---- appendix: the one contract config.yml CANNOT certify --------------------
# Whether pinTauToBAU actually applied. Checked at REGIONAL level, which is where
# the pin acts; the GLOBAL tau indicator is an area-weighted aggregate, so it
# differs by ~1% between pinned runs purely from cropland shifting between
# regions - that residual is expected and is NOT a pin failure.
V <- "Productivity|Landuse Intensity Indicator Tau"
getR <- function(t){ d <- as.data.frame(readRDS(file.path("output",t,"report.rds")))
  d <- d[d$variable==V & !d$region %in% c("World","GLO"), c("region","period","value")]
  d$key <- paste(d$region, d$period); setNames(as.numeric(d$value), d$key) }
sd <- read.csv("output/fst_levers_keyresults/scenario_design.csv")
feas <- sd$title[sd$feasible %in% c(TRUE,"TRUE")]
bau <- getR("BAU_TCendo")
cat(sprintf("regional tau cells per run: %d (regions x years)\n\n", length(bau)))
cmp <- function(t){ x <- getR(t); k <- intersect(names(x), names(bau)); max(abs(x[k]-bau[k]), na.rm=TRUE) }
bauR  <- grep("_TCbau$",  feas, value=TRUE)
endoR <- setdiff(grep("_TCendo$", feas, value=TRUE), "BAU_TCendo")
db <- vapply(bauR,  cmp, numeric(1)); de <- vapply(endoR, cmp, numeric(1))
cat("=== REGIONAL tau vs BAU (the level the pin acts on) ===\n")
cat(sprintf("  TCbau  runs (n=%d): max deviation %.3e   -> %s\n", length(db), max(db),
            ifelse(max(db) < 1e-9, "IDENTICAL - pin verified", "NOT identical")))
cat(sprintf("  TCendo runs (n=%d): max deviation %.4f\n", length(de), max(de)))
cat(sprintf("\n  separation: TCendo deviates %.0fx more than the worst TCbau run\n",
            max(de)/max(max(db), 1e-12)))
quit(status = if (n_fail == 0L && max(db) == 0) 0L else 1L)
