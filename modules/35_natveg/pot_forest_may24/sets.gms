*** |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  MAgPIE License Exception, version 1.0 (see LICENSE file).
*** |  Contact: magpie@pik-potsdam.de

sets

* The disturbance classes carried by f35_forest_lost_share. mrland restricts the driver
* product to classes that (a) leave the land as forest, (b) MAgPIE does not decide
* endogenously, and (c) are land use rather than natural disturbance. Only shifting
* cultivation qualifies; wildfire and other natural disturbances fail (c), because the
* loss booked here is reported as land-use-change CO2. The remaining classes are
* published as validation data by mrvalidation::calcValidTreeCoverLoss instead.
* overall is the FAO FRA 2020 fire series and is loaded but never read.
  driver_source Source of forest disturbance
  / overall, shifting_cultivation /

* Note: with only one operative class, s35_forest_damage = 3 computes the same
* disturbance as s35_forest_damage = 1. The subset is kept so that re-admitting a
* class is a one-line change here and in mrland::calcForestFireLoss.
  combined_loss(driver_source) Combined loss from disturbances not modelled endogenously
  / shifting_cultivation /

  pol35 Land protection policy
  / none, npi, ndc /

  pol_stock35 Land types for land protection policies
  / forest, other /

  othertype35 Other land types
  / othernat, youngsecdf /

  shock_scen Scenario name of forest carbon shock
  / none, 002lin2030,004lin2030,008lin2030,016lin2030
   /

;
