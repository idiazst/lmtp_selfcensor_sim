# Reweight a trained bridge ensemble without changing any candidate or tuning.
# Training arrays are supplied solely to refresh the fitted-value/loss metadata.
psd_reweight_bridge <- function(model, B, V, M) {
  stopifnot(inherits(model, "cmbridge_ensemble"), model$type == "bridge", model$statistic == "u")
  active <- model$active_candidates
  solution <- cmbridge:::.simplex_qp(model$raw_gram, indefinite = TRUE)
  model$weights[] <- 0; model$weights[active] <- solution$weights
  model$gram <- model$raw_gram; model$project_psd <- FALSE
  model$psd_projection$applied <- FALSE; model$psd_projection$adjustment_norm <- 0
  model$psd_projection$removed_negative_eigenvalues <- 0L
  model$solver <- solution[c("kkt_gap", "iterations")]
  model$candidate_cv_loss <- model$candidate_raw_cv_loss
  model$raw_cv_loss <- model$cv_loss <- as.numeric(crossprod(solution$weights, model$raw_gram %*% solution$weights))
  used <- active[solution$weights > 0]
  model$predict_fun <- cmbridge:::.prediction_closure(function(newdata) {
    newdata <- cmbridge:::.as_matrix(newdata)
    predictions <- vapply(models, function(fit) predict(fit, newdata), numeric(nrow(newdata)))
    as.numeric(matrix(predictions, nrow = nrow(newdata), ncol = columns) %*% coefficient)
  }, list(models = model$candidates[used], coefficient = model$weights[used], columns = length(used)))
  model$fitted[] <- NA_real_
  complete <- model$complete_case_index
  model$fitted[complete] <- model$predict_fun(V[complete, , drop = FALSE])
  residual <- M * ifelse(is.na(model$fitted), 0, model$fitted) - 1
  model$moment_loss <- cmbridge:::.ensemble_gram(matrix(residual, ncol = 1L), B,
    model$scoring_kernel, "u")[1L, 1L]
  model$fit_provenance <- "shared candidates, globally reweighted without PSD"
  model
}

psd_restore_response_cache <- function(fitted, canonical, task, d, g, fold) {
  original <- canonical$response_nuisance_cache
  if (!is.environment(original$beta)) return(0L)
  args <- study_arguments(g); encoded <- as.data.frame(d); encoded$..bridge_row <- seq_len(nrow(d))
  for (s in seq_along(args$time_vary)) for (name in args$time_vary[[s]]) {
    key <- paste0("..bridge_", s, "_", name)
    encoded[[key]] <- ifelse(is.na(d[[name]]), 0, d[[name]])
    encoded[[paste0(key, "_missing")]] <- as.numeric(is.na(d[[name]]))
  }
  rows <- task$folds[[fold]]$training_set
  clean <- lapply(cm_library(bridge = TRUE), function(candidate) {
    candidate$control$penalty_ids <- candidate$control$penalty_folds <- NULL; candidate
  })
  signature <- function(project) digest::digest(list(task$id[rows], encoded[rows, , drop = FALSE],
    clean, trt_library, "rbf", project, FALSE, TRUE))
  # Reject reuse unless the original cache's complete data/library signature matches.
  stopifnot(identical(signature(TRUE), original$signature))
  cache <- fitted$response_nuisance_cache
  cache$signature <- signature(FALSE); cache$splits <- fitted$nested_split_function
  cache$beta <- new.env(parent = emptyenv()); cache$ratio <- new.env(parent = emptyenv())
  count <- 0L
  for (key in ls(original$beta, all.names = TRUE)) {
    entry <- get(key, original$beta, inherits = FALSE); model <- entry$model
    if (is.null(model)) next
    train <- match(entry$training_ids, task$id); s <- entry$horizon
    stopifnot(!anyNA(train), all(train %in% rows),
      identical(as.integer(fitted$nested_split_function(entry$training_ids)), as.integer(model$fold_id)))
    for (candidate in model$candidates) if (!is.null(candidate$penalty_ids))
      stopifnot(identical(as.integer(fitted$nested_split_function(candidate$penalty_ids)),
        as.integer(candidate$penalty_fold_id)))
    H <- task$vars$history("A", s); A <- task$vars$A[[s]]
    B <- as.matrix(encoded[train, c(H, A), drop = FALSE])
    V <- as.matrix(cbind(encoded[train, H, drop = FALSE], d[train, args$health[[s]], drop = FALSE]))
    entry$model <- psd_reweight_bridge(model, B, V, d[[args$measurement[s]]][train])
    assign(key, entry, cache$beta); count <- count + 1L
  }
  count
}
