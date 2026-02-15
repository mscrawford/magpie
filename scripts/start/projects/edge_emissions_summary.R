# |  Summary table of edge-effect emissions in both CO2 and C units
# |  Input: report.rds from 6 runs
# |  Output: Console tables

library(renv)
renv::load(".")

runs <- list.dirs("output", recursive = FALSE, full.names = TRUE)
runs <- sort(runs[grepl("^output/SSP[123]_edge(ON|OFF)_", runs)])

# Extract data for all runs
data_list <- list()
for (r in runs) {
  qu <- readRDS(file.path(r, "report.rds"))
  
  # Extract SSP and edge from folder name
  parts <- strsplit(basename(r), "_")[[1]]
  ssp <- parts[1]
  edge <- parts[2]
  
  # Annual LUC at 2050
  luc_annual <- qu[qu$variable == "Emissions|CO2|Land|+|Land-use Change" & 
                   qu$region == "World" & qu$period == 2050, "value"]
  
  # Cumulative LUC 1995-2050
  luc_cum <- qu[qu$variable == "Emissions|CO2|Land|Cumulative|+|Land-use Change" & 
                qu$region == "World" & qu$period == 2050, "value"]
  
  data_list[[basename(r)]] <- data.frame(
    ssp = ssp,
    edge = edge,
    luc_annual_co2 = luc_annual,
    luc_cum_co2 = luc_cum,
    stringsAsFactors = FALSE
  )
}

# Combine
df <- do.call(rbind, data_list)
rownames(df) <- NULL

# Convert to C
df$luc_annual_c <- df$luc_annual_co2 / (44/12)
df$luc_cum_c <- df$luc_cum_co2 / (44/12)

# Calculate differences
diffs <- data.frame(ssp = character(), annual_co2 = numeric(), annual_c = numeric(),
                    cum_co2 = numeric(), cum_c = numeric(), stringsAsFactors = FALSE)

for (ssp in c("SSP1", "SSP2", "SSP3")) {
  off_row <- df[df$ssp == ssp & df$edge == "edgeOFF", ]
  on_row  <- df[df$ssp == ssp & df$edge == "edgeON", ]
  
  diffs <- rbind(diffs, data.frame(
    ssp = ssp,
    annual_co2 = on_row$luc_annual_co2 - off_row$luc_annual_co2,
    annual_c   = on_row$luc_annual_c - off_row$luc_annual_c,
    cum_co2    = on_row$luc_cum_co2 - off_row$luc_cum_co2,
    cum_c      = on_row$luc_cum_c - off_row$luc_cum_c
  ))
}

# Print tables
cat("\n═══════════════════════════════════════════════════════════\n")
cat("  ANNUAL LUC CO2 EMISSIONS AT 2050\n")
cat("═══════════════════════════════════════════════════════════\n\n")
cat(sprintf("%-8s  %-10s  %12s  %12s\n", "SSP", "Edge", "Mt CO2/yr", "Mt C/yr"))
cat(strrep("─", 47), "\n")
for (i in 1:nrow(df)) {
  cat(sprintf("%-8s  %-10s  %12.0f  %12.0f\n", 
              df$ssp[i], df$edge[i], df$luc_annual_co2[i], df$luc_annual_c[i]))
}

cat("\n═══════════════════════════════════════════════════════════\n")
cat("  EDGE EFFECT Δ (ON - OFF) AT 2050\n")
cat("═══════════════════════════════════════════════════════════\n\n")
cat(sprintf("%-8s  %12s  %12s\n", "SSP", "Mt CO2/yr", "Mt C/yr"))
cat(strrep("─", 37), "\n")
for (i in 1:nrow(diffs)) {
  cat(sprintf("%-8s  %12.0f  %12.0f\n", 
              diffs$ssp[i], diffs$annual_co2[i], diffs$annual_c[i]))
}

cat("\n═══════════════════════════════════════════════════════════\n")
cat("  CUMULATIVE LUC EMISSIONS (1995-2050)\n")
cat("═══════════════════════════════════════════════════════════\n\n")
cat(sprintf("%-8s  %-10s  %12s  %12s\n", "SSP", "Edge", "Gt CO2", "Gt C"))
cat(strrep("─", 47), "\n")
for (i in 1:nrow(df)) {
  cat(sprintf("%-8s  %-10s  %12.1f  %12.1f\n", 
              df$ssp[i], df$edge[i], df$luc_cum_co2[i], df$luc_cum_c[i]))
}

cat("\n═══════════════════════════════════════════════════════════\n")
cat("  CUMULATIVE EDGE EFFECT Δ (ON - OFF)\n")
cat("═══════════════════════════════════════════════════════════\n\n")
cat(sprintf("%-8s  %12s  %12s\n", "SSP", "Gt CO2", "Gt C"))
cat(strrep("─", 37), "\n")
for (i in 1:nrow(diffs)) {
  cat(sprintf("%-8s  %12.1f  %12.1f\n", 
              diffs$ssp[i], diffs$cum_co2[i], diffs$cum_c[i]))
}

cat("\n═══════════════════════════════════════════════════════════\n\n")

cat("Notes:\n")
cat("• Negative values = net carbon sink (removals)\n")
cat("• Edge effects increase emissions (reduce sink) in SSP1/SSP2\n")
cat("• SSP3 shows slight decrease (more deforestation overwhelms edge effect)\n")
cat("• d = 0.25 (25% carbon loss in 100m edge zone)\n")
cat("\n")
