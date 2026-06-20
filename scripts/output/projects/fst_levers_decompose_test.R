# Synthetic unit test for the fst_levers 2^k factorial decomposition.
# Validates the decomposition algebra on KNOWN inputs (no gdx required), so the
# analytically risky core is proven before it touches any real run output.
# Run from the magpie clone root:
#   Rscript scripts/output/projects/fst_levers_decompose_test.R

source("scripts/output/projects/fst_levers_decompose.R")

fail <- 0L
chk <- function(cond, msg) {
  cat(if (isTRUE(cond)) "PASS" else "FAIL", "|", msg, "\n")
  if (!isTRUE(cond)) fail <<- fail + 1L
}

# generic k-factor spec (distinct labels per factor)
genFactors <- function(k) setNames(
  lapply(seq_len(k), function(i) c(off = paste0("F", i, "lo"), on = paste0("F", i, "hi"))),
  paste0("f", seq_len(k)))

# --- Test 1: exact round-trip for k = 2, 3, 4 --------------------------------
for (k in c(2L, 3L, 4L)) {
  f    <- genFactors(k)
  n    <- 2^k
  vals <- seq_len(n)^1.27 - 3.1 * seq_len(n) + 5   # deterministic, varied
  cells <- setNames(as.list(vals), allFactorCells(f))
  eff  <- decomposeFactorial(cells, f)
  rec  <- reconstructFactorial(eff, f)
  orig <- unlist(cells)
  err  <- max(abs(orig - rec[names(orig)]))
  chk(length(eff) == n, sprintf("k=%d: 2^k effects returned (%d)", k, length(eff)))
  chk(err < 1e-9, sprintf("k=%d: round-trip reconstruction exact (max err %.2e)", k, err))
}

# --- Test 2: FST 4-factor names + reference corner ---------------------------
chk(cellName(c(0,0,0,0)) == "NoProtect_BioOff_DietOff_TCbau", "reference corner name")
chk(cellName(c(1,1,1,1)) == "Protect_BioOn_DietOn_TCendo",    "all-on corner name")

# --- Test 3: purely additive => mains exact, all interactions vanish ---------
grid <- expand.grid(rep(list(0:1), 4))
add  <- list()
for (r in seq_len(nrow(grid))) {
  b <- as.integer(grid[r, ])
  add[[cellName(b)]] <- 10 + 2*b[1] + 3*b[2] + 5*b[3] + 7*b[4]
}
e2 <- decomposeFactorial(add)
chk(abs(e2[["reference"]]  - 10) < 1e-9, "additive: reference = 10")
chk(abs(e2[["protection"]] - 2)  < 1e-9, "additive: protection main = 2")
chk(abs(e2[["bioenergy"]]  - 3)  < 1e-9, "additive: bioenergy main = 3")
chk(abs(e2[["diet"]]       - 5)  < 1e-9, "additive: diet main = 5")
chk(abs(e2[["tc"]]         - 7)  < 1e-9, "additive: tc main = 7")
mains <- c("reference", "protection", "bioenergy", "diet", "tc")
chk(max(abs(unlist(e2[setdiff(names(e2), mains)]))) < 1e-9, "additive: all interactions = 0")

# --- Test 4: pure 4-way interaction -----------------------------------------
abcd <- list()
for (r in seq_len(nrow(grid))) { b <- as.integer(grid[r, ]); abcd[[cellName(b)]] <- prod(b) }
e3 <- decomposeFactorial(abcd)
chk(abs(e3[["protection:bioenergy:diet:tc"]] - 1) < 1e-9, "pure 4-way = 1")
chk(max(abs(unlist(e3[setdiff(names(e3), "protection:bioenergy:diet:tc")]))) < 1e-9,
    "pure 4-way: all other effects = 0")

# --- Test 5: missing corner (the expected-infeasible Protect_BioOn_DietOff_TCbau)
#             NA-propagates only into effects whose incl-excl sum touches it -----
miss <- setNames(as.list(seq_len(16)^1.1), allFactorCells())
miss[["Protect_BioOn_DietOff_TCbau"]] <- NULL   # cell {protection, bioenergy}
e4 <- decomposeFactorial(miss)
# effects referencing {protection,bioenergy}: exactly those S containing BOTH
chk(is.na(e4[["protection:bioenergy"]]),          "missing corner: protection:bioenergy = NA")
chk(is.na(e4[["protection:bioenergy:diet"]]),     "missing corner: protection:bioenergy:diet = NA")
chk(is.na(e4[["protection:bioenergy:tc"]]),       "missing corner: protection:bioenergy:tc = NA")
chk(is.na(e4[["protection:bioenergy:diet:tc"]]),  "missing corner: 4-way = NA")
chk(!is.na(e4[["protection"]]),                   "missing corner: protection main still defined")
chk(!is.na(e4[["diet:tc"]]),                      "missing corner: diet:tc still defined")
chk(!is.na(e4[["bioenergy"]]),                    "missing corner: bioenergy main still defined")

cat("\n", if (fail == 0L) "ALL DECOMPOSITION TESTS PASSED" else
    sprintf("%d TEST(S) FAILED", fail), "\n", sep = "")
if (fail > 0L) quit(status = 1L)
