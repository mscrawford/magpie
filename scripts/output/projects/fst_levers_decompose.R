# |  (C) 2008-2025 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of MAgPIE and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  MAgPIE License Exception, version 1.0 (see LICENSE file).
# |  Contact: magpie@pik-potsdam.de

# Treatment-coded 2^k factorial decomposition for the fst_levers experiment.
# Pure functions: no gdx, no plotting, no MAgPIE dependency. Unit-tested by
# scripts/output/projects/fst_levers_decompose_test.R -- run that before
# trusting any number this file produces on real output.
#
# WHY A GENERAL 2^k AND NOT A HARD-CODED CUBE: fst_levers is two overlapping
# 2^3 cubes (see fst_levers_config.R). Both go through the same code here, and
# a later design change in the factor count does not require a rewrite.
#
# ---------------------------------------------------------------------------
# SIGN CONVENTION (read this before quoting any number)
#
# Effects here are in the NATURAL direction:
#
#     effect > 0  =>  turning the factor ON INCREASES the outcome
#
# The yield_gap deliverables used the OPPOSITE convention ("positive delta =
# the lever REDUCES the outcome"). Do not mix them. Convert once, explicitly,
# at the reporting boundary with asReductionConvention(), never ad hoc in a
# plotting call.
# ---------------------------------------------------------------------------
#
# MISSING CELLS. Infeasible corners are expected in this design (Half-Earth
# protection plus high bioenergy demand with tau pinned to BAU is the likeliest
# to fail). Every effect whose inclusion-exclusion sum touches an absent cell is
# returned as NA and reported as NA. It is never silently zeroed, and never
# quietly dropped from a mean.

# ---- internals --------------------------------------------------------------

# Canonical key for a cell: the ON factors, in the order given by `factors`.
# The all-OFF corner is "(reference)".
.cellKey <- function(on, factors) {
  on <- factors[factors %in% on]
  if (length(on) == 0) "(reference)" else paste(on, collapse = ":")
}

# All subsets of `factors`, as a list of character vectors, ordered by size.
.subsets <- function(factors) {
  out <- list(character(0))
  for (k in seq_along(factors)) {
    out <- c(out, utils::combn(factors, k, simplify = FALSE))
  }
  out
}

# Map a cells data.frame to a lookup keyed by .cellKey.
.cellLookup <- function(cells, factors, value_col) {
  stopifnot(all(factors %in% names(cells)), value_col %in% names(cells))
  lvl <- unique(unlist(cells[factors]))
  bad <- setdiff(lvl, c("on", "off"))
  if (length(bad)) stop("factor columns must be 'on'/'off'; found: ", paste(bad, collapse = ", "))
  keys <- vapply(seq_len(nrow(cells)), function(i) {
    .cellKey(factors[unlist(cells[i, factors]) == "on"], factors)
  }, character(1))
  if (anyDuplicated(keys)) {
    stop("duplicate cells for: ", paste(unique(keys[duplicated(keys)]), collapse = ", "))
  }
  stats::setNames(as.numeric(cells[[value_col]]), keys)
}

# ---- public -----------------------------------------------------------------

#' Treatment-coded decomposition of a 2^k factorial.
#'
#' effect(T) = sum over S subset of T of (-1)^(|T|-|S|) * Y(S)
#' with the all-OFF corner Y(empty) reported as the "(reference)" term.
#'
#' @param cells     data.frame, one row per cell, one "on"/"off" column per factor
#' @param factors   character vector of factor column names
#' @param value_col name of the numeric outcome column
#' @return data.frame(term, order, effect, n_missing) ordered by interaction order
decomposeFactorial <- function(cells, factors, value_col = "value") {
  Y <- .cellLookup(cells, factors, value_col)
  terms <- .subsets(factors)

  rows <- lapply(terms, function(tset) {
    key <- .cellKey(tset, factors)
    if (length(tset) == 0) {
      return(data.frame(term = key, order = 0L,
                        effect = unname(Y[key]),
                        n_missing = as.integer(is.na(Y[key]) || is.na(unname(Y[key]))),
                        stringsAsFactors = FALSE))
    }
    subs <- .subsets(tset)
    vals <- vapply(subs, function(s) {
      v <- Y[.cellKey(s, factors)]
      if (length(v) == 0) NA_real_ else unname(v)
    }, numeric(1))
    signs <- vapply(subs, function(s) (-1)^(length(tset) - length(s)), numeric(1))
    n_missing <- sum(is.na(vals))
    data.frame(term = key, order = length(tset),
               effect = if (n_missing > 0) NA_real_ else sum(signs * vals),
               n_missing = as.integer(n_missing), stringsAsFactors = FALSE)
  })

  out <- do.call(rbind, rows)
  out[order(out$order, out$term), ]
}

#' Rebuild every cell from a decomposition. Y(S) = sum over T subset of S of effect(T).
#' Exact round-trip is the decomposition's own correctness check.
reconstructFactorial <- function(effects, factors) {
  eff <- stats::setNames(effects$effect, effects$term)
  cellsets <- .subsets(factors)
  rows <- lapply(cellsets, function(s) {
    subs <- .subsets(s)
    vals <- vapply(subs, function(t) {
      v <- eff[.cellKey(t, factors)]
      if (length(v) == 0) NA_real_ else unname(v)
    }, numeric(1))
    d <- as.data.frame(as.list(stats::setNames(
      ifelse(factors %in% s, "on", "off"), factors)), stringsAsFactors = FALSE)
    d$value <- if (anyNA(vals)) NA_real_ else sum(vals)
    d
  })
  do.call(rbind, rows)
}

#' Flip to the yield_gap reporting convention: positive = the lever REDUCES the
#' outcome. The reference level itself is NOT negated (it is a level, not an effect).
asReductionConvention <- function(effects) {
  effects$effect <- ifelse(effects$order == 0, effects$effect, -effects$effect)
  attr(effects, "sign_convention") <- "positive = lever reduces the outcome (yield_gap convention)"
  effects
}

#' Averaged pairwise interaction between two factors, over every context formed
#' by the other factors' levels.
#'
#' For each context: d1 = Y(f1) - Y(0), d2 = Y(f2) - Y(0), d12 = Y(f1,f2) - Y(0),
#' interaction = d12 - (d1 + d2).
#'
#' Classification is relative to the COMMON DIRECTION of the two main effects:
#'   substitute  - joint effect weaker than the sum of parts
#'   complement  - joint effect stronger than the sum of parts
#'   additive    - interaction negligible against the larger main effect
#'   mixed       - the two main effects point in opposite directions, so
#'                 "weaker/stronger than additive" has no single meaning
#'
#' Contexts with a missing corner are skipped and counted in n_missing_contexts;
#' they are never treated as zero.
pairwiseInteractions <- function(cells, factors, f1, f2, value_col = "value", tol = 0.05) {
  stopifnot(f1 %in% factors, f2 %in% factors, f1 != f2)
  Y <- .cellLookup(cells, factors, value_col)
  others <- setdiff(factors, c(f1, f2))

  contexts <- .subsets(others)
  res <- lapply(contexts, function(ctx) {
    g <- function(extra) {
      v <- Y[.cellKey(c(ctx, extra), factors)]
      if (length(v) == 0) NA_real_ else unname(v)
    }
    y00 <- g(character(0)); y10 <- g(f1); y01 <- g(f2); y11 <- g(c(f1, f2))
    if (anyNA(c(y00, y10, y01, y11))) return(NULL)
    d1 <- y10 - y00; d2 <- y01 - y00; d12 <- y11 - y00
    data.frame(context = .cellKey(ctx, factors),
               d1 = d1, d2 = d2, d12 = d12, interaction = d12 - (d1 + d2),
               stringsAsFactors = FALSE)
  })
  keep <- Filter(Negate(is.null), res)
  n_missing <- length(contexts) - length(keep)

  if (length(keep) == 0) {
    return(list(factors = c(f1, f2), mean_interaction = NA_real_,
                classification = NA_character_, n_contexts = 0L,
                n_missing_contexts = as.integer(n_missing), contexts = NULL))
  }
  tab <- do.call(rbind, keep)
  mi <- mean(tab$interaction)
  d1m <- mean(tab$d1); d2m <- mean(tab$d2)
  scale <- max(abs(d1m), abs(d2m))

  cls <- if (!is.finite(scale) || scale == 0) {
    "additive"
  } else if (abs(mi) < tol * scale) {
    "additive"
  } else if (sign(d1m) != sign(d2m) || d1m == 0 || d2m == 0) {
    "mixed"
  } else if (sign(mi) != sign(d1m)) {
    "substitute"
  } else {
    "complement"
  }

  list(factors = c(f1, f2), mean_interaction = mi, classification = cls,
       n_contexts = nrow(tab), n_missing_contexts = as.integer(n_missing),
       contexts = tab)
}
