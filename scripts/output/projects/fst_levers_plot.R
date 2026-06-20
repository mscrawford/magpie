# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# fst_levers_plot.R  (2^4 design: protection x bioenergy x diet x TC)
#
# Postprocessing + plotting for the fst_levers experiment. Reads the 17 run
# folders + the orchestrator summary RDS, extracts 12 outcomes as GLO scalar
# series, and writes to output/fst_levers_plots/:
#
#   1. feasibility heatmap over all 17 runs (cube layout; BAU noted apart)
#   2. primary protection x bioenergy 2x2 at TCendo, split by diet
#   3a. TC-isolation slice:   dTC   = Y(TCendo) - Y(TCbau)   per (prot,bio,diet) cell
#   3b. diet-isolation slice: dDiet = Y(DietOn) - Y(DietOff) per (prot,bio,TC)   cell
#   4. full 2^4 reference-delta decomposition (ref = NoProtect_BioOff_DietOff_TCbau)
#      -> marginal_contributions.csv  (+ cube_cell_values.csv)
#   + per-outcome time series faceted by the cube.
#
# Decomposition algebra: scripts/output/projects/fst_levers_decompose.R
# (general 2^k, unit-tested in fst_levers_decompose_test.R before use here).
#
# Outcomes (yield_gap's 9 + 3 the new factors require): cropland, pasture, total
# forest, forestry area, LUCC CO2, total land CO2, N surplus, water withdrawal,
# BII, production, food price index, bioenergy crop area (kbe60).

suppressMessages({
  library(magpie4); library(magclass); library(gdx2)
  library(ggplot2); library(dplyr); library(tidyr)
})

source("scripts/output/projects/fst_levers_decompose.R")

OUT_DIR <- "output/fst_levers_plots"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
DECOMP_YEAR <- as.integer(Sys.getenv("FST_LEVERS_DECOMP_YEAR", "2100"))

# ---- discover runs ----------------------------------------------------------
summary_path <- "output/fst_levers_summary.rds"
if (!file.exists(summary_path))
  stop("Summary RDS not found at ", summary_path, "; run fst_levers.R first.")
summary_df <- readRDS(summary_path)
summary_df$gdx    <- file.path("output", summary_df$title, "fulldata.gdx")
summary_df$exists <- file.exists(summary_df$gdx)

isTRUE_vec <- function(x) vapply(x, isTRUE, logical(1))

summary_df$protection <- ifelse(grepl("^Protect",   summary_df$scenario), "Protect",
                         ifelse(grepl("^NoProtect", summary_df$scenario), "NoProtect", NA))
summary_df$bioenergy  <- ifelse(grepl("BioOn",  summary_df$scenario), "BioOn",
                         ifelse(grepl("BioOff", summary_df$scenario), "BioOff", NA))
summary_df$diet       <- ifelse(grepl("DietOn",  summary_df$scenario), "DietOn",
                         ifelse(grepl("DietOff", summary_df$scenario), "DietOff", NA))
summary_df$is_cube    <- !is.na(summary_df$protection) & !is.na(summary_df$bioenergy) &
                         !is.na(summary_df$diet)

message("Run inventory:")
print(summary_df[, c("title", "tc_state", "feasible", "exists")], row.names = FALSE)

CUBE_TITLES  <- allFactorCells()                      # 16 cube cell names (== run titles)
missing_cube <- setdiff(CUBE_TITLES,
                        summary_df$title[isTRUE_vec(summary_df$feasible) & summary_df$exists])
if (length(missing_cube) > 0)
  message("\nNOTE: cube corners missing / infeasible (effects using them will be NA):\n  ",
          paste(missing_cube, collapse = "\n  "))

# ---- scenario design table (for the deck) -----------------------------------
feasOf <- function(scen, tc) {
  f <- summary_df$feasible[summary_df$title == paste0(scen, "_", tc)]
  if (length(f) == 0) "-" else if (isTRUE(f)) "feasible" else if (is.na(f)) "unknown" else "INFEASIBLE"
}
fac <- function(scen, pat, on, off, none) if (grepl("^BAU", scen)) none else if (grepl(pat, scen)) on else off
cube_scen <- unique(sub("_TC(endo|bau)$", "", CUBE_TITLES))
design_df <- do.call(rbind, lapply(c("BAU", cube_scen), function(s) data.frame(
  scenario   = s,
  protection = fac(s, "^Protect", "30by30",              "none",       "none (NPi)"),
  bioenergy  = fac(s, "BioOn",    "1.5C PkBudg650",       "off",        "NPi baseline"),
  diet       = fac(s, "DietOn",   "EAT-Lancet FLX 2500",  "endogenous", "endogenous"),
  TCendo     = feasOf(s, "TCendo"),
  TCbau      = feasOf(s, "TCbau"),
  stringsAsFactors = FALSE)))
write.csv(design_df, file.path(OUT_DIR, "scenario_design.csv"), row.names = FALSE)
message("\nScenario design (constant backdrop on the 8 cells: PkBudg650 + BII 0.78 + N MACC max + water EFP):")
print(design_df, row.names = FALSE)

# ---- styling ----------------------------------------------------------------
protection_levels <- c("NoProtect", "Protect"); bioenergy_levels <- c("BioOff", "BioOn")
diet_levels       <- c("DietOff", "DietOn");     tc_levels        <- c("TCbau", "TCendo")
protection_labels <- c(NoProtect = "No protection", Protect = "30by30")
bioenergy_labels  <- c(BioOff = "No bioenergy",     BioOn = "1.5C bioenergy")
diet_labels       <- c(DietOff = "Endog. diet",     DietOn = "EAT-Lancet")

my_theme <- theme_bw(base_size = 11) +
  theme(panel.border = element_rect(fill = NA, color = "grey75", linewidth = 0.4),
        panel.grid.minor = element_blank(),
        panel.grid.major = element_line(color = "grey92", linewidth = 0.3),
        strip.background = element_rect(fill = "grey95", color = NA),
        strip.text = element_text(face = "bold", size = 9),
        plot.title = element_text(face = "bold", size = 12),
        plot.subtitle = element_text(color = "grey30", size = 9))

tc_colors <- c(TCbau = "#E69F00", TCendo = "#0072B2"); bau_color <- "grey45"
order_colors <- c("main" = "#0072B2", "two-way" = "#009E73",
                  "three-way" = "#D55E00", "four-way" = "#9D4EDD")

# ---- load outcomes from the precomputed per-run report.rds ------------------
# The model's postprocessing already wrote every reporting variable to each run's
# report.rds, so we read those (a ~4 MB quitte per run) instead of recomputing
# from the 600 MB gdx. Recomputing reportNitrogenPollution (grid-level) x 13 runs
# was ~45 min; this is seconds. Outcome label -> report variable name (the quitte
# 'variable' column carries NO unit suffix; units are a separate column):
# Boundary-led order: the RQ's four planetary boundaries first, then supporting indicators.
OUTCOME_VARS <- c(
  "N surplus (Mt Nr/yr)"       = "Resources|Nitrogen|Pollution|Surplus",              # Nitrogen boundary
  "Total land CO2 (Mt CO2/yr)" = "Emissions|CO2|Land",                                # Climate boundary
  "Cropland (Mha)"             = "Resources|Land Cover|+|Cropland",                    # Land boundary (system change)
  "Total forest (Mha)"         = "Resources|Land Cover|Forest|+|Natural Forest",       # Land boundary (forest cover)
  "BII"                        = "Biodiversity|BII",                                   # Biodiversity boundary
  "LUCC CO2 (Mt CO2/yr)"       = "Emissions|CO2|Land|+|Land-use Change",               # -- supporting indicators --
  "Pasture (Mha)"              = "Resources|Land Cover|+|Pastures and Rangelands",
  "Forestry area (Mha)"        = "Resources|Land Cover|Forest|+|Planted Forest",
  "Water withdrawal (km3/yr)"  = "Resources|Water|Withdrawal|Agriculture",
  "Production (Mt DM/yr)"      = "Production",
  "Food price index"           = "Prices|Food Expenditure Index",                     # consumer, index 2010=100
  "Bioenergy area (Mha)"       = "Resources|Land Cover|Cropland|Croparea|+|Bioenergy crops")

# Planetary-boundary grouping (the RQ's four boundaries; everything else = supporting).
BOUNDARY <- c("N surplus (Mt Nr/yr)" = "Nitrogen", "Total land CO2 (Mt CO2/yr)" = "Climate",
              "Cropland (Mha)" = "Land", "Total forest (Mha)" = "Land", "BII" = "Biodiversity")
# One representative outcome per boundary, for the 4-panel "answer" figure.
BOUNDARY_ANSWER <- c(Nitrogen = "N surplus (Mt Nr/yr)", Climate = "Total land CO2 (Mt CO2/yr)",
                     Land = "Cropland (Mha)", Biodiversity = "BII")
# Prefix the boundary in facet/axis labels for the 5 boundary outcomes; pass others through.
ocLabel <- function(x) ifelse(x %in% names(BOUNDARY), paste0(BOUNDARY[x], ":  ", x), x)

# read all GLO report rows for one run (once); returns variable/year_num/value
readReportGLO <- function(title) {
  f <- file.path("output", title, "report.rds")
  if (!file.exists(f)) return(NULL)
  d <- as.data.frame(readRDS(f))
  d <- d[as.character(d$region) %in% c("World", "GLO"), , drop = FALSE]  # report.rds uses "World"
  data.frame(variable = as.character(d$variable),
             year_num = suppressWarnings(as.numeric(as.character(d$period))),
             value    = suppressWarnings(as.numeric(d$value)), stringsAsFactors = FALSE)
}

pool <- summary_df[summary_df$exists & isTRUE_vec(summary_df$feasible), ]
rep_list <- lapply(pool$title, readReportGLO); names(rep_list) <- pool$title

OUTCOMES <- list()
for (oc in names(OUTCOME_VARS)) {
  var <- OUTCOME_VARS[[oc]]; rows <- list()
  for (i in seq_len(nrow(pool))) {
    rd <- rep_list[[pool$title[i]]]; if (is.null(rd)) next
    sub <- rd[rd$variable == var, , drop = FALSE]
    if (nrow(sub) == 0) next
    rows[[length(rows) + 1]] <- data.frame(
      title = pool$title[i], scenario = pool$scenario[i], protection = pool$protection[i],
      bioenergy = pool$bioenergy[i], diet = pool$diet[i], tc_state = pool$tc_state[i],
      is_cube = pool$is_cube[i], year_num = sub$year_num, value = sub$value,
      stringsAsFactors = FALSE)
  }
  if (length(rows) > 0) OUTCOMES[[oc]] <- do.call(rbind, rows)
}
missing_oc <- setdiff(names(OUTCOME_VARS), names(OUTCOMES))
if (length(missing_oc) > 0)
  message("\nWARNING: outcome(s) not found in report.rds:\n  ", paste(missing_oc, collapse = "\n  "))
OUTCOME_ORDER <- intersect(names(OUTCOME_VARS), names(OUTCOMES))

# cell value per run title at a year (summed over residual dims)
cellAt <- function(df, title, year) {
  if (is.null(df)) return(NA_real_)
  sel <- df$title == title & df$year_num == year
  if (!any(sel)) return(NA_real_)
  sum(df$value[sel], na.rm = TRUE)
}
cubeValues <- function(df, year) setNames(vapply(CUBE_TITLES, function(t) cellAt(df, t, year),
                                                 numeric(1)), CUBE_TITLES)

# ---- (1) feasibility heatmap (17 runs) --------------------------------------
heat <- summary_df |>
  mutate(status = case_when(!exists ~ "missing", is.na(feasible) ~ "unreadable",
                            feasible ~ "feasible", TRUE ~ "infeasible"))
hc <- heat |> filter(.data$is_cube) |>
  mutate(protection = factor(protection, protection_levels, protection_labels[protection_levels]),
         bioenergy  = factor(bioenergy,  bioenergy_levels,  bioenergy_labels[bioenergy_levels]),
         diet       = factor(diet,       diet_levels,       diet_labels[diet_levels]),
         tc_state   = factor(tc_state,   tc_levels))
status_colors <- c(feasible = "#2A9D8F", infeasible = "#E76F51", unreadable = "#F4A261", missing = "grey75")
p_heat <- ggplot(hc, aes(bioenergy, protection, fill = status)) +
  geom_tile(color = "white", linewidth = 0.5) +
  scale_fill_manual(values = status_colors, drop = FALSE) +
  facet_grid(diet ~ tc_state) +
  labs(title = "fst_levers feasibility (2^4 cube)",
       subtitle = sprintf("BAU_TCendo (outside cube): %s. Reference = NoProtect/No bioenergy/Endog. diet/TCbau.",
                          heat$status[heat$title == "BAU_TCendo"][1]),
       x = "Bioenergy", y = "Protection", fill = "modelstat") +
  my_theme + theme(axis.text.x = element_text(angle = 20, hjust = 1))
ggsave(file.path(OUT_DIR, "01_feasibility_heatmap.pdf"), p_heat, width = 7.5, height = 5)

# ---- (4) full 2^4 decomposition + CSV ---------------------------------------
sanit <- function(s) gsub(":", "_x_", s)
bauValue <- function(df, year) cellAt(df, "BAU_TCendo", year)

eff_rows <- lapply(OUTCOME_ORDER, function(oc) {
  eff <- decomposeFactorial(as.list(cubeValues(OUTCOMES[[oc]], DECOMP_YEAR)))
  row <- as.data.frame(eff, check.names = FALSE)
  names(row) <- sanit(names(row))
  cbind(outcome = oc, year = DECOMP_YEAR, bau = bauValue(OUTCOMES[[oc]], DECOMP_YEAR), row)
})
effects_df <- do.call(rbind, eff_rows)
cell_rows  <- lapply(OUTCOME_ORDER, function(oc) {
  cv <- cubeValues(OUTCOMES[[oc]], DECOMP_YEAR)
  data.frame(outcome = oc, t(cv), check.names = FALSE)
})
cells_df <- do.call(rbind, cell_rows)
write.csv(effects_df, file.path(OUT_DIR, "marginal_contributions.csv"), row.names = FALSE)
write.csv(cells_df,   file.path(OUT_DIR, "cube_cell_values.csv"),       row.names = FALSE)
message(sprintf("\n2^4 decomposition (year %d) written; main effects:", DECOMP_YEAR))
print(effects_df[, c("outcome", "protection", "bioenergy", "diet", "tc")], row.names = FALSE)

# long form for the effect bar plot (drop reference + meta cols)
eff_labels <- setdiff(effectOrder(), "reference")          # 15 effects, canonical order
ord_of <- function(lab) c("main", "two-way", "three-way", "four-way")[lengths(strsplit(lab, ":"))]
eff_long <- effects_df |>
  select(outcome, all_of(sanit(eff_labels))) |>
  pivot_longer(-outcome, names_to = "effect_s", values_to = "value") |>
  mutate(effect = factor(gsub("_x_", ":", effect_s), levels = eff_labels),
         order  = factor(ord_of(as.character(effect)),
                         levels = c("main", "two-way", "three-way", "four-way")),
         outcome = factor(outcome, levels = OUTCOME_ORDER))
p_dec <- ggplot(eff_long, aes(effect, value, fill = order)) +
  geom_hline(yintercept = 0, color = "grey60", linewidth = 0.3) +
  geom_col(width = 0.8, na.rm = TRUE) +
  facet_wrap(~ outcome, scales = "free_y", ncol = 3, labeller = labeller(outcome = ocLabel)) +
  scale_fill_manual(values = order_colors, drop = FALSE) +
  labs(title = sprintf("2^4 reference-delta decomposition (%d)", DECOMP_YEAR),
       subtitle = paste0("Reference = NoProtect_BioOff_DietOff_TCbau. 4 main + 6 two-way + 4 three-way",
                         " + 1 four-way effect.\nGaps = NA (an interaction touching a missing corner)."),
       x = NULL, y = "Effect on outcome", fill = "effect order") +
  my_theme +
  theme(axis.text.x = element_text(angle = 60, hjust = 1, size = 5), legend.position = "bottom")
ggsave(file.path(OUT_DIR, "04_decomposition_2x2x2x2.pdf"), p_dec, width = 14, height = 12)

# ---- (5) main-effects matrix: how each lever relaxes each outcome -----------
# Reduction-positive (positive = lever REDUCES the outcome), matching yield_gap.
# Computed at ENDOGENOUS TC, where all 8 protection x bioenergy x diet cells are
# feasible - the 2^4 treatment-coded bioenergy main effect would be NA because its
# TCbau reference cell (BioOn + TCbau) is infeasible. TC's own effect is taken as
# TCendo vs BAU-pinned at the all-policy-off cell.
FST_FACTORS_3 <- FST_FACTORS[c("protection", "bioenergy", "diet")]
endoCells3 <- function(df, year) setNames(
  vapply(allFactorCells(FST_FACTORS_3),
         function(c3) cellAt(df, paste0(c3, "_TCendo"), year), numeric(1)),
  allFactorCells(FST_FACTORS_3))
lever_disp <- c(protection = "Protection", bioenergy = "Bioenergy", diet = "Diet", tc = "TC")
me_long <- do.call(rbind, lapply(OUTCOME_ORDER, function(oc) {
  df <- OUTCOMES[[oc]]
  e3 <- decomposeFactorial(as.list(endoCells3(df, DECOMP_YEAR)), FST_FACTORS_3)
  tc_eff <- cellAt(df, "NoProtect_BioOff_DietOff_TCendo", DECOMP_YEAR) -
            cellAt(df, "NoProtect_BioOff_DietOff_TCbau",  DECOMP_YEAR)
  data.frame(outcome = oc, lever = names(lever_disp),
             effect = c(e3$protection, e3$bioenergy, e3$diet, tc_eff),
             stringsAsFactors = FALSE)
}))
me_long$reduction <- -me_long$effect
me_long <- me_long |>
  group_by(outcome) |>
  mutate(fill_norm = reduction / max(abs(reduction), na.rm = TRUE)) |>   # comparable across rows
  ungroup() |>
  mutate(lever   = factor(lever_disp[lever], levels = lever_disp),
         outcome = factor(outcome, levels = OUTCOME_ORDER))
p_me <- ggplot(me_long, aes(lever, outcome, fill = fill_norm)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = ifelse(is.na(reduction), "NA", signif(reduction, 3))), size = 2.6) +
  scale_fill_gradient2(low = "#762A83", mid = "white", high = "#1B7837", midpoint = 0,
                       limits = c(-1, 1), breaks = c(-1, 0, 1),
                       labels = c("increases", "0", "reduces")) +
  labs(title = sprintf("Main effect of each lever, per outcome (%d, endogenous TC)", DECOMP_YEAR),
       subtitle = paste0("Cell label = absolute effect (reduction-positive). Colour = effect normalized ",
                         "within each outcome row (dominant lever = full shade), so rows are comparable.\n",
                         "Protection/bioenergy/diet at endogenous TC; TC = endo vs BAU-pinned (other levers off)."),
       x = "Lever", y = NULL, fill = "within-row\neffect") + my_theme
ggsave(file.path(OUT_DIR, "05_main_effects.pdf"), p_me, width = 7.5, height = 6)

# ---- (6) substitution matrix: are the levers substituting one another? ------
sub_df <- do.call(rbind, lapply(OUTCOME_ORDER, function(oc) {
  pii <- pairwiseInteractions(as.list(cubeValues(OUTCOMES[[oc]], DECOMP_YEAR)))
  pii$outcome <- oc; pii
}))
sub_df$pair <- paste(lever_disp[sub_df$lever_i], lever_disp[sub_df$lever_j], sep = " x ")
write.csv(sub_df[, c("outcome", "pair", "main_i", "main_j", "interaction", "frac", "relation", "n_contexts")],
          file.path(OUT_DIR, "substitution.csv"), row.names = FALSE)
message(sprintf("\nLever substitution (%d):", DECOMP_YEAR))
print(sub_df[, c("outcome", "pair", "relation", "frac")], row.names = FALSE)
sub_df <- sub_df |>
  mutate(outcome  = factor(outcome, levels = OUTCOME_ORDER),
         relation = factor(ifelse(is.na(relation), "n/a (infeasible)", relation),
                           levels = c("substitute", "complement", "additive", "mixed", "n/a (infeasible)")))
rel_colors <- c(substitute = "#2166AC", complement = "#B2182B", additive = "grey85",
                mixed = "#F4A261", `n/a (infeasible)` = "grey55")
p_sub <- ggplot(sub_df, aes(pair, outcome, fill = relation)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = ifelse(is.na(frac), "", sprintf("%+.0f%%", 100 * frac))), size = 2.2) +
  scale_fill_manual(values = rel_colors, drop = FALSE) +
  labs(title = sprintf("Lever substitution by outcome (%d)", DECOMP_YEAR),
       subtitle = paste0("substitute = joint effect weaker than additive (diminishing returns); complement = stronger.\n",
                         "Cell label = interaction / (|main_i| + |main_j|); averaged over the other levers' on/off contexts."),
       x = "Lever pair", y = NULL, fill = "relation") +
  my_theme + theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(file.path(OUT_DIR, "06_substitution_matrix.pdf"), p_sub, width = 9, height = 6.5)

# ---- (2) primary protection x bioenergy 2x2 at TCendo, split by diet --------
prim <- list()
for (oc in OUTCOME_ORDER) {
  cv <- cubeValues(OUTCOMES[[oc]], DECOMP_YEAR)
  for (d in diet_levels) {
    ref <- cv[[cellName(c(0, 0, d == "DietOn", 1))]]   # NoProtect,BioOff,<diet>,TCendo
    for (p in protection_levels) for (b in bioenergy_levels) {
      v <- cv[[cellName(c(p == "Protect", b == "BioOn", d == "DietOn", 1))]]
      prim[[length(prim) + 1]] <- data.frame(outcome = oc, diet = d, protection = p,
                                             bioenergy = b, delta = v - ref, stringsAsFactors = FALSE)
    }
  }
}
prim_df <- do.call(rbind, prim) |>
  mutate(protection = factor(protection, protection_levels, protection_labels[protection_levels]),
         bioenergy  = factor(bioenergy,  bioenergy_levels,  bioenergy_labels[bioenergy_levels]),
         diet       = factor(diet,       diet_levels,       diet_labels[diet_levels]),
         outcome    = factor(outcome, levels = OUTCOME_ORDER))
p_prim <- ggplot(prim_df, aes(bioenergy, protection, fill = delta)) +
  geom_tile(color = "white", linewidth = 0.4) +
  geom_text(aes(label = ifelse(is.na(delta), "NA", signif(delta, 3))), size = 2.1) +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0) +
  facet_grid(outcome ~ diet, scales = "free") +
  labs(title = sprintf("Primary: protection x bioenergy at TCendo, split by diet (%d)", DECOMP_YEAR),
       subtitle = "Cell delta vs NoProtect/No bioenergy at the same diet, TCendo.",
       x = "Bioenergy", y = "Protection", fill = "delta") +
  my_theme + theme(axis.text.x = element_text(angle = 20, hjust = 1), strip.text.y = element_text(size = 6))
ggsave(file.path(OUT_DIR, "02_primary_protect_x_bio_by_diet.pdf"), p_prim, width = 7, height = 16)

# ---- (3) isolation slices: dTC and dDiet ------------------------------------
# dTC and dDiet are only DEFINED on cells where both arms of the differenced factor
# are feasible. BioOn+TCbau is infeasible, so: dTC exists only at BioOff cells (its
# TCbau arm); dDiet exists everywhere except BioOn+TCbau. We therefore enumerate ONLY
# the defined cells, each with a UNIQUE label. (Round-1 lens audit C9/C10: the prior
# substr()-truncated labels collapsed BioOff/BioOn and DietOff/DietOn, so geom_col
# silently STACKED distinct contexts into one fabricated bar.)
isoRows <- function(kind) {
  rows <- list()
  for (oc in OUTCOME_ORDER) {
    cv <- cubeValues(OUTCOMES[[oc]], DECOMP_YEAR)
    if (kind == "tc") {
      for (p in protection_levels) for (d in diet_levels) {       # BioOff only (BioOn+TCbau infeasible)
        hi <- cv[[cellName(c(p == "Protect", FALSE, d == "DietOn", 1))]]   # TCendo
        lo <- cv[[cellName(c(p == "Protect", FALSE, d == "DietOn", 0))]]   # TCbau
        rows[[length(rows) + 1]] <- data.frame(outcome = oc,
          cell = sprintf("%s | %s", protection_labels[p], diet_labels[d]),
          delta = hi - lo, stringsAsFactors = FALSE)
      }
    } else {
      for (p in protection_levels) for (b in bioenergy_levels) for (tc in tc_levels) {
        if (b == "BioOn" && tc == "TCbau") next                   # infeasible: dDiet undefined
        hi <- cv[[cellName(c(p == "Protect", b == "BioOn", 1, tc == "TCendo"))]]   # DietOn
        lo <- cv[[cellName(c(p == "Protect", b == "BioOn", 0, tc == "TCendo"))]]   # DietOff
        rows[[length(rows) + 1]] <- data.frame(outcome = oc,
          cell = sprintf("%s | %s | %s", protection_labels[p], bioenergy_labels[b], tc),
          delta = hi - lo, stringsAsFactors = FALSE)
      }
    }
  }
  out <- do.call(rbind, rows) |> mutate(outcome = factor(outcome, levels = OUTCOME_ORDER))
  # GUARD (lens-audit round-1 fix): the (outcome, cell) label MUST be 1:1, else geom_col stacks.
  dup <- out |> dplyr::count(outcome, cell) |> dplyr::filter(.data$n > 1L)
  if (nrow(dup) > 0L) stop("isoRows(", kind, "): non-unique cell labels would stack: ",
                           paste(unique(dup$cell), collapse = ", "))
  out
}
for (k in c("tc", "diet")) {
  d <- isoRows(k)
  ttl <- if (k == "tc") "TC isolation: dTC = Y(TCendo) - Y(TCbau)"
         else           "Diet isolation: dDiet = Y(DietOn) - Y(DietOff)"
  sub <- if (k == "tc")
    "dTC at the No-bioenergy cells, by protection x diet. BioOn dTC is undefined: 1.5C bioenergy is infeasible without endogenous TC."
  else
    "dDiet per cell (BioOn+TCbau dropped: infeasible). Compare TCbau vs TCendo: the diet lever's effect roughly holds, it does not double."
  p <- ggplot(d, aes(cell, delta, fill = delta > 0)) +
    geom_hline(yintercept = 0, color = "grey60", linewidth = 0.3) +
    geom_col(width = 0.7, show.legend = FALSE, na.rm = TRUE) +
    scale_fill_manual(values = c(`TRUE` = "#B2182B", `FALSE` = "#2166AC")) +
    facet_wrap(~ outcome, scales = "free_y", ncol = 3, labeller = labeller(outcome = ocLabel)) +
    labs(title = sprintf("%s (%d)", ttl, DECOMP_YEAR), subtitle = sub, x = NULL,
         y = if (k == "tc") "dTC" else "dDiet") +
    my_theme + theme(axis.text.x = element_text(angle = 35, hjust = 1, size = 6))
  ggsave(file.path(OUT_DIR, sprintf("03%s_%s_isolation.pdf", if (k == "tc") "a" else "b", k)),
         p, width = 12, height = 11)
}

# ---- (0) THE ANSWER: how important is endogenous TC across the four boundaries ----
# One panel per planetary boundary; dTC at the feasible (No-bioenergy) cells. The
# headline RQ figure: it leads the deck.
ans <- do.call(rbind, lapply(names(BOUNDARY_ANSWER), function(bd) {
  oc <- BOUNDARY_ANSWER[[bd]]
  if (!oc %in% OUTCOME_ORDER) return(NULL)
  cv <- cubeValues(OUTCOMES[[oc]], DECOMP_YEAR)
  do.call(rbind, lapply(protection_levels, function(p) do.call(rbind, lapply(diet_levels, function(dd) {
    hi <- cv[[cellName(c(p == "Protect", FALSE, dd == "DietOn", 1))]]   # BioOff, TCendo
    lo <- cv[[cellName(c(p == "Protect", FALSE, dd == "DietOn", 0))]]   # BioOff, TCbau
    data.frame(boundary = sprintf("%s  -  %s", bd, oc),
               cell = sprintf("%s | %s", protection_labels[p], diet_labels[dd]),
               delta = hi - lo, stringsAsFactors = FALSE)
  }))))
}))
ans$boundary <- factor(ans$boundary, levels = unique(ans$boundary))
p_ans <- ggplot(ans, aes(cell, delta, fill = delta > 0)) +
  geom_hline(yintercept = 0, color = "grey60", linewidth = 0.3) +
  geom_col(width = 0.68, show.legend = FALSE, na.rm = TRUE) +
  geom_text(aes(label = signif(delta, 3), vjust = ifelse(delta > 0, -0.4, 1.3)), size = 2.9) +
  scale_fill_manual(values = c(`TRUE` = "#B2182B", `FALSE` = "#2166AC")) +
  facet_wrap(~ boundary, scales = "free_y", ncol = 2) +
  labs(title = sprintf("How much does endogenous TC move each planetary boundary? (%d)", DECOMP_YEAR),
       subtitle = paste0("dTC = Y(TCendo) - Y(TCbau) at the No-bioenergy cells, by protection x diet. ",
                         "Blue = TC lowers the indicator, red = raises it.\n",
                         "1.5C bioenergy (BioOn) is INFEASIBLE without endogenous TC: tau is a prerequisite, not just one lever among four."),
       x = NULL, y = "dTC (TCendo - TCbau)") +
  my_theme + theme(axis.text.x = element_text(angle = 20, hjust = 1, size = 8))
ggsave(file.path(OUT_DIR, "00_tc_importance_boundaries.pdf"), p_ans, width = 10, height = 7.5)

# ---- per-outcome time series faceted by the cube ----------------------------
plotTS <- function(df, oc, file) {
  if (is.null(df)) return(invisible())
  cube <- df[df$is_cube %in% TRUE, ]
  if (nrow(cube) == 0) return(invisible())
  cube <- cube |>
    mutate(protection = factor(protection, protection_levels, protection_labels[protection_levels]),
           bioenergy  = factor(bioenergy,  bioenergy_levels,  bioenergy_labels[bioenergy_levels]),
           diet       = factor(diet,  diet_levels, diet_labels[diet_levels]),
           tc_state   = factor(tc_state, tc_levels))
  bau <- df[df$title == "BAU_TCendo", ]; bau_rep <- NULL
  if (nrow(bau) > 0) {
    bau_rep <- do.call(rbind, lapply(protection_labels[protection_levels], function(pl)
      do.call(rbind, lapply(bioenergy_labels[bioenergy_levels], function(bl) {
        b <- bau; b$protection <- pl; b$bioenergy <- bl; b }))))
    bau_rep <- bau_rep |>
      mutate(protection = factor(protection, protection_labels[protection_levels]),
             bioenergy  = factor(bioenergy,  bioenergy_labels[bioenergy_levels]))
  }
  p <- ggplot(cube, aes(year_num, value, color = tc_state, linetype = diet,
                        group = interaction(tc_state, diet))) +
    geom_line(linewidth = 1, na.rm = TRUE)
  if (!is.null(bau_rep))
    p <- p + geom_line(data = bau_rep, aes(year_num, value), color = bau_color,
                       linetype = "dotted", linewidth = 0.7, inherit.aes = FALSE, na.rm = TRUE)
  p <- p + scale_color_manual(values = tc_colors) + facet_grid(protection ~ bioenergy) +
    labs(title = ocLabel(oc), subtitle = "Solid/dashed = cube cells (color=TC, linetype=diet). Dotted grey = BAU.",
         x = "Year", y = oc, color = "TC state", linetype = "Diet") + my_theme
  ggsave(file.path(OUT_DIR, file), p, width = 9, height = 6.5)
}
ts_i <- 5L
for (oc in OUTCOME_ORDER) {
  plotTS(OUTCOMES[[oc]], oc, sprintf("ts_%02d_%s.pdf", ts_i, gsub("[^a-z0-9]+", "_", tolower(oc))))
  ts_i <- ts_i + 1L
}

message("\nPlots + CSVs written to ", normalizePath(OUT_DIR))
