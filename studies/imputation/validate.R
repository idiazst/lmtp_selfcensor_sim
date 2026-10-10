# Validate saved corrected jobs independently of the fitting loop.
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(args[1L])
repo <- normalizePath(Sys.getenv("SIM_REPO", "."))
source(file.path(repo, "scripts/setup.R"))
frozen <- Sys.getenv("MI_LMTP_SOURCE")
source(if (nzchar(frozen)) file.path(frozen, "dgp.R") else
  file.path(repo, "studies/imputation/dgp.R"))
manifest <- if (file.exists(file.path(root, "checkpoint-manifest.json"))) jsonlite::fromJSON(file.path(root, "checkpoint-manifest.json")) else NULL
paths <- list.files(file.path(root, "jobs"), "\\.rds$", full.names = TRUE)
stopifnot(length(paths) > 0L)
if (file.exists(file.path(root, "design.csv"))) {
  design <- read.csv(file.path(root, "design.csv"))
  expected_keys <- sprintf("%s-n%d-r%03d.rds", design$scenario, design$n, design$replicate)
  stopifnot(!anyDuplicated(expected_keys), setequal(basename(paths), expected_keys),
    length(paths) == length(expected_keys))
}
checks <- list()
for (path in paths) {
  x <- readRDS(path)
  if (length(manifest)) stopifnot(digest::digest(file = path, algo = "sha256") == manifest[[basename(path)]])
  stopifnot(x$scenario %in% c("mar_only", "shadow_only", "both", "neither"),
    identical(unname(x$package_versions), c("0.3.0.9020", "1.6.0.9021", "3.19.0")),
    basename(path) == sprintf("%s-n%d-r%03d.rds", x$scenario, x$n, x$replicate))
  set.seed(x$data_seed)
  stopifnot(identical(x$data, mi_draw_data(x$n, x$scenario)$observed))
  stopifnot(all(is.na(x$data$Y2) == (x$data$R2 == 0L)))
  original <- list(data = x$data, results = list(sdr = x$results$bridge_sdr, tmle = x$results$bridge_tmle))
  input_path <- if (file.exists(x$input)) x$input else file.path(root, "inputs/jobs", basename(x$input))
  if (file.exists(input_path)) {
    original <- readRDS(input_path)
    stopifnot(identical(x$data, original$data),
      identical(x$results$bridge_tmle, original$results$tmle),
      identical(x$results$bridge_sdr, original$results$sdr),
      identical(x$input_sha256, digest::digest(file = input_path, algo = "sha256")))
  } else stopifnot(length(manifest) > 0L) # Published saved checkpoints need their SHA manifest.
  if (is.null(x$imputations)) {
    stopifnot(any(vapply(x$results, function(z) !is.null(z$error), TRUE)))
    next
  }
  stopifnot(identical(x$imputations$sha256, digest::digest(x$imputations$y, algo = "sha256")),
    ncol(x$imputations$y) == 50L,
    all(x$imputations$y[x$data$R2 == 1L, ] == x$data$Y2[x$data$R2 == 1L]))
  reconstruction_error <- if (length(x$imputations$reconstruction_error)) max(x$imputations$reconstruction_error) else 0
  stopifnot(reconstruction_error == 0)
  for (method in c("tmle", "sdr")) {
    p <- x$results[[paste0("mi_", method)]]
    fits <- x$complete_fits[[method]]
    failures <- sum(vapply(fits, function(z) !is.null(z$error), TRUE))
    stopifnot(length(fits) == 50L)
    if (!is.null(p$error)) {
      stopifnot(failures > 0)
      next
    }
    Q <- vapply(fits, `[[`, 0, "estimate"); U <- vapply(fits, `[[`, 0, "variance")
    expected <- mice::pool.scalar(Q, U, n = x$n, k = 5L)
    total <- mean(U) + 51 / 50 * var(Q)
    stopifnot(failures == 0L, identical(Q, p$complete_estimates), identical(U, p$complete_variances),
      abs(mean(Q) - p$estimate) < 1e-14, abs(p$se^2 - total) < 1e-14,
      abs(p$lower - (mean(Q) - qt(.975, expected$df) * sqrt(total))) < 1e-14,
      abs(p$upper - (mean(Q) + qt(.975, expected$df) * sqrt(total))) < 1e-14)
    first <- fits[[1L]]$first_fit
    stopifnot(inherits(first, "lmtp"), identical(first$estimator, toupper(method)),
      abs(var(first$estimate@eif) / x$n - U[1L]) < 1e-14,
      identical(first$folds, original$results$sdr$folds),
      identical(first$learner_folds, original$results$sdr$learner_folds),
      all(first$outcome_reg[, 2L] == x$imputations$y[, 1L]))
    a <- lapply(fits, `[[`, "audit")
    stopifnot(all(vapply(a, `[[`, 0, "score_error") < 1e-8),
      all(vapply(a, `[[`, 0, "estimate_error") < 1e-7),
      all(vapply(a, `[[`, 0, "support_failures") == 0L),
      all(vapply(a, `[[`, 0, "noninterior_selections") == 0L))
    checks[[length(checks) + 1L]] <- data.frame(scenario = x$scenario, n = x$n,
      replicate = x$replicate, method = method, completed_data_fits = length(fits),
      failures = failures, imputation_reconstruction_error = reconstruction_error,
      pool_variance_error = abs(p$se^2 - total),
      max_score_error = max(vapply(a, `[[`, 0, "score_error")),
      max_estimate_error = max(vapply(a, `[[`, 0, "estimate_error")),
      minimum_cell_count = min(vapply(a, `[[`, 0, "minimum_cell_count")),
      imputation_mcse_over_se = p$imputation_mcse / p$se,
      seconds = p$seconds)
  }
}
stopifnot(length(checks) > 0)
checks <- do.call(rbind, checks)
write.csv(checks, file.path(root, "validation-checks.csv"), row.names = FALSE)
writeLines(c("# Corrected-estimator validation", "",
  sprintf("Validated %d saved datasets and %d successful pooled MI analyses.", length(paths), nrow(checks)),
  "", "Checkpoint hashes match; observed data reproduce from the original seeds; imputation hashes and observed outcomes match. Both MI arms have 50 completed-data fits. Each first fit is a standard lmtp object with the expected estimator name, original folds, and completed outcome.",
  "", sprintf("Maximum imputation reconstruction error: %.3g; maximum independent pooling variance error: %.3g; maximum EIF reconstruction error: %.3g; minimum saturated support cell: %d.", max(checks$imputation_reconstruction_error), max(checks$pool_variance_error), max(checks$max_score_error), min(checks$minimum_cell_count)),
  "", sprintf("Mean MI Monte Carlo SE / total SE: %.1f%%; maximum: %.1f%%.", 100 * mean(checks$imputation_mcse_over_se), 100 * max(checks$imputation_mcse_over_se))),
  file.path(root, "VALIDATION.md"))
print(checks)
