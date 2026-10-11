source("studies/longitudinal/diagnostics/bridge_adjoint_setup.R")
out <- Sys.getenv("DIAGNOSTIC_OUTPUT", "results/longitudinal/bridge-adjoint-seed-check")
workers <- as.integer(Sys.getenv("DIAGNOSTIC_WORKERS", "6"))
dir.create(file.path(out, "jobs"), recursive = TRUE, showWarnings = FALSE)

# Use the lower-coverage estimator to select seeds, without optimizing any fit
# or penalty against known functions. "Bias" here is a realized absolute error.
r <- fread("results/longitudinal/replicates.csv")
r <- r[mechanism == "discrete_dose" & n == 4000L & horizon == 2L &
  estimator == "sdr" & scenario == "beta1_lambda1_ratio1_m1" &
  (is.na(error) | error == "")]
r[, absolute_error := abs(estimate - truth)]
setorder(r, absolute_error, replicate)
selection <- r[c(.N, 1L), .(seed, replicate, estimate, truth, absolute_error,
  estimation_error, mean_sequential_eif, mean_bridge_adjoint_eif)]
selection[, selected := c("largest_bias", "smallest_bias")]
stopifnot(nrow(r) == 199L, identical(selection$seed, c(5203041L, 5203167L)))
fwrite(selection, file.path(out, "selected-seeds.csv"))
design <- selection[, .(n = c(4000L, 10000L, 50000L)), by = .(selected, seed, replicate)]
fwrite(design, file.path(out, "design.csv"))
sources <- c("scripts/setup.R", "dependencies/package-pins.json",
  "studies/longitudinal/dgp.R", "studies/longitudinal/study.R",
  "studies/longitudinal/diagnostics/bridge_adjoint_setup.R",
  "studies/longitudinal/diagnostics/run_bridge_adjoint.R",
  "studies/longitudinal/diagnostics/plot_bridge_adjoint.R")
manifest <- setNames(vapply(sources, function(p) digest::digest(file = p, algo = "sha256"), ""), sources)
fingerprint <- digest::digest(list(manifest, design, packageVersion("cmbridge"), packageVersion("lmtp")), algo = "sha256")
fp <- file.path(out, "fingerprint.txt")
if (file.exists(fp)) stopifnot(readLines(fp)[1L] == fingerprint)
writeLines(fingerprint, fp)
jsonlite::write_json(as.list(manifest), file.path(out, "source-manifest.json"), auto_unbox = TRUE, pretty = TRUE)
writeLines(capture.output(sessionInfo()), file.path(out, "session.txt"))
g <- make_mechanism("discrete_dose"); audit <- require_valid_mechanism(g)
fwrite(audit, file.path(out, "dgp-assumptions.csv"))
p <- enumerate_data(g)
pt <- study_task(p, g)$task
pop_truth <- true_values(p, g)
# Verify chosen solutions, independently of any fitted model.
for (s in seq_len(g$tau)) {
  phi <- apply(pop_truth$ratios[, seq_len(s), drop = FALSE], 1, prod) *
    ifelse(p[[paste0("R", s + 1L)]] == 1, p[[paste0("Y", s + 1L)]], 0)
  z <- moment_tables(p, pt, s, pop_truth$beta[, s], pop_truth$lambda[, s], phi, p$probability)
  stopifnot(max(abs(z$bridge$residual)) < 1e-10, max(abs(z$adjoint$residual)) < 1e-10)
}

one <- function(i) {
  z <- design[i]
  set.seed(z$seed)
  d <- draw_data(z$n, g)
  saved <- if (z$n == 4000L) readRDS(sprintf(
    "results/longitudinal/jobs/discrete_dose-n4000-r%03d.rds", z$replicate)) else NULL
  prepared <- if (is.null(saved)) study_task(d, g, learner_groups = 3L, balance_measurement = TRUE) else
    study_task(d, g, folds = saved$folds, learner_folds = saved$learner_folds,
      learner_groups = 3L, balance_measurement = TRUE)
  task <- prepared$task
  if (!is.null(saved)) stopifnot(identical(task$folds, saved$folds),
    identical(task$learner_folds, saved$learner_folds), saved$design$seed == z$seed)
  nu <- true_values(d, g)
  for (fold in seq_along(task$folds)) for (s in seq_len(g$tau)) {
    key <- sprintf("seed%d-n%d-t%d-fold%d", z$seed, z$n, s + 1L, fold)
    path <- file.path(out, "jobs", paste0(key, ".rds"))
    if (file.exists(path)) {
      previous <- readRDS(path)
      stopifnot(previous$fingerprint == fingerprint, is.null(previous$error))
      next
    }
    started <- proc.time()[3L]; warnings <- character()
    cat(format(Sys.time()), "START", key, "\n"); flush.console()
    result <- tryCatch(withCallingHandlers({
      train <- task$folds[[fold]]$training_set
      valid <- task$folds[[fold]]$validation_set
      stopifnot(!length(intersect(train, valid)), setequal(c(train, valid), seq_len(z$n)))
      nested <- lmtp:::make_bridge_nested_folds(task$id[train], d[train, c("R2", "R3"), drop = FALSE],
        task$learner_folds[[fold]])
      libraries <- lapply(c(TRUE, FALSE), function(is_bridge) {
        library <- cm_library(bridge = is_bridge)
        for (a in seq_along(library)) if (!is.null(library[[a]]$control$penalty_scales)) {
          library[[a]]$control$penalty_ids <- task$id[train]
          library[[a]]$control$penalty_folds <- nested
        }
        library
      })
      H <- task$vars$history("A", s); A <- task$vars$A[[s]]
      B <- as.matrix(task$natural[, c(H, A), drop = FALSE])
      V <- as.matrix(cbind(task$natural[, H, drop = FALSE],
        d[, c(paste0("C", s + 1L, "_covariate"), paste0("Y", s + 1L)), drop = FALSE]))
      M <- d[[paste0("R", s + 1L)]]
      phi <- apply(nu$ratios[, seq_len(s), drop = FALSE], 1, prod) *
        ifelse(M == 1, d[[paste0("Y", s + 1L)]], 0)
      bridge <- cmbridge::fit_bridge_ensemble(B[train, , drop = FALSE], V[train, , drop = FALSE],
        M[train], library = libraries[[1L]], fold_id = task$learner_folds[[fold]], kernel = "rbf")
      cat(format(Sys.time()), "BRIDGE DONE", key, "\n"); flush.console()
      adjoint <- cmbridge::fit_adjoint_ensemble(B[train, , drop = FALSE], V[train, , drop = FALSE],
        M[train], phi[train], library = libraries[[2L]], fold_id = task$learner_folds[[fold]], kernel = "rbf")
      observed <- valid[M[valid] == 1L]
      sample_beta <- rep(NA_real_, length(valid))
      sample_beta[M[valid] == 1L] <- predict(bridge, V[observed, , drop = FALSE])
      sample_adjoint <- predict(adjoint, B[valid, , drop = FALSE])
      sample_points <- rbindlist(list(data.table(function_name = "bridge", row = observed,
        truth = nu$beta[observed, s], estimate = sample_beta[M[valid] == 1L],
        previous_measured = d[[paste0("R", s)]][observed]),
        data.table(function_name = "adjoint", row = valid, truth = nu$lambda[valid, s],
          estimate = sample_adjoint, previous_measured = d[[paste0("R", s)]][valid])))
      PB <- as.matrix(pt$natural[, c(H, A), drop = FALSE])
      PV <- as.matrix(cbind(pt$natural[, H, drop = FALSE],
        p[, c(paste0("C", s + 1L, "_covariate"), paste0("Y", s + 1L)), drop = FALSE]))
      PM <- p[[paste0("R", s + 1L)]] == 1L
      pop_beta <- rep(NA_real_, nrow(p)); pop_beta[PM] <- predict(bridge, PV[PM, , drop = FALSE])
      pop_adjoint <- predict(adjoint, PB)
      pop_phi <- apply(pop_truth$ratios[, seq_len(s), drop = FALSE], 1, prod) *
        ifelse(PM, p[[paste0("Y", s + 1L)]], 0)
      equations <- moment_tables(p, pt, s, pop_beta, pop_adjoint, pop_phi, p$probability)
      population_points <- rbindlist(list(
        data.table(function_name = "bridge", cell = cell_key(PV[PM, , drop = FALSE]),
          truth = pop_truth$beta[PM, s], estimate = pop_beta[PM], probability = p$probability[PM],
          previous_measured = p[[paste0("R", s)]][PM])[, .(truth = truth[1L], estimate = estimate[1L],
            probability = sum(probability), previous_measured = previous_measured[1L]), by = .(function_name, cell)],
        data.table(function_name = "adjoint", cell = cell_key(PB), truth = pop_truth$lambda[, s],
          estimate = pop_adjoint, probability = p$probability,
          previous_measured = p[[paste0("R", s)]])[, .(truth = truth[1L], estimate = estimate[1L],
            probability = sum(probability), previous_measured = previous_measured[1L]), by = .(function_name, cell)]))
      for (model in list(bridge, adjoint)) {
        stopifnot(all(is.finite(model$weights)), abs(sum(model$weights) - 1) < 1e-10,
          all(model$weights >= 0))
        for (candidate in model$candidates) if (!is.null(candidate$penalty_cv))
          stopifnot(grepl("^interior", candidate$penalty_status))
      }
      stopifnot(all(is.finite(sample_points$estimate)), all(is.finite(population_points$estimate)),
        all(sample_points[function_name == "bridge", estimate] >= 1))
      list(bridge = bridge, adjoint = adjoint, sample_points = sample_points,
        population_points = population_points, equations = equations, validation = valid,
        training = train, fold_id = task$learner_folds[[fold]],
        data_sha256 = digest::digest(d, algo = "sha256"))
    }, warning = function(w) {warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")}),
      error = function(e) list(error = conditionMessage(e), condition = e))
    result$design <- c(as.list(z), list(time = s + 1L, fold = fold))
    result$fingerprint <- fingerprint
    result$seconds <- unname(proc.time()[3L] - started)
    result$warnings <- unique(warnings)
    temporary <- paste0(path, ".tmp"); saveRDS(result, temporary, compress = "gzip")
    stopifnot(file.rename(temporary, path))
    cat(format(Sys.time()), "END", key, sprintf("%.1fs", result$seconds), if (is.null(result$error)) "OK" else result$error, "\n"); flush.console()
    if (!is.null(result$error)) stop("Failed fit retained: ", key, ": ", result$error)
  }
  TRUE
}
answers <- parallel::mclapply(seq_len(nrow(design)), one,
  mc.cores = min(workers, nrow(design)), mc.preschedule = FALSE, mc.set.seed = FALSE)
stopifnot(length(answers) == 6L, all(vapply(answers, isTRUE, TRUE)),
  length(list.files(file.path(out, "jobs"), "\\.rds$")) == 36L)
writeLines(format(Sys.time(), tz = "America/New_York", usetz = TRUE), file.path(out, "FITTING-COMPLETED.txt"))
Sys.setenv(DIAGNOSTIC_OUTPUT = out)
source("studies/longitudinal/diagnostics/plot_bridge_adjoint.R")
