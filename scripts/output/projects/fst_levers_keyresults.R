# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# Standalone analysis for the 5-factor fst_levers design (25 runs).
# Produces every figure the deck needs, plus a CSV behind each one.
#
#   Rscript --vanilla scripts/output/projects/fst_levers_keyresults.R
#   python3 scripts/output/projects/fst_levers_keyresults_deck.py
#
# (--vanilla because the PC's renv project library is not hydrated; the system
# library has ggplot2/dplyr/tidyr. On the cluster, plain Rscript is fine.)
#
# Reads each run's precomputed report.rds - NOT the gdx: same numbers, seconds
# instead of ~45 min. The 2^k decomposition algebra is reused from
# fst_levers_decompose.R (unit-tested, 30 assertions) rather than re-derived.
#
# THREE GUARDS THAT SHAPE EVERYTHING BELOW:
#
# 1. Factor levels are parsed by SPLITTING the run name on "_", never by regex.
#    The 2^4-era plotter used grepl("^Protect")/grepl("^NoProtect"), which returns
#    NA for every name in this design (they all start CPon/CPoff) - and "_NoProt_"
#    contains "Prot", so a naive regex silently mislabels the control arm.
#
# 2. The 4 infeasible corners (CPon_BioOn_*_TCbau) are EXCLUDED, never zeroed.
#    Any decomposition term whose inclusion-exclusion sum touches one comes back
#    NA and is drawn as an explicit gap.
#
# 3. A missing outcome is a HARD STOP, not a warning. Two variable names
#    inherited from the 2^4 plotter are absent from these report.rds and produced
#    silent NaN bars before this guard existed.

suppressMessages({ library(ggplot2); library(dplyr); library(tidyr) })
source("scripts/output/projects/fst_levers_decompose.R")

YEAR <- 2100
OUT  <- "output/fst_levers_keyresults"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# ---- 1. discover runs + parse the 5 factors ---------------------------------

runs <- list.files("output", pattern = "^(BAU_TCendo|CP(on|off)_Bio(On|Off)_(Prot|NoProt)_Diet(On|Off)_TC(endo|bau))$")
if (!length(runs)) stop("no fst_levers run dirs under output/")

parseRun <- function(title) {
  tk <- strsplit(title, "_", fixed = TRUE)[[1]]
  if (identical(tk[1], "BAU"))
    return(data.frame(title = title, cell = "BAU", cp = NA, bio = NA, prot = NA,
                      diet = NA, tc = ifelse(tk[2] == "TCendo", "on", "off"),
                      tc_state = tk[2], is_policy = FALSE, stringsAsFactors = FALSE))
  stopifnot(length(tk) == 5L)
  data.frame(title = title, cell = paste(tk[1:4], collapse = "_"),
             cp   = ifelse(tk[1] == "CPon",   "on", "off"),
             bio  = ifelse(tk[2] == "BioOn",  "on", "off"),
             prot = ifelse(tk[3] == "Prot",   "on", "off"),
             diet = ifelse(tk[4] == "DietOn", "on", "off"),
             tc   = ifelse(tk[5] == "TCendo", "on", "off"),   # "on" = TC available
             tc_state = tk[5], is_policy = TRUE, stringsAsFactors = FALSE)
}
design <- do.call(rbind, lapply(runs, parseRun))

# ---- 2. feasibility: modelstat, zeros NOT filtered --------------------------
feasOf <- function(title) {
  f <- file.path("output", title, "runstatistics.rda")
  if (!file.exists(f)) return(NA)
  e <- new.env(); if (inherits(try(load(f, envir = e), silent = TRUE), "try-error")) return(NA)
  ms <- suppressWarnings(as.numeric(e$stats$modelstat))
  if (!length(ms)) return(NA)
  all(ms %in% c(2, 7))
}
design$feasible <- vapply(design$title, feasOf, logical(1))
message(sprintf("runs: %d | feasible: %d | infeasible: %d", nrow(design),
                sum(design$feasible %in% TRUE), sum(design$feasible %in% FALSE)))
if (any(design$feasible %in% FALSE))
  message("  excluded: ", paste(design$title[design$feasible %in% FALSE], collapse = ", "))

# ---- 3. outcomes from report.rds, ALL years --------------------------------
# Two names from the 2^4 plotter are STALE for these runs and yield nothing:
#   "Biodiversity|BII"                       -> "SDG|SDG15|Terrestrial biodiversity"
#   "Resources|Nitrogen|Pollution|Surplus"   -> sum of the cropland + pasture
#                                               budget Nutrient Surplus terms
# The nitrogen indicator is therefore NARROWER in scope than the retired one
# (no AWM / non-agricultural / end-of-life terms). Not interchangeable with June.
#
# CO2: LAND-USE CHANGE, not the total land flux. "Emissions|CO2|Land" =
# "...|+|Land-use Change" + "...|+|Indirect", and the indirect term is EXOGENOUS
# here - it is bit-identical in all 21 feasible runs at all 18 years (asserted
# below), a constant -5860 Mt CO2/yr at 2100. It therefore adds nothing to any
# contrast (it cancels in every delta) while dominating every LEVEL plot: it is
# 60-140% of the bar height and it flips the reported sign, so the total reads as
# a 4-10 Gt/yr sink in every scenario and the policy signal becomes a sliver on
# top of a constant. Land-use change CO2 is the anthropogenic flux the levers
# actually move, and it is what the sibling yield_gap plotter already reported.
OUTCOME_VARS <- list(
  "Cropland+pasture N surplus (Mt Nr/yr)" =
    c("Resources|Nitrogen|Cropland Budget|Balance|+|Nutrient Surplus",
      "Resources|Nitrogen|Pasture Budget|Balance|+|Nutrient Surplus"),
  "Land-use change CO2 (Mt CO2/yr)"  = "Emissions|CO2|Land|+|Land-use Change",
  "Cropland (Mha)"                   = "Resources|Land Cover|+|Cropland",
  "Terrestrial biodiversity (index)" = "SDG|SDG15|Terrestrial biodiversity",
  "Total forest (Mha)"               = "Resources|Land Cover|Forest|+|Natural Forest",
  "Water withdrawal (km3/yr)"        = "Resources|Water|Withdrawal|Agriculture",
  "Food price index"                 = "Prices|Food Expenditure Index",
  "Bioenergy area (Mha)"             = "Resources|Land Cover|Cropland|Croparea|+|Bioenergy crops")

BOUNDARY <- c("Cropland+pasture N surplus (Mt Nr/yr)" = "Nitrogen",
              "Land-use change CO2 (Mt CO2/yr)"       = "Climate",
              "Cropland (Mha)"                        = "Land",
              "Terrestrial biodiversity (index)"      = "Biodiversity")
SUPPORTING <- setdiff(names(OUTCOME_VARS), names(BOUNDARY))
# Desired direction: lower is better everywhere except the biodiversity index.
DESIRED <- setNames(rep(-1, length(OUTCOME_VARS)), names(OUTCOME_VARS))
DESIRED["Terrestrial biodiversity (index)"] <- 1

readGLO <- function(title) {
  f <- file.path("output", title, "report.rds")
  if (!file.exists(f)) return(NULL)
  d <- as.data.frame(readRDS(f))
  d <- d[as.character(d$region) %in% c("World", "GLO"), , drop = FALSE]  # "World", not "GLO"
  data.frame(variable = as.character(d$variable),
             year     = suppressWarnings(as.numeric(as.character(d$period))),
             value    = suppressWarnings(as.numeric(d$value)), stringsAsFactors = FALSE)
}
pool <- design[design$feasible %in% TRUE, ]
reps <- lapply(pool$title, readGLO); names(reps) <- pool$title

# Guard behind the CO2 choice above. Reporting land-use-change CO2 rather than the
# total land flux is a pure re-baselining ONLY while the indirect term is the same
# in every run. That holds here by construction (all runs share one climate input,
# so the climate-driven carbon-density flux is exogenous), but "by construction"
# is exactly the kind of claim that quietly stops being true after a merge.
indCO2 <- lapply(reps, function(rd) {
  x <- rd[rd$variable == "Emissions|CO2|Land|+|Indirect", c("year", "value")]
  setNames(x$value, as.character(x$year))
})
indCO2 <- indCO2[lengths(indCO2) > 0]
if (length(indCO2) > 1) {
  yy  <- Reduce(intersect, lapply(indCO2, names))
  mm  <- vapply(indCO2, function(x) x[yy], numeric(length(yy)))
  spr <- max(apply(mm, 1, function(x) diff(range(x))))
  message(sprintf("indirect CO2 flux: %d runs x %d years, max within-year spread %.3g Mt CO2/yr (2100 offset %.0f)",
                  ncol(mm), nrow(mm), spr, mm[nrow(mm), 1]))
  if (spr > 1e-6)
    stop("the indirect CO2 flux is NOT scenario-invariant (spread ", signif(spr, 4),
         " Mt CO2/yr). Reporting land CO2 as land-use change only is then no longer ",
         "a constant re-baselining - revisit the OUTCOME_VARS comment before plotting.")
}

allv <- do.call(rbind, lapply(names(OUTCOME_VARS), function(oc) {
  vs <- OUTCOME_VARS[[oc]]
  do.call(rbind, lapply(pool$title, function(t) {
    rd <- reps[[t]]; if (is.null(rd)) return(NULL)
    s <- rd[rd$variable %in% vs, , drop = FALSE]
    if (length(unique(s$variable)) != length(vs)) return(NULL)   # partial sum = silent understatement
    agg <- aggregate(value ~ year, data = s, FUN = sum)
    data.frame(outcome = oc, title = t, year = agg$year, value = agg$value,
               stringsAsFactors = FALSE)
  }))
}))
miss <- setdiff(names(OUTCOME_VARS), unique(allv$outcome))
if (length(miss))
  stop("outcome(s) absent from report.rds: ", paste(miss, collapse = "; "),
       "\n  check names against unique(readRDS(<run>/report.rds)$variable)")

dat  <- merge(allv, design, by = "title")
term <- dat[dat$year == YEAR, ]           # terminal-year slice
pol  <- term[term$is_policy, ]

# ---- styling ----------------------------------------------------------------
ARM_COL <- c("1.5C + bioenergy" = "#C1442E", "1.5C, baseline bio" = "#0072B2",
             "current policy" = "#999999")
# House standard: every panel carries a frame. theme_minimal drops panel.border,
# so it is added back here rather than per-figure - that way the unfaceted
# figures (F01, F12) get the same frame and the deck reads as one set. Matches
# the sibling yield_gap plotter (grey75 / 0.4).
th <- theme_minimal(base_size = 11) +
  theme(panel.border = element_rect(fill = NA, colour = "grey75", linewidth = 0.4),
        panel.grid.minor = element_blank(), strip.text = element_text(face = "bold"),
        plot.title = element_text(face = "bold"), legend.position = "top")
gs <- function(f, p, w = 11, h = 6.5) ggsave(file.path(OUT, f), p, width = w, height = h)
# Outcome names are long. Rotated left-hand strips clip them, so facet strips stay
# in ggplot's default position and the text is wrapped instead of truncated.
WRAP <- ggplot2::label_wrap_gen(width = 24)

# geom_col SUMS every row sharing an x/fill/facet key (position = "stack" by
# default). Two rows collapsing onto one key produce a fabricated bar with no
# warning, and it passes every numeric check on the underlying data. This bit
# once already in this script (the TC figure drew the SUM of 4 cells under a
# caption saying "mean"). Assert the plotted frame is 1:1 with its key.
assertOneRowPerBar <- function(d, keys, what) {
  n <- nrow(unique(d[, keys, drop = FALSE]))
  if (n != nrow(d))
    stop(what, ": ", nrow(d), " rows map to ", n, " bars - geom_col would stack them. ",
         "Aggregate explicitly before plotting.")
  invisible(TRUE)
}
armOf <- function(cp, bio) ifelse(cp == "off", "current policy",
                          ifelse(bio == "on", "1.5C + bioenergy", "1.5C, baseline bio"))
lab <- function(x) paste0(ifelse(x %in% names(BOUNDARY), paste0(BOUNDARY[x], ": "), ""), x)

# ---- F01 feasibility --------------------------------------------------------
f1 <- design
f1$cellLab <- ifelse(f1$cell == "BAU", "BAU",
                     paste0(ifelse(f1$cp == "on", "CP+", "CP-"), ifelse(f1$bio == "on", " Bio+", " Bio-"),
                            ifelse(f1$prot == "on", " Prot+", " Prot-"), ifelse(f1$diet == "on", " Diet+", " Diet-")))
ord <- f1 %>% distinct(.data$cellLab, .data$cp, .data$bio, .data$prot, .data$diet) %>%
  arrange(.data$cp, .data$bio, .data$prot, .data$diet)
f1$cellLab <- factor(f1$cellLab, levels = rev(ord$cellLab))
f1$status  <- ifelse(f1$feasible %in% TRUE, "solved", "no feasible solution")
gs("01_feasibility.pdf",
   ggplot(f1, aes(tc_state, cellLab, fill = status)) +
     geom_tile(colour = "white", linewidth = 0.8) +
     scale_fill_manual(values = c("solved" = "#4C9F70", "no feasible solution" = "#C1442E"), name = NULL) +
     labs(title = "All 25 runs: 21 solved, 4 with no feasible solution",
          subtitle = "Every failure is the same corner: 1.5C carbon price + bioenergy demand with tau frozen at BAU",
          x = "TC regime", y = NULL) + th, 10, 7)

# ---- F02/F03 time series (TCendo, the realistic case) ----------------------
tsPlot <- function(ocs, file, title) {
  d <- dat[dat$is_policy & dat$tc == "on" & dat$outcome %in% ocs & dat$year >= 1995, ]
  d$arm <- armOf(d$cp, d$bio)
  d$dietLab <- ifelse(d$diet == "on", "with dietary shift", "no dietary shift")
  d$protLab <- ifelse(d$prot == "on", "protection on", "protection off")
  d$facet <- lab(d$outcome)
  gs(file, ggplot(d, aes(year, value, colour = arm, linetype = protLab)) +
       geom_line(linewidth = 0.7) +
       facet_grid(facet ~ dietLab, scales = "free_y", labeller = WRAP) +
       scale_colour_manual(values = ARM_COL, name = NULL) +
       scale_linetype_manual(values = c("protection on" = "solid", "protection off" = "22"), name = NULL) +
       labs(title = title, subtitle = "Endogenous TC only. The 1.5C + bioenergy arm has no frozen-tau counterpart.",
            x = NULL, y = NULL) + th, 12, 8)
}
tsPlot(names(BOUNDARY), "02_timeseries_boundaries.pdf", "The four planetary boundaries over time")
tsPlot(SUPPORTING,      "03_timeseries_supporting.pdf", "Supporting indicators over time")

# ---- isolation slices: dTC and dDiet ---------------------------------------
isoSlice <- function(lever) {
  keep <- setdiff(c("cp", "bio", "prot", "diet", "tc"), lever)
  w <- pol %>% select(all_of(c("outcome", keep, lever, "value"))) %>%
    pivot_wider(names_from = all_of(lever), values_from = "value")
  w$delta <- w$on - w$off
  w
}
REGIMES <- c("current policy", "1.5C, baseline bio", "1.5C + bioenergy")
DIETLAB <- c("no dietary shift", "with dietary shift")

# ---- F04 what tau buys, BY REGIME -------------------------------------------
# The x-axis is the POLICY REGIME because that is what tau's value is contingent
# on, and the fill is the dietary shift because averaging over it hides a 5-8x
# spread rather than a bit of noise (that spread IS figure 13). The earlier
# version of this figure averaged over both and drew one bar per regime, which
# left the individual cells scattered 2x either side of their own mean with no
# visible reason. Bars = mean over the protection arm; points = its two cells.
tc_w <- isoSlice("tc")
tc_w$arm     <- armOf(tc_w$cp, tc_w$bio)
tc_w$facet   <- lab(tc_w$outcome)
tc_w$regime  <- factor(tc_w$arm, levels = REGIMES)
tc_w$dietLab <- factor(ifelse(tc_w$diet == "on", DIETLAB[2], DIETLAB[1]), levels = DIETLAB)

t4  <- tc_w[tc_w$outcome %in% names(BOUNDARY), ]
t4m <- t4 %>% filter(!is.na(.data$delta)) %>%
  group_by(.data$facet, .data$regime, .data$dietLab) %>%
  summarise(delta = mean(.data$delta), .groups = "drop") %>% as.data.frame()
assertOneRowPerBar(t4m, c("facet", "regime", "dietLab"), "F04 tau by regime")
# A regime with no TCbau counterpart anywhere is LABELLED, not silently dropped:
# an empty x-position reads as "zero effect", which is the opposite of the truth.
t4gap <- t4 %>% group_by(.data$facet, .data$regime) %>%
  summarise(gone = all(is.na(.data$delta)), .groups = "drop") %>%
  filter(.data$gone) %>% mutate(delta = 0) %>% as.data.frame()

gs("04_tc_isolation.pdf",
   ggplot(t4m, aes(.data$regime, .data$delta, fill = .data$dietLab)) +
     geom_col(position = position_dodge(width = 0.7), width = 0.62) +
     geom_point(data = t4[!is.na(t4$delta), ],
                aes(.data$regime, .data$delta, group = .data$dietLab),
                position = position_dodge(width = 0.7), inherit.aes = FALSE,
                size = 1.3, colour = "#333333", alpha = 0.85) +
     geom_hline(yintercept = 0, linewidth = 0.3) +
     geom_text(data = t4gap, aes(.data$regime, .data$delta),
               label = "no solution\nat frozen tau", inherit.aes = FALSE,
               size = 2.9, lineheight = 0.95, vjust = -0.3, colour = "#C1442E") +
     facet_wrap(~facet, scales = "free_y", labeller = WRAP) +
     scale_fill_manual(values = c("#0072B2", "#8FCBEA") %>% setNames(DIETLAB), name = NULL) +
     labs(title = "What endogenous tau buys, by policy regime (2100)",
          subtitle = paste("dTC = Y(TCendo) - Y(TCbau). Tau is worth almost nothing under current policy and a great deal under 1.5C;",
                           "\nunder 1.5C WITH bioenergy the frozen-tau run has no solution at all. The dietary shift takes most of tau's value away."),
          x = NULL, y = "difference at 2100 (outcome units)") + th, 12, 7)

# ---- F05 what the dietary shift buys, same construction ---------------------
diet_w <- isoSlice("diet")
diet_w$arm   <- armOf(diet_w$cp, diet_w$bio)
diet_w$facet <- lab(diet_w$outcome)
d5  <- diet_w[diet_w$outcome %in% names(BOUNDARY) & !is.na(diet_w$delta), ]
d5$regime <- factor(d5$arm, levels = REGIMES)
d5$tcLab  <- factor(ifelse(d5$tc == "on", "endogenous tau", "tau frozen at BAU"),
                    levels = c("tau frozen at BAU", "endogenous tau"))
d5m <- d5 %>% group_by(.data$facet, .data$regime, .data$tcLab) %>%
  summarise(delta = mean(.data$delta), .groups = "drop") %>% as.data.frame()
assertOneRowPerBar(d5m, c("facet", "regime", "tcLab"), "F05 diet by regime")
gs("05_diet_isolation.pdf",
   ggplot(d5m, aes(.data$regime, .data$delta, fill = .data$tcLab)) +
     geom_col(position = position_dodge(width = 0.7), width = 0.62) +
     geom_point(data = d5, aes(.data$regime, .data$delta, group = .data$tcLab),
                position = position_dodge(width = 0.7), inherit.aes = FALSE,
                size = 1.3, colour = "#333333", alpha = 0.85) +
     geom_hline(yintercept = 0, linewidth = 0.3) +
     facet_wrap(~facet, scales = "free_y", labeller = WRAP) +
     scale_fill_manual(values = c("tau frozen at BAU" = "#E69F00",
                                  "endogenous tau" = "#009E73"), name = NULL) +
     labs(title = "What the dietary shift buys, by policy regime (2100)",
          subtitle = paste("dDiet = Y(DietOn) - Y(DietOff), split by TC state. The mirror image of figure 04: the dietary shift delivers under",
                           "\nboth climate regimes, and it delivers most where tau is frozen - the same replacement effect seen from the other side."),
          x = NULL, y = "difference at 2100 (outcome units)") + th, 12, 7)

# ---- F06 primary: protection x bioenergy 2x2 at 1.5C, by diet --------------
p2 <- pol[pol$cp == "on" & pol$tc == "on" & pol$outcome %in% names(BOUNDARY), ]
p2$protLab <- factor(ifelse(p2$prot == "on", "protection on", "protection off"),
                     levels = c("protection off", "protection on"))
p2$bioLab  <- factor(ifelse(p2$bio == "on", "with bioenergy", "baseline bioenergy"),
                     levels = c("baseline bioenergy", "with bioenergy"))
p2$dietLab <- ifelse(p2$diet == "on", "with dietary shift", "no dietary shift")
p2$facet   <- lab(p2$outcome)
assertOneRowPerBar(p2, c("facet","dietLab","bioLab","protLab"), "F06 protection x bioenergy")
# An INTERACTION plot, not dodged bars. These four cells differ by a few percent
# of their own level, so bars from a zero baseline spend ~95% of their ink on the
# part that is identical in every cell and the 2x2 reads as four equal blocks -
# on the biodiversity panel (0.81 everywhere) it is unreadable outright. Lines on
# a free, non-zero-anchored axis put the ink on the differences instead, and the
# interaction is then the thing the eye actually picks up: parallel lines = the
# two levers are independent, converging lines = bioenergy eats protection's gain.
gs("06_protection_x_bioenergy.pdf",
   ggplot(p2, aes(.data$bioLab, .data$value, colour = .data$protLab, group = .data$protLab)) +
     geom_line(linewidth = 0.7) + geom_point(size = 2.2) +
     facet_grid(facet ~ dietLab, scales = "free_y", labeller = WRAP) +
     scale_colour_manual(values = c("protection off" = "#E69F00", "protection on" = "#0072B2"), name = NULL) +
     labs(title = "Protection x bioenergy at 1.5C and endogenous TC (2100 levels)",
          subtitle = paste("The primary 2x2, split by whether the dietary shift is also applied. The vertical gap between the lines IS the protection effect;",
                           "\nit narrows to the right in every panel. Note the y axes do not start at zero - these are levels, shown on a scale that resolves the differences."),
          x = NULL, y = NULL) + th, 12, 8)

# ---- F07 protection effect eroded by bioenergy ------------------------------
ero <- pol %>% filter(.data$tc == "on", .data$cp == "on") %>%
  select("outcome", "bio", "prot", "diet", "value") %>%
  pivot_wider(names_from = "prot", values_from = "value") %>%
  mutate(prot_effect = .data$on - .data$off) %>%
  group_by(.data$outcome, .data$bio) %>%
  summarise(prot_effect = mean(.data$prot_effect), .groups = "drop")
eroB <- ero[ero$outcome %in% names(BOUNDARY), ]
eroB$facet  <- lab(eroB$outcome)
eroB$bioLab <- ifelse(eroB$bio == "on", "with bioenergy demand", "baseline bioenergy")
assertOneRowPerBar(eroB, c("facet","bioLab"), "F07 protection erosion")
gs("07_protection_vs_bioenergy.pdf",
   ggplot(eroB, aes(bioLab, prot_effect, fill = bioLab)) +
     geom_col(width = 0.6) + geom_hline(yintercept = 0, linewidth = 0.3) +
     facet_wrap(~facet, scales = "free_y", labeller = WRAP) +
     scale_fill_manual(values = c("with bioenergy demand" = "#C1442E",
                                  "baseline bioenergy" = "#0072B2"), guide = "none") +
     labs(title = "Does ambitious land protection deliver less when bioenergy competes for land?",
          subtitle = "Effect of the protection bundle (Half-Earth + BII + SNV + env-flows), at 1.5C and endogenous TC, averaged over diet",
          x = NULL, y = "protection effect at 2100 (outcome units)") + th)

# ---- F08 main effects -------------------------------------------------------
endo <- pol[pol$tc == "on", ]
mainEff <- function(oc, lever) {
  d <- endo[endo$outcome == oc, ]
  if (lever == "bio") d <- d[d$cp == "on", ]     # identified only at climate on
  if (lever == "cp")  d <- d[d$bio == "off", ]   # identified only at baseline bio
  mean(d$value[d[[lever]] == "on"], na.rm = TRUE) - mean(d$value[d[[lever]] == "off"], na.rm = TRUE)
}
LEVERS <- c(cp = "Climate policy (1.5C)", bio = "Bioenergy demand",
            prot = "Protection bundle", diet = "Dietary shift")
me <- do.call(rbind, lapply(names(BOUNDARY), function(oc)
  do.call(rbind, lapply(names(LEVERS), function(l)
    data.frame(outcome = oc, lever = LEVERS[[l]], effect = mainEff(oc, l), stringsAsFactors = FALSE)))))
me$facet <- lab(me$outcome)
me$helps <- sign(me$effect) == DESIRED[me$outcome]
assertOneRowPerBar(me, c("facet","lever"), "F08 main effects")
gs("08_main_effects.pdf",
   ggplot(me, aes(reorder(lever, abs(effect)), effect, fill = helps)) +
     geom_col(width = 0.65) + geom_hline(yintercept = 0, linewidth = 0.3) + coord_flip() +
     facet_wrap(~facet, scales = "free_x", labeller = WRAP) +
     scale_fill_manual(values = c("TRUE" = "#4C9F70", "FALSE" = "#C1442E"),
                       labels = c("TRUE" = "moves boundary the desired way", "FALSE" = "moves it the wrong way"),
                       name = NULL) +
     labs(title = "Main effect of each lever on each boundary (2100, endogenous TC)",
          subtitle = paste("Desired direction is lower for cropland / land CO2 / N surplus, HIGHER for the biodiversity index.",
                           "Bioenergy is identified only at 1.5C,",
                           "\nclimate only at baseline bioenergy (the design has a deliberate hole). Tau is deliberately ABSENT: a single main effect would average its",
                           "\nlarge 1.5C value against its near-zero current-policy value and report the mean as if it were the effect. See figures 04 and 13."),
          x = NULL, y = "mean effect at 2100 (outcome units)") + th)

# ---- F09/F10 the two 2^4 cubes: full decomposition --------------------------
# Cube A (climate on): bio x prot x diet x tc, 12 of 16 cells feasible.
# Cube B (baseline bioenergy): cp x prot x diet x tc, all 16 feasible.
CUBES <- list(
  A = list(fix = c(cp = "on"),  fac = c("bio", "prot", "diet", "tc"),
           lab = "Cube A: under 1.5C climate policy"),
  B = list(fix = c(bio = "off"), fac = c("cp", "prot", "diet", "tc"),
           lab = "Cube B: at baseline bioenergy"))
NICE <- c(bio = "Bio", prot = "Prot", diet = "Diet", tc = "TC", cp = "Climate")
decompAll <- list()
for (nm in names(CUBES)) {
  cu <- CUBES[[nm]]
  rows <- lapply(names(BOUNDARY), function(oc) {
    d <- pol[pol$outcome == oc & pol[[names(cu$fix)]] == cu$fix, ]
    cells <- d[, c(cu$fac, "value")]
    e <- decomposeFactorial(cells, cu$fac, "value")
    e$outcome <- oc; e$cube <- nm; e
  })
  decompAll[[nm]] <- do.call(rbind, rows)
}
decomp <- do.call(rbind, decompAll)
decomp$termNice <- vapply(strsplit(decomp$term, ":", fixed = TRUE), function(p)
  if (identical(p, "(reference)")) "(reference)" else paste(NICE[p], collapse = " x "), character(1))
decomp$facet <- lab(decomp$outcome)

for (nm in names(CUBES)) {
  d <- decomp[decomp$cube == nm & decomp$order > 0, ]
  d$missing <- is.na(d$effect)
  d$plotval <- ifelse(d$missing, 0, d$effect)
  # d spans term x outcome, so sum(d$missing) counts red-x MARKS, not terms. The
  # subtitle used to print that count and call them terms - "32 terms" on a figure
  # showing 15 term labels, contradicting the deck caption's "8 of 15". Count
  # DISTINCT terms, and claim panel-invariance only when the pattern really is.
  naTerms  <- unique(d$termNice[d$missing])
  nTerms   <- length(unique(d$termNice))
  sameEach <- length(naTerms) > 0 &&
              all(tapply(d$missing, d$facet, sum) == length(naTerms))
  gs(sprintf("%02d_decomposition_cube%s.pdf", if (nm == "A") 9 else 10, nm),
     ggplot(d, aes(reorder(termNice, .data$order), plotval, fill = factor(.data$order))) +
       geom_col(width = 0.7) + coord_flip() + geom_hline(yintercept = 0, linewidth = 0.3) +
       geom_point(data = d[d$missing, ], aes(termNice, 0), inherit.aes = FALSE,
                  shape = 4, size = 2, colour = "#C1442E") +
       facet_wrap(~facet, scales = "free_x", labeller = WRAP) +
       scale_fill_brewer(palette = "Blues", name = "interaction order") +
       labs(title = paste0("Full 2^4 decomposition - ", CUBES[[nm]]$lab),
            subtitle = paste0("Treatment-coded against the all-OFF corner. ",
                              if (length(naTerms))
                                paste0("Red x = not identifiable (", length(naTerms), " of ",
                                       nTerms, " terms touch an infeasible cell",
                                       if (sameEach) ", the same terms in every panel" else "",
                                       ").")
                              else "All 16 cells feasible, every term identified."),
            x = NULL, y = "effect at 2100 (outcome units)") + th, 11, 7)
}

# ---- F11 pairwise substitution ----------------------------------------------
subs <- do.call(rbind, lapply(names(CUBES), function(nm) {
  cu <- CUBES[[nm]]
  do.call(rbind, lapply(names(BOUNDARY), function(oc) {
    d <- pol[pol$outcome == oc & pol[[names(cu$fix)]] == cu$fix, ]
    cells <- d[, c(cu$fac, "value")]
    prs <- combn(cu$fac, 2, simplify = FALSE)
    do.call(rbind, lapply(prs, function(p) {
      r <- pairwiseInteractions(cells, cu$fac, p[1], p[2], "value")
      data.frame(cube = nm, outcome = oc, pair = paste(NICE[p], collapse = " x "),
                 cls = ifelse(is.na(r$classification), "not identifiable", r$classification),
                 n_missing = r$n_missing_contexts, stringsAsFactors = FALSE)
    }))
  }))
}))
subs$facet <- lab(subs$outcome)
subs$cubeLab <- ifelse(subs$cube == "A", "A: under 1.5C", "B: baseline bioenergy")
gs("11_substitution_matrix.pdf",
   ggplot(subs, aes(pair, cubeLab, fill = cls)) +
     geom_tile(colour = "white", linewidth = 0.8) +
     facet_wrap(~facet, ncol = 1, labeller = WRAP) +
     scale_fill_manual(values = c(substitute = "#E69F00", complement = "#0072B2",
                                  additive = "#CCCCCC", mixed = "#9970AB",
                                  `not identifiable` = "#F2F2F2"), name = NULL) +
     labs(title = "Do the levers substitute for one another?",
          subtitle = "Substitute = the pair together delivers less than the sum of its parts. Averaged over the other levers' contexts.",
          x = NULL, y = "cube") + th +
     theme(axis.text.x = element_text(angle = 30, hjust = 1)), 11, 9)

# ---- F12 WHERE each lever moves land (explains the biodiversity result) ------
# The biodiversity index is a naturalness-weighted land composition, so the size
# of a lever's index effect depends on WHICH pools it moves between, not only on
# how many hectares it moves.
POOL_VARS <- c(Cropland = "Resources|Land Cover|+|Cropland",
               Pasture  = "Resources|Land Cover|+|Pastures and Rangelands",
               `Natural forest` = "Resources|Land Cover|Forest|+|Natural Forest",
               `Other natural land` = "Resources|Land Cover|+|Other Land")
poolAt <- function(t, v) {
  rd <- reps[[t]]; if (is.null(rd)) return(NA_real_)
  x <- rd[rd$variable == v & rd$year == YEAR, ]
  if (!nrow(x)) NA_real_ else sum(x$value, na.rm = TRUE)
}
pe <- do.call(rbind, lapply(names(POOL_VARS), function(pn) {
  d <- pool[pool$is_policy & pool$tc == "on", ]
  d$val <- vapply(d$title, poolAt, numeric(1), POOL_VARS[[pn]])
  ef <- function(lever) { s2 <- d; if (lever == "cp") s2 <- s2[s2$bio == "off", ]
    mean(s2$val[s2[[lever]] == "on"], na.rm = TRUE) - mean(s2$val[s2[[lever]] == "off"], na.rm = TRUE) }
  data.frame(pool = pn, lever = c("Climate policy (1.5C)", "Protection bundle", "Dietary shift"),
             effect = c(ef("cp"), ef("prot"), ef("diet")), stringsAsFactors = FALSE)
}))
pe$pool <- factor(pe$pool, levels = c("Cropland", "Pasture", "Other natural land", "Natural forest"))
assertOneRowPerBar(pe, c("pool", "lever"), "F12 land pools")
gs("12_where_levers_move_land.pdf",
   ggplot(pe, aes(pool, effect, fill = lever)) +
     geom_col(position = position_dodge(width = 0.75), width = 0.7) +
     geom_hline(yintercept = 0, linewidth = 0.3) +
     scale_fill_manual(values = c("Climate policy (1.5C)" = "#0072B2",
                                  "Protection bundle" = "#4C9F70",
                                  "Dietary shift" = "#E69F00"), name = NULL) +
     labs(title = "Where each lever moves land (2100, endogenous TC)",
          subtitle = paste("Comparable hectares, different destinations. Climate policy's signature move is cropland -> forest;",
                           "\nthe protection bundle's is pasture -> other (non-forest) natural land, a smaller step up the naturalness gradient."),
          x = NULL, y = "change vs the lever's off state (Mha)") + th, 11, 6)
write.csv(pe, file.path(OUT, "land_pool_effects.csv"), row.names = FALSE)

# ---- F13 tau vs the dietary shift: the replacement effect -------------------
# yield_gap's marginal-contribution view, recomputed on this design and split by
# climate regime. Within each (climate, protection) context the reference is the
# most constrained cell - no dietary shift, tau frozen at BAU - and the three
# treatments are tau alone, diet alone, both. Bioenergy is held at BASELINE: it
# is the only arm with a complete TCbau set at BOTH climate regimes, since the
# 1.5C + bioenergy corner has no frozen-tau solution to difference against.
#
# The dashed rule on the third bar is "tau alone + diet alone" - what the pair
# would deliver if the two levers were independent. The bar falling short of it
# IS the replacement effect, read straight off the figure instead of inferred
# from an interaction coefficient in a 15-term decomposition.
mc <- pol %>% filter(.data$bio == "off") %>%
  select("outcome", "cp", "prot", "diet", "tc", "value") %>%
  mutate(cellkey = paste0("d", .data$diet, "_t", .data$tc)) %>%
  select(-"diet", -"tc") %>%
  pivot_wider(names_from = "cellkey", values_from = "value")
MCCELLS <- c("doff_toff", "doff_ton", "don_toff", "don_ton")
stopifnot(all(MCCELLS %in% names(mc)), !anyNA(mc[, MCCELLS]))
mc <- mc %>% mutate(
  tc_only   = .data$doff_ton - .data$doff_toff,
  diet_only = .data$don_toff - .data$doff_toff,
  both      = .data$don_ton  - .data$doff_toff,
  sum_parts = .data$tc_only + .data$diet_only,
  synergy   = .data$both - .data$sum_parts,
  tc_share  = ifelse(.data$both == 0, NA_real_, .data$tc_only / .data$both),
  regime    = factor(ifelse(.data$cp == "on", "1.5C carbon price", "current policy"),
                     levels = c("current policy", "1.5C carbon price")),
  facet     = lab(.data$outcome))

MCLEV <- c("tau only", "diet only", "tau + diet")
mcl <- mc %>% select("outcome", "facet", "regime", "prot", "tc_only", "diet_only", "both") %>%
  pivot_longer(c("tc_only", "diet_only", "both"), names_to = "lever", values_to = "delta") %>%
  mutate(lever = factor(setNames(MCLEV, c("tc_only", "diet_only", "both"))[.data$lever],
                        levels = MCLEV)) %>% as.data.frame()
mclB <- mcl[mcl$outcome %in% names(BOUNDARY), ]
m13  <- mclB %>% group_by(.data$facet, .data$regime, .data$lever) %>%
  summarise(delta = mean(.data$delta), .groups = "drop") %>% as.data.frame()
assertOneRowPerBar(m13, c("facet", "regime", "lever"), "F13 replacement")
sp13 <- mc %>% filter(.data$outcome %in% names(BOUNDARY)) %>%
  group_by(.data$facet, .data$regime) %>%
  summarise(sum_parts = mean(.data$sum_parts), .groups = "drop") %>%
  mutate(x = which(MCLEV == "tau + diet")) %>% as.data.frame()

gs("13_tc_vs_diet_replacement.pdf",
   ggplot(m13, aes(.data$lever, .data$delta, fill = .data$lever)) +
     geom_col(width = 0.62) +
     geom_point(data = mclB, aes(.data$lever, .data$delta), inherit.aes = FALSE,
                size = 1.3, colour = "#333333", alpha = 0.85) +
     geom_segment(data = sp13, aes(x = .data$x - 0.36, xend = .data$x + 0.36,
                                   y = .data$sum_parts, yend = .data$sum_parts),
                  inherit.aes = FALSE, linetype = "22", linewidth = 0.55, colour = "#1F1F1F") +
     geom_hline(yintercept = 0, linewidth = 0.3) +
     facet_grid(facet ~ regime, scales = "free_y", labeller = WRAP) +
     scale_fill_manual(values = setNames(c("#0072B2", "#009E73", "#CC79A7"), MCLEV), guide = "none") +
     labs(title = "Tau and the dietary shift replace one another",
          subtitle = paste("Change from the most constrained cell (no dietary shift, tau frozen at BAU), at baseline bioenergy.",
                           "Bar = mean over the protection arm, points = its two cells.",
                           "\nDashed rule = tau alone + diet alone, i.e. what the pair would deliver if independent.",
                           "Where the bar stops short of it, the second lever is",
                           "\nbuying back ground the first already took."),
          x = NULL, y = "change from reference at 2100 (outcome units)") +
     th + theme(strip.text.y.right = element_text(angle = 0)), 12.5, 8.5)
write.csv(mc[, c("outcome", "cp", "prot", "tc_only", "diet_only", "both", "sum_parts", "synergy", "tc_share")],
          file.path(OUT, "replacement.csv"), row.names = FALSE)

# ---- CSVs behind every figure ----------------------------------------------
sd <- design[, c("title","cell","cp","bio","prot","diet","tc_state","is_policy","feasible")]
write.csv(sd,                                            file.path(OUT, "scenario_design.csv"), row.names = FALSE)
write.csv(term[term$is_policy, c("title","outcome","value")], file.path(OUT, "cell_values_2100.csv"), row.names = FALSE)
write.csv(tc_w,                                          file.path(OUT, "tc_effect.csv"), row.names = FALSE)
write.csv(diet_w,                                        file.path(OUT, "diet_effect.csv"), row.names = FALSE)
write.csv(eroB[, c("outcome","bio","prot_effect")],      file.path(OUT, "protection_vs_bioenergy.csv"), row.names = FALSE)
write.csv(me[, c("outcome","lever","effect","helps")],   file.path(OUT, "main_effects.csv"), row.names = FALSE)
write.csv(decomp[, c("cube","outcome","term","termNice","order","effect","n_missing")],
                                                         file.path(OUT, "decomposition.csv"), row.names = FALSE)
write.csv(subs[, c("cube","outcome","pair","cls","n_missing")],
                                                         file.path(OUT, "substitution.csv"), row.names = FALSE)

message("\nwrote ", length(list.files(OUT, "\\.pdf$")), " figures + ",
        length(list.files(OUT, "\\.csv$")), " CSVs to ", OUT)
