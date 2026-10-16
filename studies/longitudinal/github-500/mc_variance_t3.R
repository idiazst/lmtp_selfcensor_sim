# Saved-result analysis only; no estimator, nuisance or penalty is fitted.
source("studies/longitudinal/github-500/config.R")
input <- Sys.getenv("MC_INPUT", ".runtime/full500-variance-t3")
outdir <- Sys.getenv("MC_OUTPUT", "results/longitudinal/full500-github-20261013/variance-t3")
stopifnot(normalizePath(input, mustWork = TRUE) != normalizePath(outdir, mustWork = FALSE))
full500_prepare(outdir)
manifest <- jsonlite::fromJSON(file.path(input, "checkpoint-manifest.json"), simplifyVector = FALSE)
paths <- list.files(file.path(input, "jobs"), "[.]rds$", full.names = TRUE)
stopifnot(length(paths) > 0L, length(paths) == length(manifest), length(paths) <= 4000L)
results <- errors <- logs <- list()
for (path in paths) {
  job_name <- sub("[.]rds$", "", basename(path))
  expected <- full500_design[job == job_name]
  fit <- readRDS(path)
  stopifnot(nrow(expected) == 1L,
    digest::digest(file = path, algo = "sha256") == manifest[[basename(path)]]$sha256,
    identical(fit$fingerprint, full500_fingerprint),
    fit$design$seed == expected$seed, fit$design$n == expected$n,
    fit$design$mechanism == expected$mechanism, fit$design$replicate == expected$replicate)
  if (!is.null(fit$results) && nrow(fit$results)) {
    r <- copy(fit$results)
    stopifnot(!anyDuplicated(r[, .(estimator, horizon)]),
      all(is.finite(as.matrix(r[, .(estimate, truth, se, lower, upper)]))), all(r$se > 0),
      all(r$seed == expected$seed), all(r$n == expected$n),
      all(r$mechanism == expected$mechanism), all(r$replicate == expected$replicate))
    results[[length(results) + 1L]] <- r
  }
  failed <- !is.null(fit$errors) && nrow(fit$errors) > 0L
  if (!failed) stopifnot(nrow(fit$results) == 4L)
  if (failed) {
    e <- copy(as.data.table(fit$errors))
    for (field in c("mechanism", "n", "replicate", "seed"))
      if (!field %in% names(e)) e[, (field) := expected[[field]]]
    e[, job := job_name]
    errors[[length(errors) + 1L]] <- e
  }
  logs[[length(logs) + 1L]] <- expected[, .(job, mechanism, n, replicate, seed,
    recorded_error = failed, returned_outcome_estimates = if (is.null(fit$results)) 0L else nrow(fit$results))]
}
x <- rbindlist(results, fill = TRUE)
log <- rbindlist(logs)
error_table <- rbindlist(errors, fill = TRUE)
if (!ncol(error_table)) error_table <- data.table(error = character())
keys <- c("mechanism", "n", "horizon", "estimator", "scenario")
stopifnot(!anyDuplicated(x[, c(keys, "replicate"), with = FALSE]),
  max(abs(x$mean_sequential_eif + x$mean_bridge_adjoint_eif - (x$estimate - x$truth))) < 1e-10)
x[, `:=`(estimation_error = estimate - truth, covered = lower <= truth & upper >= truth)]
setorderv(x, c(keys, "replicate"))
s <- x[, .(successful = .N, truth = mean(truth), mean_estimate = mean(estimate),
  bias = mean(estimation_error), root_n_bias = sqrt(n[1L]) * mean(estimation_error),
  root_n_bias_mcse = sqrt(n[1L]) * sd(estimation_error) / sqrt(.N),
  rmse = sqrt(mean(estimation_error^2)), empirical_sd = sd(estimate), mean_se = mean(se),
  coverage = mean(covered)), by = keys]
s <- merge(s, log[, .(datasets_completed = .N), by = .(mechanism, n)], by = c("mechanism", "n"))
s[, `:=`(planned = 500L, failed = datasets_completed - successful, pending = 500L - datasets_completed)]
fwrite(x, file.path(outdir, "replicates.csv"))
fwrite(s, file.path(outdir, "summary.csv"))
fwrite(log, file.path(outdir, "job_log.csv"))
fwrite(error_table, file.path(outdir, "errors.csv"))
for (name in c("checkpoint-manifest.json", "artifact-provenance.json"))
  stopifnot(file.copy(file.path(input, name), file.path(outdir, name), overwrite = TRUE))
writeLines("# Monte Carlo variance analysis of the saved estimators", file.path(outdir, "REPORT.md"))
source("studies/longitudinal/github-500/bias_variance.R")
a <- augment_bias_variance_report(outdir)
t3 <- merge(a[horizon == 2L], s[, c(keys, "datasets_completed", "failed", "pending"), with = FALSE], by = keys)
t3[, `:=`(mc_variance = empirical_sd^2, mean_reported_variance = sqrt_mean_estimated_variance^2,
  mc_variance_coverage_change = empirical_sd_coverage - actual_coverage)]
setorder(t3, mechanism, n, estimator)
fwrite(t3, file.path(outdir, "t3-variance-diagnosis.csv"))
intervals <- merge(x[horizon == 2L], t3[, c(keys, "empirical_sd", "bias"), with = FALSE], by = keys)
intervals[, `:=`(mc_lower = estimate - qnorm(.975) * empirical_sd,
  mc_upper = estimate + qnorm(.975) * empirical_sd,
  centered_mc_lower = estimate - bias - qnorm(.975) * empirical_sd,
  centered_mc_upper = estimate - bias + qnorm(.975) * empirical_sd)]
intervals[, `:=`(mc_covered = mc_lower <= truth & mc_upper >= truth,
  centered_mc_covered = centered_mc_lower <= truth & centered_mc_upper >= truth)]
fwrite(intervals[, .(mechanism, n, replicate, seed, estimator, truth, estimate, se, lower, upper,
  covered, empirical_sd, bias, mc_lower, mc_upper, mc_covered,
  centered_mc_lower, centered_mc_upper, centered_mc_covered)], file.path(outdir, "t3-mc-intervals.csv"))

table <- function(dt) {
  dt <- as.data.frame(dt)
  c(paste0("| ", paste(names(dt), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(dt)), collapse = " | "), " |"),
    apply(dt, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |")), "")
}
lines <- c("# Does Monte Carlo variance explain undercoverage at t=3?", "",
  sprintf("**PRELIMINARY: %d of 4,000 dataset checkpoints; %d datasets have recorded estimator errors.** Snapshot analyzed %s.",
    nrow(log), sum(log$recorded_error), format(Sys.time(), tz = "America/New_York", usetz = TRUE)), "",
  "Each table uses every returned t=3 estimate in its setting. Failed estimators are retained in errors.csv and excluded from variance and coverage calculations, because they do not return an interval. Pending datasets are not included. The estimator, nuisance fits, penalties, splits and seeds are unchanged. No new datasets are fitted for this analysis.", "",
  "## Calculation", "",
  "Within each treatment setting, sample size and estimator, compute the sample variance of the estimates across Monte Carlo runs, centered at their average estimate, with divisor equal to the number of returned estimates minus one. Its square root is the Monte Carlo SD. This approximates the estimator's true sampling SD; it is not the root mean squared error, and it is not divided by the square root of the number of simulation runs.", "",
  "For each saved estimate, replace its reported SE by this common Monte Carlo SD and recompute the interval as the estimate plus or minus 1.959964 times that SD. The estimate itself is not shifted. MC SD coverage therefore preserves the original mean bias. MC SD, subtract mean bias additionally subtracts the across-run mean estimation error before forming the interval, separating the effect of mean bias from interval width. These are simulation diagnostics, not new usable estimators or proposed confidence intervals.", "",
  "The variance ratio is mean(reported SE squared) divided by the Monte Carlo variance. A ratio below one indicates variance underestimation on average; a ratio above one indicates overestimation on average. Because the same completed runs estimate the variance and evaluate coverage, uncertainty calculations resample runs and re-estimate both quantities. All observations, including extreme estimates, are retained.", "")
labels <- c(discrete_dose = "Numerical dose", binary_longitudinal = "Binary treatment")
for (name in names(labels)) {
  z <- t3[mechanism == name]
  lines <- c(lines, paste0("## ", labels[[name]]), "",
    table(z[, .(n, Estimator = toupper(estimator), Returned = returned, Failed = failed, Pending = pending,
      `Reported SE coverage` = sprintf("%.1f%%", 100 * actual_coverage),
      `MC SD coverage` = sprintf("%.1f%%", 100 * empirical_sd_coverage),
      `MC SD, subtract mean bias` = sprintf("%.1f%%", 100 * remove_mean_bias_empirical_sd_coverage),
      VarianceRatio = sprintf("%.3f", variance_ratio),
      `Bias / MC SD` = sprintf("%.3f", bias_in_empirical_sd))]))
}
lines <- c(lines, "## Simulation uncertainty for the numerical-dose comparison", "",
  "The intervals below are 95% bootstrap simulation intervals from 2,000 resamples of completed Monte Carlo runs; estimates and reported SEs stay paired, and bias and SD are recomputed in every resample. Coverage-change intervals account for the dependence between the two coverage calculations. They describe simulation uncertainty, not uncertainty about the causal parameter.", "",
  table(t3[mechanism == "discrete_dose", .(n, Estimator = toupper(estimator),
    `MC SD coverage, interval` = sprintf("%.1f%% [%.1f%%, %.1f%%]", 100 * empirical_sd_coverage,
      100 * empirical_sd_coverage_mc_lower, 100 * empirical_sd_coverage_mc_upper),
    `MC SD, subtract bias, interval` = sprintf("%.1f%% [%.1f%%, %.1f%%]", 100 * remove_mean_bias_empirical_sd_coverage,
      100 * remove_mean_bias_empirical_sd_coverage_mc_lower, 100 * remove_mean_bias_empirical_sd_coverage_mc_upper),
    `Coverage change, percentage points` = sprintf("%+.1f [%+.1f, %+.1f]", 100 * mc_variance_coverage_change,
      100 * empirical_sd_change_mc_lower, 100 * empirical_sd_change_mc_upper),
    `Estimated / MC variance, interval` = sprintf("%.3f [%.3f, %.3f]", variance_ratio,
      variance_ratio_mc_lower, variance_ratio_mc_upper))]),
  "## Reading the comparison", "",
  "If replacing SEs by the Monte Carlo SD brings coverage close to 95%, the reported interval widths contribute to undercoverage. If coverage remains low, variance estimation alone is insufficient: mean bias or a nonnormal sampling distribution can still be responsible. The bias-subtracted calculation helps distinguish those explanations. A common Monte Carlo SD also removes differences in interval widths across datasets, so a coverage change need not arise solely from average variance underestimation.", "",
  "Rare large errors can inflate the Monte Carlo variance, especially for binary treatment. The complete CSV reports the largest-error shares of MSE, standardized-error quantiles, and all variance/coverage calculations. No outlier is removed. Partial completion may depend on fitting difficulty, and the sampling-variance calculation is conditional on an estimator returning successfully. Results remain preliminary until the full study and its failures are assessed.", "",
  "![Original and Monte Carlo-SD coverage](figures/mc-variance-t3-coverage.png)", "",
  "[Complete t=3 calculations](t3-variance-diagnosis.csv), [each recomputed t=3 interval](t3-mc-intervals.csv), [all saved estimates and reported intervals](replicates.csv), [counts and errors by dataset](job_log.csv), [recorded failures](errors.csv), [complete bias/variance assessment](BIAS-VARIANCE.md), [checkpoint hashes](checkpoint-manifest.json), [artifact provenance](artifact-provenance.json), and [frozen fitting sources](source-manifest.json).")

png(file.path(outdir, "figures", "mc-variance-t3-coverage.png"), width = 2100L, height = 1500L, res = 170,
  type = if (Sys.info()[["sysname"]] == "Darwin") "quartz" else "cairo")
par(mfrow = c(2, 2), mar = c(4.5, 4.7, 3, 1), mgp = c(2.8, .8, 0))
fields <- c("actual_coverage", "empirical_sd_coverage", "remove_mean_bias_empirical_sd_coverage")
colors <- c("#333333", "#0072B2", "#D55E00")
for (name in names(labels)) for (method in c("sdr", "tmle")) {
  z <- t3[mechanism == name & estimator == method][order(n)]
  plot(NA, xlim = log10(range(z$n)), ylim = pmax(0, pmin(1, range(.95, unlist(t3[mechanism == name, ..fields])) + c(-.015, .015))),
    xaxt = "n", xlab = "Sample size", ylab = "Fraction of intervals containing the true value",
    main = paste(labels[[name]], toupper(method)))
  axis(1, log10(z$n), format(z$n, big.mark = ",")); abline(h = .95, lty = 2, col = "grey55")
  for (j in seq_along(fields)) lines(log10(z$n), z[[fields[j]]], col = colors[j], pch = 14L + j, type = "b")
  legend("bottomright", c("Reported SE", "MC SD", "MC SD, subtract mean bias"),
    col = colors, lty = 1, pch = 15:17, bty = "n", cex = .75)
}
dev.off()
writeLines(lines, file.path(outdir, "REPORT.md"))
jsonlite::write_json(list(analyzed_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  completed_checkpoints = nrow(log), datasets_with_errors = sum(log$recorded_error),
  fitting_fingerprint = full500_fingerprint, fitting_changes = FALSE,
  analysis_source_sha256 = digest::digest(file = "studies/longitudinal/github-500/mc_variance_t3.R", algo = "sha256"),
  estimates_sha256 = digest::digest(file = file.path(outdir, "replicates.csv"), algo = "sha256")),
  file.path(outdir, "analysis-provenance.json"), pretty = TRUE, auto_unbox = TRUE)
cat("Verified checkpoints:", nrow(log), "; datasets with errors:", sum(log$recorded_error), "\n")
print(t3[mechanism == "discrete_dose", .(n, estimator, returned, actual_coverage, empirical_sd_coverage,
  remove_mean_bias_empirical_sd_coverage, variance_ratio, bias_in_empirical_sd)])
