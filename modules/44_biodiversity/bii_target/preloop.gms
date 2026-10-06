*** |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  MAgPIE License Exception, version 1.0 (see LICENSE file).
*** |  Contact: magpie@pik-potsdam.de

* Calculate biome share
i44_biome_share(j,biome44) = 0;
i44_biome_share(j,biome44)$(sum(biome44_2, f44_biome_area(j,biome44_2)) > 0) = 
   f44_biome_area(j,biome44) / sum(biome44_2, f44_biome_area(j,biome44_2));

* Set i44_biome_area_reg
i44_biome_area_reg(i,biome44) = 
  sum((cell(i,j),land), pcm_land(j,land) * i44_biome_share(j,biome44));

* Weight of each biome type and region in the cost for missing BII (experiment of 2026-10-06, not upstream):
* equal by default; with s44_bii_area_weight = 1 the area relative to the mean area of the biome types with area,
* so that the weights average one and a uniform shortfall costs the same under both settings.
p44_bii_cost_weight(i,biome44) = 1;
p44_mean_biome_area = sum((i,biome44), i44_biome_area_reg(i,biome44)) / sum((i,biome44)$(i44_biome_area_reg(i,biome44) > 0), 1);
if(s44_bii_area_weight = 1,
  p44_bii_cost_weight(i,biome44) = i44_biome_area_reg(i,biome44) / p44_mean_biome_area;
);

p44_bii_target(t,i,biome44) = 0;

if (s44_start_year <= sm_fix_SSP2,
  abort "Start year for BII target interpolation has to be greater than sm_fix_SSP2"
);
