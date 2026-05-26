# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# tc_vs_landuse_plot.R
#
# Postprocessing + plotting for the "TC vs land-use change" experiment.
# Reads the 5 TC_* run folders (BAU + 2 transition scenarios x 2 TC states)
# and the summary RDS from the orchestrator, extracts a range of outcome
# variables, and writes plots to output/tc_vs_landuse_plots/.

suppressMessages({
  library(magpie4)
  library(magclass)
  library(gdx2)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
})

source("scripts/start/projects/tc_vs_landuse_config.R")

OUT_DIR <- "output/tc_vs_landuse_plots"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ---- discover runs ----------------------------------------------------------

summary_path <- "output/tc_vs_landuse_summary.rds"
if (!file.exists(summary_path)) {
  stop("Summary RDS not found at ", summary_path,
       "; run scripts/start/projects/tc_vs_landuse.R first.")
}
summary_df <- readRDS(summary_path)

summary_df$gdx    <- file.path("output", summary_df$title, "fulldata.gdx")
summary_df$exists <- file.exists(summary_df$gdx)

isTRUE_vec <- function(x) vapply(x, isTRUE, logical(1))

message("Run inventory:")
print(summary_df[, c("scenario", "tc_state", "feasible", "exists")],
      row.names = FALSE)

SCENARIO_DISPLAY <- c(BAU         = "BAU",
                      TransNoDiet = "Transition without Diet",
                      TransDiet   = "Transition with Diet")

summary_df$scenario_display <- SCENARIO_DISPLAY[summary_df$scenario]

# ---- styling ----------------------------------------------------------------

my_theme <- theme_bw(base_size = 11) +
  theme(panel.border     = element_rect(fill = NA, color = "grey75", linewidth = 0.4),
        panel.grid.minor = element_blank(),
        panel.grid.major = element_line(color = "grey92", linewidth = 0.3),
        strip.background = element_rect(fill = "grey95", color = NA),
        strip.text       = element_text(face = "bold", size = 10),
        legend.position  = "right",
        plot.title       = element_text(face = "bold", size = 12),
        plot.subtitle    = element_text(color = "grey30", size = 9))

scenario_levels <- c("BAU", "Transition without Diet", "Transition with Diet")
tc_levels       <- c("TCbau", "TCendo")

# Okabe-Ito palette for TC state (colorblind-safe, professional)
tc_colors <- c(TCbau = "#E69F00", TCendo = "#0072B2")

# Earthy thematic palette for land categories
land_cover_levels <- c("Cropland", "Pasture", "Forest", "Urban", "Other")
land_cover_colors <- c(
  Cropland = "#D4A574",
  Pasture  = "#E5C589",
  Forest   = "#386641",
  Urban    = "#6C757D",
  Other    = "#B5A88C"
)

# Okabe-Ito subset for the marginal-contribution bars
lever_colors <- c("TC only"              = "#0072B2",
                  "Diet only"            = "#009E73",
                  "TC + Diet (combined)" = "#CC79A7")

# ---- generic collection helper ----------------------------------------------

# Apply `extractor` to every feasible+existing run and stack into a tall df
# annotated with scenario / scenario_display / tc_state / title columns.
collect <- function(extractor) {
  feasible <- summary_df[isTRUE_vec(summary_df$feasible) & summary_df$exists, ]
  out <- list()
  for (i in seq_len(nrow(feasible))) {
    df <- extractor(feasible$gdx[i])
    if (is.null(df) || nrow(df) == 0) next
    df$scenario         <- feasible$scenario[i]
    df$scenario_display <- feasible$scenario_display[i]
    df$tc_state         <- feasible$tc_state[i]
    df$title            <- feasible$title[i]
    out[[length(out) + 1]] <- df
  }
  if (length(out) == 0) return(NULL)
  do.call(rbind, out)
}

# Helper to take a single magclass variable, pivot to long, attach year col
mc_to_df <- function(mc) {
  df <- as.data.frame(mc)
  names(df) <- tolower(names(df))
  yc <- intersect(c("year", "years"), names(df))[1]
  df$year_num <- as.numeric(sub("y", "", df[[yc]]))
  df
}

# ---- Plot 1: feasibility heatmap --------------------------------------------

p1_data <- summary_df |>
  mutate(scenario_display = factor(scenario_display, levels = scenario_levels),
         tc_state         = factor(tc_state, levels = tc_levels),
         status = case_when(
           !exists           ~ "missing",
           is.na(feasible)   ~ "unreadable",
           feasible          ~ "feasible",
           TRUE              ~ "infeasible"
         ))

p1 <- ggplot(p1_data, aes(x = tc_state, y = scenario_display, fill = status)) +
  geom_tile(color = "white", linewidth = 0.4) +
  scale_fill_manual(values = c(feasible = "#2A9D8F",
                               infeasible = "#E76F51",
                               unreadable = "#F4A261",
                               missing = "grey75")) +
  labs(title = "Feasibility by scenario and TC state",
       subtitle = "TCbau: tau pinned to BAU trajectory. TCendo: tau endogenous.",
       x = "TC state", y = "Scenario", fill = "modelstat") +
  my_theme

ggsave(file.path(OUT_DIR, "01_feasibility_heatmap.pdf"), p1,
       width = 7, height = 3.5)

# ---- Plot 2: Land Cover Change over time -----------------------------------

# Top-level "Resources|Land Cover Change|+|<category> (million ha wrt 1995)"
# variables from reportLandUseChange().
extractLandCoverChange <- function(gdx) {
  x <- try(reportLandUseChange(gdx, level = "glo"), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)

  keep <- c(
    Cropland = "Resources|Land Cover Change|+|Cropland (million ha wrt 1995)",
    Pasture  = "Resources|Land Cover Change|+|Pastures and Rangelands (million ha wrt 1995)",
    Forest   = "Resources|Land Cover Change|+|Forest (million ha wrt 1995)",
    Urban    = "Resources|Land Cover Change|+|Urban Area (million ha wrt 1995)",
    Other    = "Resources|Land Cover Change|+|Other Land (million ha wrt 1995)"
  )
  present <- keep[keep %in% getNames(x)]
  if (length(present) == 0) return(NULL)

  rows <- list()
  for (cat in names(present)) {
    sub <- x[, , present[[cat]]]
    df <- mc_to_df(sub)
    df$land_cover <- cat
    rows[[length(rows) + 1]] <- df[, c("year_num", "land_cover", "value")]
  }
  do.call(rbind, rows)
}

lcc_df <- collect(extractLandCoverChange)
if (!is.null(lcc_df)) {
  lcc_df$scenario_display <- factor(lcc_df$scenario_display, levels = scenario_levels)
  lcc_df$tc_state         <- factor(lcc_df$tc_state, levels = tc_levels)
  lcc_df$land_cover       <- factor(lcc_df$land_cover, levels = land_cover_levels)

  p2 <- ggplot(lcc_df, aes(x = year_num, y = value, color = land_cover)) +
    geom_hline(yintercept = 0, color = "grey60", linewidth = 0.3) +
    geom_line(linewidth = 1.3) +
    scale_color_manual(values = land_cover_colors) +
    facet_grid(scenario_display ~ tc_state) +
    labs(title = "Global Land Cover Change (cumulative, wrt 1995)",
         subtitle = "Positive = category gains land since 1995; negative = loses.",
         x = "Year", y = "Cumulative change (Mha)", color = "Land cover") +
    my_theme

  ggsave(file.path(OUT_DIR, "02_land_cover_change.pdf"), p2,
         width = 10, height = 7)
}

# ---- Plot 3: terminal-year Land Cover Change bars --------------------------

if (!is.null(lcc_df)) {
  terminal_year <- max(lcc_df$year_num)
  comp_terminal <- lcc_df |>
    filter(year_num == terminal_year)

  p3 <- ggplot(comp_terminal, aes(x = land_cover, y = value, fill = land_cover)) +
    geom_hline(yintercept = 0, color = "grey60", linewidth = 0.3) +
    geom_col(width = 0.7, alpha = 0.95) +
    scale_fill_manual(values = land_cover_colors) +
    facet_grid(scenario_display ~ tc_state) +
    labs(title = sprintf("Land Cover Change at %d (cumulative wrt 1995)", terminal_year),
         x = NULL, y = "Cumulative change (Mha)", fill = "Land cover") +
    my_theme +
    theme(axis.text.x     = element_text(angle = 30, hjust = 1),
          legend.position = "none")

  ggsave(file.path(OUT_DIR, "03_land_cover_change_terminal.pdf"), p3,
         width = 9, height = 6)
}

# ---- Plot 4: tau over time --------------------------------------------------

extractTauDF <- function(gdx) {
  x <- try({
    tau_full <- gdx2::readGDX(gdx, "ov13_tau_core", format = "first_found")
    if (is.null(tau_full)) return(NULL)
    tau_full[, , "level"]
  }, silent = TRUE)
  if (inherits(x, "try-error") || is.null(x)) return(NULL)
  as.data.frame(x)
}

tau_df <- collect(extractTauDF)
if (!is.null(tau_df)) {
  names(tau_df) <- tolower(names(tau_df))
  year_col_t <- intersect(c("year", "years"), names(tau_df))[1]
  type_col_t <- intersect(c("data1", "data", "tautype"), names(tau_df))[1]
  tau_df$year_num         <- as.numeric(sub("y", "", tau_df[[year_col_t]]))
  tau_df$scenario_display <- factor(tau_df$scenario_display, levels = scenario_levels)
  tau_df$tc_state         <- factor(tau_df$tc_state, levels = tc_levels)

  tau_mean <- tau_df |>
    group_by(scenario_display, tc_state, year_num, .data[[type_col_t]]) |>
    summarise(value = mean(value, na.rm = TRUE), .groups = "drop")

  p4 <- ggplot(tau_mean, aes(x = year_num, y = value,
                             color = tc_state, linetype = .data[[type_col_t]],
                             group = interaction(tc_state, .data[[type_col_t]]))) +
    geom_line(linewidth = 1.3) +
    scale_color_manual(values = tc_colors) +
    facet_wrap(~ scenario_display, nrow = 1) +
    labs(title = "Mean tau over time (across superregions)",
         x = "Year", y = "tau (index)", color = "TC state",
         linetype = "tautype") +
    my_theme

  ggsave(file.path(OUT_DIR, "04_tau_trajectory.pdf"), p4,
         width = 10, height = 4)
}

# ---- Plot 5: Land-Use Change CO2 emissions ---------------------------------

extractLUCEmissions <- function(gdx) {
  x <- try(reportEmissions(gdx, level = "glo"), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)
  var_name <- "Emissions|CO2|Land|+|Land-use Change (Mt CO2/yr)"
  if (!var_name %in% getNames(x)) return(NULL)
  mc_to_df(x[, , var_name])
}

emis_df <- collect(extractLUCEmissions)
if (!is.null(emis_df)) {
  emis_df$scenario_display <- factor(emis_df$scenario_display, levels = scenario_levels)
  emis_df$tc_state         <- factor(emis_df$tc_state, levels = tc_levels)

  p5 <- ggplot(emis_df, aes(x = year_num, y = value,
                            color = tc_state, group = tc_state)) +
    geom_hline(yintercept = 0, color = "grey60", linewidth = 0.3) +
    geom_line(linewidth = 1.3) +
    scale_color_manual(values = tc_colors) +
    facet_wrap(~ scenario_display, nrow = 1) +
    labs(title = "Global Land-Use Change CO2 emissions",
         subtitle = "Emissions|CO2|Land|Land-use Change. Negative = net land-use carbon sink.",
         x = "Year", y = "Mt CO2 / yr", color = "TC state") +
    my_theme

  ggsave(file.path(OUT_DIR, "05_lucc_emissions.pdf"), p5,
         width = 10, height = 4)
}

# ---- Plot 6: production -----------------------------------------------------

extractProduction <- function(gdx) {
  x <- try(magpie4::production(gdx, level = "glo"), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)
  as.data.frame(x)
}

prod_df <- collect(extractProduction)
if (!is.null(prod_df)) {
  names(prod_df) <- tolower(names(prod_df))
  year_col_p <- intersect(c("year", "years"), names(prod_df))[1]
  prod_df$year_num         <- as.numeric(sub("y", "", prod_df[[year_col_p]]))
  prod_df$scenario_display <- factor(prod_df$scenario_display, levels = scenario_levels)
  prod_df$tc_state         <- factor(prod_df$tc_state, levels = tc_levels)

  prod_total <- prod_df |>
    group_by(scenario_display, tc_state, year_num) |>
    summarise(value = sum(value, na.rm = TRUE), .groups = "drop")

  p6 <- ggplot(prod_total, aes(x = year_num, y = value,
                               color = tc_state, group = tc_state)) +
    geom_line(linewidth = 1.3) +
    scale_color_manual(values = tc_colors) +
    facet_wrap(~ scenario_display, nrow = 1) +
    labs(title = "Total agricultural production (sum across commodities)",
         x = "Year", y = "Production (Mt DM/yr)", color = "TC state") +
    my_theme

  ggsave(file.path(OUT_DIR, "06_production.pdf"), p6,
         width = 10, height = 4)
}

# ---- Plot 7: food price index ----------------------------------------------

extractFoodPriceIndex <- function(gdx) {
  x <- try(magpie4::priceIndexFood(gdx, level = "glo"), silent = TRUE)
  if (inherits(x, "try-error") || is.null(x)) return(NULL)
  as.data.frame(x)
}

fpi_df <- collect(extractFoodPriceIndex)
if (!is.null(fpi_df)) {
  names(fpi_df) <- tolower(names(fpi_df))
  year_col_f <- intersect(c("year", "years"), names(fpi_df))[1]
  fpi_df$year_num         <- as.numeric(sub("y", "", fpi_df[[year_col_f]]))
  fpi_df$scenario_display <- factor(fpi_df$scenario_display, levels = scenario_levels)
  fpi_df$tc_state         <- factor(fpi_df$tc_state, levels = tc_levels)

  p7 <- ggplot(fpi_df, aes(x = year_num, y = value,
                           color = tc_state, group = tc_state)) +
    geom_hline(yintercept = 100, linetype = "dotted", color = "grey50") +
    geom_line(linewidth = 1.3) +
    scale_color_manual(values = tc_colors) +
    facet_wrap(~ scenario_display, nrow = 1) +
    labs(title = "Global food price index (Laspeyres, baseyear 2005)",
         subtitle = "100 = 2005 baseline. BAU drifts to ~83 by 2100.",
         x = "Year", y = "Index", color = "TC state") +
    my_theme

  ggsave(file.path(OUT_DIR, "07_food_price_index.pdf"), p7,
         width = 10, height = 4)
}

# ---- Plot 9: biodiversity intactness index ----------------------------------

extractBII <- function(gdx) {
  x <- try(BII(gdx, level = "glo"), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)
  mc_to_df(x)
}

bii_df <- collect(extractBII)
if (!is.null(bii_df)) {
  bii_df$scenario_display <- factor(bii_df$scenario_display, levels = scenario_levels)
  bii_df$tc_state         <- factor(bii_df$tc_state, levels = tc_levels)

  p9 <- ggplot(bii_df, aes(x = year_num, y = value,
                           color = tc_state, group = tc_state)) +
    geom_hline(yintercept = 0.78, linetype = "dotted", color = "grey50") +
    geom_line(linewidth = 1.3) +
    scale_color_manual(values = tc_colors) +
    facet_wrap(~ scenario_display, nrow = 1) +
    labs(title = "Global Biodiversity Intactness Index (BII)",
         subtitle = "Dotted line at 0.78 = s44_bii_target in transition scenarios.",
         x = "Year", y = "BII", color = "TC state") +
    my_theme

  ggsave(file.path(OUT_DIR, "09_bii.pdf"), p9,
         width = 10, height = 4)
}

# ---- Plot 10: agricultural water withdrawal --------------------------------

extractWaterWithdrawal <- function(gdx) {
  x <- try(reportWaterUsage(gdx, detail = FALSE, level = "glo"), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)
  var_name <- "Resources|Water|Withdrawal|Agriculture (km3/yr)"
  if (!var_name %in% getNames(x)) return(NULL)
  mc_to_df(x[, , var_name])
}

water_df <- collect(extractWaterWithdrawal)
if (!is.null(water_df)) {
  water_df$scenario_display <- factor(water_df$scenario_display, levels = scenario_levels)
  water_df$tc_state         <- factor(water_df$tc_state, levels = tc_levels)

  p10 <- ggplot(water_df, aes(x = year_num, y = value,
                              color = tc_state, group = tc_state)) +
    geom_line(linewidth = 1.3) +
    scale_color_manual(values = tc_colors) +
    facet_wrap(~ scenario_display, nrow = 1) +
    labs(title = "Global agricultural water withdrawal",
         subtitle = "Resources|Water|Withdrawal|Agriculture (crops + livestock).",
         x = "Year", y = "km3 / yr", color = "TC state") +
    my_theme

  ggsave(file.path(OUT_DIR, "10_water_withdrawal.pdf"), p10,
         width = 10, height = 4)
}

# ---- Plot 11: nitrogen pollution surplus ------------------------------------

extractNitrogenSurplus <- function(gdx) {
  x <- try(reportNitrogenPollution(gdx, level = "glo"), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)
  var_name <- "Resources|Nitrogen|Pollution|Surplus (Mt Nr/yr)"
  if (!var_name %in% getNames(x)) return(NULL)
  mc_to_df(x[, , var_name])
}

n_df <- collect(extractNitrogenSurplus)
if (!is.null(n_df)) {
  n_df$scenario_display <- factor(n_df$scenario_display, levels = scenario_levels)
  n_df$tc_state         <- factor(n_df$tc_state, levels = tc_levels)

  p11 <- ggplot(n_df, aes(x = year_num, y = value,
                          color = tc_state, group = tc_state)) +
    geom_line(linewidth = 1.3) +
    scale_color_manual(values = tc_colors) +
    facet_wrap(~ scenario_display, nrow = 1) +
    labs(title = "Global nitrogen pollution surplus",
         subtitle = "Resources|Nitrogen|Pollution|Surplus (cropland + pasture + AWM + non-ag + end-of-life).",
         x = "Year", y = "Mt Nr / yr", color = "TC state") +
    my_theme

  ggsave(file.path(OUT_DIR, "11_nitrogen_surplus.pdf"), p11,
         width = 10, height = 4)
}

# ---- Plot 8 + CSV: marginal-contribution decomposition (TC x Diet) ---------
#
# 2x2 within the "Transition" backdrop (carbon + 30by30 + biodiv + N + water,
# all on in every cell). Diet is the second lever.
#
#                | Diet OFF (TransNoDiet)        | Diet ON (TransDiet)
#   TCbau        | Y_ref                         | Y_Diet
#   TCendo       | Y_TC                          | Y_Both
#
# Sign convention: positive delta = the lever REDUCES Y.

# Recompute land stocks from magpie4::land() to support the marginal-bar
# outcomes (we need stocks, not the change-from-1995 series above).
extractLand <- function(gdx) {
  x <- try(magpie4::land(gdx, level = "glo"), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)
  as.data.frame(x)
}

land_df <- collect(extractLand)
if (!is.null(land_df)) {
  names(land_df) <- tolower(names(land_df))
  land_col <- intersect(c("data1", "data", "kall", "land"), names(land_df))[1]
  year_col <- intersect(c("year", "years"), names(land_df))[1]
  land_df$year_num <- as.numeric(sub("y", "", land_df[[year_col]]))
}

pickCell <- function(df, scen, tc, year_target) {
  yr_col <- if ("year" %in% names(df)) df$year else df$years
  yr <- as.numeric(sub("y", "", yr_col))
  keep <- df$scenario == scen & df$tc_state == tc & yr == year_target
  if (!any(keep)) return(NA_real_)
  sum(df$value[keep], na.rm = TRUE)
}

decomposeOutcome <- function(df, outcome_label, year) {
  Y_ref  <- pickCell(df, "TransNoDiet", "TCbau",  year)
  Y_TC   <- pickCell(df, "TransNoDiet", "TCendo", year)
  Y_Diet <- pickCell(df, "TransDiet",   "TCbau",  year)
  Y_Both <- pickCell(df, "TransDiet",   "TCendo", year)
  d_TC   <- Y_ref - Y_TC
  d_Diet <- Y_ref - Y_Diet
  d_Both <- Y_ref - Y_Both
  data.frame(
    outcome             = outcome_label,
    year                = year,
    Y_ref               = Y_ref,
    Y_TC_only           = Y_TC,
    Y_Diet_only         = Y_Diet,
    Y_Both              = Y_Both,
    delta_TC            = d_TC,
    delta_Diet          = d_Diet,
    delta_Both          = d_Both,
    synergy             = d_Both - (d_TC + d_Diet),
    TC_share_of_Both    = ifelse(d_Both != 0, d_TC   / d_Both, NA),
    Diet_share_of_Both  = ifelse(d_Both != 0, d_Diet / d_Both, NA),
    stringsAsFactors = FALSE)
}

computeMarginalContributions <- function(year = 2100) {
  rows <- list()

  # ---- Land categories (from magpie4::land()) ----
  if (!is.null(land_df)) {
    sub_crop <- land_df[land_df[[land_col]] == "crop", ]
    rows[[length(rows) + 1]] <- decomposeOutcome(sub_crop, "Cropland (Mha)", year)

    sub_past <- land_df[land_df[[land_col]] == "past", ]
    rows[[length(rows) + 1]] <- decomposeOutcome(sub_past, "Pasture (Mha)", year)

    sub_forest <- land_df[land_df[[land_col]] %in% c("primforest", "secdforest"), ]
    sub_forest_agg <- sub_forest |>
      group_by(scenario, tc_state, year_num, .data[[year_col]]) |>
      summarise(value = sum(value, na.rm = TRUE), .groups = "drop")
    rows[[length(rows) + 1]] <- decomposeOutcome(
      sub_forest_agg, "Total forest (Mha)", year)
  }

  # ---- Environmental flows ----
  if (!is.null(emis_df)) {
    rows[[length(rows) + 1]] <- decomposeOutcome(emis_df, "LUCC CO2 (Mt CO2/yr)", year)
  }
  if (!is.null(n_df)) {
    rows[[length(rows) + 1]] <- decomposeOutcome(n_df, "N surplus (Mt Nr/yr)", year)
  }
  if (!is.null(water_df)) {
    rows[[length(rows) + 1]] <- decomposeOutcome(water_df, "Water withdrawal (km3/yr)", year)
  }

  # ---- Biodiversity + economic ----
  if (!is.null(bii_df)) {
    rows[[length(rows) + 1]] <- decomposeOutcome(bii_df, "BII", year)
  }
  if (!is.null(prod_df)) {
    rows[[length(rows) + 1]] <- decomposeOutcome(prod_df, "Production (Mt DM/yr)", year)
  }
  if (!is.null(fpi_df)) {
    rows[[length(rows) + 1]] <- decomposeOutcome(fpi_df, "Food price index", year)
  }

  if (length(rows) == 0) return(NULL)
  do.call(rbind, rows)
}

mc_df <- tryCatch(computeMarginalContributions(year = 2100), error = function(e) NULL)
if (!is.null(mc_df)) {
  write.csv(mc_df, file.path(OUT_DIR, "marginal_contributions.csv"),
            row.names = FALSE)
  message("\nMarginal-contribution decomposition (year = 2100):")
  print(mc_df[, c("outcome", "delta_TC", "delta_Diet", "delta_Both", "synergy",
                  "TC_share_of_Both", "Diet_share_of_Both")], row.names = FALSE)

  outcome_order <- c("Cropland (Mha)", "Pasture (Mha)", "Total forest (Mha)",
                     "LUCC CO2 (Mt CO2/yr)", "N surplus (Mt Nr/yr)",
                     "Water withdrawal (km3/yr)",
                     "BII", "Production (Mt DM/yr)", "Food price index")

  fmt_delta <- function(x) {
    ifelse(is.na(x), "",
           ifelse(abs(x) >= 10, formatC(x, format = "d"),
                  formatC(signif(x, 3), format = "g", digits = 3)))
  }

  mc_long <- mc_df |>
    select(outcome, delta_TC, delta_Diet, delta_Both) |>
    tidyr::pivot_longer(cols = c(delta_TC, delta_Diet, delta_Both),
                        names_to = "lever", values_to = "delta") |>
    mutate(lever = factor(lever,
                          levels = c("delta_TC", "delta_Diet", "delta_Both"),
                          labels = c("TC only", "Diet only", "TC + Diet (combined)")),
           outcome = factor(outcome, levels = outcome_order))

  p8 <- ggplot(mc_long, aes(x = lever, y = delta, fill = lever)) +
    geom_hline(yintercept = 0, color = "grey60", linewidth = 0.3) +
    geom_col(width = 0.7, alpha = 0.95) +
    geom_text(aes(label = fmt_delta(delta),
                  vjust = ifelse(delta >= 0, -0.3, 1.2)),
              size = 3) +
    facet_wrap(~ outcome, scales = "free_y", ncol = 3) +
    scale_fill_manual(values = lever_colors) +
    scale_y_continuous(expand = expansion(mult = c(0.18, 0.18))) +
    labs(title = "Marginal contribution of TC vs Diet vs both (2100)",
         subtitle = paste0("Reference: Transition without Diet, TCbau. ",
                           "Treatment: Transition with Diet, TCendo.\n",
                           "Transition backdrop (always on): 1.5C carbon price + 30by30 + ",
                           "biodiv (BII 0.78) + N MACCs (max) + water EFP.\n",
                           "Positive bar = lever REDUCES the outcome; negative = lever GROWS it."),
         x = NULL, y = "Reduction from reference",
         fill = NULL) +
    my_theme +
    theme(legend.position = "none",
          axis.text.x = element_text(angle = 15, hjust = 1))

  ggsave(file.path(OUT_DIR, "08_marginal_contributions.pdf"), p8,
         width = 12, height = 10)
}

message("\nPlots written to ", normalizePath(OUT_DIR))
