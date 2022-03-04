# |  (C) 2008-2022 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# --------------------------------------------------------------
# description: Create INMS output dataset
# comparison script: FALSE
# ---------------------------------------------------------------

# Version 1.00 - Benjamin Leon Bodirsky
# Version 2.00 - Michael Crawford

library(gms)
library(magpie4)

message("Starting INMS grid-level output runscript")

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

message("Generating grid-level INMS output for the run: ", title)
gdx <- file.path(outputdir, "fulldata.gdx")

baseDir <- getwd()
INMSOutputDir <- file.path(baseDir, "output", "INMS_Reports")
if (!dir.exists(INMSOutputDir)) {
  dir.create(INMSOutputDir)
}

out <- getReportGridINMS(gdx = gdx, reportOutputDir = INMSOutputDir, magpieOutputDir = outputdir, scenario = title)
