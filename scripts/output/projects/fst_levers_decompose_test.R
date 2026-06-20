# Synthetic unit test for the fst_levers 2^3 decomposition.
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

set_cells <- function(v) {
  cells <- list(); i <- 1L
  for (a in 0:1) for (b in 0:1) for (c in 0:1) {
    cells[[cubeCellName(a, b, c)]] <- v[i]; i <- i + 1L
  }
  cells
}

# --- Test 1: exact round-trip on arbitrary cell values -----------------------
vals  <- c(12.3, -4.5, 100, 0.7, 88, -1.2, 3.14, 42)
cells <- set_cells(vals)
eff   <- decomposeCube(cells)
rec   <- reconstructCube(eff)
orig  <- unlist(cells)
err   <- max(abs(orig - rec[names(orig)]))
chk(err < 1e-9, sprintf("round-trip reconstruction exact (max err %.2e)", err))

# --- Test 2: purely additive => interactions vanish, mains exact -------------
add <- list()
for (a in 0:1) for (b in 0:1) for (c in 0:1)
  add[[cubeCellName(a, b, c)]] <- 10 + 3*a + 5*b + 7*c
e2 <- decomposeCube(add)
chk(abs(e2$Y_ref - 10)        < 1e-9, "additive: Y_ref = 10")
chk(abs(e2$main_protect - 3)  < 1e-9, "additive: main_protect = 3")
chk(abs(e2$main_bioenergy - 5) < 1e-9, "additive: main_bioenergy = 5")
chk(abs(e2$main_tc - 7)       < 1e-9, "additive: main_tc = 7")
chk(max(abs(c(e2$two_protect_bio, e2$two_protect_tc,
              e2$two_bio_tc, e2$three_way))) < 1e-9,
    "additive: all interactions = 0")

# --- Test 3: pure protection x bioenergy interaction -------------------------
ab <- list()
for (a in 0:1) for (b in 0:1) for (c in 0:1)
  ab[[cubeCellName(a, b, c)]] <- a * b
e3 <- decomposeCube(ab)
chk(abs(e3$two_protect_bio - 1) < 1e-9, "pure AB: two_protect_bio = 1")
chk(max(abs(c(e3$Y_ref, e3$main_protect, e3$main_bioenergy, e3$main_tc,
              e3$two_protect_tc, e3$two_bio_tc, e3$three_way))) < 1e-9,
    "pure AB: all other effects = 0")

# --- Test 4: pure three-way interaction --------------------------------------
abc <- list()
for (a in 0:1) for (b in 0:1) for (c in 0:1)
  abc[[cubeCellName(a, b, c)]] <- a * b * c
e4 <- decomposeCube(abc)
chk(abs(e4$three_way - 1) < 1e-9, "pure ABC: three_way = 1")
chk(max(abs(unlist(e4[setdiff(names(e4), "three_way")]))) < 1e-9,
    "pure ABC: all other effects = 0")

# --- Test 5: missing corner (the expected-infeasible Protect_BioOn_TCbau)
#             propagates NA, so it is surfaced, never silently zero ------------
miss <- set_cells(vals)
miss[["Protect_BioOn_TCbau"]] <- NULL          # cell (1,1,0)
e5 <- decomposeCube(miss)
chk(is.na(e5$two_protect_bio), "missing 110: two_protect_bio = NA (surfaced)")
chk(is.na(e5$three_way),       "missing 110: three_way = NA (surfaced)")
chk(!is.na(e5$main_tc),        "missing 110: main_tc still defined")
chk(!is.na(e5$two_bio_tc),     "missing 110: two_bio_tc still defined")

cat("\n", if (fail == 0L) "ALL DECOMPOSITION TESTS PASSED" else
    sprintf("%d TEST(S) FAILED", fail), "\n", sep = "")
if (fail > 0L) quit(status = 1L)
