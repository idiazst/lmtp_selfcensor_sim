# Functions for saved-output analysis. Nothing here fits a nuisance or estimator.
recover_saved_gradients <- function(checkpoint) {
  g <- make_mechanism(checkpoint$design$mechanism, dose_max = 3L,
    visits = checkpoint$design$visits)
  set.seed(checkpoint$design$seed)
  data <- draw_data(checkpoint$design$n, g)
  n <- nrow(data)
  population <- checkpoint$population
  index <- match(cell_key(data), cell_key(population[, names(data), drop = FALSE]))
  stopifnot(!anyNA(index), !anyDuplicated(cell_key(population[, names(data), drop = FALSE])))
  folds <- checkpoint$folds
  validation_rows <- unlist(lapply(folds, `[[`, "validation_set"))
  stopifnot(identical(sort(as.integer(validation_rows)), seq_len(n)))
  fold_id <- integer(n)
  for (j in seq_along(folds)) fold_id[folds[[j]]$validation_set] <- j
  results <- copy(checkpoint$results)
  if (is.null(results) || !nrow(results))
    return(list(results = data.table(), audit = data.table(), cells = NULL))
  setorder(results, estimator, horizon)
  scores <- matrix(NA_real_, n, nrow(results))
  audit <- list()
  for (method in unique(results$estimator)) {
    columns <- which(results$estimator == method)
    z <- results[columns]
    stopifnot(uniqueN(z$scenario) == 1L)
    for (j in seq_along(folds)) {
      name <- paste(method, z$scenario[1L], j, sep = "/")
      nu <- checkpoint$fitted_functions[[name]]
      stopifnot(!is.null(nu))
      support_scores <- raw_scores(population, g, nu)$score
      v <- folds[[j]]$validation_set
      scores[v, columns] <- support_scores[index[v], z$horizon, drop = FALSE]
    }
  }
  stopifnot(all(is.finite(scores)))
  estimate <- colMeans(scores)
  se <- apply(scores, 2L, sd) / sqrt(n)
  estimate_error <- abs(estimate - results$estimate)
  se_error <- abs(se - results$se)
  # Saved predictions on the full support can differ from the original
  # validation-row batch at floating-point precision. Measure that discrepancy
  # in sampling-SE units rather than an arbitrary outcome-unit tolerance.
  stopifnot(all(estimate_error / results$se < 1e-5), all(se_error / results$se < 1e-5))
  centered <- sweep(scores, 2L, estimate, "-")
  if (!is.null(checkpoint$eif_components) && nrow(checkpoint$eif_components)) {
    for (k in seq_len(nrow(results))) {
      row <- results[k]
      recorded <- checkpoint$eif_components[estimator == row$estimator & horizon == row$horizon & scenario == row$scenario][order(person)]
      stopifnot(nrow(recorded) == n, max(abs(recorded$total_eif - centered[, k])) < 1e-8)
    }
  }
  key <- paste(fold_id, index, sep = "/")
  unique_keys <- unique(key)
  group <- match(key, unique_keys)
  first <- match(unique_keys, key)
  counts <- tabulate(group, nbins = length(unique_keys))
  values <- centered[first, , drop = FALSE]
  stopifnot(sum(counts) == n, max(abs(values[group, , drop = FALSE] - centered)) < 1e-10,
    max(abs(colSums(values * counts))) < 1e-7)
  audit <- results[, .(estimator, horizon, scenario)]
  audit[, `:=`(estimate_error = estimate_error, se_error = se_error,
    estimate_error_over_se = estimate_error / results$se, se_relative_error = se_error / results$se,
    influence_mean = colMeans(centered), grouped_cells = length(counts), observations = n,
    conditional_skewness_exponential = 2 * colSums(centered^3) / colSums(centered^2)^1.5,
    conditional_excess_kurtosis_rademacher = -2 * colSums(centered^4) / colSums(centered^2)^2,
    conditional_excess_kurtosis_exponential = 6 * colSums(centered^4) / colSums(centered^2)^2)]
  list(results = results, audit = audit,
    cells = list(count = counts, centered_score = values, fold = fold_id[first], population_row = index[first]))
}

multiplier_intervals <- function(recovered, n, seed, draws = 9999L, batch = 500L) {
  base <- recovered$results
  if (!nrow(base)) return(data.table())
  stopifnot(n >= 2L, draws >= 999L, batch >= 1L)
  counts <- recovered$cells$count
  values <- recovered$cells$centered_score
  # This uses the same R-1 sample-variance convention as the saved Wald SEs.
  normalization <- sqrt(n / (n - 1L)) / n
  output <- list()
  for (law in c("gaussian", "rademacher", "exponential")) {
    timing <- proc.time()[["elapsed"]]
    if (law == "gaussian") {
      # Exact conditional Gaussian quantiles; no Monte Carlo noise is needed.
      lower_quantile <- -qnorm(.975) * base$se
      upper_quantile <- qnorm(.975) * base$se
      simulated_sd <- base$se
      draws_used <- 0L
    } else {
      set.seed(1200000000L + as.integer(seed) + if (law == "exponential") 10000000L else 0L)
      perturbations <- matrix(NA_real_, draws, nrow(base))
      for (start in seq.int(1L, draws, by = batch)) {
        end <- min(draws, start + batch - 1L)
        b <- end - start + 1L
        sizes <- rep(counts, each = b)
        # Equal person-level score vectors can be grouped exactly. Binomial
        # and Gamma sums retain the law of independent person multipliers.
        multipliers <- if (law == "rademacher")
          matrix(2 * rbinom(b * length(counts), size = sizes, prob = .5) - sizes, b) else
          matrix(rgamma(b * length(counts), shape = sizes, rate = 1) - sizes, b)
        perturbations[start:end, ] <- (multipliers %*% values) * normalization
      }
      if (law == "rademacher") {
        # The conditional distribution is symmetric; pool both tails.
        upper_quantile <- apply(abs(perturbations), 2L, quantile, .95, names = FALSE, type = 7L)
        lower_quantile <- -upper_quantile
      } else {
        lower_quantile <- apply(perturbations, 2L, quantile, .025, names = FALSE, type = 7L)
        upper_quantile <- apply(perturbations, 2L, quantile, .975, names = FALSE, type = 7L)
      }
      simulated_sd <- apply(perturbations, 2L, sd)
      draws_used <- draws
    }
    row <- base[, .(mechanism, n, replicate, seed, estimator, horizon, scenario, truth, estimate,
      se, original_lower = lower, original_upper = upper)]
    row[, `:=`(multiplier = law, bootstrap_draws = draws_used,
      lower_error_quantile = lower_quantile, upper_error_quantile = upper_quantile,
      lower = estimate - upper_quantile, upper = estimate - lower_quantile,
      conditional_sd = se, simulated_sd = simulated_sd,
      seconds = proc.time()[["elapsed"]] - timing)]
    row[, `:=`(covered = lower <= truth & upper >= truth,
      original_covered = original_lower <= truth & original_upper >= truth,
      interval_length = upper - lower)]
    if (law == "gaussian") stopifnot(max(abs(row$lower - row$original_lower)) < 1e-10,
      max(abs(row$upper - row$original_upper)) < 1e-10, identical(row$covered, row$original_covered))
    output[[law]] <- row
  }
  rbindlist(output)
}
