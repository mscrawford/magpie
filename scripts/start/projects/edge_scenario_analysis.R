# =============================================================================
# edge_scenario_analysis.R
#
# PURPOSE: Replicate the pre-integration fragmentation emissions analysis
#          using the actual MAgPIE runs WITH and WITHOUT edge effects baked in.
#          Reads fulldata.gdx from 6 scenario runs (3 SSPs × edge ON/OFF).
#
# WORKING DEFINITIONS:
#   p        = forest fraction (forest area / total cell area, 0-1)
#   E        = forest edge length (km)
#   d        = edge depth (km) = 0.1 km (100m)
#   d_frac   = degradation fraction = 0.25 (25% carbon loss in edge zone)
#   f_edge   = edge fraction (fraction of forest that is edge-affected)
#   factor   = 1 - f_edge * d_frac (carbon density multiplicative factor)
#
# INPUTS:
#   output/SSP{1,2,3}_edge{ON,OFF}_*/fulldata.gdx  (6 runs)
#
# OUTPUTS:
#   output/plots/global_edge_area/magpie_edge_*.pdf
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
})

cat("=== MAgPIE Edge-Effect Scenario Analysis ===\n\n")

# Find the library path for gamstransfer
lp <- list.files("renv/library", recursive = TRUE, full.names = TRUE,
                 pattern = "gamstransfer$")
if (length(lp) > 0) {
  lib_path <- gsub("/gamstransfer$", "", dirname(lp[1]))
  .libPaths(c(lib_path, .libPaths()))
}
library(gamstransfer)

# =============================================================================
# SECTION 1: LOCATE AND LOAD RUN DATA
# =============================================================================
cat("--- Section 1: Load scenario data ---\n")

find_run <- function(pattern) {
  dirs <- list.dirs("output", recursive = FALSE)
  d <- grep(pattern, dirs, value = TRUE)
  if (length(d) == 0) stop("No run found matching: ", pattern)
  d[1]
}

run_info <- list(
  list(ssp = "SSP1", edge = "OFF", label = "SSP1 (PkBudg650)", pattern = "SSP1_edgeOFF"),
  list(ssp = "SSP1", edge = "ON",  label = "SSP1 (PkBudg650)", pattern = "SSP1_edgeON"),
  list(ssp = "SSP2", edge = "OFF", label = "SSP2 (NPi)",       pattern = "SSP2_edgeOFF"),
  list(ssp = "SSP2", edge = "ON",  label = "SSP2 (NPi)",       pattern = "SSP2_edgeON"),
  list(ssp = "SSP3", edge = "OFF", label = "SSP3 (NPi)",       pattern = "SSP3_edgeOFF"),
  list(ssp = "SSP3", edge = "ON",  label = "SSP3 (NPi)",       pattern = "SSP3_edgeON")
)

extract_run <- function(info) {
  run_dir <- find_run(info$pattern)
  gdx_path <- file.path(run_dir, "fulldata.gdx")
  cat(sprintf("  Loading %s_%s from %s\n", info$ssp, info$edge, basename(run_dir)))
  m <- Container$new(gdx_path)

  # --- Land areas ---
  ov <- m$getSymbols("ov_land")[[1]]$records
  land <- ov[ov$type == "level", c("t", "j", "land", "value")]
  land$year <- as.integer(gsub("y", "", land$t))
  names(land)[4] <- "area_mha"

  # Forest area per cluster
  forest_types <- c("primforest", "secdforest", "forestry")
  forest <- land[land$land %in% forest_types, ]
  fa <- aggregate(area_mha ~ j + year, data = forest, FUN = sum)
  names(fa)[3] <- "forest_mha"

  # Total land per cluster (constant)
  total <- aggregate(area_mha ~ j, data = land[land$year == min(land$year), ], FUN = sum)
  names(total)[2] <- "total_mha"

  fa <- merge(fa, total, by = "j")
  fa$p <- pmin(fa$forest_mha / fa$total_mha, 1.0)

  # Land by type (for primary/secondary split)
  land_wide <- reshape(land[land$land %in% c("primforest", "secdforest", "forestry", "crop", "past"),
                            c("j", "year", "land", "area_mha")],
                       timevar = "land", idvar = c("j", "year"), direction = "wide")
  names(land_wide) <- gsub("area_mha\\.", "", names(land_wide))

  # --- Carbon stocks ---
  cs <- m$getSymbols("ov_carbon_stock")[[1]]$records
  cs_l <- cs[cs$type == "level" & cs$stockType == "actual",
             c("t", "j", "land", "c_pools", "value")]
  cs_l$year <- as.integer(gsub("y", "", cs_l$t))

  # Total carbon stock (vegc only for forest types)
  vegc <- cs_l[cs_l$land %in% forest_types & cs_l$c_pools == "vegc", ]
  vegc_agg <- aggregate(value ~ j + year, data = vegc, FUN = sum)
  names(vegc_agg)[3] <- "vegc_MtC"

  # All carbon
  all_c <- aggregate(value ~ j + year, data = cs_l, FUN = sum)
  names(all_c)[3] <- "total_C_MtC"

  # --- Carbon density (fm_carbon_density, possibly edge-modified) ---
  cd <- m$getSymbols("fm_carbon_density")[[1]]$records
  cd_forest_vegc <- cd[cd$land %in% c("primforest", "secdforest") & cd$c_pools == "vegc", ]
  cd_forest_vegc$year <- as.integer(gsub("y", "", cd_forest_vegc$t_all))
  cd_avg <- aggregate(value ~ j + year, data = cd_forest_vegc, FUN = mean)
  names(cd_avg)[3] <- "vegc_density_tCha"

  # --- Edge-effect parameters (only for ON runs) ---
  edge_frac <- NULL
  edge_factor <- NULL
  if (info$edge == "ON") {
    ef <- m$getSymbols("p35_edge_fraction")[[1]]$records
    names(ef)[2] <- "edge_fraction"
    edge_frac <- ef

    cf <- m$getSymbols("p35_carbon_edge_factor")[[1]]$records
    names(cf)[2] <- "carbon_factor"
    edge_factor <- cf
  }

  # --- Merge ---
  result <- merge(fa, vegc_agg, by = c("j", "year"), all.x = TRUE)
  result <- merge(result, all_c, by = c("j", "year"), all.x = TRUE)
  result <- merge(result, cd_avg, by = c("j", "year"), all.x = TRUE)
  result <- merge(result, land_wide, by = c("j", "year"), all.x = TRUE)

  result$ssp <- info$ssp
  result$edge <- info$edge
  result$ssp_label <- info$label
  result$region <- gsub("_[0-9]+$", "", result$j)

  list(data = result, edge_frac = edge_frac, edge_factor = edge_factor)
}

all_runs <- lapply(run_info, extract_run)
all_data <- do.call(rbind, lapply(all_runs, function(x) x$data))

# Collect edge diagnostics from ON runs
edge_diag <- do.call(rbind, lapply(run_info[c(2,4,6)], function(info) {
  run <- all_runs[[which(sapply(run_info, function(x) x$pattern) == info$pattern)]]
  ef <- run$edge_frac
  cf <- run$edge_factor
  if (!is.null(ef) && !is.null(cf)) {
    d <- merge(ef, cf, by = "j")
    d$ssp <- info$ssp
    d$region <- gsub("_[0-9]+$", "", d$j)
    d
  }
}))

out_dir <- "../output/plots/global_edge_area"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# SECTION 2: GLOBAL TIME SERIES
# =============================================================================
cat("\n--- Section 2: Global time series ---\n")

# Aggregate to global
glo <- aggregate(cbind(forest_mha, vegc_MtC, total_C_MtC) ~ year + ssp + edge + ssp_label,
                 data = all_data, FUN = sum)

# P1: Forest area comparison (replicating the old style)
col_ssp <- c(SSP1 = "#1b9e77", SSP2 = "#d95f02", SSP3 = "#7570b3")

p1 <- ggplot(glo, aes(x = year, y = forest_mha, color = ssp, linetype = edge)) +
  geom_line(linewidth = 1.1) + geom_point(size = 2) +
  scale_color_manual(values = col_ssp) +
  scale_linetype_manual(values = c(OFF = "dashed", ON = "solid"),
                        labels = c(OFF = "No edge effects", ON = "Edge effects (d=0.25)")) +
  labs(title = "Global Forest Area (Primforest + Secdforest + Forestry)",
       x = "Year", y = "Forest area (Mha)",
       color = "SSP", linetype = "") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")
ggsave(file.path(out_dir, "magpie_edge_forest_area.pdf"), p1, width = 10, height = 6)
cat("  Saved: magpie_edge_forest_area.pdf\n")

# P2: Vegetation carbon
p2 <- ggplot(glo, aes(x = year, y = vegc_MtC / 1000, color = ssp, linetype = edge)) +
  geom_line(linewidth = 1.1) + geom_point(size = 2) +
  scale_color_manual(values = col_ssp) +
  scale_linetype_manual(values = c(OFF = "dashed", ON = "solid"),
                        labels = c(OFF = "No edge effects", ON = "Edge effects (d=0.25)")) +
  labs(title = "Global Forest Vegetation Carbon",
       x = "Year", y = "Vegetation carbon (GtC)",
       color = "SSP", linetype = "") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")
ggsave(file.path(out_dir, "magpie_edge_vegc.pdf"), p2, width = 10, height = 6)
cat("  Saved: magpie_edge_vegc.pdf\n")

# =============================================================================
# SECTION 3: EMISSIONS DECOMPOSITION (ON - OFF)
# =============================================================================
cat("\n--- Section 3: Emissions decomposition ---\n")

# Compute carbon stock changes and attribute to edge vs non-edge
glo_wide <- reshape(glo[, c("year", "ssp", "edge", "forest_mha", "vegc_MtC")],
                    timevar = "edge", idvar = c("year", "ssp"), direction = "wide")

glo_wide$delta_vegc <- glo_wide$vegc_MtC.ON - glo_wide$vegc_MtC.OFF
glo_wide$delta_forest <- glo_wide$forest_mha.ON - glo_wide$forest_mha.OFF
glo_wide$pct_vegc <- 100 * glo_wide$delta_vegc / abs(glo_wide$vegc_MtC.OFF)

# Compute annualized emissions from stock changes
emis_list <- list()
for (s in c("SSP1", "SSP2", "SSP3")) {
  for (edge_val in c("OFF", "ON")) {
    d <- glo[glo$ssp == s & glo$edge == edge_val, ]
    d <- d[order(d$year), ]
    for (i in 2:nrow(d)) {
      dt <- d$year[i] - d$year[i-1]
      # Emissions = previous_stock - current_stock (positive = emission)
      emis_vegc <- (d$vegc_MtC[i-1] - d$vegc_MtC[i]) / dt * (44/12)  # MtCO2/yr
      emis_list[[length(emis_list) + 1]] <- data.frame(
        ssp = s, edge = edge_val, year = d$year[i],
        emis_vegc_MtCO2yr = emis_vegc,
        stringsAsFactors = FALSE
      )
    }
  }
}
emis <- do.call(rbind, emis_list)

# Separate fragmentation contribution: ON emissions minus OFF emissions
emis_wide <- reshape(emis, timevar = "edge", idvar = c("year", "ssp"), direction = "wide")
emis_wide$frag_MtCO2yr <- emis_wide$emis_vegc_MtCO2yr.ON - emis_wide$emis_vegc_MtCO2yr.OFF

# P3: LUC emissions vs fragmentation (replicating the old decomposition)
plot_data <- rbind(
  data.frame(ssp = emis_wide$ssp, year = emis_wide$year,
             source = "LUC (baseline)", value = emis_wide$emis_vegc_MtCO2yr.OFF,
             stringsAsFactors = FALSE),
  data.frame(ssp = emis_wide$ssp, year = emis_wide$year,
             source = "Fragmentation addition", value = emis_wide$frag_MtCO2yr,
             stringsAsFactors = FALSE)
)

col_source <- c("LUC (baseline)" = "grey50", "Fragmentation addition" = "#D55E00")

p3 <- ggplot(plot_data, aes(x = year, y = value, color = source)) +
  geom_line(linewidth = 1) + geom_point(size = 1.5) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey70") +
  facet_wrap(~ ssp, nrow = 1) +
  scale_color_manual(values = col_source) +
  labs(title = "Forest Vegc Emissions: Baseline LUC vs Fragmentation Addition",
       subtitle = "Fragmentation = (emissions with edge ON) - (emissions with edge OFF). d=0.25.",
       x = "Year", y = "Emissions (MtCO2/yr)", color = "") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"))
ggsave(file.path(out_dir, "magpie_edge_emissions_decomp.pdf"), p3, width = 14, height = 5)
cat("  Saved: magpie_edge_emissions_decomp.pdf\n")

# P4: Cumulative emissions
emis_wide <- emis_wide[order(emis_wide$ssp, emis_wide$year), ]
for (s in c("SSP1", "SSP2", "SSP3")) {
  idx <- emis_wide$ssp == s
  dt <- diff(c(min(glo$year), emis_wide$year[idx]))
  emis_wide$cum_off[idx] <- cumsum(emis_wide$emis_vegc_MtCO2yr.OFF[idx] * dt)
  emis_wide$cum_on[idx]  <- cumsum(emis_wide$emis_vegc_MtCO2yr.ON[idx] * dt)
  emis_wide$cum_frag[idx] <- cumsum(emis_wide$frag_MtCO2yr[idx] * dt)
}

cum_plot <- rbind(
  data.frame(ssp = emis_wide$ssp, year = emis_wide$year,
             source = "LUC (baseline)", value = emis_wide$cum_off / 1000,
             stringsAsFactors = FALSE),
  data.frame(ssp = emis_wide$ssp, year = emis_wide$year,
             source = "LUC + fragmentation", value = emis_wide$cum_on / 1000,
             stringsAsFactors = FALSE),
  data.frame(ssp = emis_wide$ssp, year = emis_wide$year,
             source = "Fragmentation only", value = emis_wide$cum_frag / 1000,
             stringsAsFactors = FALSE)
)

col_cum <- c("LUC (baseline)" = "grey50", "LUC + fragmentation" = "#D55E00",
             "Fragmentation only" = "#0072B2")

p4 <- ggplot(cum_plot, aes(x = year, y = value, color = source)) +
  geom_line(linewidth = 1) + geom_point(size = 1.5) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey70") +
  facet_wrap(~ ssp, nrow = 1) +
  scale_color_manual(values = col_cum) +
  labs(title = "Cumulative Forest Vegetation Carbon Emissions",
       subtitle = "LUC baseline vs with fragmentation. d=0.25.",
       x = "Year", y = "Cumulative emissions (GtCO2)", color = "") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"))
ggsave(file.path(out_dir, "magpie_edge_cumulative.pdf"), p4, width = 14, height = 5)
cat("  Saved: magpie_edge_cumulative.pdf\n")

# =============================================================================
# SECTION 4: EDGE FRACTION AND CARBON FACTOR DIAGNOSTICS
# =============================================================================
cat("\n--- Section 4: Edge diagnostics ---\n")

# P5: Edge fraction distribution by region
p5 <- ggplot(edge_diag, aes(x = edge_fraction, fill = ssp)) +
  geom_histogram(bins = 30, alpha = 0.5, position = "identity") +
  facet_wrap(~ ssp, nrow = 1) +
  scale_fill_manual(values = col_ssp) +
  labs(title = "Edge Fraction Distribution Across Clusters (Final Timestep)",
       subtitle = "f_edge = fraction of forest area within 100m of edge",
       x = "Edge fraction", y = "Number of clusters") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none",
        strip.text = element_text(face = "bold"))
ggsave(file.path(out_dir, "magpie_edge_fraction_hist.pdf"), p5, width = 12, height = 4)
cat("  Saved: magpie_edge_fraction_hist.pdf\n")

# P6: Carbon factor vs edge fraction, colored by region
focus_regions <- c("LAM", "SSA", "OAS", "CHA", "CAZ")
ed_focus <- edge_diag[edge_diag$region %in% focus_regions, ]

p6 <- ggplot(ed_focus, aes(x = edge_fraction, y = carbon_factor, color = region)) +
  geom_point(size = 2, alpha = 0.7) +
  facet_wrap(~ ssp, nrow = 1) +
  scale_color_brewer(palette = "Set1") +
  labs(title = "Carbon Density Reduction Factor vs Edge Fraction",
       subtitle = "factor = 1 - f_edge × 0.25. Lower = more degradation.",
       x = "Edge fraction", y = "Carbon factor", color = "Region") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"))
ggsave(file.path(out_dir, "magpie_edge_factor_scatter.pdf"), p6, width = 14, height = 5)
cat("  Saved: magpie_edge_factor_scatter.pdf\n")

# =============================================================================
# SECTION 5: REGIONAL DECOMPOSITION
# =============================================================================
cat("\n--- Section 5: Regional analysis ---\n")

# Regional forest area and carbon
reg <- aggregate(cbind(forest_mha, vegc_MtC) ~ year + ssp + edge + region,
                 data = all_data, FUN = sum)

# Focus on key tropical regions
reg_focus <- reg[reg$region %in% focus_regions, ]

# P7: Regional forest area
p7 <- ggplot(reg_focus, aes(x = year, y = forest_mha, color = ssp, linetype = edge)) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~ region, scales = "free_y", nrow = 1) +
  scale_color_manual(values = col_ssp) +
  scale_linetype_manual(values = c(OFF = "dashed", ON = "solid"),
                        labels = c(OFF = "No edge", ON = "Edge ON")) +
  labs(title = "Forest Area by Region",
       x = "Year", y = "Forest area (Mha)",
       color = "SSP", linetype = "") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
ggsave(file.path(out_dir, "magpie_edge_regional_forest.pdf"), p7, width = 16, height = 5)
cat("  Saved: magpie_edge_regional_forest.pdf\n")

# P8: Regional carbon stock difference (ON - OFF as %)
reg_wide <- reshape(reg[, c("year", "ssp", "region", "edge", "vegc_MtC")],
                    timevar = "edge", idvar = c("year", "ssp", "region"), direction = "wide")
reg_wide$pct_diff <- 100 * (reg_wide$vegc_MtC.ON - reg_wide$vegc_MtC.OFF) / abs(reg_wide$vegc_MtC.OFF)
reg_wide$pct_diff[!is.finite(reg_wide$pct_diff)] <- 0

reg_focus_diff <- reg_wide[reg_wide$region %in% focus_regions, ]

p8 <- ggplot(reg_focus_diff, aes(x = year, y = pct_diff, color = ssp)) +
  geom_line(linewidth = 1) + geom_point(size = 1.5) +
  geom_hline(yintercept = 0, linetype = "dotted", color = "grey50") +
  facet_wrap(~ region, nrow = 1) +
  scale_color_manual(values = col_ssp) +
  labs(title = "Vegetation Carbon Change Due to Edge Effects (% difference)",
       subtitle = "(ON - OFF) / OFF × 100. Negative = carbon loss from edge degradation.",
       x = "Year", y = "% change in vegc", color = "SSP") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"))
ggsave(file.path(out_dir, "magpie_edge_regional_vegc_pct.pdf"), p8, width = 16, height = 5)
cat("  Saved: magpie_edge_regional_vegc_pct.pdf\n")

# =============================================================================
# SECTION 6: CARBON DENSITY COMPARISON (unmodified vs edge-modified)
# =============================================================================
cat("\n--- Section 6: Carbon density analysis ---\n")

# Compare carbon densities between ON and OFF runs for 2050
cd_2050 <- all_data[all_data$year == 2050 & !is.na(all_data$vegc_density_tCha), ]

cd_wide <- reshape(cd_2050[, c("j", "ssp", "edge", "vegc_density_tCha", "p")],
                   timevar = "edge", idvar = c("j", "ssp"), direction = "wide")
cd_wide$density_ratio <- cd_wide$vegc_density_tCha.ON / cd_wide$vegc_density_tCha.OFF
cd_wide$region <- gsub("_[0-9]+$", "", cd_wide$j)

cd_focus <- cd_wide[cd_wide$region %in% focus_regions, ]

p9 <- ggplot(cd_focus, aes(x = p.OFF, y = density_ratio, color = region)) +
  geom_point(size = 2, alpha = 0.7) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey50") +
  facet_wrap(~ ssp, nrow = 1) +
  scale_color_brewer(palette = "Set1") +
  labs(title = "Carbon Density Ratio (ON/OFF) vs Forest Fraction at y2050",
       subtitle = "Ratio < 1 means edge effects reduced carbon density. Lower p → more edge effect.",
       x = "Forest fraction (p)", y = "Density ratio (ON/OFF)", color = "Region") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"))
ggsave(file.path(out_dir, "magpie_edge_density_ratio.pdf"), p9, width = 14, height = 5)
cat("  Saved: magpie_edge_density_ratio.pdf\n")

# =============================================================================
# SECTION 7: SUMMARY TABLE
# =============================================================================
cat("\n=== SUMMARY ===\n\n")

cat("Global totals at y2050 (from GDX data):\n")
cat(sprintf("%-20s %12s %12s %8s   %12s %12s %8s\n",
            "", "Forest OFF", "Forest ON", "Δ%",
            "VegC OFF", "VegC ON", "Δ%"))
for (s in c("SSP1", "SSP2", "SSP3")) {
  d <- glo_wide[glo_wide$year == 2050 & glo_wide$ssp == s, ]
  cat(sprintf("%-20s %10.0f Mha %10.0f Mha %+.2f%%   %10.0f GtC %10.0f GtC %+.2f%%\n",
              s,
              d$forest_mha.OFF, d$forest_mha.ON,
              100 * d$delta_forest / d$forest_mha.OFF,
              d$vegc_MtC.OFF / 1000, d$vegc_MtC.ON / 1000,
              d$pct_vegc))
}

cat("\nCumulative fragmentation emissions 1995-2050 (GtCO2):\n")
for (s in c("SSP1", "SSP2", "SSP3")) {
  d <- emis_wide[emis_wide$ssp == s & emis_wide$year == 2050, ]
  cat(sprintf("  %s: LUC baseline = %+.1f GtCO2, with frag = %+.1f GtCO2, frag only = %+.1f GtCO2\n",
              s, d$cum_off / 1000, d$cum_on / 1000, d$cum_frag / 1000))
}

cat("\nEdge diagnostics (final timestep):\n")
for (s in c("SSP1", "SSP2", "SSP3")) {
  ed <- edge_diag[edge_diag$ssp == s, ]
  cat(sprintf("  %s: edge_frac [%.3f, %.3f], mean=%.3f | factor [%.3f, %.3f], mean=%.3f\n",
              s,
              min(ed$edge_fraction), max(ed$edge_fraction), mean(ed$edge_fraction),
              min(ed$carbon_factor), max(ed$carbon_factor), mean(ed$carbon_factor)))
}

cat(sprintf("\n9 plots saved to: %s\n", normalizePath(out_dir)))
cat("\n=== Analysis complete ===\n")
