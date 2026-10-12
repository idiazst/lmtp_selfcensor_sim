# Validate the original frozen dependencies before loading this isolated study.
source("scripts/setup.R")
.libPaths(c(Sys.getenv("PSD_LIBRARY", ".runtime/psd-balanced-library"),
            ".runtime/psd-library", .libPaths()))
stopifnot(as.character(packageVersion("cmbridge")) == "0.3.0.9029",
          as.character(packageVersion("lmtp")) == "1.6.0.9022")
# Reuse the completed study verbatim except its bootstrap/version assertions.
for (expression in as.list(parse("studies/longitudinal/study.R"))[-1L]) {
  if (is.call(expression) && identical(expression[[1L]], as.name("stopifnot")) &&
      grepl("packageVersion", paste(deparse(expression), collapse = " "))) next
  eval(expression, envir = .GlobalEnv)
}
original_study_control <- study_control
psd_project <- TRUE
study_control <- function(learner_groups = 2L) {
  control <- original_study_control(learner_groups)
  control$.cm_project_psd <- psd_project
  control
}
# Reference functions and conditional equations evaluate fits only.
for (expression in parse("studies/longitudinal/diagnostics/bridge_adjoint_setup.R"))
  if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
      is.symbol(expression[[2L]]) && as.character(expression[[2L]]) %in% c("true_values", "moment_tables"))
    eval(expression, envir = .GlobalEnv)
source("studies/longitudinal/diagnostics/psd_shared_fits.R")
psd_output <- Sys.getenv("PSD_OUTPUT", "results/longitudinal/psd-numerical-n4000-v2")

psd_audit <- function(references, task, d, p, pt, g) {
  audits <- weights <- recovery <- equations <- points <- failures <- list()
  nu_true <- true_values(d, g); pop_true <- true_values(p, g)
  for (fold in seq_along(references)) {
    fitted <- references[[fold]]; validation <- task$folds[[fold]]$validation_set
    for (s in seq_len(g$tau)) {
      H <- task$vars$history("A", s); A <- task$vars$A[[s]]
      B <- as.matrix(task$natural[, c(H, A), drop = FALSE])
      V <- as.matrix(cbind(task$natural[, H, drop = FALSE],
        d[, c(paste0("C", s + 1L, "_covariate"), paste0("Y", s + 1L)), drop = FALSE]))
      PB <- as.matrix(pt$natural[, c(H, A), drop = FALSE])
      PV <- as.matrix(cbind(pt$natural[, H, drop = FALSE],
        p[, c(paste0("C", s + 1L, "_covariate"), paste0("Y", s + 1L)), drop = FALSE]))
      M <- d[[paste0("R", s + 1L)]] == 1L; PM <- p[[paste0("R", s + 1L)]] == 1L
      audit_model <- function(model, kind, key, training_ids) {
        stopifnot(inherits(model, "cmbridge_ensemble"), identical(model$statistic, "u"),
          identical(model$psd_projection$applied, psd_project),
          !length(intersect(as.character(training_ids), as.character(task$id[validation]))),
          model$solver$kkt_gap <= 1e-8)
        X <- if (kind == "bridge") V[validation[M[validation]], , drop = FALSE] else B[validation, , drop = FALSE]
        cp <- lapply(model$candidates, predict, newdata = X)
        tuning <- list(final = lapply(model$candidates, `[[`, "penalty_cv"),
          folds = model$fold_penalty_cv, boundaries = model$fold_penalty_boundary)
        audits[[length(audits) + 1L]] <<- data.table(fold = fold, horizon = s,
          kind = kind, fit_key = key, training_n = model$n, active = paste(model$active_candidates, collapse = ";"),
          candidate_hash = digest::digest(cp, algo = "sha256"),
          cv_prediction_hash = digest::digest(model$cv_predictions, algo = "sha256"),
          raw_gram_hash = digest::digest(model$raw_gram, algo = "sha256"),
          tuning_hash = digest::digest(tuning, algo = "sha256"),
          fold_hash = digest::digest(model$fold_id, algo = "sha256"),
          projection_applied = model$psd_projection$applied,
          projection_norm = model$psd_projection$adjustment_norm,
          min_raw_eigenvalue = min(model$psd_projection$eigenvalues),
          raw_cv_loss = model$raw_cv_loss, selected_cv_loss = model$cv_loss,
          solver_gap = model$solver$kkt_gap)
        weights[[length(weights) + 1L]] <<- data.table(fold = fold, horizon = s,
          kind = kind, fit_key = key, training_n = model$n, candidate = names(model$weights),
          weight = as.numeric(model$weights))
        for (failure in model$candidate_failures) failures[[length(failures) + 1L]] <<-
          data.table(fold = fold, horizon = s, kind = kind, fit_key = key,
            candidate = failure$candidate, scope = failure$scope, message = failure$message)
      }
      audit_model(fitted$beta_fits[[s]], "bridge", "outer", task$id[task$folds[[fold]]$training_set])
      audit_model(fitted$adjoint_fits[[s]], "adjoint", "outer", task$id[task$folds[[fold]]$training_set])
      cache <- fitted$response_nuisance_cache$beta
      if (is.environment(cache)) for (key in ls(cache, all.names = TRUE)) {
        entry <- get(key, cache, inherits = FALSE)
        if (entry$horizon == s && !is.null(entry$model))
          audit_model(entry$model, "bridge", paste0("response/", key), entry$training_ids)
      }
      beta <- rep(NA_real_, nrow(p)); beta[PM] <- predict(fitted$beta_fits[[s]], PV[PM, , drop = FALSE])
      adjoint <- predict(fitted$adjoint_fits[[s]], PB)
      phi <- apply(pop_true$ratios[, seq_len(s), drop = FALSE], 1L, prod) * ifelse(PM, p[[paste0("Y", s + 1L)]], 0)
      eq <- moment_tables(p, pt, s, beta, adjoint, phi, p$probability)
      for (kind in c("bridge", "adjoint")) {
        e <- eq[[kind]]
        recovery[[length(recovery) + 1L]] <- data.table(fold = fold, horizon = s, kind = kind,
          equation_rmse = sqrt(sum(e$probability * e$residual^2) / sum(e$probability)),
          equation_max = max(abs(e$residual)),
          function_rmse_to_reference = if (kind == "bridge")
            sqrt(sum(p$probability[PM] * (beta[PM] - pop_true$beta[PM, s])^2) / sum(p$probability[PM])) else
              sqrt(sum(p$probability * (adjoint - pop_true$lambda[, s])^2)))
        equations[[length(equations) + 1L]] <- cbind(data.table(fold = fold, horizon = s, kind = kind), e)
      }
      for (kind in c("bridge", "adjoint")) {
        vi <- if (kind == "bridge") validation[M[validation]] else validation
        estimate <- if (kind == "bridge") predict(fitted$beta_fits[[s]], V[vi, , drop = FALSE]) else
          predict(fitted$adjoint_fits[[s]], B[vi, , drop = FALSE])
        truth <- if (kind == "bridge") nu_true$beta[vi, s] else nu_true$lambda[vi, s]
        points[[length(points) + 1L]] <- data.table(fold = fold, horizon = s, kind = kind,
          row = vi, truth = truth, estimate = estimate, previous_measured = d[[paste0("R", s)]][vi])
      }
    }
  }
  list(audit = rbindlist(audits), nuisance_weights = rbindlist(weights), recovery = rbindlist(recovery),
    equation_rows = rbindlist(equations, fill = TRUE), points = rbindlist(points),
    nuisance_failures = rbindlist(failures, fill = TRUE))
}
