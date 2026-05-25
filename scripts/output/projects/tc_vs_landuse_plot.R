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

# Scenario order = increasing layering of policies
scenario_levels <- c("BAU", "Energy", "EnergyCons", "Full", "FullPlus")
f_label <- function(f_num) {
  ifelse(f_num == 1.0, "f=1 (endogenous)", sprintf("f=%.2f", f_num))
}
f_levels <- c("f=0.00", "f=0.50", "f=0.75", "f=1 (endogenous)")

# ---- Plot 1: feasibility heatmap --------------------------------------------

p1_data <- summary_df |>
  mutate(scenario = factor(scenario, levels = scenario_levels),
         f_label  = factor(f_label(f_num),
                           levels = f_levels),
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
                             levels = f_levels)

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
                            levels = f_levels)

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
                             levels = f_levels)

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
  fpi_df$year_num <- as.numeric(sub("y", "", fpi_df[[year_col_f]]))
  fpi_df$scenario <- factor(fpi_df$scenario, levels = scenario_levels)
  fpi_df$f_label  <- factor(f_label(fpi_df$f_num), levels = f_levels)

  p7 <- ggplot(fpi_df, aes(x = year_num, y = value,
                           color = f_label, group = f_label)) +
    geom_line(linewidth = 0.7) +
    geom_hline(yintercept = 100, linetype = "dotted", color = "grey50") +
    facet_wrap(~ scenario, nrow = 1) +
    labs(title = "Global food price index (Laspeyres, baseyear 2005)",
         subtitle = "100 = 2005 baseline. BAU sits at ~83 by 2100.",
         x = "Year", y = "Index", color = "Blend fraction") +
    my_theme

  ggsave(file.path(OUT_DIR, "07_food_price_index.pdf"), p7,
         width = 12, height = 4)
}

prod_df <- collect(extractProduction)
if (!is.null(prod_df)) {
  names(prod_df) <- tolower(names(prod_df))
  year_col_p <- intersect(c("year", "years"), names(prod_df))[1]
  comm_col_p <- intersect(c("data1", "data", "kall"), names(prod_df))[1]
  prod_df$year_num <- as.numeric(sub("y", "", prod_df[[year_col_p]]))
  prod_df$scenario <- factor(prod_df$scenario, levels = scenario_levels)
  prod_df$f_label  <- factor(f_label(prod_df$f_num),
                             levels = f_levels)

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

# ---- Plot 8 + CSV: marginal contribution decomposition ---------------------

# For an outcome Y at year 2100, the experiment supports a clean
# decomposition because we have all four corner points of the (TC, Diet)
# 2x2 with the policies layered consistently:
#
#                    diet OFF              diet ON
#   TC at BAU        Y(EnergyCons, f=0)    Y(Full, f=0)
#   TC at endo (f=1) Y(EnergyCons, f=1)    Y(Full, f=1)
#
# Reference cell: Y_ref = Y(EnergyCons, f=0) -- carbon price + 30by30 active
# but TC stuck at BAU and no diet transition.
#
#   delta_TC    = Y_ref - Y(EnergyCons, f=1)   (TC alone, diet off)
#   delta_Diet  = Y_ref - Y(Full, f=0)         (diet alone, TC off)
#   delta_Both  = Y_ref - Y(Full, f=1)         (both together)
#   synergy     = delta_Both - (delta_TC + delta_Diet)
#                 < 0 -> substitutes; > 0 -> complements
#
# Sign convention: positive delta = the lever REDUCES Y (good for cropland,
# food prices; bad if you wanted secdforest expansion -- caveat in the
# README).

computeMarginalContributions <- function(year = 2100) {
  pick <- function(df, scen, fnum, year_num) {
    s <- df |> filter(scenario == scen, abs(f_num - fnum) < 1e-9, year_num == !!year_num)
    if (nrow(s) == 0) return(NA_real_)
    sum(s$value, na.rm = TRUE)
  }
  # Outcomes to decompose: cropland, primforest, secdforest from land_df;
  # food price index from fpi_df. Sum across data dim for land totals.
  out <- list()

  if (exists("land_df") && !is.null(land_df)) {
    for (lt in c("crop", "primforest", "secdforest")) {
      sub <- land_df |> filter(.data[[land_col]] == lt)
      Y_ref      <- pick(sub, "EnergyCons", 0,   year)
      Y_TC       <- pick(sub, "EnergyCons", 1,   year)
      Y_Diet     <- pick(sub, "Full",       0,   year)
      Y_Both     <- pick(sub, "Full",       1,   year)
      delta_TC   <- Y_ref - Y_TC
      delta_Diet <- Y_ref - Y_Diet
      delta_Both <- Y_ref - Y_Both
      out[[length(out) + 1]] <- data.frame(
        outcome = paste0("land_", lt, "_Mha"),
        year = year,
        Y_ref = Y_ref, Y_TC_only = Y_TC, Y_Diet_only = Y_Diet, Y_Both = Y_Both,
        delta_TC = delta_TC, delta_Diet = delta_Diet, delta_Both = delta_Both,
        synergy = delta_Both - (delta_TC + delta_Diet),
        TC_share_of_Both   = ifelse(delta_Both != 0, delta_TC / delta_Both, NA),
        Diet_share_of_Both = ifelse(delta_Both != 0, delta_Diet / delta_Both, NA),
        stringsAsFactors = FALSE
      )
    }
  }
  if (exists("fpi_df") && !is.null(fpi_df)) {
    Y_ref      <- pick(fpi_df, "EnergyCons", 0,   year)
    Y_TC       <- pick(fpi_df, "EnergyCons", 1,   year)
    Y_Diet     <- pick(fpi_df, "Full",       0,   year)
    Y_Both     <- pick(fpi_df, "Full",       1,   year)
    out[[length(out) + 1]] <- data.frame(
      outcome = "food_price_index",
      year = year,
      Y_ref = Y_ref, Y_TC_only = Y_TC, Y_Diet_only = Y_Diet, Y_Both = Y_Both,
      delta_TC = Y_ref - Y_TC, delta_Diet = Y_ref - Y_Diet, delta_Both = Y_ref - Y_Both,
      synergy = (Y_ref - Y_Both) - ((Y_ref - Y_TC) + (Y_ref - Y_Diet)),
      TC_share_of_Both   = ifelse((Y_ref - Y_Both) != 0, (Y_ref - Y_TC) / (Y_ref - Y_Both), NA),
      Diet_share_of_Both = ifelse((Y_ref - Y_Both) != 0, (Y_ref - Y_Diet) / (Y_ref - Y_Both), NA),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, out)
}

mc_df <- tryCatch(computeMarginalContributions(year = 2100), error = function(e) NULL)
if (!is.null(mc_df)) {
  write.csv(mc_df, file.path(OUT_DIR, "marginal_contributions.csv"),
            row.names = FALSE)
  message("\nMarginal contribution decomposition (year = 2100, reference = EnergyCons f=0):")
  print(mc_df[, c("outcome", "delta_TC", "delta_Diet", "delta_Both", "synergy",
                  "TC_share_of_Both", "Diet_share_of_Both")], row.names = FALSE)

  # Bar plot: side-by-side deltas
  mc_long <- mc_df |>
    select(outcome, delta_TC, delta_Diet, delta_Both) |>
    tidyr::pivot_longer(cols = c(delta_TC, delta_Diet, delta_Both),
                        names_to = "lever", values_to = "delta") |>
    mutate(lever = factor(lever,
                          levels = c("delta_TC", "delta_Diet", "delta_Both"),
                          labels = c("TC only", "Diet only", "TC + Diet (combined)")))

  p8 <- ggplot(mc_long, aes(x = lever, y = delta, fill = lever)) +
    geom_col(width = 0.7) +
    geom_text(aes(label = round(delta, 1)), vjust = -0.3, size = 3) +
    facet_wrap(~ outcome, scales = "free_y", nrow = 1) +
    scale_fill_manual(values = c("TC only" = "#1f77b4",
                                 "Diet only" = "#2ca02c",
                                 "TC + Diet (combined)" = "#9467bd")) +
    labs(title = "Marginal contribution of TC vs Diet vs both (2100)",
         subtitle = paste0("Reference cell: EnergyCons at f=0 (carbon price + 30by30 active, TC at BAU level, no diet).\n",
                           "Positive bar = lever REDUCES the outcome (cropland Mha, food price index)."),
         x = NULL, y = "Reduction from reference (units = outcome unit)",
         fill = NULL) +
    my_theme +
    theme(legend.position = "none",
          axis.text.x = element_text(angle = 15, hjust = 1))

  ggsave(file.path(OUT_DIR, "08_marginal_contributions.pdf"), p8,
         width = 11, height = 5)
}

message("\nPlots written to ", normalizePath(OUT_DIR))
