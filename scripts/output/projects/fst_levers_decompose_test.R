# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# Synthetic unit test for fst_levers_decompose.R.
#
# Run this BEFORE trusting the decomposition on real gdx output:
#   Rscript scripts/output/projects/fst_levers_decompose_test.R
#
# The cell values below are CONSTRUCTED from known effects, so the expected
# answer is exact and independent of any model run. Without a positive test like
# this, "no interaction found" is indistinguishable from "the algebra is wrong".
#
# Every assertion goes through chk(), which counts. The script fails unless the
# executed assertion count equals EXPECTED_CHECKS, so a block that silently did
# not run cannot pass.

here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1]))
if (is.na(here) || !nzchar(here)) here <- "scripts/output/projects"
source(file.path(here, "fst_levers_decompose.R"))

EXPECTED_CHECKS <- 30L
n_checks <- 0L; n_fail <- 0L
chk <- function(cond, label) {
  n_checks <<- n_checks + 1L
  status <- if (isTRUE(cond)) "ok  " else { n_fail <<- n_fail + 1L; "FAIL" }
  cat("  [", status, "] ", label, "\n", sep = "")
}
eq <- function(a, b, tol = 1e-9) is.finite(a) && is.finite(b) && abs(a - b) < tol

FACTORS <- c("a", "b", "c")

# Keys are ":"-joined ON factors, with the all-OFF corner named "(reference)"
# to match fst_levers_decompose.R (and because y[[""]] is an R error).
REF <- "(reference)"
onOf <- function(k) if (identical(k, REF)) character(0) else strsplit(k, ":", fixed = TRUE)[[1]]

# Build a cells data.frame from a Y vector keyed as above.
mkCellsFor <- function(y, fac) {
  rows <- lapply(seq_along(y), function(i) {
    on <- onOf(names(y)[i])
    d <- as.data.frame(as.list(stats::setNames(
      ifelse(fac %in% on, "on", "off"), fac)), stringsAsFactors = FALSE)
    d$value <- unname(y[i]); d
  })
  do.call(rbind, rows)
}
mkCells <- function(y) mkCellsFor(y, FACTORS)

# --- ground truth: cells built FROM known effects ---------------------------
TRUE_EFF <- c(reference = 100, a = 10, b = 20, c = 40,
              `a:b` = 3, `a:c` = 5, `b:c` = 7, `a:b:c` = 1)
Y <- c(100,
       100 + 10,
       100 + 20,
       100 + 40,
       100 + 10 + 20 + 3,
       100 + 10 + 40 + 5,
       100 + 20 + 40 + 7,
       100 + 10 + 20 + 40 + 3 + 5 + 7 + 1)
names(Y) <- c(REF, "a", "b", "c", "a:b", "a:c", "b:c", "a:b:c")
cells <- mkCells(Y)

# key of row i of a cells data.frame, in the same "(reference)"/"a:b" vocabulary
keyOf <- function(df, i, fac = FACTORS) {
  on <- fac[unlist(df[i, fac]) == "on"]
  if (length(on) == 0) REF else paste(on, collapse = ":")
}
keysOf <- function(df, fac = FACTORS) {
  vapply(seq_len(nrow(df)), function(i) keyOf(df, i, fac), character(1))
}
dropCell <- function(df, k) df[keysOf(df) != k, , drop = FALSE]
# same, but for an arbitrary factor set (used by the 2^4 block below)
dropCell4 <- function(df, k, fac) df[keysOf(df, fac) != k, , drop = FALSE]

cat("full 2^3 cube -- effects must be recovered exactly:\n")
d <- decomposeFactorial(cells, FACTORS)
get <- function(term) d$effect[d$term == term]

chk(eq(get("(reference)"), 100), "reference = 100")
chk(eq(get("a"), 10),            "main effect a = 10")
chk(eq(get("b"), 20),            "main effect b = 20")
chk(eq(get("c"), 40),            "main effect c = 40")
chk(eq(get("a:b"), 3),           "two-way a:b = 3")
chk(eq(get("a:c"), 5),           "two-way a:c = 5")
chk(eq(get("b:c"), 7),           "two-way b:c = 7")
chk(eq(get("a:b:c"), 1),         "three-way a:b:c = 1")

cat("\nround trip:\n")
rec   <- reconstructFactorial(d, FACTORS)
rec_y <- stats::setNames(rec$value, keysOf(rec))
chk(all(vapply(seq_along(Y), function(i) eq(rec_y[[names(Y)[i]]], unname(Y[i])), logical(1))),
    "reconstructFactorial rebuilds all 8 cells exactly")

cat("\nmissing corners must propagate as NA, never as zero:\n")
d_no_abc <- decomposeFactorial(dropCell(cells, "a:b:c"), FACTORS)
g2 <- function(term) d_no_abc$effect[d_no_abc$term == term]
chk(is.na(g2("a:b:c")),  "dropping the abc corner -> three-way is NA")
chk(eq(g2("a:b"), 3),    "...and a:b is still exact")
chk(eq(g2("a"), 10),     "...and main effect a is still exact")

d_no_ab <- decomposeFactorial(dropCell(cells, "a:b"), FACTORS)
g3 <- function(term) d_no_ab$effect[d_no_ab$term == term]
chk(is.na(g3("a:b")) && is.na(g3("a:b:c")),
    "dropping the ab corner -> a:b AND a:b:c are NA (inclusion-exclusion touches it)")
chk(eq(g3("a:c"), 5) && eq(g3("b:c"), 7),
    "...and the untouched two-ways are still exact")

d_no_ref <- decomposeFactorial(dropCell(cells, REF), FACTORS)
chk(all(is.na(d_no_ref$effect)),
    "dropping the reference corner -> every effect is NA")

cat("\nsign convention:\n")
r <- asReductionConvention(d)
chk(eq(r$effect[r$term == "a"], -10) && eq(r$effect[r$term == "(reference)"], 100),
    "asReductionConvention negates effects but not the reference level")

cat("\npairwise interaction classification:\n")
F2  <- c("a", "b")
mk2 <- function(vals) {
  y <- vals; names(y) <- c(REF, "a", "b", "a:b")
  mkCellsFor(y, F2)
}
# both main effects positive, joint weaker than additive -> substitute
sub <- pairwiseInteractions(mk2(c(100, 110, 120, 125)), F2, "a", "b")
chk(sub$classification == "substitute" && eq(sub$mean_interaction, -5),
    "joint weaker than sum of parts -> substitute (interaction -5)")
# exactly additive
add <- pairwiseInteractions(mk2(c(100, 110, 120, 130)), F2, "a", "b")
chk(add$classification == "additive" && eq(add$mean_interaction, 0),
    "joint equal to sum of parts -> additive")
# joint stronger than additive -> complement
cmp <- pairwiseInteractions(mk2(c(100, 110, 120, 140)), F2, "a", "b")
chk(cmp$classification == "complement", "joint stronger than sum of parts -> complement")
# opposing main effects -> mixed
mix <- pairwiseInteractions(mk2(c(100, 110, 80, 85)), F2, "a", "b")
chk(mix$classification == "mixed", "main effects in opposite directions -> mixed")

cat("\nmissing contexts are counted, not silently averaged away:\n")
pw_full <- pairwiseInteractions(cells, FACTORS, "a", "b")
chk(pw_full$n_contexts == 2 && pw_full$n_missing_contexts == 0,
    "full cube -> both contexts (c off, c on) used")
pw_gap <- pairwiseInteractions(dropCell(cells, "a:b:c"), FACTORS, "a", "b")
chk(pw_gap$n_contexts == 1 && pw_gap$n_missing_contexts == 1,
    "one corner gone -> 1 context used, 1 reported missing")

# --- 2^4 cube: the design produces two of these (Prot x Diet x TC x one of ----
# {Bio, Climate}), so exercise a 4-factor decomposition end to end. Cells are
# built INDEPENDENTLY of the code under test (a plain subset-sum over known
# effects), so recovery is a real check, not a round-trip against the same code.
cat("\n2^4 cube -- 4-factor decomposition recovered exactly:\n")
FACTORS4 <- c("w", "x", "y", "z")

# subsets of a factor vector, as ":"-joined keys ("(reference)" for the empty set)
subsetKeys4 <- function(fac) {
  ks <- "(reference)"
  for (k in seq_along(fac)) {
    ks <- c(ks, apply(utils::combn(fac, k), 2, paste, collapse = ":"))
  }
  ks
}
# known effects: 4 mains, a few interactions, rest zero
EFF4 <- c(`(reference)` = 50, w = 4, x = 8, y = 16, z = 32,
          `w:x` = 2, `y:z` = 3, `w:x:y` = 1)
# Y(S) = sum over T subset of S of EFF4[T]; missing effect keys are 0
allKeys4 <- subsetKeys4(FACTORS4)
Y4 <- vapply(allKeys4, function(k) {
  on   <- onOf(k)                                   # ON factors of this cell
  subs <- subsetKeys4(if (length(on) == 0) character(0) else on)
  sum(vapply(subs, function(t) {
    e <- EFF4[t]; if (is.na(e)) 0 else unname(e)
  }, numeric(1)))
}, numeric(1))
names(Y4) <- allKeys4
cells4 <- mkCellsFor(Y4, FACTORS4)

d4  <- decomposeFactorial(cells4, FACTORS4)
g4  <- function(term) d4$effect[d4$term == term]
chk(eq(g4("w"), 4) && eq(g4("x"), 8) && eq(g4("y"), 16) && eq(g4("z"), 32),
    "2^4: all four main effects recovered")
chk(eq(g4("w:x"), 2) && eq(g4("y:z"), 3),
    "2^4: the two-way interactions w:x and y:z recovered")
chk(eq(g4("w:x:y"), 1), "2^4: the three-way interaction w:x:y recovered")
chk(eq(g4("x:y"), 0) && eq(g4("w:x:y:z"), 0),
    "2^4: unset interactions come back as 0, not spurious")
rec4   <- reconstructFactorial(d4, FACTORS4)
rec4_y <- stats::setNames(rec4$value, keysOf(rec4, FACTORS4))
chk(all(vapply(allKeys4, function(k) eq(rec4_y[[k]], unname(Y4[k])), logical(1))),
    "2^4: reconstructFactorial rebuilds all 16 cells exactly")
d4_gap <- decomposeFactorial(dropCell4(cells4, "w:x:y:z", FACTORS4), FACTORS4)
chk(is.na(d4_gap$effect[d4_gap$term == "w:x:y:z"]) &&
    eq(d4_gap$effect[d4_gap$term == "w:x"], 2),
    "2^4: dropping the 4-way corner -> only the 4-way is NA, lower terms exact")

cat("\ninput validation:\n")
dup <- rbind(cells, cells[1, ])
chk(inherits(try(decomposeFactorial(dup, FACTORS), silent = TRUE), "try-error"),
    "duplicate cells are rejected")
bad <- cells; bad$a[1] <- "yes"
chk(inherits(try(decomposeFactorial(bad, FACTORS), silent = TRUE), "try-error"),
    "factor levels other than on/off are rejected")

cat("\nassertions executed: ", n_checks, " (expected ", EXPECTED_CHECKS, "), failures: ",
    n_fail, "\n", sep = "")
if (n_checks != EXPECTED_CHECKS) { cat("INVALID: assertion count mismatch\n"); quit(status = 2L) }
cat(if (n_fail == 0L) "ALL CHECKS PASSED\n" else "THERE WERE FAILURES\n")
quit(status = if (n_fail == 0L) 0L else 1L)
