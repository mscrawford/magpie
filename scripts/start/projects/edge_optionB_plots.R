# |  Option B comparison plots: SSP1/2/3 × {OFF, INST, SYMM}
# |  Compares edge reporting: instant vs symmetric pipeline (Option B)
# |  Input: report.rds from 9 runs
# |  Output: PDFs in ../output/plots/optionB/
# |  Usage: cd magpie && Rscript scripts/start/projects/edge_optionB_plots.R

library(ggplot2)

cat("=== Option B Comparison Plots ===\n\n")

# --- Locate run folders ---
output_dir <- "output"

find_run <- function(pattern) {
  dirs <- list.dirs(output_dir, recursive = FALSE)
  d <- grep(pattern, dirs, value = TRUE)
  # Only keep runs that have a report.rds
  d <- d[file.exists(file.path(d, "report.rds"))]
  if (length(d) == 0) stop("No completed run found matching: ", pattern)
  d[length(d)]  # latest match
}

run_info <- list(
  list(ssp = "SSP1", edge = "OFF",  pattern = "SSP1_optB_OFF"),
  list(ssp = "SSP1", edge = "INST", pattern = "SSP1_optB_INST"),
  list(ssp = "SSP1", edge = "SYMM", pattern = "SSP1_optB_SYMMv2_"),
  list(ssp = "SSP2", edge = "OFF",  pattern = "SSP2_optB_OFF"),
  list(ssp = "SSP2", edge = "INST", pattern = "SSP2_optB_INST"),
  list(ssp = "SSP2", edge = "SYMM", pattern = "SSP2_optB_SYMMv2_"),
  list(ssp = "SSP3", edge = "OFF",  pattern = "SSP3_optB_OFF"),
  list(ssp = "SSP3", edge = "INST", pattern = "SSP3_optB_INST"),
  list(ssp = "SSP3", edge = "SYMM", pattern = "SSP3_optB_SYMMv2_2")
)

cat("Loading reports...\n")
all_data <- do.call(rbind, lapply(run_info, function(info) {
  run_dir <- find_run(info$pattern)
  rds_path <- file.path(run_dir, "report.rds")
  cat(sprintf("  %s_%s: %s\n", info$ssp, info$edge, basename(run_dir)))
  r <- readRDS(rds_path)
  r$ssp <- info$ssp
  r$edge <- info$edge
  r
}))

all_data$region_name <- all_data$region
glo <- all_data[all_data$region_name == "World", ]

plot_dir <- "../output/plots/optionB"
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

ssp_colors <- c(SSP1 = "#1b9e77", SSP2 = "#d95f02", SSP3 = "#7570b3")
edge_lines <- c(OFF = "dotted", INST = "dashed", SYMM = "solid")
edge_labs  <- c(OFF = "No edge effects", INST = "Instant release", SYMM = "Option B (symmetric)")

# --- Helper ---
plot_ts <- function(data, var, y_lab, title, fname, facet_ssp = FALSE) {
  d <- data[data$variable == var, ]
  if (nrow(d) == 0) { cat("  SKIP:", var, "\n"); return(invisible(NULL)) }
  p <- ggplot(d, aes(x = period, y = value, color = ssp, linetype = edge)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = ssp_colors) +
    scale_linetype_manual(values = edge_lines, labels = edge_labs) +
    labs(title = title, x = "Year", y = y_lab, color = "SSP", linetype = "Edge mode") +
    theme_minimal(base_size = 14) + theme(legend.position = "bottom")
  if (facet_ssp) p <- p + facet_wrap(~ ssp, nrow = 1)
  ggsave(file.path(plot_dir, fname), p, width = if (facet_ssp) 14 else 10, height = 6)
  cat("  Saved:", fname, "\n")
}

# =============================================================================
# P1: Edge degradation emissions — THE KEY COMPARISON
# =============================================================================
cat("\nP1: Edge degradation emissions\n")
plot_ts(glo,
  "Emissions|CO2|Land|Land-use Change|Forest degradation|+|Edge degradation",
  "Mt CO2/yr", "Edge Degradation Emissions: INST vs SYMM (Option B)",
  "edge_degrad_emissions.pdf", facet_ssp = TRUE)

# =============================================================================
# P2: Edge degradation stock
# =============================================================================
cat("P2: Edge degradation stock\n")
plot_ts(glo,
  "Emissions|CO2|Land|Land-use Change|Forest degradation|Edge degradation|Stock",
  "Mt CO2", "Edge Carbon Stock (equilibrium loss × density × area)",
  "edge_degrad_stock.pdf", facet_ssp = TRUE)

# =============================================================================
# P3: Total forest degradation (shifting cult + edge)
# =============================================================================
cat("P3: Forest degradation total\n")
plot_ts(glo,
  "Emissions|CO2|Land|Land-use Change|+|Forest degradation",
  "Mt CO2/yr", "Total Forest Degradation (Shifting Cultivation + Edge)",
  "forest_degradation_total.pdf", facet_ssp = TRUE)

# =============================================================================
# P4: Total LUC emissions
# =============================================================================
cat("P4: LUC emissions\n")
plot_ts(glo,
  "Emissions|CO2|Land|+|Land-use Change",
  "Mt CO2/yr", "Total CO2 from Land-Use Change",
  "luc_emissions.pdf")

# =============================================================================
# P5: Cumulative LUC emissions
# =============================================================================
cat("P5: Cumulative LUC\n")
plot_ts(glo,
  "Emissions|CO2|Land|Cumulative|+|Land-use Change",
  "Gt CO2", "Cumulative CO2 from Land-Use Change",
  "cumulative_luc.pdf")

# =============================================================================
# P6: Land-use outcomes (should be IDENTICAL for INST and SYMM)
# =============================================================================
cat("P6: Forest area (verify INST = SYMM)\n")
plot_ts(glo,
  "Resources|Land Cover|+|Forest",
  "Mha", "Global Forest Area (INST and SYMM should overlap)",
  "forest_area_verify.pdf")

# =============================================================================
# P7: Vegetation carbon
# =============================================================================
cat("P7: Vegetation carbon\n")
plot_ts(glo,
  "Resources|Carbon|+|Vegetation",
  "GtC", "Global Vegetation Carbon Stock",
  "vegc_stock.pdf")

# =============================================================================
# P8: Difference (INST - OFF) vs (SYMM - OFF) for edge emissions
# =============================================================================
cat("P8: INST vs SYMM difference from OFF\n")
edge_var <- "Emissions|CO2|Land|Land-use Change|Forest degradation|+|Edge degradation"
d_edge <- glo[glo$variable == edge_var, c("period", "ssp", "edge", "value")]

if (nrow(d_edge) > 0) {
  d_inst <- d_edge[d_edge$edge == "INST", c("period", "ssp", "value")]
  d_symm <- d_edge[d_edge$edge == "SYMM", c("period", "ssp", "value")]
  d_comp <- merge(d_inst, d_symm, by = c("period", "ssp"), suffixes = c("_inst", "_symm"))
  d_comp$diff <- d_comp$value_symm - d_comp$value_inst

  p8 <- ggplot(d_comp, aes(x = period, y = diff, color = ssp)) +
    geom_line(linewidth = 1.2) +
    geom_hline(yintercept = 0, linetype = "dotted", color = "grey40") +
    scale_color_manual(values = ssp_colors) +
    labs(title = "Edge Emissions: SYMM minus INST (Option B - Instant)",
         subtitle = "Negative = SYMM reports less emissions. Should converge to 0 over ~3τ = 39yr",
         x = "Year", y = "Mt CO2/yr", color = "SSP") +
    theme_minimal(base_size = 14) + theme(legend.position = "bottom")
  ggsave(file.path(plot_dir, "edge_symm_minus_inst.pdf"), p8, width = 10, height = 6)
  cat("  Saved: edge_symm_minus_inst.pdf\n")
}

# =============================================================================
# P9: Cumulative edge difference
# =============================================================================
cat("P9: Cumulative SYMM vs INST edge emissions\n")
if (nrow(d_edge) > 0) {
  # Compute cumulative for INST and SYMM
  cum_data <- do.call(rbind, lapply(c("SSP1", "SSP2", "SSP3"), function(s) {
    do.call(rbind, lapply(c("INST", "SYMM"), function(e) {
      dd <- d_edge[d_edge$ssp == s & d_edge$edge == e, ]
      dd <- dd[order(dd$period), ]
      if (nrow(dd) < 2) return(NULL)
      dt <- diff(c(dd$period[1] - 5, dd$period))
      dd$cumul <- cumsum(dd$value * dt) / 1000  # Gt CO2
      dd
    }))
  }))

  p9 <- ggplot(cum_data, aes(x = period, y = cumul, color = ssp, linetype = edge)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = ssp_colors) +
    scale_linetype_manual(values = c(INST = "dashed", SYMM = "solid"),
                          labels = c(INST = "Instant", SYMM = "Option B")) +
    labs(title = "Cumulative Edge Degradation Emissions",
         subtitle = "INST and SYMM should converge as τ-lag settles",
         x = "Year", y = "Gt CO2 (cumulative)", color = "SSP", linetype = "Mode") +
    theme_minimal(base_size = 14) + theme(legend.position = "bottom")
  ggsave(file.path(plot_dir, "cumulative_edge_inst_vs_symm.pdf"), p9, width = 10, height = 6)
  cat("  Saved: cumulative_edge_inst_vs_symm.pdf\n")
}

# =============================================================================
# P10: LUC decomposition for SSP2 (INST vs SYMM side by side)
# =============================================================================
cat("P10: LUC decomposition SSP2\n")
decomp_vars <- c(
  "Emissions|CO2|Land|Land-use Change|+|Deforestation",
  "Emissions|CO2|Land|Land-use Change|+|Forest degradation",
  "Emissions|CO2|Land|Land-use Change|+|Other land conversion",
  "Emissions|CO2|Land|Land-use Change|+|Regrowth"
)
d10 <- glo[glo$variable %in% decomp_vars & glo$ssp == "SSP2" & glo$edge %in% c("INST", "SYMM"), ]
d10$component <- sub("Emissions\\|CO2\\|Land\\|Land-use Change\\|\\+\\|", "", d10$variable)

if (nrow(d10) > 0) {
  p10 <- ggplot(d10, aes(x = period, y = value, fill = component)) +
    geom_area(alpha = 0.7) +
    facet_wrap(~ edge, labeller = labeller(edge = c(INST = "Instant Release", SYMM = "Option B Symmetric"))) +
    labs(title = "SSP2: LUC Emission Components — INST vs SYMM",
         x = "Year", y = "Mt CO2/yr", fill = "Component") +
    theme_minimal(base_size = 13) + theme(legend.position = "bottom") +
    guides(fill = guide_legend(ncol = 2))
  ggsave(file.path(plot_dir, "luc_decomp_ssp2_inst_vs_symm.pdf"), p10, width = 12, height = 7)
  cat("  Saved: luc_decomp_ssp2_inst_vs_symm.pdf\n")
}

# =============================================================================
# P11: Verify land-use identity (INST forest area - SYMM forest area)
# =============================================================================
cat("P11: Verify INST = SYMM land use\n")
forest_var <- "Resources|Land Cover|+|Forest"
d_forest <- glo[glo$variable == forest_var & glo$edge %in% c("INST", "SYMM"),
                c("period", "ssp", "edge", "value")]
d_fi <- d_forest[d_forest$edge == "INST", c("period", "ssp", "value")]
d_fs <- d_forest[d_forest$edge == "SYMM", c("period", "ssp", "value")]
d_fcomp <- merge(d_fi, d_fs, by = c("period", "ssp"), suffixes = c("_inst", "_symm"))
d_fcomp$diff_mha <- d_fcomp$value_symm - d_fcomp$value_inst

if (nrow(d_fcomp) > 0) {
  max_diff <- max(abs(d_fcomp$diff_mha), na.rm = TRUE)
  cat(sprintf("  Max forest area diff (INST vs SYMM): %.4f Mha\n", max_diff))
  if (max_diff < 0.01) {
    cat("  ✓ VERIFIED: INST and SYMM produce identical land-use outcomes\n")
  } else {
    cat("  ⚠ WARNING: INST and SYMM differ by > 0.01 Mha!\n")
  }
}

# =============================================================================
# Summary
# =============================================================================
cat("\n=== Summary: Edge emissions at key years ===\n")
edge_summary <- glo[glo$variable == edge_var & glo$period %in% c(1995, 2020, 2050, 2100),
                     c("period", "ssp", "edge", "value")]
if (nrow(edge_summary) > 0) {
  edge_summary <- edge_summary[order(edge_summary$ssp, edge_summary$period, edge_summary$edge), ]
  for (s in c("SSP1", "SSP2", "SSP3")) {
    cat(sprintf("\n%s:\n", s))
    cat(sprintf("  %8s %10s %10s\n", "Year", "INST", "SYMM"))
    for (yr in c(1995, 2020, 2050, 2100)) {
      v_i <- edge_summary$value[edge_summary$ssp == s & edge_summary$edge == "INST" & edge_summary$period == yr]
      v_s <- edge_summary$value[edge_summary$ssp == s & edge_summary$edge == "SYMM" & edge_summary$period == yr]
      if (length(v_i) > 0 && length(v_s) > 0) {
        cat(sprintf("  %8d %10.1f %10.1f MtCO2/yr\n", yr, v_i, v_s))
      }
    }
  }
}

cat(sprintf("\nAll plots saved to: %s\n", normalizePath(plot_dir, mustWork = FALSE)))

# =============================================================================
# P12: Shifting cultivation comparison (SSP3 only)
# =============================================================================
cat("\nP12: Shifting cultivation comparison (SSP3)\n")
shiftON_dir <- tryCatch(find_run("SSP3_optB_SYMMv2_shiftON"), error = function(e) NULL)
if (!is.null(shiftON_dir)) {
  r_shift <- readRDS(file.path(shiftON_dir, "report.rds"))
  r_shift$ssp <- "SSP3"
  r_shift$edge <- "SYMM+shiftON"
  r_shift$region_name <- r_shift$region
  glo_shift <- r_shift[r_shift$region_name == "World", ]

  # Combine SSP3 runs for comparison
  ssp3_runs <- rbind(
    glo[glo$ssp == "SSP3", ],
    glo_shift
  )

  edge_lines_ext <- c(OFF = "dotted", INST = "dashed", SYMM = "solid", `SYMM+shiftON` = "twodash")
  edge_labs_ext <- c(OFF = "No edge", INST = "Instant", SYMM = "Option B", `SYMM+shiftON` = "Option B + shift cult ON")

  # P12a: Total forest degradation
  d12a <- ssp3_runs[ssp3_runs$variable == "Emissions|CO2|Land|Land-use Change|+|Forest degradation", ]
  if (nrow(d12a) > 0) {
    p12a <- ggplot(d12a, aes(x = period, y = value, linetype = edge, color = edge)) +
      geom_line(linewidth = 1.2) +
      scale_linetype_manual(values = edge_lines_ext, labels = edge_labs_ext) +
      scale_color_manual(values = c(OFF = "grey60", INST = "#e41a1c", SYMM = "#377eb8", `SYMM+shiftON` = "#4daf4a"),
                         labels = edge_labs_ext) +
      labs(title = "SSP3: Forest Degradation Emissions",
           subtitle = "Comparing persistent vs fading shifting cultivation",
           x = "Year", y = "Mt CO2/yr", linetype = "Mode", color = "Mode") +
      theme_minimal(base_size = 14) + theme(legend.position = "bottom")
    ggsave(file.path(plot_dir, "ssp3_shiftcult_degradation.pdf"), p12a, width = 10, height = 6)
    cat("  Saved: ssp3_shiftcult_degradation.pdf\n")
  }

  # P12b: Shifting cultivation component only
  shift_var <- "Emissions|CO2|Land|Land-use Change|Forest degradation|+|Shifting cultivation"
  d12b <- ssp3_runs[ssp3_runs$variable == shift_var, ]
  if (nrow(d12b) > 0) {
    p12b <- ggplot(d12b, aes(x = period, y = value, linetype = edge, color = edge)) +
      geom_line(linewidth = 1.2) +
      scale_linetype_manual(values = edge_lines_ext, labels = edge_labs_ext) +
      scale_color_manual(values = c(OFF = "grey60", INST = "#e41a1c", SYMM = "#377eb8", `SYMM+shiftON` = "#4daf4a"),
                         labels = edge_labs_ext) +
      labs(title = "SSP3: Shifting Cultivation Emissions Only",
           subtitle = "s35_forest_damage=1 (constant) vs =2 (faded out by 2050)",
           x = "Year", y = "Mt CO2/yr", linetype = "Mode", color = "Mode") +
      theme_minimal(base_size = 14) + theme(legend.position = "bottom")
    ggsave(file.path(plot_dir, "ssp3_shiftcult_only.pdf"), p12b, width = 10, height = 6)
    cat("  Saved: ssp3_shiftcult_only.pdf\n")
  }

  # P12c: Edge degradation component
  d12c <- ssp3_runs[ssp3_runs$variable == edge_var, ]
  if (nrow(d12c) > 0) {
    p12c <- ggplot(d12c, aes(x = period, y = value, linetype = edge, color = edge)) +
      geom_line(linewidth = 1.2) +
      scale_linetype_manual(values = edge_lines_ext, labels = edge_labs_ext) +
      scale_color_manual(values = c(OFF = "grey60", INST = "#e41a1c", SYMM = "#377eb8", `SYMM+shiftON` = "#4daf4a"),
                         labels = edge_labs_ext) +
      labs(title = "SSP3: Edge Degradation Emissions",
           subtitle = "Does persistent shifting cultivation change edge dynamics?",
           x = "Year", y = "Mt CO2/yr", linetype = "Mode", color = "Mode") +
      theme_minimal(base_size = 14) + theme(legend.position = "bottom")
    ggsave(file.path(plot_dir, "ssp3_shiftcult_edge.pdf"), p12c, width = 10, height = 6)
    cat("  Saved: ssp3_shiftcult_edge.pdf\n")
  }

  # P12d: Total LUC emissions
  d12d <- ssp3_runs[ssp3_runs$variable == "Emissions|CO2|Land|+|Land-use Change", ]
  if (nrow(d12d) > 0) {
    p12d <- ggplot(d12d, aes(x = period, y = value, linetype = edge, color = edge)) +
      geom_line(linewidth = 1.2) +
      scale_linetype_manual(values = edge_lines_ext, labels = edge_labs_ext) +
      scale_color_manual(values = c(OFF = "grey60", INST = "#e41a1c", SYMM = "#377eb8", `SYMM+shiftON` = "#4daf4a"),
                         labels = edge_labs_ext) +
      labs(title = "SSP3: Total LUC Emissions",
           subtitle = "Impact of persistent shifting cultivation on total land-use change",
           x = "Year", y = "Mt CO2/yr", linetype = "Mode", color = "Mode") +
      theme_minimal(base_size = 14) + theme(legend.position = "bottom")
    ggsave(file.path(plot_dir, "ssp3_shiftcult_luc_total.pdf"), p12d, width = 10, height = 6)
    cat("  Saved: ssp3_shiftcult_luc_total.pdf\n")
  }

  # Summary table
  cat("\n=== SSP3 Shifting Cultivation Summary ===\n")
  for (v in c(shift_var, edge_var, "Emissions|CO2|Land|Land-use Change|+|Forest degradation")) {
    cat(sprintf("\n%s:\n", sub(".*\\|", "", v)))
    for (yr in c(2020, 2050, 2100)) {
      vals <- sapply(c("SYMM", "SYMM+shiftON"), function(e) {
        x <- ssp3_runs$value[ssp3_runs$variable == v & ssp3_runs$edge == e & ssp3_runs$period == yr]
        if (length(x) == 0) NA else x
      })
      cat(sprintf("  %d: SYMM=%.1f  shiftON=%.1f  diff=%.1f MtCO2/yr\n",
                  yr, vals[1], vals[2], vals[2] - vals[1]))
    }
  }
} else {
  cat("  SKIP: SSP3_optB_SYMMv2_shiftON not found yet\n")
}

cat("\n=== Done ===\n")
