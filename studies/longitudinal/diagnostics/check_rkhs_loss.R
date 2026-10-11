# Read-only loss evaluation of the saved fits; no nuisance models are refitted.
source("studies/longitudinal/diagnostics/bridge_adjoint_setup.R")
input <- "results/longitudinal/bridge-adjoint-seed-check"
out <- "results/longitudinal/rkhs-loss-check"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
kernel_spec <- getFromNamespace(".ensemble_kernel", "cmbridge")
features <- getFromNamespace(".ensemble_features", "cmbridge")
gram <- getFromNamespace(".ensemble_gram", "cmbridge")
scale_apply <- getFromNamespace(".scale_apply", "cmbridge")
project <- getFromNamespace(".project_gram_psd", "cmbridge")
simplex <- getFromNamespace(".simplex_qp", "cmbridge")
quadratic <- function(w, G) as.numeric(crossprod(w, G %*% w))

g <- make_mechanism("discrete_dose")
p <- enumerate_data(g); pt <- study_task(p, g)$task; ptrue <- true_values(p, g)
paths <- list.files(file.path(input, "jobs"), "t3-fold.*[.]rds$", full.names = TRUE)
stopifnot(length(paths) == 18L)
population <- validation <- cv <- weights <- curves <- checks <- list()
data_cache <- new.env(parent = emptyenv())
for (path in paths) {
  x <- readRDS(path); size <- x$design$n; seed <- x$design$seed
  key <- paste(seed, size)
  if (!exists(key, data_cache, inherits = FALSE)) {
    set.seed(seed); d <- draw_data(size, g)
    assign(key, list(d = d, task = study_task(d, g)$task, truth = true_values(d, g)), data_cache)
  }
  saved <- get(key, data_cache, inherits = FALSE)
  d <- saved$d; task <- saved$task; truth <- saved$truth
  stopifnot(digest::digest(d, algo = "sha256") == x$data_sha256)
  s <- 2L; H <- task$vars$history("A", s); A <- task$vars$A[[s]]
  B <- as.matrix(task$natural[, c(H, A), drop = FALSE])
  V <- as.matrix(cbind(task$natural[, H, drop = FALSE], d[, c("C3_covariate", "Y3"), drop = FALSE]))
  PB <- as.matrix(pt$natural[, c(H, A), drop = FALSE])
  PV <- as.matrix(cbind(pt$natural[, H, drop = FALSE], p[, c("C3_covariate", "Y3"), drop = FALSE]))
  M <- d$R3 == 1L; PM <- p$R3 == 1L
  phi <- apply(truth$ratios, 1L, prod) * ifelse(M, d$Y3, 0)
  pphi <- apply(ptrue$ratios, 1L, prod) * ifelse(PM, p$Y3, 0)
  meta <- function(z) cbind(data.table(selected = x$design$selected, seed = seed,
    n = size, time = 3L, fold = x$design$fold), z)
  for (type in c("bridge", "adjoint")) {
    model <- x[[type]]; names <- c(names(model$candidates), "true")
    Z <- if (type == "bridge") B else V
    PZ <- if (type == "bridge") PB else PV
    pindex <- if (type == "bridge") seq_len(nrow(p)) else which(PM)
    pweights <- p$probability[pindex]; pweights <- pweights / sum(pweights)
    pr <- matrix(NA_real_, length(pindex), length(names), dimnames = list(NULL, names))
    vr <- matrix(NA_real_, length(x$validation), length(names), dimnames = list(NULL, names))
    for (name in names) {
      if (type == "bridge") {
        value <- if (name == "true") ptrue$beta[PM, s] else predict(model$candidates[[name]], PV[PM, , drop = FALSE])
        pr[, name] <- -1; pr[PM, name] <- value - 1
        measured <- x$validation[M[x$validation]]
        value <- if (name == "true") truth$beta[measured, s] else predict(model$candidates[[name]], V[measured, , drop = FALSE])
        vr[, name] <- -1; vr[M[x$validation], name] <- value - 1
      } else {
        value <- if (name == "true") ptrue$lambda[pindex, s] else predict(model$candidates[[name]], PB[pindex, , drop = FALSE])
        pr[, name] <- value - pphi[pindex]
        measured <- x$validation[M[x$validation]]
        value <- if (name == "true") truth$lambda[measured, s] else predict(model$candidates[[name]], B[measured, , drop = FALSE])
        vr[M[x$validation], name] <- value - phi[measured]
      }
    }
    vi <- if (type == "bridge") seq_along(x$validation) else which(M[x$validation])
    outer_z <- Z[x$validation[vi], , drop = FALSE]
    outer_gram <- gram(vr[vi, , drop = FALSE], outer_z, model$scoring_kernel)
    outer_features <- features(outer_z, model$scoring_kernel)
    outer_v <- crossprod(crossprod(outer_features, vr[vi, , drop = FALSE]) / length(vi))
    existing <- c(model$weights[names(model$candidates)], true = 0)
    true_weight <- c(rep(0, length(names) - 1L), 1)
    # Group exact population residual moments before evaluating the full RBF.
    keys <- cell_key(PZ[pindex, , drop = FALSE]); levels <- unique(keys)
    group <- match(keys, levels); first <- match(levels, keys)
    moments <- rowsum(pr * pweights, group, reorder = FALSE)
    stopifnot(max(abs(moments[, "true"])) < 1e-12)
    pop_approx <- pop_exact <- empirical <- matrix(0, length(names), length(names), dimnames = list(names, names))
    replay_error <- numeric(length(model$fold_n_scored))
    population_full_equation_error <- max(abs(moments[, "true"]))
    train <- x$training; labels <- model$fold_id
    true_residual <- if (type == "bridge") {
      r <- rep(-1, length(train)); r[M[train]] <- truth$beta[train[M[train]], s] - 1; r
    } else truth$lambda[train, s] - phi[train]
    for (fold in seq_along(model$fold_n_scored)) {
      ii <- which(labels == fold); tr <- which(labels != fold)
      if (type == "adjoint") {
        ii <- ii[M[train[ii]]]; tr <- tr[M[train[tr]]]
      }
      spec <- kernel_spec(Z[train[tr], , drop = FALSE], model$scoring_kernel$kernel,
        model$scoring_kernel$control, seed = 1L + fold)
      r <- cbind(model$cv_residuals[ii, names(model$candidates), drop = FALSE], true = true_residual[ii])
      G <- gram(r, Z[train[ii], , drop = FALSE], spec)
      replay_error[fold] <- max(abs(G[-nrow(G), -ncol(G)] - model$fold_gram[[fold]]))
      factor <- model$fold_n_scored[fold] / sum(model$fold_n_scored)
      empirical <- empirical + factor * G
      pf <- features(PZ[pindex, , drop = FALSE], spec)
      feature_moments <- crossprod(pf, pr * pweights)
      pop_approx <- pop_approx + factor * crossprod(feature_moments)
      scaled <- scale_apply(PZ[pindex[first], , drop = FALSE], spec$scale)
      K <- cmbridge::rbf_kernel(scaled, scaled, spec$bandwidth)
      pop_exact <- pop_exact + factor * crossprod(moments, K %*% moments)
    }
    stopifnot(max(replay_error) < 1e-12,
      max(abs(empirical[-nrow(empirical), -ncol(empirical)] - model$raw_gram)) < 1e-12)
    stopifnot(all(diag(pop_exact) > -1e-15), all(diag(pop_approx) > -1e-15),
      abs(pop_exact["true", "true"]) < 1e-24,
      abs(pop_approx["true", "true"]) < 1e-24)
    full_opt <- simplex(pop_exact)$weights
    approx_opt <- simplex(pop_approx)$weights
    full_original <- c(simplex(pop_exact[-nrow(pop_exact), -ncol(pop_exact)])$weights, 0)
    approx_original <- c(simplex(pop_approx[-nrow(pop_approx), -ncol(pop_approx)])$weights, 0)
    # A PSD projection depends on the full candidate set. Augment with the
    # true function only for this diagnostic; preserve the original weights.
    augmented <- project(empirical)$gram
    augmented_opt <- simplex(augmented)$weights
    for (name in c(names, "ensemble")) {
      w <- if (name == "ensemble") existing else as.numeric(names == name)
      population[[length(population) + 1L]] <- meta(data.table(function_name = type,
        candidate = name, full_rbf_loss = quadratic(w, pop_exact), nystrom_loss = quadratic(w, pop_approx)))
      validation[[length(validation) + 1L]] <- meta(data.table(function_name = type,
        candidate = name, held_out_u_statistic = quadratic(w, outer_gram),
        held_out_v_statistic = quadratic(w, outer_v)))
      cv[[length(cv) + 1L]] <- meta(data.table(function_name = type, candidate = name,
        original_u_statistic = quadratic(w, empirical),
        augmented_psd_loss = quadratic(w, augmented)))
    }
    for (method in c("population_full", "population_nystrom", "population_full_original",
                    "population_nystrom_original", "validation_augmented_psd")) {
      w <- switch(method, population_full = full_opt, population_nystrom = approx_opt,
        population_full_original = full_original, population_nystrom_original = approx_original,
        validation_augmented_psd = augmented_opt)
      selection_gram <- switch(method, population_full = pop_exact,
        population_nystrom = pop_approx, population_full_original = pop_exact,
        population_nystrom_original = pop_approx, validation_augmented_psd = augmented)
      weights[[length(weights) + 1L]] <- meta(data.table(function_name = type,
        method = method, candidate = names, weight = w,
        resulting_selection_loss = quadratic(w, selection_gram),
        resulting_population_full_loss = quadratic(w, pop_exact)))
    }
    for (fraction in seq(0, 1, length.out = 101L)) {
      w <- fraction * existing + (1 - fraction) * true_weight
      curves[[length(curves) + 1L]] <- meta(data.table(function_name = type,
        ensemble_fraction = fraction, population_full_rbf = quadratic(w, pop_exact),
        population_nystrom = quadratic(w, pop_approx), validation_u_statistic = quadratic(w, empirical)))
    }
    checks[[length(checks) + 1L]] <- meta(data.table(function_name = type,
      maximum_true_population_moment = population_full_equation_error,
      maximum_cv_replay_error = max(replay_error),
      true_full_loss = pop_exact["true", "true"], true_nystrom_loss = pop_approx["true", "true"],
      full_population_optimum_weight_true = tail(full_opt, 1L),
      nystrom_population_optimum_weight_true = tail(approx_opt, 1L),
      original_projected_ensemble_loss = model$cv_loss))
  }
  cat("Checked", basename(path), "\n"); flush.console()
}
for (name in c("population", "validation", "cv", "weights", "curves", "checks")) {
  value <- rbindlist(get(name))
  assign(name, value)
  fwrite(value, file.path(out, paste0(name, ".csv")))
}
summary <- population[, .(full_rbf_loss = mean(full_rbf_loss), nystrom_loss = mean(nystrom_loss)),
  by = .(selected, seed, n, function_name, candidate)]
fwrite(summary, file.path(out, "population-summary.csv"))
print(summary[n == 50000 & function_name == "bridge"])
print(checks[, .(maximum_cv_replay_error = max(maximum_cv_replay_error),
  maximum_true_population_moment = max(maximum_true_population_moment),
  maximum_true_full_loss = max(true_full_loss), maximum_true_nystrom_loss = max(true_nystrom_loss))])
sources <- c("studies/longitudinal/diagnostics/check_rkhs_loss.R",
  "studies/longitudinal/diagnostics/bridge_adjoint_setup.R", "studies/longitudinal/dgp.R",
  "studies/longitudinal/study.R", "dependencies/package-pins.json")
jsonlite::write_json(as.list(setNames(vapply(sources, function(path)
  digest::digest(file = path, algo = "sha256"), ""), sources)),
  file.path(out, "source-manifest.json"), pretty = TRUE, auto_unbox = TRUE)
writeLines(capture.output(sessionInfo()), file.path(out, "session.txt"))
