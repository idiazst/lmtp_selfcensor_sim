source("studies/longitudinal/diagnostics/statistic_setup.R")
out <- statistic_output
dir.create(file.path(out, "jobs"), recursive = TRUE, showWarnings = FALSE)
workers <- as.integer(Sys.getenv("DIAGNOSTIC_WORKERS", "6"))
stopifnot(workers >= 1L)
r <- fread("results/longitudinal/replicates.csv")
selection <- rbindlist(lapply(statistic_mechanisms, function(mechanism_name) {
  z <- r[mechanism == mechanism_name & n == 4000L & horizon == 2L & estimator == "sdr" &
    scenario == "beta1_lambda1_ratio1_m1" & (is.na(error) | error == "")]
  z[, absolute_error := abs(estimate - truth)]
  setorder(z, absolute_error, replicate)
  z <- z[c(.N, 1L), .(mechanism, seed, replicate, estimate, truth,
    absolute_error, estimation_error)]
  z[, selected := c("largest_bias", "smallest_bias")]
  z
}))
fwrite(selection, file.path(out, "selected-seeds.csv"))
design <- selection[, CJ(n = c(4000L, 10000L, 50000L), statistic = c("u", "v")),
  by = .(mechanism, selected, seed, replicate)]
# Match the old frozen libraries; only the statistic is varied in fresh fits.
sources <- c("scripts/setup.R", "dependencies/package-pins.json",
  "studies/longitudinal/dgp.R", "studies/longitudinal/study.R",
  "studies/longitudinal/diagnostics/bridge_adjoint_setup.R",
  "studies/longitudinal/diagnostics/statistic_setup.R",
  "studies/longitudinal/diagnostics/run_statistic_comparison.R")
manifest <- setNames(vapply(sources, function(p) digest::digest(file = p, algo = "sha256"), ""), sources)
package_sources <- list.files("../cmbridge/R", full.names = TRUE)
package_manifest <- setNames(vapply(package_sources, function(p)
  digest::digest(file = p, algo = "sha256"), ""), package_sources)
fingerprint <- digest::digest(list(manifest, package_manifest, design, statistic_times,
  packageVersion("cmbridge"), packageVersion("lmtp")), algo = "sha256")
fp <- file.path(out, "fingerprint.txt")
if (file.exists(fp)) stopifnot(readLines(fp)[1L] == fingerprint)
writeLines(fingerprint, fp)
fwrite(design, file.path(out, "design.csv"))
jsonlite::write_json(list(study = as.list(manifest), package = as.list(package_manifest)),
  file.path(out, "source-manifest.json"), auto_unbox = TRUE, pretty = TRUE)
writeLines(capture.output(sessionInfo()), file.path(out, "session.txt"))
audits <- lapply(statistic_mechanisms, function(mechanism_name) {
  g <- make_mechanism(mechanism_name); audit <- require_valid_mechanism(g)
  p <- enumerate_data(g); pt <- study_task(p, g)$task; nu <- true_values(p, g)
  for (s in seq_len(g$tau)) {
    M <- p[[paste0("R", s + 1L)]] == 1L
    phi <- apply(nu$ratios[, seq_len(s), drop = FALSE], 1, prod) * ifelse(M, p[[paste0("Y", s + 1L)]], 0)
    eq <- moment_tables(p, pt, s, nu$beta[, s], nu$lambda[, s], phi, p$probability)
    stopifnot(max(abs(eq$bridge$residual)) < 1e-10, max(abs(eq$adjoint$residual)) < 1e-10)
  }
  setDT(audit)
  audit[, mechanism := mechanism_name]
  audit
})
fwrite(rbindlist(audits, fill = TRUE), file.path(out, "dgp-assumptions.csv"))

one <- function(i) {
  z <- design[i]; g <- make_mechanism(z$mechanism)
  set.seed(z$seed); d <- draw_data(z$n, g)
  original <- if (z$n == 4000L) readRDS(sprintf("results/longitudinal/jobs/%s-n4000-r%03d.rds",
    z$mechanism, z$replicate)) else NULL
  prepared <- if (is.null(original)) study_task(d, g, learner_groups = 3L, balance_measurement = TRUE) else
    study_task(d, g, folds = original$folds, learner_folds = original$learner_folds,
      learner_groups = 3L, balance_measurement = TRUE)
  task <- prepared$task; nu <- true_values(d, g)
  if (!is.null(original)) stopifnot(identical(task$folds, original$folds),
    identical(task$learner_folds, original$learner_folds), original$design$seed == z$seed)
  for (fold in seq_along(task$folds)) for (outcome_time in statistic_times) {
    s <- outcome_time - 1L
    key <- sprintf("%s-seed%d-n%d-t%d-fold%d-%s", z$mechanism, z$seed, z$n, outcome_time, fold, z$statistic)
    path <- file.path(out, "jobs", paste0(key, ".rds"))
    if (file.exists(path)) {
      previous <- readRDS(path)
      stopifnot(previous$fingerprint == fingerprint)
      next
    }
    previous_path <- sprintf("results/longitudinal/bridge-adjoint-seed-check/jobs/seed%d-n%d-t%d-fold%d.rds",
      z$seed, z$n, outcome_time, fold)
    if (z$mechanism == "discrete_dose" && z$statistic == "u" && file.exists(previous_path)) {
      result <- readRDS(previous_path)
      stopifnot(is.null(result$error), result$data_sha256 == digest::digest(d, algo = "sha256"),
        identical(result$training, task$folds[[fold]]$training_set),
        identical(result$validation, task$folds[[fold]]$validation_set),
        identical(result$fold_id, task$learner_folds[[fold]]))
      result$original_checkpoint_sha256 <- digest::digest(file = previous_path, algo = "sha256")
      result$fit_provenance <- "reused frozen U checkpoint"
      result$fit_package_version <- "0.3.0.9020"
      result$design <- c(as.list(z), list(time = outcome_time, fold = fold))
      result$fingerprint <- fingerprint
      saveRDS(result, path, compress = "gzip")
      cat(format(Sys.time()), "REUSED", key, "\n"); flush.console()
      next
    }
    started <- proc.time()[3L]; warnings <- character()
    cat(format(Sys.time()), "START", key, "\n"); flush.console()
    result <- tryCatch(withCallingHandlers({
      train <- task$folds[[fold]]$training_set; valid <- task$folds[[fold]]$validation_set
      stopifnot(!length(intersect(train, valid)), setequal(c(train, valid), seq_len(z$n)))
      nested <- lmtp:::make_bridge_nested_folds(task$id[train], d[train, c("R2", "R3"), drop = FALSE],
        task$learner_folds[[fold]])
      libraries <- lapply(c(TRUE, FALSE), function(bridge) {
        lib <- cm_library(bridge = bridge)
        for (j in seq_along(lib)) if (!is.null(lib[[j]]$control$penalty_scales)) {
          lib[[j]]$control$penalty_ids <- task$id[train]
          lib[[j]]$control$penalty_folds <- nested
        }
        lib
      })
      H <- task$vars$history("A", s); A <- task$vars$A[[s]]
      B <- as.matrix(task$natural[, c(H, A), drop = FALSE])
      V <- as.matrix(cbind(task$natural[, H, drop = FALSE],
        d[, c(paste0("C", outcome_time, "_covariate"), paste0("Y", outcome_time)), drop = FALSE]))
      M <- d[[paste0("R", outcome_time)]]
      phi <- apply(nu$ratios[, seq_len(s), drop = FALSE], 1, prod) *
        ifelse(M == 1, d[[paste0("Y", outcome_time)]], 0)
      bridge <- cmbridge::fit_bridge_ensemble(B[train, , drop = FALSE], V[train, , drop = FALSE], M[train],
        library = libraries[[1L]], fold_id = task$learner_folds[[fold]], kernel = "rbf", statistic = z$statistic)
      cat(format(Sys.time()), "BRIDGE DONE", key, "\n"); flush.console()
      adjoint <- cmbridge::fit_adjoint_ensemble(B[train, , drop = FALSE], V[train, , drop = FALSE], M[train],
        phi[train], library = libraries[[2L]], fold_id = task$learner_folds[[fold]], kernel = "rbf", statistic = z$statistic)
      for (model in list(bridge, adjoint)) {
        stopifnot(all(is.finite(model$weights)), abs(sum(model$weights) - 1) < 1e-10,
          all(model$weights >= 0), identical(model$statistic, z$statistic))
        for (candidate in model$candidates) if (!is.null(candidate$penalty_cv))
          stopifnot(grepl("^interior", candidate$penalty_status), all(candidate$penalty_cv$scale > 0),
            all(candidate$penalty_cv$statistic == z$statistic))
        if (z$statistic == "v") stopifnot(!model$psd_projection$applied,
          model$psd_projection$adjustment_norm == 0, max(abs(model$gram - model$raw_gram)) == 0)
      }
      list(bridge = bridge, adjoint = adjoint, validation = valid, training = train,
        fold_id = task$learner_folds[[fold]], data_sha256 = digest::digest(d, algo = "sha256"),
        fit_provenance = "fresh statistic-specific penalty CV and ensemble fit", fit_package_version = "0.3.0.9022")
    }, warning = function(w) {warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")}),
      error = function(e) list(error = conditionMessage(e), condition = e))
    result$design <- c(as.list(z), list(time = outcome_time, fold = fold))
    result$fingerprint <- fingerprint; result$seconds <- unname(proc.time()[3L] - started)
    result$warnings <- unique(warnings)
    temporary <- paste0(path, ".tmp"); saveRDS(result, temporary, compress = "gzip")
    stopifnot(file.rename(temporary, path))
    cat(format(Sys.time()), "END", key, sprintf("%.1fs", result$seconds),
      if (is.null(result$error)) "OK" else result$error, "\n"); flush.console()
  }
  TRUE
}
answers <- parallel::mclapply(seq_len(nrow(design)), one,
  mc.cores = min(workers, nrow(design)), mc.preschedule = FALSE, mc.set.seed = FALSE)
stopifnot(length(answers) == nrow(design), all(vapply(answers, isTRUE, TRUE)),
  length(list.files(file.path(out, "jobs"), "[.]rds$")) == nrow(design) * 3L * length(statistic_times))
writeLines(format(Sys.time(), tz = "America/New_York", usetz = TRUE), file.path(out, "FITTING-COMPLETED.txt"))
