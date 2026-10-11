# Reuse the approved DGP and numerical specifications without loading the
# outcome-regression study (this diagnostic does not fit those regressions).
source("scripts/setup.R")
library(data.table)
library(lmtp)
future::plan(future::sequential)
data.table::setDTthreads(1L)
source("studies/longitudinal/dgp.R")
wanted <- c("study_control", "study_shift", "study_arguments", "study_task",
  "cm_library", "state_index", "action_index", "enumerate_data",
  "population_truth_functions", "cell_key", "conditional_mean")
found <- character()
for (expression in parse("studies/longitudinal/study.R")) {
  if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
      is.symbol(expression[[2L]]) && as.character(expression[[2L]]) %in% wanted) {
    eval(expression, envir = .GlobalEnv)
    found <- c(found, as.character(expression[[2L]]))
  }
}
stopifnot(setequal(found, wanted))

true_values <- function(data, g) {
  answer <- population_truth_functions(data, g)
  # Select the inverse measurement-probability bridge, a valid member of the
  # prespecified inverse-expit class, also at histories with a missed visit.
  # The earlier constant bridge at those histories is another valid solution.
  for (s in seq_len(g$tau)) {
    observed <- data[[paste0("R", s + 1L)]] == 1L
    h <- state_index(data, s)
    health <- 1L + data[[paste0("C", s + 1L, "_covariate")]][observed] +
      2L * data[[paste0("Y", s + 1L)]][observed]
    answer$beta[observed, s] <- 1 / g$measurement[cbind(
      data$C1_baseline[observed] + 1L, s, h[observed], health)]
  }
  answer
}

moment_tables <- function(d, task, s, beta, adjoint, phi, weights) {
  H <- task$vars$history("A", s)
  A <- task$vars$A[[s]]
  M <- d[[paste0("R", s + 1L)]] == 1L
  B <- cell_key(task$natural[, c(H, A), drop = FALSE])
  V <- cell_key(cbind(task$natural[, H, drop = FALSE],
    d[, c(paste0("C", s + 1L, "_covariate"), paste0("Y", s + 1L)), drop = FALSE]))
  residual <- rep(-1, nrow(d)); residual[M] <- beta[M] - 1
  bridge <- data.table(cell = B, weight = weights, residual = residual)[,
    .(probability = sum(weight), residual = sum(weight * residual) / sum(weight)), by = cell]
  adj <- data.table(cell = V[M], weight = weights[M],
    loading = phi[M], estimate = adjoint[M])[, .(probability = sum(weight),
      true_conditional_mean = sum(weight * loading) / sum(weight),
      estimated_conditional_mean = sum(weight * estimate) / sum(weight)), by = cell]
  adj[, residual := estimated_conditional_mean - true_conditional_mean]
  list(bridge = bridge, adjoint = adj)
}
