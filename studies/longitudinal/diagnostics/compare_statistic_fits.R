# Evaluate each criterion on exactly the same saved predictions as well as on
# its own penalty-CV refits. DGP truth is used only to evaluate the results.
source("studies/longitudinal/diagnostics/statistic_setup.R")
input <- statistic_output
out <- Sys.getenv("STATISTIC_EVALUATION_OUTPUT", input)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
kernel_spec <- getFromNamespace(".ensemble_kernel", "cmbridge")
gram <- getFromNamespace(".ensemble_gram", "cmbridge")
project <- getFromNamespace(".project_gram_psd", "cmbridge")
simplex <- getFromNamespace(".simplex_qp", "cmbridge")
scale_apply <- getFromNamespace(".scale_apply", "cmbridge")
quadratic <- function(w, G) as.numeric(crossprod(w, G %*% w))

# The simplex is compact even for an indefinite score. With <=4 candidates,
# enumerate vertices and stationary points on every face. If a minimizing face
# is singular, the same minimum occurs on one of its boundary faces.
raw_simplex <- function(G) {
  p <- nrow(G); stopifnot(p <= 4L)
  scale <- max(abs(G))
  if (scale == 0) return(rep(1 / p, p))
  A <- (G + t(G)) / (2 * scale)
  best <- rep(0, p); best[which.min(diag(A))] <- 1
  value <- quadratic(best, A)
  for (mask in seq_len(2^p - 1L)) {
    ii <- which(as.logical(intToBits(mask)[seq_len(p)])); q <- length(ii)
    lhs <- rbind(cbind(A[ii, ii, drop = FALSE], 1), c(rep(1, q), 0))
    candidate <- tryCatch(solve(lhs, c(rep(0, q), 1)), error = function(e) NULL)
    if (is.null(candidate) || any(!is.finite(candidate)) || any(candidate[seq_len(q)] < -1e-10)) next
    w <- numeric(p); w[ii] <- pmax(candidate[seq_len(q)], 0); w <- w / sum(w)
    loss <- quadratic(w, A)
    if (loss < value) {best <- w; value <- loss}
  }
  stopifnot(all(best >= 0), abs(sum(best) - 1) < 1e-12,
    quadratic(best, A) <= min(diag(A)) + 1e-10)
  best
}
stopifnot(identical(raw_simplex(diag(c(-1, -2, 1))), c(0, 1, 0)))

paths <- list.files(file.path(input, "jobs"), "[.]rds$", full.names = TRUE)
design <- fread(file.path(input, "design.csv"))
expected <- nrow(design) * 3L * length(statistic_times)
complete <- length(paths) == expected && file.exists(file.path(input, "FITTING-COMPLETED.txt"))
stopifnot(complete || identical(Sys.getenv("ALLOW_PARTIAL"), "true"))
fingerprint <- readLines(file.path(input, "fingerprint.txt"))[1L]
datasets <- new.env(parent = emptyenv()); populations <- new.env(parent = emptyenv())
metrics <- weights <- predictions <- equation_rows <- candidate_losses <- augmented <- checks <- failures <- tuning <- penalty_boundaries <- warning_rows <- list()
for (path in paths) {
  x <- readRDS(path); z <- x$design
  stopifnot(identical(x$fingerprint, fingerprint))
  meta <- function(dt) cbind(as.data.table(z[c("mechanism", "selected", "seed", "n", "time", "fold", "statistic")]), dt)
  if (!is.null(x$error)) {
    failures[[length(failures) + 1L]] <- meta(data.table(function_name = "both", candidate = NA_character_,
      scope = "outer fit", message = x$error))
    next
  }
  pkey <- z$mechanism; dkey <- paste(z$mechanism, z$seed, z$n)
  if (!exists(pkey, populations, inherits = FALSE)) {
    g <- make_mechanism(z$mechanism); p <- enumerate_data(g)
    assign(pkey, list(g = g, p = p, task = study_task(p, g)$task, truth = true_values(p, g)), populations)
  }
  pop <- get(pkey, populations, inherits = FALSE); g <- pop$g; p <- pop$p
  if (!exists(dkey, datasets, inherits = FALSE)) {
    set.seed(z$seed); d <- draw_data(z$n, g)
    assign(dkey, list(d = d, task = study_task(d, g)$task, truth = true_values(d, g)), datasets)
  }
  dat <- get(dkey, datasets, inherits = FALSE); d <- dat$d; task <- dat$task; nu <- dat$truth
  stopifnot(x$data_sha256 == digest::digest(d, algo = "sha256"),
    !length(intersect(x$training, x$validation)),
    setequal(c(x$training, x$validation), seq_len(z$n)))
  s <- z$time - 1L; H <- task$vars$history("A", s); A <- task$vars$A[[s]]
  B <- as.matrix(task$natural[, c(H, A), drop = FALSE])
  V <- as.matrix(cbind(task$natural[, H, drop = FALSE],
    d[, c(paste0("C", z$time, "_covariate"), paste0("Y", z$time)), drop = FALSE]))
  PB <- as.matrix(pop$task$natural[, c(H, A), drop = FALSE])
  PV <- as.matrix(cbind(pop$task$natural[, H, drop = FALSE],
    p[, c(paste0("C", z$time, "_covariate"), paste0("Y", z$time)), drop = FALSE]))
  M <- d[[paste0("R", z$time)]] == 1L; PM <- p[[paste0("R", z$time)]] == 1L
  phi <- apply(nu$ratios[, seq_len(s), drop = FALSE], 1, prod) * ifelse(M, d[[paste0("Y", z$time)]], 0)
  pphi <- apply(pop$truth$ratios[, seq_len(s), drop = FALSE], 1, prod) * ifelse(PM, p[[paste0("Y", z$time)]], 0)
  for (type in c("bridge", "adjoint")) {
    model <- x[[type]]; candidates <- names(model$candidates)
    X <- if (type == "bridge") V else B; Z <- if (type == "bridge") B else V
    PX <- if (type == "bridge") PV else PB; PZ <- if (type == "bridge") PB else PV
    train <- x$training; labels <- model$fold_id
    truth_residual <- if (type == "bridge") {
      v <- rep(-1, length(train)); v[M[train]] <- nu$beta[train[M[train]], s] - 1; v
    } else nu$lambda[train, s] - phi[train]
    vi <- if (type == "bridge") x$validation[M[x$validation]] else x$validation
    pi <- if (type == "bridge") which(PM) else seq_len(nrow(p))
    pscored <- if (type == "bridge") seq_len(nrow(p)) else which(PM)
    pfitted <- vapply(model$candidates, function(fit) predict(fit, PX[pi, , drop = FALSE]), numeric(length(pi)))
    vfitted <- vapply(model$candidates, function(fit) predict(fit, X[vi, , drop = FALSE]), numeric(length(vi)))
    pfitted <- matrix(pfitted, ncol = length(candidates), dimnames = list(NULL, candidates))
    vfitted <- matrix(vfitted, ncol = length(candidates), dimnames = list(NULL, candidates))
    pr <- if (type == "bridge") {
      r <- matrix(-1, nrow(p), length(candidates)); r[PM, ] <- pfitted - 1; r
    } else pfitted[PM, , drop = FALSE] - pphi[PM]
    pr <- cbind(pr, true = if (type == "bridge") {
      r <- rep(-1, nrow(p)); r[PM] <- pop$truth$beta[PM, s] - 1; r
    } else pop$truth$lambda[PM, s] - pphi[PM])
    colnames(pr) <- c(candidates, "true")
    pw <- p$probability[pscored]; pw <- pw / sum(pw)
    keys <- cell_key(PZ[pscored, , drop = FALSE]); levels <- unique(keys)
    moments <- rowsum(pr * pw, match(keys, levels), reorder = FALSE)
    first <- match(levels, keys)
    GU <- GV <- GP <- matrix(0, length(candidates) + 1L, length(candidates) + 1L,
      dimnames = list(c(candidates, "true"), c(candidates, "true")))
    for (fold in seq_along(model$fold_n_scored)) {
      ii <- which(labels == fold); tr <- which(labels != fold)
      if (type == "adjoint") {ii <- ii[M[train[ii]]]; tr <- tr[M[train[tr]]]}
      spec <- kernel_spec(Z[train[tr], , drop = FALSE], model$scoring_kernel$kernel,
        model$scoring_kernel$control, 1L + fold)
      residual <- cbind(model$cv_residuals[ii, candidates, drop = FALSE], true = truth_residual[ii])
      factor <- model$fold_n_scored[fold] / sum(model$fold_n_scored)
      GU <- GU + factor * gram(residual, Z[train[ii], , drop = FALSE], spec, "u")
      GV <- GV + factor * gram(residual, Z[train[ii], , drop = FALSE], spec, "v")
      scaled <- scale_apply(PZ[pscored[first], , drop = FALSE], spec$scale)
      K <- cmbridge::rbf_kernel(scaled, scaled, spec$bandwidth)
      GP <- GP + factor * crossprod(moments, K %*% moments)
    }
    native <- if (z$statistic == "u") GU else GV
    replay_error <- max(abs(native[candidates, candidates, drop = FALSE] - model$raw_gram))
    stopifnot(replay_error < 1e-12, abs(GP["true", "true"]) < 1e-24,
      max(abs(moments[, "true"])) < 1e-12,
      min(eigen(GV, symmetric = TRUE, only.values = TRUE)$values) > -1e-10)
    if (length(model$candidate_failures)) for (failure in model$candidate_failures)
      failures[[length(failures) + 1L]] <- meta(data.table(function_name = type, candidate = failure$candidate,
        scope = failure$scope, message = failure$message))
    for (candidate in candidates) for (scope in c("final_refit", paste0("learner_fold_", seq_along(model$fold_penalty_cv)))) {
      cv <- if (scope == "final_refit") model$candidates[[candidate]]$penalty_cv else
        model$fold_penalty_cv[[as.integer(sub("learner_fold_", "", scope))]][[candidate]]
      boundary <- if (scope == "final_refit") model$candidates[[candidate]]$penalty_boundary else
        model$fold_penalty_boundary[[as.integer(sub("learner_fold_", "", scope))]][[candidate]]
      if (!is.null(cv)) {
        cv <- copy(as.data.table(cv))
        if ("statistic" %in% names(cv)) cv[, statistic := NULL]
        if ("selected" %in% names(cv)) setnames(cv, "selected", "penalty_selected")
        tuning[[length(tuning) + 1L]] <- meta(cbind(data.table(function_name = type, candidate = candidate, scope = scope), cv))
      }
      if (!is.null(boundary) && nrow(boundary)) penalty_boundaries[[length(penalty_boundaries) + 1L]] <- meta(
        cbind(data.table(function_name = type, candidate = candidate, scope = scope), as.data.table(boundary)))
    }
    # Full refits use each API setting for both tuning and stacking. The fixed-
    # candidate comparison uses only the saved U-tuned library and changes weights.
    selections <- list(refit = model$weights[candidates])
    if (z$statistic == "u") {
      selections$fixed_u_psd <- simplex(project(GU[candidates, candidates, drop = FALSE])$gram)$weights
      selections$fixed_u_raw <- raw_simplex(GU[candidates, candidates, drop = FALSE])
      selections$fixed_v <- simplex(GV[candidates, candidates, drop = FALSE])$weights
      stopifnot(max(abs(selections$fixed_u_psd - selections$refit)) < 1e-7)
    }
    ptarget <- if (type == "bridge") pop$truth$beta[pi, s] else pop$truth$lambda[pi, s]
    vtarget <- if (type == "bridge") nu$beta[vi, s] else nu$lambda[vi, s]
    for (method in names(selections)) {
      w <- as.numeric(selections[[method]])
      stopifnot(all(w >= 0), abs(sum(w) - 1) < 1e-10)
      pe <- as.numeric(pfitted %*% w); ve <- as.numeric(vfitted %*% w)
      if (type == "bridge") stopifnot(all(pe >= 1), all(ve >= 1))
      full_beta <- full_adjoint <- rep(NA_real_, nrow(p))
      if (type == "bridge") full_beta[pi] <- pe else full_adjoint[pi] <- pe
      eq <- moment_tables(p, pop$task, s, full_beta, full_adjoint, pphi, p$probability)[[type]]
      add <- data.table(function_name = type, method = method)
      metrics[[length(metrics) + 1L]] <- meta(cbind(add, data.table(
        population_function_rmse = sqrt(sum(p$probability[pi] * (pe - ptarget)^2) / sum(p$probability[pi])),
        population_equation_rmse = sqrt(sum(eq$probability * eq$residual^2) / sum(eq$probability)),
        population_equation_max = max(abs(eq$residual)),
        population_full_rbf_loss = quadratic(c(w, 0), GP),
        cv_u_loss = quadratic(c(w, 0), GU), cv_v_loss = quadratic(c(w, 0), GV),
        candidate_failures = length(model$candidate_failures))))
      all_weights <- setNames(rep(0, length(model$weights)), names(model$weights)); all_weights[candidates] <- w
      weights[[length(weights) + 1L]] <- meta(cbind(add, data.table(candidate = names(all_weights), weight = as.numeric(all_weights))))
      predictions[[length(predictions) + 1L]] <- meta(cbind(add, data.table(row = vi, truth = vtarget,
        estimate = ve, previous_measured = d[[paste0("R", s)]][vi])))
      equation_rows[[length(equation_rows) + 1L]] <- meta(cbind(add, eq))
    }
    for (candidate in c(candidates, "true")) candidate_losses[[length(candidate_losses) + 1L]] <- meta(
      data.table(function_name = type, candidate = candidate,
        cv_u = GU[candidate, candidate], cv_v = GV[candidate, candidate],
        population_full_rbf = GP[candidate, candidate]))
    for (method in c("u_psd", "u_raw", "v", "population")) {
      G <- switch(method, u_psd = project(GU)$gram, u_raw = GU, v = GV, population = GP)
      w <- if (method == "u_raw") raw_simplex(G) else simplex(G)$weights
      augmented[[length(augmented) + 1L]] <- meta(data.table(function_name = type, method = method,
        true_weight = tail(w, 1L), selected_score = quadratic(w, G),
        population_full_rbf_loss = quadratic(w, GP)))
    }
    if (length(candidates) > 1L) {
      tangent <- contr.helmert(length(candidates))
      tangent <- sweep(tangent, 2L, sqrt(colSums(tangent^2)), "/")
      simplex_curvature <- min(eigen(crossprod(tangent, GU[candidates, candidates, drop = FALSE] %*% tangent),
        symmetric = TRUE, only.values = TRUE)$values)
    } else simplex_curvature <- 0
    checks[[length(checks) + 1L]] <- meta(data.table(function_name = type,
      cv_replay_error = replay_error, true_population_loss = GP["true", "true"],
      true_population_moment_max = max(abs(moments[, "true"])),
      v_min_eigenvalue = min(eigen(GV, symmetric = TRUE, only.values = TRUE)$values),
      u_min_eigenvalue = min(eigen(GU[candidates, candidates, drop = FALSE], symmetric = TRUE, only.values = TRUE)$values),
      u_simplex_min_curvature = simplex_curvature,
      checkpoint_sha256 = digest::digest(file = path, algo = "sha256"),
      fit_provenance = x$fit_provenance, fit_package_version = x$fit_package_version))
  }
  if (length(x$warnings)) warning_rows[[length(warning_rows) + 1L]] <- meta(data.table(warning = x$warnings))
  cat("Evaluated", basename(path), "\n"); flush.console()
}
for (name in c("metrics", "weights", "equation_rows", "candidate_losses", "augmented", "checks", "failures", "tuning", "penalty_boundaries", "warning_rows")) {
  value <- rbindlist(get(name), fill = TRUE)
  if (!ncol(value)) value <- data.table(message = character())
  stopifnot(!anyDuplicated(names(value)))
  fwrite(value, file.path(out, paste0(name, ".csv")))
  assign(name, value)
}
predictions <- rbindlist(predictions)
fwrite(predictions, file.path(out, "out-of-sample-predictions.csv.gz"), compress = "gzip")
for (group in split(predictions, by = c("mechanism", "seed", "n", "time", "statistic", "function_name", "method")))
  stopifnot(!anyDuplicated(group$row), if (complete && group$function_name[1L] == "adjoint")
    nrow(group) == group$n[1L] else TRUE)
summary <- metrics[, .(population_function_rmse = sqrt(mean(population_function_rmse^2)),
  population_equation_rmse = sqrt(mean(population_equation_rmse^2)), population_equation_max = max(population_equation_max),
  population_full_rbf_loss = mean(population_full_rbf_loss), candidate_failures = sum(candidate_failures), folds = .N),
  by = .(mechanism, selected, seed, n, time, statistic, function_name, method)]
fwrite(summary, file.path(out, "summary.csv"))
stopifnot(max(checks$cv_replay_error) < 1e-12,
  max(abs(checks$true_population_loss)) < 1e-24, max(checks$true_population_moment_max) < 1e-12)
writeLines(c(if (complete) "COMPLETE" else "PRELIMINARY: incomplete checkpoints",
  sprintf("Expected checkpoints: %d; saved: %d; failed outer fits: %d", expected, length(paths),
    sum(failures$scope == "outer fit")),
  sprintf("Candidate failures: %d", sum(failures$scope != "outer fit")),
  sprintf("Max CV replay error: %.3e", max(checks$cv_replay_error)),
  sprintf("Max true population loss: %.3e", max(abs(checks$true_population_loss))),
  "All fitted bridge predictions >= 1; no adjoint bounds imposed.",
  "DGP truth only evaluates losses/predictions and supplies the isolated adjoint loading.",
  "No treatment/outcome regressions, new parameter estimates or coverage study."), file.path(out, "VERIFICATION.txt"))
post_sources <- c("studies/longitudinal/diagnostics/compare_statistic_fits.R",
  "studies/longitudinal/diagnostics/report_statistic_comparison.R")
post_sources <- post_sources[file.exists(post_sources)]
jsonlite::write_json(as.list(setNames(vapply(post_sources, function(p)
  digest::digest(file = p, algo = "sha256"), ""), post_sources)),
  file.path(out, "postprocessing-manifest.json"), auto_unbox = TRUE, pretty = TRUE)
writeLines(if (complete) format(Sys.time(), tz = "America/New_York", usetz = TRUE) else "PRELIMINARY",
  file.path(out, "EVALUATION-COMPLETED.txt"))
print(summary[time == 3L & method == "refit"])
