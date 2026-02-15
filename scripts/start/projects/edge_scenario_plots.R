# |  Plot comparison of 6 scenario runs (3 SSPs × 2 edge settings)
# |  Input: report.rds from each run folder
# |  Output: PDFs in output/plots/

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
reports <- lapply(runs, function(d) {
  r <- readRDS(file.path(d, "report.rds"))
  r
})

# Combine into one data frame
all_data <- do.call(rbind, lapply(names(reports), function(nm) {
  r <- reports[[nm]]
  parts <- strsplit(nm, "_")[[1]]
  r$ssp <- parts[1]
  r$edge <- parts[2]
  r$run_label <- nm
  r
}))

# Use only global aggregates (region 13 = GLO in MAgPIE with 12 regions)
# Check region naming
cat("Regions:", paste(unique(all_data$region), collapse=", "), "\n")

# Region mapping for MAgPIE h12
region_map <- c(
  "1" = "CAZ", "2" = "CHA", "3" = "EUR", "4" = "IND", "5" = "JPN",
  "6" = "LAM", "7" = "MEA", "8" = "NEU", "9" = "OAS", "10" = "REF",
  "11" = "SSA", "12" = "USA", "13" = "GLO"
)
# Region names are already text in this report format
all_data$region_name <- all_data$region

glo <- all_data[all_data$region_name == "World", ]

plot_dir <- "../output/plots"
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

# --- Helper: extract and plot a variable ---
plot_var <- function(data, var_name, y_label, title, filename) {
  d <- data[data$variable == var_name, ]
  if (nrow(d) == 0) {
    cat(sprintf("  WARNING: Variable '%s' not found\n", var_name))
    return(invisible(NULL))
  }
  d$linetype <- ifelse(d$edge == "ON", "solid", "dashed")

  p <- ggplot(d, aes(x = period, y = value, color = ssp, linetype = edge)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = c(SSP1 = "#1b9e77", SSP2 = "#d95f02", SSP3 = "#7570b3")) +
    scale_linetype_manual(values = c(OFF = "dashed", ON = "solid"),
                          labels = c(OFF = "No edge effects", ON = "With edge effects (d=0.25)")) +
    labs(title = title, x = "Year", y = y_label, color = "SSP", linetype = "Edge effects") +
    theme_minimal(base_size = 14) +
    theme(legend.position = "bottom")

  ggsave(file.path(plot_dir, filename), p, width = 10, height = 6)
  cat(sprintf("  Saved: %s\n", filename))
}

# --- P1: Total forest area ---
cat("\nPlot 1: Forest area\n")
plot_var(glo, "Resources|Land Cover|+|Forest", "Mha",
         "Global Forest Area by SSP and Edge Effects", "scenario_forest_area.pdf")

# --- P2: Primary + secondary forest separately ---
cat("Plot 2: Primary vs secondary forest\n")
vars_forest <- c(
  "Resources|Land Cover|Forest|Natural Forest|+|Primary Forest",
  "Resources|Land Cover|Forest|Natural Forest|+|Secondary Forest"
)
d_forest <- glo[glo$variable %in% vars_forest, ]
d_forest$forest_type <- ifelse(grepl("Primary", d_forest$variable), "Primary", "Secondary")

p2 <- ggplot(d_forest, aes(x = period, y = value, color = ssp, linetype = edge)) +
  geom_line(linewidth = 0.9) +
  facet_wrap(~ forest_type, scales = "free_y") +
  scale_color_manual(values = c(SSP1 = "#1b9e77", SSP2 = "#d95f02", SSP3 = "#7570b3")) +
  scale_linetype_manual(values = c(OFF = "dashed", ON = "solid"),
                        labels = c(OFF = "No edge effects", ON = "With edge effects")) +
  labs(title = "Primary and Secondary Forest Area", x = "Year", y = "Mha",
       color = "SSP", linetype = "Edge effects") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")
ggsave(file.path(plot_dir, "scenario_forest_primary_secondary.pdf"), p2, width = 12, height = 6)
cat("  Saved: scenario_forest_primary_secondary.pdf\n")

# --- P3: Vegetation carbon stocks ---
cat("Plot 3: Vegetation carbon\n")
plot_var(glo, "Resources|Carbon|+|Vegetation", "Gt C",
         "Global Vegetation Carbon Stock", "scenario_vegc_stock.pdf")

# Also total carbon
plot_var(glo, "Resources|Carbon", "Gt C",
         "Global Total Carbon Stock (Veg + Litter + Soil)", "scenario_total_carbon.pdf")

# --- P4: Difference plots (ON minus OFF) ---
cat("Plot 4: Differences\n")
key_vars <- c(
  "Resources|Land Cover|+|Forest",
  "Resources|Carbon|+|Vegetation",
  "Resources|Carbon",
  "Resources|Land Cover|Forest|Natural Forest|+|Primary Forest"
)

diff_data <- do.call(rbind, lapply(c("SSP1", "SSP2", "SSP3"), function(s) {
  on  <- glo[glo$ssp == s & glo$edge == "ON", ]
  off <- glo[glo$ssp == s & glo$edge == "OFF", ]
  do.call(rbind, lapply(key_vars, function(v) {
    d_on  <- on[on$variable == v, c("period", "value")]
    d_off <- off[off$variable == v, c("period", "value")]
    merged <- merge(d_on, d_off, by = "period", suffixes = c("_on", "_off"))
    merged$diff <- merged$value_on - merged$value_off
    merged$pct_diff <- 100 * merged$diff / abs(merged$value_off)
    merged$ssp <- s
    merged$variable <- v
    merged[, c("period", "diff", "pct_diff", "ssp", "variable")]
  }))
}))

# Short variable labels
var_labels <- c(
  "Resources|Land Cover|+|Forest" = "Forest Area (Mha)",
  "Resources|Carbon|+|Vegetation" = "Vegetation Carbon (Gt C)",
  "Resources|Carbon" = "Total Carbon (Gt C)",
  "Resources|Land Cover|Forest|Natural Forest|+|Primary Forest" = "Primary Forest (Mha)"
)
diff_data$var_label <- var_labels[diff_data$variable]

p4a <- ggplot(diff_data, aes(x = period, y = pct_diff, color = ssp)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
  facet_wrap(~ var_label, scales = "free_y") +
  scale_color_manual(values = c(SSP1 = "#1b9e77", SSP2 = "#d95f02", SSP3 = "#7570b3")) +
  labs(title = "Effect of Edge Effects (ON - OFF, % change)",
       x = "Year", y = "% difference (ON vs OFF)", color = "SSP") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")
ggsave(file.path(plot_dir, "scenario_edge_effect_pct_diff.pdf"), p4a, width = 12, height = 8)
cat("  Saved: scenario_edge_effect_pct_diff.pdf\n")

p4b <- ggplot(diff_data, aes(x = period, y = diff, color = ssp)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
  facet_wrap(~ var_label, scales = "free_y") +
  scale_color_manual(values = c(SSP1 = "#1b9e77", SSP2 = "#d95f02", SSP3 = "#7570b3")) +
  labs(title = "Effect of Edge Effects (ON - OFF, absolute)",
       x = "Year", y = "Absolute difference (ON - OFF)", color = "SSP") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")
ggsave(file.path(plot_dir, "scenario_edge_effect_abs_diff.pdf"), p4b, width = 12, height = 8)
cat("  Saved: scenario_edge_effect_abs_diff.pdf\n")

# --- P5: Regional forest area (LAM, SSA, OAS focus) ---
cat("Plot 5: Regional forest area\n")
focus_regions <- c("LAM", "SSA", "OAS", "CHA", "CAZ")
reg <- all_data[all_data$region_name %in% focus_regions &
                all_data$variable == "Resources|Land Cover|+|Forest", ]

p5 <- ggplot(reg, aes(x = period, y = value, color = ssp, linetype = edge)) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~ region_name, scales = "free_y", nrow = 1) +
  scale_color_manual(values = c(SSP1 = "#1b9e77", SSP2 = "#d95f02", SSP3 = "#7570b3")) +
  scale_linetype_manual(values = c(OFF = "dashed", ON = "solid"),
                        labels = c(OFF = "No edge", ON = "Edge (d=0.25)")) +
  labs(title = "Forest Area by Region", x = "Year", y = "Mha",
       color = "SSP", linetype = "Edge") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")
ggsave(file.path(plot_dir, "scenario_regional_forest.pdf"), p5, width = 16, height = 5)
cat("  Saved: scenario_regional_forest.pdf\n")

# --- P6: Regional vegetation carbon ---
cat("Plot 6: Regional vegetation carbon\n")
reg_c <- all_data[all_data$region_name %in% focus_regions &
                  all_data$variable == "Resources|Carbon|+|Vegetation", ]

p6 <- ggplot(reg_c, aes(x = period, y = value, color = ssp, linetype = edge)) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~ region_name, scales = "free_y", nrow = 1) +
  scale_color_manual(values = c(SSP1 = "#1b9e77", SSP2 = "#d95f02", SSP3 = "#7570b3")) +
  scale_linetype_manual(values = c(OFF = "dashed", ON = "solid"),
                        labels = c(OFF = "No edge", ON = "Edge (d=0.25)")) +
  labs(title = "Vegetation Carbon by Region", x = "Year", y = "Gt C",
       color = "SSP", linetype = "Edge") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")
ggsave(file.path(plot_dir, "scenario_regional_vegc.pdf"), p6, width = 16, height = 5)
cat("  Saved: scenario_regional_vegc.pdf\n")

# --- P7: GHG emission costs ---
cat("Plot 7: GHG emission costs\n")
plot_var(glo, "Costs|+|GHG Emissions", "billion US$2005/yr",
         "GHG Emission Costs by SSP", "scenario_ghg_costs.pdf")

# --- Summary table ---
cat("\n========== SUMMARY TABLE ==========\n")
cat("Forest area and vegetation carbon at y2050:\n\n")
sum_vars <- c("Resources|Land Cover|+|Forest", "Resources|Carbon|+|Vegetation")
for (v in sum_vars) {
  cat(sprintf("--- %s ---\n", v))
  d <- glo[glo$variable == v & glo$period == 2050, ]
  for (s in c("SSP1", "SSP2", "SSP3")) {
    off_val <- d$value[d$ssp == s & d$edge == "OFF"]
    on_val  <- d$value[d$ssp == s & d$edge == "ON"]
    pct <- 100 * (on_val - off_val) / abs(off_val)
    cat(sprintf("  %s: OFF=%.1f, ON=%.1f, diff=%.2f%%\n", s, off_val, on_val, pct))
  }
  cat("\n")
}

cat("\nAll plots saved to:", normalizePath(plot_dir), "\n")
