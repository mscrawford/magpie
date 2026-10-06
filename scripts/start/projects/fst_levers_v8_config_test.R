# Assertions for the FSTL8 arm config. Counted.
#   * BAU8 is BAU7 plus c30_bioen_water = "all", and nothing else.
#   * THE PARTNER RUNS are the two named cube corners plus four interest-rate keys
#     each, 0.1 for high pressure and 0.04 for low, and set no historical rate.
#   * THE BAU HAS NO ENVIRONMENTAL-FLOW KEY (the policy belongs to the transformation).
#   * THE 16 CELLS ARE FSTL7's, switch for switch, under a new prefix.
#   * NO FSTL7 RUN, AND NEITHER EARLIER BAU, IS NAMED (force_replace).

source("scripts/start/projects/fst_levers_v8_config.R")

EXPECTED_CHECKS <- 16L
n_checks <- 0L
n_fail   <- 0L
chk <- function(cond, label) {
  n_checks <<- n_checks + 1L
  if (!isTRUE(cond)) { n_fail <<- n_fail + 1L; cat("  FAIL: ", label, "\n", sep = "") }
  invisible(cond)
}
partner <- grep("^FSTL8P_", names(FST_LEVERS_SCENARIOS), value = TRUE)
cells   <- setdiff(names(FST_LEVERS_SCENARIOS), c(FST_LEVERS_BAU, partner))
bau   <- FST_LEVERS_SCENARIOS[[FST_LEVERS_BAU]]

chk(identical(FST_LEVERS_BAU, "BAU8"), "the tau pin source is BAU8")
chk(identical(bau$c30_bioen_water, "all"), "BAU8 allows irrigated bioenergy")
chk(identical(bau[setdiff(names(bau), "c30_bioen_water")], .bau7[[1]]),
    "apart from that one key BAU8 is BAU7")
chk(!"c42_env_flow_policy" %in% names(bau), "BAU8 sets no environmental-flow policy")
chk(length(cells) == 8L && all(grepl("^FSTL8_", cells)), "8 cells, all with the FSTL8_ prefix")
chk(identical(unname(FST_LEVERS_SCENARIOS[cells]), unname(.fstl7)) &&
      identical(sub("^FSTL8_", "FSTL7_", cells), names(.fstl7)),
    "the cells are FSTL7's, switch for switch and in order")
chk(all(vapply(FST_LEVERS_SCENARIOS[cells], function(b) identical(b$c30_bioen_water, bau$c30_bioen_water),
               logical(1))),
    "BAU and all eight cells agree on c30_bioen_water")
chk(!any(grepl("^FSTL[2-7]_|^BAU7$|^BAU$", names(FST_LEVERS_SCENARIOS))) &&
      !any(grepl("^FSTL[2-7]_", FST_LEVERS_TCBAU_SCENARIOS)),
    "no run of an earlier arm and no earlier BAU is named")

# --- the partner 2 x 2 (6 checks) ---
INT_KEYS <- c("s12_interest_lic", "s12_interest_hic", "s12_interest_lic_noselect", "s12_interest_hic_noselect")
corner   <- c(FSTL8P_HighPressure = "FSTL8_CPon_BioOnXJPded_Prot_DietOff",
              FSTL8P_LowPressure  = "FSTL8_CPon_BioNone_NoProt_DietEL")
rate     <- c(FSTL8P_HighPressure = "0.1", FSTL8P_LowPressure = "0.04")
chk(identical(sort(partner), sort(names(corner))), "exactly the two partner scenarios are named")
for (s in names(corner)) {
  blk <- FST_LEVERS_SCENARIOS[[s]]
  chk(identical(blk[setdiff(names(blk), INT_KEYS)], FST_LEVERS_SCENARIOS[[corner[[s]]]]),
      paste0(s, ": apart from the interest keys it is the cube corner ", corner[[s]]))
  chk(setequal(intersect(names(blk), INT_KEYS), INT_KEYS) &&
        all(vapply(blk[INT_KEYS], identical, logical(1), rate[[s]])) &&
        !any(grepl("hist_interest", names(blk))),
      paste0(s, ": all four future interest keys are ", rate[[s]], ", no historical key is set"))
}
chk(all(partner %in% FST_LEVERS_TCBAU_SCENARIOS) && nrow(FSTL2_DESIGN) == 8L,
    "both partner scenarios also run with frozen tau; the design table holds the 8 cube cells only")
titles <- c(vapply(names(FST_LEVERS_SCENARIOS), tcRunName, character(1), "TCendo"),
            vapply(FST_LEVERS_TCBAU_SCENARIOS,  tcRunName, character(1), "TCbau"))
chk(length(titles) == 21L && !any(duplicated(titles)), "21 distinct run titles (BAU8, 16 cube, 4 partner)")
onDisk   <- intersect(titles, list.files("output"))
finished <- vapply(onDisk, function(t) {
  rs <- file.path("output", t, "runstatistics.rda")
  if (!file.exists(rs)) return(FALSE)
  e <- new.env(); load(rs, envir = e); !is.null(e$stats$modelstat)
}, logical(1))
chk(all(finished), paste0("every FSTL8 title on disk is a finished run (unfinished: ",
                          paste(onDisk[!finished], collapse = ", "), ")"))

cat("checks run: ", n_checks, " (expected ", EXPECTED_CHECKS, "), failures: ", n_fail, "\n", sep = "")
if (n_checks != EXPECTED_CHECKS)
  stop("assertion COUNT mismatch: ran ", n_checks, ", expected ", EXPECTED_CHECKS)
if (n_fail > 0) stop(n_fail, " assertion(s) failed.")
cat("fst_levers v8 config OK.\n")
