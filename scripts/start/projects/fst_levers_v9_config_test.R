# Assertions for the FSTL9 arm config. Counted.
#   * THE ONE CHANGE: c42_env_flow_policy is "on" in the four protection-ON cells and
#     "off" in the four protection-OFF cells; every other key of every cell is FSTL8's.
#   * BAU8 is the baseline, unchanged, and sets no environmental-flow policy.
#   * THE PARTNER RUNS are the two named FSTL9 corners plus four interest-rate keys.
#   * NO RUN OF AN EARLIER ARM IS NAMED except BAU8 (force_replace).
#   * ON DISK: the ten titles this arm reuses are links to finished FSTL8 runs with the
#     same switches; the ten new titles are absent or finished. Run it before a launch.

source("scripts/start/projects/fst_levers_v9_config.R")

EXPECTED_CHECKS <- 17L
n_checks <- 0L
n_fail   <- 0L
chk <- function(cond, label) {
  n_checks <<- n_checks + 1L
  if (!isTRUE(cond)) { n_fail <<- n_fail + 1L; cat("  FAIL: ", label, "\n", sep = "") }
  invisible(cond)
}
partner <- grep("^FSTL9P_", names(FST_LEVERS_SCENARIOS), value = TRUE)
cells   <- setdiff(names(FST_LEVERS_SCENARIOS), c(FST_LEVERS_BAU, partner))
bau     <- FST_LEVERS_SCENARIOS[[FST_LEVERS_BAU]]
prot    <- grepl("_Prot_", cells)
flows   <- vapply(FST_LEVERS_SCENARIOS[cells], function(b) b$c42_env_flow_policy, character(1))
drop_flows <- function(b) b[names(b) != "c42_env_flow_policy"]

# --- the baseline and the cube (8 checks) ---
chk(identical(FST_LEVERS_BAU, "BAU8") && identical(bau, .bau8[[1]]), "the baseline and tau pin source is BAU8, unchanged")
chk(!"c42_env_flow_policy" %in% names(bau), "BAU8 sets no environmental-flow policy")
chk(length(cells) == 8L && all(grepl("^FSTL9_", cells)) && sum(prot) == 4L, "8 cells with the FSTL9_ prefix, 4 with protection")
chk(all(flows[prot] == "on") && all(flows[!prot] == "off"), "flow protection is on with land protection and off without it")
chk(identical(unname(lapply(FST_LEVERS_SCENARIOS[cells], drop_flows)), unname(lapply(.fstl8, drop_flows))) &&
      identical(sub("^FSTL9_", "FSTL8_", cells), names(.fstl8)),
    "apart from that key the cells are FSTL8's, switch for switch and in order")
chk(identical(unname(FST_LEVERS_SCENARIOS[cells[prot]]), unname(.fstl8[prot])), "the four protection-ON cells are FSTL8's, every key")
chk(all(vapply(FST_LEVERS_SCENARIOS[cells], function(b) sum(names(b) == "c42_env_flow_policy") == 1L &&
                 identical(b$c30_bioen_water, "all"), logical(1))),
    "each cell holds the flow key once and allows irrigated bioenergy")
chk(!any(grepl("^FSTL[2-8]P?_|^BAU7$|^BAU$", names(FST_LEVERS_SCENARIOS))) &&
      !any(grepl("^FSTL[2-8]P?_", FST_LEVERS_TCBAU_SCENARIOS)),
    "no run of an earlier arm is named, and of the earlier baselines only BAU8")

# --- the partner 2 x 2 (6 checks) ---
INT_KEYS <- c("s12_interest_lic", "s12_interest_hic", "s12_interest_lic_noselect", "s12_interest_hic_noselect")
corner   <- c(FSTL9P_HighPressure = "FSTL9_CPon_BioOnXJPded_Prot_DietOff",
              FSTL9P_LowPressure  = "FSTL9_CPon_BioNone_NoProt_DietEL")
rate     <- c(FSTL9P_HighPressure = "0.1", FSTL9P_LowPressure = "0.04")
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
chk(identical(FST_LEVERS_SCENARIOS$FSTL9P_HighPressure$c42_env_flow_policy, "on") &&
      identical(FST_LEVERS_SCENARIOS$FSTL9P_LowPressure$c42_env_flow_policy, "off"),
    "flow protection is in the high-pressure row and not in the low-pressure row")

# --- titles and what is on disk (3 checks) ---
# unname: vapply over a character vector names its result, and identical() compares names too.
titles <- unname(c(vapply(names(FST_LEVERS_SCENARIOS), tcRunName, character(1), "TCendo"),
                   vapply(FST_LEVERS_TCBAU_SCENARIOS,  tcRunName, character(1), "TCbau")))
chk(length(titles) == 21L && !any(duplicated(titles)) && all(partner %in% FST_LEVERS_TCBAU_SCENARIOS) &&
      nrow(FSTL2_DESIGN) == 8L,
    "21 distinct run titles (BAU8, 16 cube, 4 partner); the design table holds the 8 cube cells")
finished <- function(t) {
  rs <- file.path("output", t, "runstatistics.rda")
  if (!file.exists(rs)) return(FALSE)
  e <- new.env(); load(rs, envir = e); !is.null(e$stats$modelstat)
}
reused <- grep("_Prot_|^FSTL9P_HighPressure_", titles, value = TRUE)
new    <- setdiff(titles, c(reused, "BAU8_TCendo"))
target <- sub("^FSTL9", "FSTL8", reused)
linked <- vapply(seq_along(reused), function(i) {
  link <- Sys.readlink(file.path("output", reused[i]))
  nzchar(link) && identical(basename(link), target[i]) && finished(reused[i]) && finished(target[i])
}, logical(1))
chk(length(reused) == 10L && all(linked),
    paste0("the ten reused titles are links to their finished FSTL8 runs (not so: ",
           paste(reused[!linked], collapse = ", "), ")"))
onDisk <- intersect(new, list.files("output"))
done   <- vapply(onDisk, finished, logical(1))
chk(length(new) == 10L && all(done) && !any(nzchar(Sys.readlink(file.path("output", onDisk)))),
    paste0("the ten new titles are absent or finished runs of their own (unfinished: ",
           paste(onDisk[!done], collapse = ", "), ")"))

cat("checks run: ", n_checks, " (expected ", EXPECTED_CHECKS, "), failures: ", n_fail, "\n", sep = "")
if (n_checks != EXPECTED_CHECKS)
  stop("assertion COUNT mismatch: ran ", n_checks, ", expected ", EXPECTED_CHECKS)
if (n_fail > 0) stop(n_fail, " assertion(s) failed.")
cat("fst_levers v9 config OK.\n")
