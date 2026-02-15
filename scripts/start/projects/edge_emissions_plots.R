# |  Edge-effect scenario comparison plots using proper emissions reporting
# |  Input: report.rds from 6 runs (3 SSPs × 2 edge settings)
# |  Output: PDFs in output/plots/
# |  Uses: Emissions|CO2|Land variables from fixed reportEmissions()

library(ggplot2)

# --- Locate run folders ---
output_dir <- "output"
runs <- list(
  SSP1_OFF = list.files(output_dir, "^SSP1_edgeOFF_", full.names = TRUE)[1],
  SSP1_ON  = list.files(output_dir, "^SSP1_edgeON_",  full.names = TRUE)[1],
  SSP2_OFF = list.files(output_dir, "^SSP2_edgeOFF_", full.names = TRUE)[1],
  SSP2_ON  = list.files(output_dir, "^SSP2_edgeON_",  full.names = TRUE)[1],
  SSP3_OFF = list.files(output_dir, "^SSP3_edgeOFF_", full.names = TRUE)[1],
  SSP3_ON  = list.files(output_dir, "^SSP3_edgeON_",  full.names = TRUE)[1]
)

cat("Loading reports...\n")
reports <- lapply(runs, function(d) readRDS(file.path(d, "report.rds")))

all_data <- do.call(rbind, lapply(names(reports), function(nm) {
  r <- reports[[nm]]
  parts <- strsplit(nm, "_")[[1]]
  r$ssp <- parts[1]
  r$edge <- parts[2]
  r$run_label <- nm
  r
}))

all_data$region_name <- all_data$region
glo <- all_data[all_data$region_name == "World", ]

plot_dir <- "../output/plots"
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

ssp_colors <- c(SSP1 = "#1b9e77", SSP2 = "#d95f02", SSP3 = "#7570b3")
edge_lines <- c(OFF = "dashed", ON = "solid")
edge_labs  <- c(OFF = "No edge effects", ON = "With edge effects (d=0.25)")

# --- Helper: simple time series plot ---
plot_ts <- function(data, var, y_lab, title, fname) {
  d <- data[data$variable == var, ]
  if (nrow(d) == 0) { cat("  SKIP:", var, "\n"); return(invisible(NULL)) }
  p <- ggplot(d, aes(x = period, y = value, color = ssp, linetype = edge)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = ssp_colors) +
    scale_linetype_manual(values = edge_lines, labels = edge_labs) +
    labs(title = title, x = "Year", y = y_lab, color = "SSP", linetype = "Edge effects") +
    theme_minimal(base_size = 14) + theme(legend.position = "bottom")
  ggsave(file.path(plot_dir, fname), p, width = 10, height = 6)
  cat("  Saved:", fname, "\n")
}

# =============================================================================
# P1: Net CO2 flux from land (yearly)
# =============================================================================
cat("\nP1: Net CO2 emissions from land\n")
plot_ts(glo, "Emissions|CO2|Land", "Mt CO2/yr",
        "Net CO2 Flux from Land (incl. indirect)", "emis_co2_land_total.pdf")

# =============================================================================
# P2: LUC emissions only (yearly) 
# =============================================================================
cat("P2: Land-use change CO2 emissions\n")
plot_ts(glo, "Emissions|CO2|Land|+|Land-use Change", "Mt CO2/yr",
        "CO2 Emissions from Land-Use Change", "emis_co2_luc.pdf")

# =============================================================================
# P3: LUC emissions decomposition — stacked area for one SSP (SSP2)
# =============================================================================
cat("P3: LUC decomposition (SSP2)\n")
decomp_vars <- c(
  "Emissions|CO2|Land|Land-use Change|+|Deforestation",
  "Emissions|CO2|Land|Land-use Change|+|Forest degradation",
  "Emissions|CO2|Land|Land-use Change|+|Other land conversion",
  "Emissions|CO2|Land|Land-use Change|+|Regrowth",
  "Emissions|CO2|Land|Land-use Change|+|Soil",
  "Emissions|CO2|Land|Land-use Change|+|Peatland",
  "Emissions|CO2|Land|Land-use Change|+|Timber",
  "Emissions|CO2|Land|Land-use Change|+|Wood Harvest"
)
d3 <- glo[glo$variable %in% decomp_vars & glo$ssp == "SSP2", ]
d3$component <- sub("Emissions\\|CO2\\|Land\\|Land-use Change\\|\\+\\|", "", d3$variable)

if (nrow(d3) > 0) {
  p3 <- ggplot(d3, aes(x = period, y = value, fill = component)) +
    geom_area(alpha = 0.7) +
    facet_wrap(~ edge, labeller = labeller(edge = c(OFF = "No Edge Effects", ON = "Edge Effects ON"))) +
    labs(title = "SSP2: LUC Emission Components", x = "Year", y = "Mt CO2/yr", fill = "Component") +
    theme_minimal(base_size = 13) + theme(legend.position = "bottom") +
    guides(fill = guide_legend(ncol = 2))
  ggsave(file.path(plot_dir, "emis_luc_decomp_ssp2.pdf"), p3, width = 12, height = 7)
  cat("  Saved: emis_luc_decomp_ssp2.pdf\n")
}

# =============================================================================
# P4: Difference (ON - OFF) for key emissions
# =============================================================================
cat("P4: Edge effect on emissions (ON - OFF)\n")
diff_vars <- c(
  "Emissions|CO2|Land",
  "Emissions|CO2|Land|+|Land-use Change",
  "Emissions|CO2|Land|+|Indirect"
)
d4_on  <- glo[glo$variable %in% diff_vars & glo$edge == "ON",
              c("period", "ssp", "variable", "value")]
d4_off <- glo[glo$variable %in% diff_vars & glo$edge == "OFF",
              c("period", "ssp", "variable", "value")]
d4 <- merge(d4_on, d4_off, by = c("period", "ssp", "variable"), suffixes = c("_on", "_off"))
d4$diff <- d4$value_on - d4$value_off
d4$var_short <- sub("Emissions\\|CO2\\|Land", "Land", d4$variable)
d4$var_short[d4$var_short == "Land"] <- "Net CO2 flux"
d4$var_short <- sub("Land\\|\\+\\|", "", d4$var_short)

p4 <- ggplot(d4, aes(x = period, y = diff, color = ssp, linetype = var_short)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dotted", color = "grey40") +
  scale_color_manual(values = ssp_colors) +
  labs(title = "Edge Effect Impact: Additional CO2 Emissions (ON - OFF)",
       x = "Year", y = "Mt CO2/yr", color = "SSP", linetype = "Variable") +
  theme_minimal(base_size = 14) + theme(legend.position = "bottom")
ggsave(file.path(plot_dir, "emis_edge_diff.pdf"), p4, width = 10, height = 6)
cat("  Saved: emis_edge_diff.pdf\n")

# =============================================================================
# P5: Cumulative LUC emissions
# =============================================================================
cat("P5: Cumulative LUC emissions\n")
plot_ts(glo, "Emissions|CO2|Land|Cumulative|+|Land-use Change", "Gt CO2",
        "Cumulative CO2 from Land-Use Change", "emis_cum_luc.pdf")

# =============================================================================
# P6: Cumulative total (net)
# =============================================================================
cat("P6: Cumulative net CO2 from land\n")
plot_ts(glo, "Emissions|CO2|Land|Cumulative", "Gt CO2",
        "Cumulative Net CO2 from Land", "emis_cum_total.pdf")

# =============================================================================
# P7: Deforestation emissions by SSP
# =============================================================================
cat("P7: Deforestation emissions\n")
plot_ts(glo, "Emissions|CO2|Land|Land-use Change|+|Deforestation", "Mt CO2/yr",
        "CO2 from Deforestation", "emis_deforestation.pdf")

# =============================================================================
# P8: Forest degradation emissions
# =============================================================================
cat("P8: Forest degradation emissions\n")
plot_ts(glo, "Emissions|CO2|Land|Land-use Change|+|Forest degradation", "Mt CO2/yr",
        "CO2 from Forest Degradation", "emis_degradation.pdf")

# =============================================================================
# P9: Total GHG (GWP100AR6)
# =============================================================================
cat("P9: Total GHG emissions from land\n")
plot_ts(glo, "Emissions|GWP100AR6|Land", "Gt CO2e/yr",
        "Total GHG Emissions from Land (GWP100 AR6)", "emis_ghg_total.pdf")

# =============================================================================
# P10: Cumulative difference (ON-OFF) for LUC
# =============================================================================
cat("P10: Cumulative edge-effect emissions\n")
cum_var <- "Emissions|CO2|Land|Cumulative|+|Land-use Change"
d10_on  <- glo[glo$variable == cum_var & glo$edge == "ON", c("period", "ssp", "value")]
d10_off <- glo[glo$variable == cum_var & glo$edge == "OFF", c("period", "ssp", "value")]
d10 <- merge(d10_on, d10_off, by = c("period", "ssp"), suffixes = c("_on", "_off"))
d10$diff <- d10$value_on - d10$value_off

p10 <- ggplot(d10, aes(x = period, y = diff, color = ssp)) +
  geom_line(linewidth = 1.2) +
  geom_hline(yintercept = 0, linetype = "dotted", color = "grey40") +
  scale_color_manual(values = ssp_colors) +
  labs(title = "Cumulative Additional CO2 from Edge Effects (ON - OFF)",
       subtitle = "Positive = more emissions with edge effects",
       x = "Year", y = "Gt CO2", color = "SSP") +
  theme_minimal(base_size = 14) + theme(legend.position = "bottom")
ggsave(file.path(plot_dir, "emis_cum_edge_diff.pdf"), p10, width = 10, height = 6)
cat("  Saved: emis_cum_edge_diff.pdf\n")

# =============================================================================
# P11: Regional LUC emissions (key tropical regions)
# =============================================================================
cat("P11: Regional LUC emissions\n")
key_regions <- c("LAM", "SSA", "OAS", "CHA", "CAZ")
d11 <- all_data[all_data$variable == "Emissions|CO2|Land|+|Land-use Change" & 
                all_data$region_name %in% key_regions, ]
if (nrow(d11) > 0) {
  p11 <- ggplot(d11, aes(x = period, y = value, color = ssp, linetype = edge)) +
    geom_line(linewidth = 0.9) +
    facet_wrap(~ region_name, scales = "free_y", ncol = 3) +
    scale_color_manual(values = ssp_colors) +
    scale_linetype_manual(values = edge_lines, labels = edge_labs) +
    labs(title = "Regional LUC CO2 Emissions", x = "Year", y = "Mt CO2/yr",
         color = "SSP", linetype = "") +
    theme_minimal(base_size = 12) + theme(legend.position = "bottom")
  ggsave(file.path(plot_dir, "emis_regional_luc.pdf"), p11, width = 14, height = 8)
  cat("  Saved: emis_regional_luc.pdf\n")
}

# =============================================================================
# P12: Vegetation carbon stock
# =============================================================================
cat("P12: Vegetation carbon\n")
plot_ts(glo, "Resources|Carbon|+|Vegetation", "GtC",
        "Global Vegetation Carbon Stock", "emis_vegc_stock.pdf")

# =============================================================================
# P13: Land Carbon Sink (indirect / CO2 fertilization effect)
# =============================================================================
cat("P13: Land carbon sink\n")
plot_ts(glo, "Emissions|CO2|Land|+|Indirect", "Mt CO2/yr",
        "Indirect CO2 Effect (CO2 fertilization + climate)", "emis_indirect.pdf")

# =============================================================================
# Summary table
# =============================================================================
cat("\n=== Summary: CO2 LUC emissions at 2050 (Mt CO2/yr) ===\n")
luc_2050 <- glo[glo$variable == "Emissions|CO2|Land|+|Land-use Change" & glo$period == 2050,
                c("ssp", "edge", "value")]
luc_2050 <- luc_2050[order(luc_2050$ssp, luc_2050$edge), ]
print(luc_2050)

cat("\n=== Cumulative LUC emissions at 2050 (Gt CO2) ===\n")
cum_2050 <- glo[glo$variable == "Emissions|CO2|Land|Cumulative|+|Land-use Change" & glo$period == 2050,
                c("ssp", "edge", "value")]
cum_2050 <- cum_2050[order(cum_2050$ssp, cum_2050$edge), ]
print(cum_2050)

cat("\nAll plots saved to:", normalizePath(plot_dir), "\n")
