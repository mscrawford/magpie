# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# tc_vs_landuse_plot.R
#
# Postprocessing + plotting for the "TC vs land-use change" experiment.
# Reads output/TC_* run folders and the summary RDS from the orchestrator,
# extracts land allocation, tau, production and emissions, and writes plots
# to output/tc_vs_landuse_plots/.

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

# Resolve gdx paths + a clean (scenario, f) label
summary_df$gdx   <- file.path("output", summary_df$title, "fulldata.gdx")
summary_df$exists <- file.exists(summary_df$gdx)

# Parse f from the f column ("endo (f=1)" -> 1.0)
summary_df$f_num <- ifelse(grepl("endo", summary_df$f, fixed = TRUE),
                           1.0, suppressWarnings(as.numeric(summary_df$f)))

message("Run inventory:")
print(summary_df[, c("scenario", "f", "f_num", "feasible", "exists")],
      row.names = FALSE)

# ---- styling ----------------------------------------------------------------

# theme_bw inherits a panel border; we make it explicit to survive theme tweaks.
my_theme <- theme_bw(base_size = 11) +
  theme(panel.border = element_rect(fill = NA, color = "grey80", linewidth = 0.5),
        strip.background = element_rect(fill = "grey95", color = NA),
        legend.position = "right")

scenario_levels <- c("BAU", "Energy", "Full")
f_label <- function(f_num) {
  ifelse(f_num == 1.0, "f=1 (endogenous)", sprintf("f=%.2f", f_num))
}

# ---- Plot 1: feasibility heatmap --------------------------------------------

p1_data <- summary_df |>
  mutate(scenario = factor(scenario, levels = scenario_levels),
         f_label  = factor(f_label(f_num),
                           levels = c("f=0.00", "f=0.50", "f=0.75", "f=1 (endogenous)")),
         status   = case_when(
           !exists           ~ "missing",
           is.na(feasible)   ~ "unreadable",
           feasible          ~ "feasible",
           TRUE              ~ "infeasible"
         ))

p1 <- ggplot(p1_data, aes(x = f_label, y = scenario, fill = status)) +
  geom_tile(color = "white", linewidth = 0.4) +
  scale_fill_manual(values = c(feasible = "#2ca02c",
                               infeasible = "#d62728",
                               unreadable = "#ff7f0e",
                               missing = "grey70")) +
  labs(title = "Feasibility by scenario and TC blend fraction",
       subtitle = "tau_blend(t,h,type) = tau_BAU + f * (tau_TS - tau_BAU)",
       x = "TC blend fraction (f)", y = "Scenario", fill = "modelstat") +
  my_theme

ggsave(file.path(OUT_DIR, "01_feasibility_heatmap.pdf"), p1,
       width = 7, height = 3.5)

# ---- helpers for series extraction ------------------------------------------

# Land allocation (cropland, pasture, forest, other, urban) over time at global level
extractLand <- function(gdx) {
  # magpie4::land returns a magpie object (region, time, land_type)
  x <- try(magpie4::land(gdx, level = "glo"), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)
  as.data.frame(x)
}

# Tau trajectory at superregional level for both crop and pastr
extractTauDF <- function(gdx) {
  x <- try({
    tau_full <- gdx2::readGDX(gdx, "ov13_tau_core", format = "first_found")
    if (is.null(tau_full)) return(NULL)
    tau_full[, , "level"]
  }, silent = TRUE)
  if (inherits(x, "try-error") || is.null(x)) return(NULL)
  as.data.frame(x)
}

# Global agricultural production for major commodity groups
extractProduction <- function(gdx) {
  x <- try(magpie4::production(gdx, level = "glo"), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)
  as.data.frame(x)
}

# Total GHG emissions (CO2eq) at global level
extractEmissions <- function(gdx) {
  x <- try(magpie4::emisCO2(gdx, level = "glo"), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)
  as.data.frame(x)
}

# Build a tall data frame for a given extractor across all feasible runs.
collect <- function(extractor) {
  feasible <- summary_df[isTRUE_vec(summary_df$feasible) & summary_df$exists, ]
  out <- list()
  for (i in seq_len(nrow(feasible))) {
    df <- extractor(feasible$gdx[i])
    if (is.null(df) || nrow(df) == 0) next
    df$scenario <- feasible$scenario[i]
    df$f_num    <- feasible$f_num[i]
    df$title    <- feasible$title[i]
    out[[length(out) + 1]] <- df
  }
  if (length(out) == 0) return(NULL)
  do.call(rbind, out)
}

isTRUE_vec <- function(x) {
  vapply(x, isTRUE, logical(1))
}

# ---- Plot 2: land allocation over time, faceted (scenario x f) -------------

land_df <- collect(extractLand)
if (!is.null(land_df)) {
  # magclass df columns vary by version; normalize column names
  # Typical: Cell, Region, Year, Data1 (land type), Value
  names(land_df) <- tolower(names(land_df))
  year_col <- intersect(c("year", "years"), names(land_df))[1]
  land_col <- intersect(c("data1", "data", "kall", "land"), names(land_df))[1]

  land_df$year_num <- as.numeric(sub("y", "", land_df[[year_col]]))
  land_df$scenario <- factor(land_df$scenario, levels = scenario_levels)
  land_df$f_label  <- factor(f_label(land_df$f_num),
                             levels = c("f=0.00", "f=0.50", "f=0.75", "f=1 (endogenous)"))

  p2 <- ggplot(land_df, aes(x = year_num, y = value,
                            fill = .data[[land_col]])) +
    geom_area(position = "stack", alpha = 0.85) +
    facet_grid(scenario ~ f_label) +
    labs(title = "Global land allocation by scenario and TC blend fraction",
         x = "Year", y = "Land area (Mha)", fill = "Land type") +
    my_theme

  ggsave(file.path(OUT_DIR, "02_land_allocation_grid.pdf"), p2,
         width = 12, height = 8)
}

# ---- Plot 3: at f*, comparison vs f=1 ---------------------------------------

# Per scenario, find f* = the smallest feasible f (or "no f* found" if none feasible)
fstar_df <- summary_df |>
  filter(scenario != "BAU") |>
  filter(isTRUE_vec(feasible)) |>
  group_by(scenario) |>
  summarise(fstar = min(f_num), .groups = "drop")

message("\nFeasibility thresholds:")
print(fstar_df)

if (!is.null(land_df) && nrow(fstar_df) > 0) {
  comparison_rows <- list()
  for (i in seq_len(nrow(fstar_df))) {
    scen  <- as.character(fstar_df$scenario[i])
    fstar <- fstar_df$fstar[i]
    sub <- land_df |>
      filter(scenario == scen, f_num %in% c(fstar, 1.0))
    if (nrow(sub) == 0) next
    sub$role <- ifelse(sub$f_num == 1.0, "TC-facilitated (f=1)", sprintf("TC-restricted (f=%.2f)", fstar))
    comparison_rows[[length(comparison_rows) + 1]] <- sub
  }
  if (length(comparison_rows) > 0) {
    comp_df <- do.call(rbind, comparison_rows)
    # Take the terminal year(s) for the bar comparison
    terminal_year <- max(comp_df$year_num)
    comp_terminal <- comp_df |> filter(year_num == terminal_year)
    p3 <- ggplot(comp_terminal, aes(x = role, y = value, fill = .data[[land_col]])) +
      geom_col(position = "stack", alpha = 0.9, width = 0.6) +
      facet_wrap(~ scenario, nrow = 1) +
      labs(title = sprintf("Land allocation at year %d: TC-restricted (f=f*) vs TC-facilitated (f=1)",
                           terminal_year),
           subtitle = "f* = smallest feasible TC blend fraction per scenario",
           x = NULL, y = "Global land area (Mha)", fill = "Land type") +
      my_theme +
      theme(axis.text.x = element_text(angle = 20, hjust = 1))
    ggsave(file.path(OUT_DIR, "03_landuse_at_threshold.pdf"), p3,
           width = 9, height = 5)
  }
}

# ---- Plot 4: tau + emissions + production sanity ----------------------------

tau_df <- collect(extractTauDF)
if (!is.null(tau_df)) {
  names(tau_df) <- tolower(names(tau_df))
  year_col_t <- intersect(c("year", "years"), names(tau_df))[1]
  reg_col_t  <- intersect(c("region", "i", "h"), names(tau_df))[1]
  type_col_t <- intersect(c("data1", "data", "tautype"), names(tau_df))[1]
  tau_df$year_num <- as.numeric(sub("y", "", tau_df[[year_col_t]]))
  tau_df$scenario <- factor(tau_df$scenario, levels = scenario_levels)
  tau_df$f_label  <- factor(f_label(tau_df$f_num),
                            levels = c("f=0.00", "f=0.50", "f=0.75", "f=1 (endogenous)"))

  # Plot tau as global mean per (scenario, f, tautype)
  tau_mean <- tau_df |>
    group_by(scenario, f_label, year_num, .data[[type_col_t]]) |>
    summarise(value = mean(value, na.rm = TRUE), .groups = "drop")

  p4 <- ggplot(tau_mean, aes(x = year_num, y = value,
                             color = f_label, linetype = .data[[type_col_t]],
                             group = interaction(f_label, .data[[type_col_t]]))) +
    geom_line(linewidth = 0.7) +
    facet_wrap(~ scenario, nrow = 1) +
    labs(title = "Mean tau over time (across superregions)",
         x = "Year", y = "tau (index)", color = "Blend fraction",
         linetype = "tautype") +
    my_theme

  ggsave(file.path(OUT_DIR, "04_tau_trajectory.pdf"), p4,
         width = 11, height = 4)
}

emis_df <- collect(extractEmissions)
if (!is.null(emis_df)) {
  names(emis_df) <- tolower(names(emis_df))
  year_col_e <- intersect(c("year", "years"), names(emis_df))[1]
  emis_df$year_num <- as.numeric(sub("y", "", emis_df[[year_col_e]]))
  emis_df$scenario <- factor(emis_df$scenario, levels = scenario_levels)
  emis_df$f_label  <- factor(f_label(emis_df$f_num),
                             levels = c("f=0.00", "f=0.50", "f=0.75", "f=1 (endogenous)"))

  # Aggregate over emission sources for a top-level view
  emis_total <- emis_df |>
    group_by(scenario, f_label, year_num) |>
    summarise(value = sum(value, na.rm = TRUE), .groups = "drop")

  p5 <- ggplot(emis_total, aes(x = year_num, y = value,
                               color = f_label, group = f_label)) +
    geom_line(linewidth = 0.7) +
    facet_wrap(~ scenario, nrow = 1) +
    labs(title = "Global AFOLU CO2-eq emissions",
         x = "Year", y = "Emissions (MtCO2eq/yr)", color = "Blend fraction") +
    my_theme

  ggsave(file.path(OUT_DIR, "05_emissions.pdf"), p5,
         width = 11, height = 4)
}

prod_df <- collect(extractProduction)
if (!is.null(prod_df)) {
  names(prod_df) <- tolower(names(prod_df))
  year_col_p <- intersect(c("year", "years"), names(prod_df))[1]
  comm_col_p <- intersect(c("data1", "data", "kall"), names(prod_df))[1]
  prod_df$year_num <- as.numeric(sub("y", "", prod_df[[year_col_p]]))
  prod_df$scenario <- factor(prod_df$scenario, levels = scenario_levels)
  prod_df$f_label  <- factor(f_label(prod_df$f_num),
                             levels = c("f=0.00", "f=0.50", "f=0.75", "f=1 (endogenous)"))

  # Total production over time, summed across commodities
  prod_total <- prod_df |>
    group_by(scenario, f_label, year_num) |>
    summarise(value = sum(value, na.rm = TRUE), .groups = "drop")

  p6 <- ggplot(prod_total, aes(x = year_num, y = value,
                               color = f_label, group = f_label)) +
    geom_line(linewidth = 0.7) +
    facet_wrap(~ scenario, nrow = 1) +
    labs(title = "Total agricultural production (sum across commodities)",
         x = "Year", y = "Production (Mt DM/yr)", color = "Blend fraction") +
    my_theme

  ggsave(file.path(OUT_DIR, "06_production.pdf"), p6,
         width = 11, height = 4)
}

message("\nPlots written to ", normalizePath(OUT_DIR))
