# |  (C) 2008-2021 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# --------------------------------------------------------------
# description: extract inms-report in mif format from run
# comparison script: FALSE
# ---------------------------------------------------------------

#Version 1.00 - Benjamin Leon Bodirsky
# 1.00: first working version

library(lucode2)
library(magpie4)
library(magpiesets)
library(iamc)
library(gms)

message("Start INMS regional reporting runscript")

############################# BASIC CONFIGURATION #######################################

if (!exists("source_include")) {

  title       <- NULL
  outputdir   <- NULL

  # Define arguments that can be read from command line
  readArgs("outputdir", "title")

}

#########################################################################################

message("Script started for output directory: ", outputdir)
cfg <- gms::loadConfig(file.path(outputdir, "config.yml"))
title <- cfg$title

message("Scenario title: ", title)

filename <- file.path(outputdir, paste0("report_", title, ".mif"))
gdx <- file.path(outputdir, "fulldata.gdx")

a <- getReportINMS(gdx, file = filename, scenario = title, dir = outputdir)
mif <- read.report(filename)

missingyears = function(x) {
  history = paste0("y", 1965 + ((0:5) * 5))
  x[[1]][[1]] <- time_interpolate(x[[1]][[1]],
                                  interpolated_year = c(history, paste0("y", 2005 + ((0:9) * 10))),
                                  integrate_interpolated_years = TRUE)
  x[[1]][[1]][, history, ] = 0
  return(x)
}

a = missingyears(mif)

write.reportProject(a, mapping = "mapping_inms.csv", file = file.path(outputdir, "report_inms.mif"))

warnings()
