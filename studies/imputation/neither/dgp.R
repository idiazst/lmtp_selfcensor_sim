# Proposed MI comparison: one treatment time and one partially observed outcome.
# Exact population calculations are design audits, never estimator inputs.

mi_scenarios <- c("mar_only", "shadow_only", "both", "neither")

mi_treatment_probability <- function(w) .4 + .2 * w
mi_outcome_probability <- function(w, a) .2 + .1 * w + .5 * a
mi_response_probability <- function(w, a, y, scenario) {
  scenario <- match.arg(scenario, mi_scenarios)
  switch(scenario,
    mar_only = .5 + .1 * w + .2 * a,
    shadow_only = .8 + .1 * w - .4 * y,
    both = .6 + .1 * w,
    neither = .675 + .1 * w + .15 * a - .3 * y)
}

mi_population <- function(scenario) {
  scenario <- match.arg(scenario, mi_scenarios)
  d <- expand.grid(W = 0:1, A1 = 0:1, Y2 = 0:1, R2 = 0:1)
  d$g <- mi_treatment_probability(d$W)
  d$mu <- mi_outcome_probability(d$W, d$A1)
  d$rho <- mi_response_probability(d$W, d$A1, d$Y2, scenario)
  d$probability <- .5 * dbinom(d$A1, 1, d$g) *
    dbinom(d$Y2, 1, d$mu) * dbinom(d$R2, 1, d$rho)
  d$scenario <- scenario
  d
}

# Not called by the population audit. Latent outcomes are separated from the
# observed frame so fitting code cannot accidentally use unobserved values.
mi_draw_data <- function(n, scenario) {
  scenario <- match.arg(scenario, mi_scenarios)
  w <- as.integer(runif(n) < .5)
  a <- as.integer(runif(n) < mi_treatment_probability(w))
  y <- as.integer(runif(n) < mi_outcome_probability(w, a))
  r <- as.integer(runif(n) < mi_response_probability(w, a, y, scenario))
  list(observed = data.frame(W = w, A1 = a,
      Y2 = ifelse(r == 1L, y, NA_integer_), R2 = r),
    latent_for_audit_only = data.frame(Y2_full = y))
}
