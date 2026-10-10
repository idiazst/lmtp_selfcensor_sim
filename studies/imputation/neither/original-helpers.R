# All statistical package code is loaded from the pinned private library.
mi_root <- Sys.getenv("MI_STUDY_ROOT", "/Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/.runtime")
mi_source <- Sys.getenv("MI_STUDY_SOURCE", "/Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/studies/imputation/neither")
.libPaths(c(file.path(mi_root, "library"), .Library), include.site = FALSE)
stopifnot(as.character(packageVersion("cmbridge")) == "0.3.0.9020",
          as.character(packageVersion("lmtp")) == "1.6.0.9021",
          as.character(packageVersion("mice")) == "3.19.0")
for (pkg in c("cmbridge", "lmtp", "mice")) stopifnot(
  normalizePath(dirname(find.package(pkg))) == normalizePath(file.path(mi_root, "library")))
library(lmtp)
future::plan(future::sequential)
data.table::setDTthreads(1L)
source(file.path(mi_source, "dgp.R"))
mi_support <- as.matrix(expand.grid(W = 0:1, value = 0:1))

mi_library <- function(bridge = TRUE) {
  link <- if (bridge) "inverse_logit" else "identity"
  list(sieve_md = list(method = "sieve_md", control = list(
    target_basis = "quadratic", instrument_basis = "quadratic",
    penalty_on = if (bridge) "link" else "function", link = link,
    penalty_scales = 10^seq(-10, 0, by = .25))),
    landweber = list(method = "landweber", control = list(
      target_basis = "quadratic", instrument_basis = "quadratic",
      link = link, precondition = bridge)),
    pmmr = list(method = "pmmr", control = list(link = link,
      target_centers_matrix = mi_support, instrument_centers_matrix = mi_support,
      target_bandwidth = 1, instrument_bandwidth = 1, scale = FALSE)))
}
mi_control <- function() lmtp_control(.learners_trt_folds = 2L,
  .learners_outcome_folds = 2L, .discrete = FALSE, .trim = 1,
  .return_full_fits = TRUE, .isotonic_constraint = FALSE, .cm_kernel = "rbf")

mi_audit <- new.env(parent = emptyenv())
mi_reset_audit <- function() {
  mi_audit$support <- list(); mi_audit$cm <- list(); mi_audit$penalties <- list()
  mi_audit$bad_support <- character(); mi_audit$regression <- list(); mi_audit$splits <- list()
}
mi_reset_audit()

# Assertion-only instrumentation: the installed package files and numerical
# routines are unchanged. Every inner and final saturated design must contain
# its complete prespecified support; an absent cell is an explicit failure.
mi_assert_support <- function(X, stage) {
  X <- as.data.frame(X)
  binary <- names(X)[names(X) %in% c("W", "A1") | grepl("^\\.\\.i\\.\\.A", names(X))]
  if (!"W" %in% binary || length(binary) != 2L ||
      !all(as.matrix(X[binary]) %in% c(0, 1))) {
    message <- paste("Unexpected saturated predictors:", paste(names(X), collapse = ","))
    mi_audit$bad_support <- c(mi_audit$bad_support, message)
    stop(message)
  }
  others <- setdiff(names(X), binary)
  if (length(others) && any(vapply(X[others], function(x) length(unique(x)) != 1L, TRUE)))
    stop("Unexpected nonconstant regression predictor")
  cell <- 1L + X[[binary[1L]]] + 2L * X[[binary[2L]]]
  counts <- tabulate(cell, nbins = 4L)
  mi_audit$support[[length(mi_audit$support) + 1L]] <- list(stage = stage,
    n = nrow(X), columns = names(X), counts = counts)
  if (any(counts == 0)) {
    message <- paste("Absent prespecified cell in", stage)
    mi_audit$bad_support <- c(mi_audit$bad_support, message)
    stop(message)
  }
}

mi_capture_cm <- function(x) {
  if (!inherits(x, "cmbridge_ensemble")) return(invisible(NULL))
  small_candidate <- function(c) if (is.null(c)) NULL else list(method = c$method,
    prediction = as.numeric(predict(c, mi_support)), tuning = c$tuning,
    solver = c$solver, penalty_cv = c$penalty_cv, penalty_boundary = c$penalty_boundary,
    penalty_status = c$penalty_status, penalty_ids = c$penalty_ids,
    penalty_fold_id = c$penalty_fold_id)
  mi_audit$cm[[length(mi_audit$cm) + 1L]] <- list(type = x$type,
    prediction = as.numeric(predict(x, mi_support)), weights = x$weights,
    candidates = lapply(x$candidates, small_candidate), failures = x$candidate_failures,
    fold_penalty_cv = x$fold_penalty_cv, fold_penalty_boundary = x$fold_penalty_boundary,
    fold_id = x$fold_id, solver = x$solver)
  invisible(NULL)
}
mi_install_audit_hooks <- function() {
  trace(".saturated_path_setup", where = asNamespace("lmtp"), print = FALSE,
    tracer = quote(get("mi_assert_support", .GlobalEnv)(X, "penalty training")))
  trace("SL.saturated_l1", where = asNamespace("lmtp"), print = FALSE,
    tracer = quote(get("mi_assert_support", .GlobalEnv)(X, "final regression")),
    exit = quote({
      audit <- get("mi_audit", .GlobalEnv)
      value <- returnValue()$fit
      audit$regression[[length(audit$regression) + 1L]] <- list(
        levels = value$levels, predictions = value$cell_predictions,
        penalty = value$penalty, family = value$family, predictor_names = value$predictor_names)
    }))
  trace(".saturated_penalty_selection", where = asNamespace("lmtp"), print = FALSE,
    exit = quote({
      audit <- get("mi_audit", .GlobalEnv)
      audit$penalties[[length(audit$penalties) + 1L]] <- returnValue()
    }))
  for (name in c("fit_bridge_ensemble", "fit_adjoint_ensemble")) trace(name,
    where = asNamespace("cmbridge"), print = FALSE,
    exit = quote(get("mi_capture_cm", .GlobalEnv)(returnValue())))
}

mi_complete_estimate <- function(d) {
  n <- nrow(d)
  cell <- 1L + d$W + 2L * d$A1
  counts <- tabulate(cell, 4L)
  if (any(counts == 0)) stop("Absent completed-data cell")
  # Cell proportions are the saturated Bernoulli likelihood estimates.
  mu <- as.numeric(rowsum(d$Y2, cell, reorder = TRUE)) / counts
  m1 <- mu[3L + d$W]
  theta <- mean(m1)
  g <- counts[3:4] / (counts[1:2] + counts[3:4])
  influence <- m1 - theta + d$A1 / g[1L + d$W] * (d$Y2 - mu[cell])
  list(estimate = theta, variance = var(influence) / n, cell_means = mu,
    influence_mean = mean(influence))
}

mi_fit_imputation <- function(d, m = 50L, seed = 1L) {
  set.seed(seed)
  ry <- d$R2 == 1L
  stopifnot(all(is.na(d$Y2) == !ry))
  X <- with(d, cbind(W, A1, W * A1))
  mi_assert_support(d[ry, c("W", "A1")], "MI responders")
  Q <- U <- numeric(m)
  check_error <- 0
  for (j in seq_len(m)) {
    completed <- d
    completed$Y2[!ry] <- mice::mice.impute.logreg(d$Y2, ry, X, wy = !ry)
    fit <- mi_complete_estimate(completed)
    Q[j] <- fit$estimate; U[j] <- fit$variance
    if (j == 1L) {
      glmfit <- glm(Y2 ~ W * A1, data = completed, family = binomial())
      check_error <- abs(mean(predict(glmfit, transform(completed, A1 = 1), type = "response")) - Q[j])
      stopifnot(check_error < 1e-8, abs(fit$influence_mean) < 1e-10)
    }
  }
  pooled <- mice::pool.scalar(Q, U, n = nrow(d), k = 5)
  se <- sqrt(pooled$t); critical <- qt(.975, pooled$df)
  list(estimate = pooled$qbar, se = se, lower = pooled$qbar - critical * se,
    upper = pooled$qbar + critical * se, df = pooled$df, m = m,
    imputation_mcse = sqrt(pooled$b / m), glm_equivalence_error = check_error,
    complete_estimates = Q, complete_variances = U, pooling = pooled)
}

mi_folds <- function(n, seed) {
  set.seed(seed)
  label <- sample(rep(1:3, length.out = n))
  lapply(1:3, function(j) list(training_set = which(label != j), validation_set = which(label == j)))
}
mi_balanced_labels <- function(ids, observed) {
  stopifnot(!anyDuplicated(ids), nrow(observed) == length(ids))
  strata <- with(observed, paste(W, A1, R2, sep = "|"))
  labels <- integer(length(ids)); offset <- 0L
  for (stratum in sort(unique(strata))) {
    group <- which(strata == stratum)
    group <- group[order(as.character(ids[group]))]
    labels[group] <- (seq_along(group) - 1L + offset) %% 2L + 1L
    offset <- offset + length(group)
  }
  stopifnot(length(unique(labels)) == 2L)
  labels
}
mi_nested_splits <- function(ids, observed, initial_labels) {
  ids <- as.character(ids)
  cache <- new.env(parent = emptyenv())
  function(current_ids) {
    current <- as.character(current_ids)
    if (!all(current %in% ids)) stop("Split requested a person outside the outer training set")
    kept <- which(ids %in% current)
    key <- digest::digest(kept)
    if (!exists(key, cache, inherits = FALSE)) {
      labels <- if (identical(kept, seq_along(ids))) initial_labels else
        mi_balanced_labels(ids[kept], observed[kept, , drop = FALSE])
      assign(key, labels, cache)
      mi_audit$splits[[length(mi_audit$splits) + 1L]] <- list(
        outer_ids = ids, training_ids = ids[kept], labels = labels)
    }
    get(key, cache, inherits = FALSE)[match(current, ids[kept])]
  }
}
mi_predict_q <- function(model, d, epsilon = NULL) {
  nd <- d
  for (nm in model$varNames) if (grepl("^\\.\\.i\\.\\.A", nm)) nd[[nm]] <- d$A1
  pred <- as.numeric(predict(model, nd, tol = NULL))
  if (!is.null(epsilon)) pred <- plogis(qlogis(pmin(1 - 1e-5, pmax(1e-5, pred))) + epsilon)
  -100 + 200 * pred
}

mi_fit_bridge <- function(d, method, folds, seed, reuse_cache = NULL) {
  set.seed(seed)
  control <- mi_control(); control$.bridge_prediction_bounds <- c(-100, 100)
  learner_folds <- lapply(folds, function(f) mi_balanced_labels(
    f$training_set, d[f$training_set, c("W", "A1", "R2")]))
  nuisance <- function(training_data, validation_data, inner_folds, task, fold) {
    key <- as.character(fold)
    if (!is.null(reuse_cache) && exists(key, reuse_cache, inherits = FALSE))
      return(get(key, reuse_cache, inherits = FALSE))
    rows <- task$folds[[fold]]$training_set
    local_control <- control
    local_control$.nested_split_function <- mi_nested_splits(task$id[rows],
      d[rows, c("W", "A1", "R2")], inner_folds)
    got <- lmtp:::bridge_nuisance_fit(d, task$natural, task, fold, "R2", list("Y2"),
      mi_library(TRUE), mi_library(FALSE), "SL.saturated_l1_cv", FALSE, local_control)
    got$response_nuisance_cache <- new.env(parent = emptyenv())
    if (!is.null(reuse_cache)) assign(key, got, reuse_cache)
    got
  }
  fit <- lmtp::lmtp_bridge(d, trt = "A1", outcome = "Y2", measurement = "R2",
    health = list("Y2"), baseline = "W", time_vary = NULL,
    shift = function(data, trt) rep(1, nrow(data)), mtp = FALSE,
    estimator = method, folds = folds, learner_folds = learner_folds,
    learners_trt = "SL.saturated_l1_cv", learners_outcome = "SL.saturated_l1_cv",
    bridge_library = mi_library(TRUE), adjoint_library = mi_library(FALSE),
    bounds = c(-100, 100), control = control, nuisance_fit = nuisance)
  point <- fit$estimates[[1L]]
  score <- correction <- numeric(nrow(d)); nu <- list()
  for (j in seq_along(folds)) {
    rows <- folds[[j]]$validation_set
    v <- d[rows, ]; bf <- fit$bridge_fits[[j]]
    eps <- if (method == "tmle") fit$targeting[[j]][[1L]]$epsilon[1L] else NULL
    q <- mi_predict_q(fit$fits_m[[j]][[1L]], v, eps)
    q1 <- mi_predict_q(fit$fits_m[[j]][[1L]], transform(v, A1 = 1), eps)
    terminal <- ifelse(v$R2 == 1L, v$Y2, 0) * bf$beta_validation[, 1L]
    residual <- ifelse(v$R2 == 1L, bf$beta_validation[, 1L], 0) - 1
    correction[rows] <- -bf$lambda_validation[, 1L] * residual
    score[rows] <- q1 + bf$ratios_validation[, 1L] * (terminal - q) + correction[rows]
    nu[[j]] <- list(beta = bf$beta_validation[, 1L], lambda = bf$lambda_validation[, 1L],
      ratio = bf$ratios_validation[, 1L], q = q, q1 = q1,
      beta_support = as.numeric(predict(bf$beta_fits[[1L]], mi_support)),
      lambda_support = as.numeric(predict(bf$adjoint_fits[[1L]], mi_support)),
      beta_weights = bf$beta_fits[[1L]]$weights, lambda_weights = bf$adjoint_fits[[1L]]$weights)
  }
  score_error <- max(abs(score - point@eif))
  estimate_error <- abs(mean(score) - point@x)
  stopifnot(score_error < 1e-7, estimate_error < 1e-7,
    max(abs(correction - fit$bridge_correction[, 1L])) < 1e-9)
  if (length(mi_audit$bad_support)) stop(paste(unique(mi_audit$bad_support), collapse = "; "))
  se <- sd(score) / sqrt(nrow(d))
  list(estimate = point@x, se = se, lower = point@x - qnorm(.975) * se,
    upper = point@x + qnorm(.975) * se, score = score,
    correction = correction, nuisance = nu, score_error = score_error,
    estimate_error = estimate_error, folds = fit$folds, learner_folds = fit$learner_folds,
    targeting = fit$targeting)
}

mi_job <- function(n, replicate, scenario, phase, directory, m = 50L) {
  key <- sprintf("%s-n%d-r%03d", scenario, n, replicate)
  output <- file.path(directory, "jobs", paste0(key, ".rds"))
  if (file.exists(output)) return(invisible(output))
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  data_seed <- 6106000L + match(n, c(1000L, 4000L)) * 10000L + replicate + if (phase == "pilot") 100000L else 0L
  set.seed(data_seed); data <- mi_draw_data(n, scenario)$observed
  folds <- mi_folds(n, data_seed + 200000L)
  results <- list(); errors <- character(); warnings <- list()
  reuse_cache <- if (Sys.getenv("MI_REUSE", "true") == "true") new.env(parent = emptyenv()) else NULL
  for (method in c("mi", "sdr", "tmle")) {
    mi_reset_audit()
    method_warnings <- character(); started <- proc.time()[3L]
    got <- tryCatch(withCallingHandlers({
      if (method == "mi") mi_fit_imputation(data, m, data_seed + 300000L + match(scenario, mi_scenarios) * 1000L)
      else mi_fit_bridge(data, method, folds, data_seed + 400000L, reuse_cache)
    }, warning = function(w) {method_warnings <<- c(method_warnings, conditionMessage(w)); invokeRestart("muffleWarning")}),
    error = function(e) list(error = conditionMessage(e), error_class = class(e), condition = e))
    got$seconds <- unname(proc.time()[3L] - started)
    got$audit <- as.list(mi_audit)
    results[[method]] <- got
    warnings[[method]] <- method_warnings
    cat(format(Sys.time(), "%H:%M:%S"), key, method,
      if (is.null(got$error)) sprintf("%.6f (%.2fs)", got$estimate, got$seconds) else paste("ERROR", got$error), "\n")
    flush.console()
  }
  out <- list(n = n, replicate = replicate, scenario = scenario, phase = phase,
    data_seed = data_seed, data = data, results = results, warnings = warnings,
    source_fingerprint = Sys.getenv("MI_SOURCE_FINGERPRINT"),
    package_versions = c(cmbridge = as.character(packageVersion("cmbridge")),
      lmtp = as.character(packageVersion("lmtp")), mice = as.character(packageVersion("mice"))))
  temp <- paste0(output, ".", Sys.getpid(), ".tmp")
  saveRDS(out, temp, compress = "gzip")
  stopifnot(file.rename(temp, output))
  invisible(output)
}
