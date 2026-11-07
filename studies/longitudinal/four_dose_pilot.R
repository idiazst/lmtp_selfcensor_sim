# Fits both outcome horizons with the native observed-history estimator. One
# adapter belongs to one dataset and fold assignment; call it for SDR and TMLE
# to reuse exactly the nuisance models that have the same training information.
four_dose_observed_adapter <- function(data, folds, specification, seed, variant) {
  stopifnot(variant %in% c("baseline", "optimized"), is.list(folds))
  trt <- list(c("D1", "B1"), c("D2", "B2"))
  outcome <- c("Y2", "Y3")
  measurement <- c("R2", "R3")
  health <- list(c("Y2", "X2"), c("Y3", "X3"))
  time_vary <- list(c("Y1", "X1", "R1"), c("Y2", "X2", "R2"))
  original <- as.data.frame(data)
  # Restrict the fitting frame to observed inputs, even if a simulator also
  # returns truth or unmasked health columns for its own diagnostics.
  columns <- unique(c(unlist(time_vary), unlist(trt), unlist(health), measurement))
  original <- original[, columns, drop = FALSE]
  stopifnot(all(original$R1 == 1), all(unlist(original[measurement]) %in% 0:1))
  for (s in seq_along(health))
    original[original[[measurement[s]]] == 0, health[[s]]] <- NA_real_
  original$..bridge_row <- seq_len(nrow(original))
  control <- specification$control
  control$.ratio_history <- TRUE
  control$.bridge_prediction_bounds <- c(-100, 100)
  outer_crossfit <- identical(specification$crossfit, "outer")
  if (outer_crossfit) control$.bridge_crossfit <- "outer"
  group_count <- max(control$.learners_trt_folds, control$.learners_outcome_folds, 2L)
  master_labels <- integer(nrow(original))
  for (k in seq_along(folds)) master_labels[folds[[k]]$validation_set] <- k
  learner_folds <- lapply(folds, function(fold) {
    train <- fold$training_set
    if (outer_crossfit) return(master_labels[train])
    set.seed(seed + 11L + min(fold$validation_set))
    parts <- lmtp:::make_folds(original[train, , drop = FALSE], V = group_count,
      strata_ids = interaction(original$R2[train], original$R3[train], drop = TRUE),
      cluster_ids = train)
    labels <- integer(length(train))
    for (k in seq_along(parts)) labels[parts[[k]]$validation_set] <- k
    labels
  })
  shift <- function(data, trt) {
    s <- match(trt[[1L]], c("D1", "D2"))
    dose <- data[, trt, drop = FALSE]
    attended <- data[[c("R1", "R2")[s]]] == 1
    dose[[1L]][attended] <- pmin(dose[[1L]][attended] + 1L, 3L)
    dose
  }
  nuisance_models <- new.env(parent = emptyenv())
  outer_elapsed <- numeric(length(folds))
  nuisance_fit <- function(training_data, validation_data, inner_folds, task, fold) {
    key <- as.character(fold)
    if (!exists(key, nuisance_models, inherits = FALSE)) {
      train <- task$folds[[fold]]$training_set
      nested <- if (outer_crossfit) {
        function(ids) {
          labels <- inner_folds[match(as.character(ids), as.character(task$id[train]))]
          if (anyNA(labels)) stop("Learner split contains a person outside the outer training fold.")
          labels
        }
      } else lmtp:::make_bridge_nested_folds(task$id[train],
        original[train, measurement, drop = FALSE], inner_folds)
      fold_control <- control
      fold_control$.nested_split_function <- nested
      start <- proc.time()[["elapsed"]]
      # The internal encoded history columns are raw-scale copies; the bridge
      # response itself comes from the unscaled, masked original frame.
      got <- lmtp:::bridge_nuisance_fit(original, task$natural, task, fold,
        measurement, health, specification$bridge, specification$adjoint,
        specification$learners, TRUE, fold_control)
      outer_elapsed[fold] <<- proc.time()[["elapsed"]] - start
      got$response_nuisance_cache <- new.env(parent = emptyenv())
      assign(key, got, envir = nuisance_models)
    }
    get(key, nuisance_models, inherits = FALSE)
  }
  function(method) {
    method <- match.arg(method, c("sdr", "tmle"))
    set.seed(seed + if (method == "sdr") 131L else 137L)
    stage_start <- outer_elapsed
    fit <- lmtp::lmtp_bridge(data = original, trt = trt, outcome = outcome,
      measurement = measurement, health = health, time_vary = time_vary, shift = shift,
      estimator = method, folds = folds, learner_folds = learner_folds,
      learners_outcome = specification$learners, learners_trt = specification$learners,
      bridge_library = specification$bridge, adjoint_library = specification$adjoint,
      control = control, bounds = c(-100, 100), mtp = TRUE, nuisance_fit = nuisance_fit)
    estimates <- fit$unprojected_estimates
    raw <- do.call(cbind, lapply(fit$estimates, function(result) result@eif))
    eif <- sweep(raw, 2L, colMeans(raw))
    se <- apply(eif, 2L, stats::sd) / sqrt(nrow(eif))
    stopifnot(length(estimates) == 2L, all(is.finite(c(estimates, eif, se))))
    bridge_summary <- function(model) {
      if (is.null(model)) return(NULL)
      list(weights = model$weights,
           penalties = lapply(model$candidates, function(x) {
             cv <- x$penalty_cv
             if (!is.null(cv)) return(cv$scale[cv$selected])
             NULL
           }),
           failures = lapply(model$candidate_failures,
             function(x) x[c("candidate", "scope", "message")]))
    }
    diagnostics <- list(
      outer_nuisance_seconds = outer_elapsed - stage_start,
      bridge = lapply(fit$bridge_fits, function(f) lapply(f$beta_fits, bridge_summary)),
      adjoint = lapply(fit$bridge_fits, function(f) lapply(f$adjoint_fits, bridge_summary)),
      nested_bridges = vapply(fit$bridge_fits, function(f) {
        e <- f$response_nuisance_cache$beta
        if (is.null(e)) return(0L)
        length(ls(e, all.names = TRUE))
      }, integer(1L))
    )
    list(estimates = estimates, se = se, eif = eif, diagnostics = diagnostics)
  }
}
