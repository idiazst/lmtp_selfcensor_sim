# Both arms fit the complete full-history curve. Each closure shares the same
# fold-scoped nuisance models between SDR and TMLE on this dataset only.
four_dose_full_adapter <- function(data, folds, specification, seed, variant) {
  variant <- match.arg(variant, c("baseline", "optimized"))
  optimized <- identical(variant, "optimized")
  control <- specification$control
  if (isTRUE(specification$policy_support))
    control$.fh_ratio_support <- list(d = four_dose_support_d, t = four_dose_support_t)
  control$.fh_cache_predictions <- optimized
  control$.fh_ratio_seed <- seed
  outer_only <- identical(specification$crossfit, "outer")
  if (outer_only) control$.fh_nested_responses <- FALSE
  learner_folds <- NULL
  if (outer_only) {
    labels <- integer(nrow(data))
    for (j in seq_along(folds)) labels[folds[[j]]$validation_set] <- j
    learner_folds <- lapply(folds, function(fold) labels[fold$training_set])
  }
  count <- if (optimized) 4L else 20L
  nodes <- (seq_len(count) - 0.5) / count
  nuisance_cache <- new.env(parent = emptyenv())
  treatment <- list(c("D1", "B1"), c("D2", "B2"))
  health <- list(c("Y1", "X1"), c("Y2", "X2"), c("Y3", "X3"))

  alpha <- function(data, trt) matrix(0, nrow(data), length(trt))
  attended <- function(data, trt) {
    cbind(pmin(data[[trt[1L]]] + 1L, 3L), data[[trt[2L]]])
  }
  continuation <- function(data, trt, epsilon) {
    cbind(pmin(floor(4 * epsilon), 3), rep(0, nrow(data)))
  }
  summarize_fit <- function(fit) {
    if (isTRUE(fit$known)) return(list(known = TRUE))
    list(weights = fit$weights,
         penalties = lapply(fit$candidates, function(candidate) {
           list(selected = candidate$penalty_cv[candidate$penalty_cv$selected, , drop = FALSE],
                status = candidate$penalty_status)
         }),
         candidate_failures = fit$candidate_failures)
  }
  function(method) {
    method <- match.arg(method, c("sdr", "tmle"))
    fit <- lmtp::lmtp_full_history(
      data = data, trt = treatment, outcome = c("Y2", "Y3"),
      measurement = c("R1", "R2", "R3"), health = health,
      k = 1, alpha = alpha, d = attended, t = continuation,
      epsilon = nodes, ratio_draws = 5L, estimator = method,
      folds = folds, learner_folds = learner_folds, learners_outcome = specification$learners,
      learners_trt = specification$learners, bridge_library = specification$bridge,
      adjoint_library = specification$adjoint, control = control,
      nuisance_cache = nuisance_cache
    )
    list(estimates = unname(fit$unprojected_estimates),
         se = vapply(fit$estimates, function(x) ife::tidy(x)$std.error, numeric(1)),
         eif = unname(fit$influence_functions),
         diagnostics = list(
           integration_doses = floor(4 * nodes),
           cache = lapply(fit$bridge_fits, function(fold) fold$cache_counts),
           bridge = lapply(fit$bridge_fits, function(fold) lapply(fold$bridges, summarize_fit)),
           adjoint = lapply(fit$bridge_fits, function(fold) {
             lapply(fold$adjoints, function(target) lapply(target, summarize_fit))
           }),
           weight_range = apply(fit$propagation_weights, 2L, range),
           targeting = fit$targeting
         ))
  }
}
