# Pure 2^k treatment-coded factorial decomposition for the fst_levers cube.
#
# Generalized from the original 2^3 version when diet was promoted to a 4th
# factor (2026-06-20). No I/O, no gdx: this is the analytically risky core, so it
# is unit-tested synthetically (known cell values, k = 2..4) BEFORE being trusted
# on real run output. See fst_levers_decompose_test.R.
#
# Factors (reference corner = all-OFF), in canonical name + order. The cell name
# is the underscore-join of the per-factor level labels, which equals the run
# title (<protection>_<bioenergy>_<diet>_<TCstate>):
FST_FACTORS <- list(
  protection = c(off = "NoProtect", on = "Protect"),
  bioenergy  = c(off = "BioOff",    on = "BioOn"),
  diet       = c(off = "DietOff",   on = "DietOn"),
  tc         = c(off = "TCbau",     on = "TCendo")
)
# Reference = NoProtect_BioOff_DietOff_TCbau. Treatment (dummy) coding, so the
# 2^k effect terms reconstruct all 2^k cells EXACTLY:
#   Y(x) = sum over factor-subsets S of  effect_S * prod_{i in S} x_i
# with effect_S = sum_{T subseteq S} (-1)^(|S|-|T|) Y(indicator(T))   (incl-excl).
# This generalizes yield_gap's 2-factor synergy to the full k-factor cube.

# canonical cell name from a 0/1 bit vector (one bit per factor, in factor order)
cellName <- function(bits, factors = FST_FACTORS) {
  bits <- as.integer(bits)
  paste(mapply(function(b, f) if (isTRUE(b == 1L)) f[["on"]] else f[["off"]],
               bits, factors), collapse = "_")
}

# all subsets of an integer vector (includes the empty set), via bitmasks
# (robust; avoids combn(, 0) edge cases)
.subsets <- function(v) {
  n <- length(v)
  if (n == 0) return(list(integer(0)))
  lapply(0:(2^n - 1L), function(m) v[bitwAnd(m, bitwShiftL(1L, seq_len(n) - 1L)) > 0L])
}

.effectLabel <- function(S, factors) {
  if (length(S) == 0) "reference" else paste(names(factors)[S], collapse = ":")
}

# canonical effect order: reference, then mains, then 2-way, ... k-way
effectOrder <- function(factors = FST_FACTORS) {
  idx  <- seq_along(factors)
  subs <- .subsets(idx)
  subs <- subs[order(lengths(subs))]
  vapply(subs, .effectLabel, character(1), factors = factors)
}

# all 2^k cell names (reference first), handy for building cell-value vectors
allFactorCells <- function(factors = FST_FACTORS) {
  idx  <- seq_along(factors)
  subs <- .subsets(idx)
  subs <- subs[order(lengths(subs))]
  vapply(subs, function(S) cellName(as.integer(idx %in% S), factors), character(1))
}

# Decompose a 2^k cube of outcome values into the reference + all 2^k - 1
# treatment-coded effects (k main, choose(k,2) two-way, ... one k-way). `cells`
# is a named list/vector keyed by cellName(). A missing or NA cell NA-propagates
# into every effect whose inclusion-exclusion sum references it, so an infeasible
# corner surfaces as NA rather than being silently treated as zero.
decomposeFactorial <- function(cells, factors = FST_FACTORS) {
  idx <- seq_along(factors)
  getY <- function(Tset) {
    v <- cells[[cellName(as.integer(idx %in% Tset), factors)]]
    if (is.null(v) || length(v) == 0) NA_real_ else as.numeric(v)
  }
  effects <- list()
  for (S in .subsets(idx)) {
    val <- 0
    for (Tt in .subsets(S)) val <- val + (-1)^(length(S) - length(Tt)) * getY(Tt)
    effects[[.effectLabel(S, factors)]] <- val
  }
  effects[effectOrder(factors)]
}

# Reconstruct all 2^k cell values from a decomposition (inverse of the above).
# Returns a named numeric vector keyed by cellName().
reconstructFactorial <- function(effects, factors = FST_FACTORS) {
  idx  <- seq_along(factors)
  grid <- expand.grid(rep(list(c(0L, 1L)), length(factors)))
  out  <- numeric(0)
  for (r in seq_len(nrow(grid))) {
    bits <- as.integer(grid[r, ])
    y <- effects[["reference"]]
    for (S in .subsets(idx)) {
      if (length(S) == 0) next
      y <- y + effects[[.effectLabel(S, factors)]] * prod(bits[S])
    }
    out[cellName(bits, factors)] <- y
  }
  out
}
