# Pure 2^3 factorial decomposition for the fst_levers cube.
#
# No I/O, no gdx: this is the analytically risky core, so it is unit-tested
# synthetically (8 known cell values) BEFORE being trusted on real run output.
# See fst_levers_decompose_test.R.
#
# Factors (reference = the all-OFF corner NoProtect_BioOff_TCbau):
#   A = forest protection   (0 = NoProtect, 1 = Protect)
#   B = 2nd-gen bioenergy    (0 = BioOff,    1 = BioOn)
#   C = technological change (0 = TCbau,     1 = TCendo)
#
# Treatment (dummy) coding, so the 8 terms reconstruct all 8 cells EXACTLY:
#   Y(a,b,c) = Yref + a*A + b*B + c*C + ab*AB + ac*AC + bc*BC + abc*ABC
# This generalizes yield_gap's 2-factor synergy (= the AB interaction in a
# single TC plane) to the full 3-factor cube.

# Canonical cube cell name from binary factor levels (matches the run titles
# minus the TC suffix convention: <Protect|NoProtect>_<BioOn|BioOff>_<TCendo|TCbau>).
cubeCellName <- function(a, b, c) {
  paste(if (a) "Protect" else "NoProtect",
        if (b) "BioOn"   else "BioOff",
        if (c) "TCendo"  else "TCbau",
        sep = "_")
}

# Decompose a cube of 8 outcome values into reference + 3 main + 3 two-way + 1
# three-way effect. `cells` is a named list/vector keyed by cubeCellName().
# A missing or NA cell propagates NA into every effect that references it, so an
# infeasible corner (the expected Protect_BioOn_TCbau) surfaces as NA rather
# than being silently treated as zero.
decomposeCube <- function(cells) {
  g <- function(a, b, c) {
    v <- cells[[cubeCellName(a, b, c)]]
    if (is.null(v) || length(v) == 0) NA_real_ else as.numeric(v)
  }
  Y000 <- g(0,0,0); Y100 <- g(1,0,0); Y010 <- g(0,1,0); Y001 <- g(0,0,1)
  Y110 <- g(1,1,0); Y101 <- g(1,0,1); Y011 <- g(0,1,1); Y111 <- g(1,1,1)
  list(
    Y_ref            = Y000,
    main_protect     = Y100 - Y000,
    main_bioenergy   = Y010 - Y000,
    main_tc          = Y001 - Y000,
    two_protect_bio  = Y110 - Y100 - Y010 + Y000,
    two_protect_tc   = Y101 - Y100 - Y001 + Y000,
    two_bio_tc       = Y011 - Y010 - Y001 + Y000,
    three_way        = Y111 - Y110 - Y101 - Y011 + Y100 + Y010 + Y001 - Y000
  )
}

# Reconstruct all 8 cell values from a decomposition (inverse of decomposeCube).
# Returns a named numeric vector keyed by cubeCellName().
reconstructCube <- function(eff) {
  rec <- function(a, b, c) {
    eff$Y_ref + a*eff$main_protect + b*eff$main_bioenergy + c*eff$main_tc +
      a*b*eff$two_protect_bio + a*c*eff$two_protect_tc + b*c*eff$two_bio_tc +
      a*b*c*eff$three_way
  }
  out <- numeric(0)
  for (a in 0:1) for (b in 0:1) for (c in 0:1) {
    out[cubeCellName(a, b, c)] <- rec(a, b, c)
  }
  out
}

# Convenience: the 8 cube cell names (NoProtect_BioOff_TCbau is the reference).
cubeCellNames <- function() {
  out <- character(0)
  for (a in 0:1) for (b in 0:1) for (c in 0:1) out <- c(out, cubeCellName(a, b, c))
  out
}
