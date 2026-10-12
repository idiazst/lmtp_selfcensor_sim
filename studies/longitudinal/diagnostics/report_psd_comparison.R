source("scripts/setup.R")
library(data.table)
out <- Sys.getenv("PSD_OUTPUT", "results/longitudinal/psd-numerical-n4000-v2")
design <- fread(file.path(out, "design.csv")); fingerprint <- readLines(file.path(out, "fingerprint.txt"))[1L]
paths <- list.files(file.path(out, "jobs"), "[.]rds$", full.names = TRUE)
stopifnot(length(paths) > 0)
tables <- setNames(lapply(c("results", "diagnostics", "errors", "audit", "nuisance_weights", "recovery",
  "equation_rows", "points", "nuisance_failures"), function(x) list()),
  c("results", "diagnostics", "errors", "audit", "nuisance_weights", "recovery", "equation_rows", "points", "nuisance_failures"))
runtimes <- data_checks <- list()
for (path in paths) {
  x <- readRDS(path); stopifnot(identical(x$fingerprint, fingerprint))
  r <- as.integer(x$design$replicate); mode <- x$mode
  runtimes[[length(runtimes) + 1L]] <- data.table(replicate = r, mode = mode, seconds = x$seconds,
    started_epoch = as.numeric(x$started), finished_epoch = as.numeric(x$finished),
    reused_response_models = if (is.null(x$reused_response_models)) 0L else x$reused_response_models,
    outer_error = if (is.null(x$outer_error)) "" else x$outer_error,
    checkpoint_sha256 = digest::digest(file = path, algo = "sha256"))
  if (!is.null(x$outer_error)) next
  data_checks[[length(data_checks) + 1L]] <- data.table(replicate = r, mode = mode,
    data_hash = x$data_sha256, folds_hash = x$folds_sha256)
  for (name in names(tables)) if (nrow(x[[name]])) {
    dt <- copy(x[[name]]); dt[, `:=`(replicate = r, mode = mode)]
    tables[[name]][[length(tables[[name]]) + 1L]] <- dt
  }
}
for (name in names(tables)) {
  dt <- rbindlist(tables[[name]], fill = TRUE)
  if (!ncol(dt)) dt <- data.table(replicate = integer(), mode = character())
  assign(name, dt)
  if (name != "points") fwrite(dt, file.path(out, paste0(name, ".csv")))
}
fwrite(points, file.path(out, "out-of-sample-predictions.csv.gz"), compress = "gzip")
runtimes <- rbindlist(runtimes); data_checks <- rbindlist(data_checks)
fwrite(runtimes, file.path(out, "runtimes.csv"))
complete <- nrow(runtimes) == 200L
if (!nrow(results)) stop("No returned estimates; inspect runtimes.csv and errors.csv.")
results[, `:=`(estimation_error = estimate - truth, covered = lower <= truth & upper >= truth)]
stopifnot(max(abs(results$mean_sequential_eif + results$mean_bridge_adjoint_eif - results$estimation_error)) < 1e-10)
fwrite(results, file.path(out, "replicates.csv"))
z <- qnorm(.975)
summary <- results[, .(returned = .N, truth = unique(truth), mean_estimate = mean(estimate),
  bias = mean(estimation_error), bias_mcse = sd(estimation_error) / sqrt(.N),
  empirical_sd = sd(estimate), rmse = sqrt(mean(estimation_error^2)), mean_se = mean(se),
  mean_interval_length = mean(upper - lower), coverage = mean(covered),
  coverage_mcse = sqrt(mean(covered) * (1 - mean(covered)) / .N),
  joint_curve_coverage = mean(joint_curve_covered),
  mean_sequential_eif = mean(mean_sequential_eif), mean_bridge_adjoint_eif = mean(mean_bridge_adjoint_eif)),
  by = .(horizon, estimator, mode)]
summary <- merge(CJ(horizon = 1:2, estimator = c("sdr", "tmle"), mode = c("psd", "raw")),
  summary, by = c("horizon", "estimator", "mode"), all.x = TRUE)
summary[is.na(returned), returned := 0L]
summary[, `:=`(planned = 100L, missing_or_failed = 100L - returned,
  coverage_mc_lower = (coverage + z^2/(2*returned) - z*sqrt(coverage*(1-coverage)/returned + z^2/(4*returned^2)))/(1+z^2/returned),
  coverage_mc_upper = (coverage + z^2/(2*returned) + z*sqrt(coverage*(1-coverage)/returned + z^2/(4*returned^2)))/(1+z^2/returned))]
setorder(summary, horizon, estimator, mode); fwrite(summary, file.path(out, "summary.csv"))
paired <- merge(results[mode == "psd"], results[mode == "raw"],
  by = c("replicate", "horizon", "estimator"), suffixes = c("_psd", "_raw"))
paired[, `:=`(estimate_change = estimate_raw - estimate_psd,
  coverage_change = as.integer(covered_raw) - as.integer(covered_psd),
  squared_error_change = estimation_error_raw^2 - estimation_error_psd^2)]
fwrite(paired, file.path(out, "paired-replicates.csv"))
paired_summary <- paired[, .(pairs = .N, mean_estimate_change = mean(estimate_change),
  estimate_change_mcse = sd(estimate_change)/sqrt(.N),
  coverage_change = mean(coverage_change), coverage_change_mcse = sd(coverage_change)/sqrt(.N),
  newly_covered = sum(!covered_psd & covered_raw), newly_missed = sum(covered_psd & !covered_raw),
  closer_to_truth = sum(abs(estimation_error_raw) < abs(estimation_error_psd)),
  mean_squared_error_change = mean(squared_error_change), mse_change_mcse = sd(squared_error_change)/sqrt(.N)),
  by = .(horizon, estimator)]
fwrite(paired_summary, file.path(out, "paired-summary.csv"))

paired_data <- merge(data_checks[mode == "psd"], data_checks[mode == "raw"], by = "replicate")
stopifnot(all(paired_data$data_hash.x == paired_data$data_hash.y), all(paired_data$folds_hash.x == paired_data$folds_hash.y))
audit_keys <- c("replicate", "fold", "horizon", "kind", "fit_key")
paired_audit <- merge(audit[mode == "psd"], audit[mode == "raw"], by = audit_keys,
  suffixes = c("_psd", "_raw"), all = TRUE)
hash_fields <- c("candidate_hash", "cv_prediction_hash", "raw_gram_hash", "tuning_hash", "fold_hash")
paired_audit[, matched := !is.na(training_n_psd) & !is.na(training_n_raw)]
for (field in hash_fields) paired_audit[, (paste0(field, "_equal")) :=
  get(paste0(field, "_psd")) == get(paste0(field, "_raw"))]
if (any(paired_audit$matched)) stopifnot(all(vapply(hash_fields, function(field)
  all(paired_audit[matched == TRUE][[paste0(field, "_equal")]]), TRUE)))
matched <- paired_audit[matched == TRUE]
if (nrow(matched)) stopifnot(all(matched$raw_cv_loss_raw <= matched$raw_cv_loss_psd +
  1e-8 * pmax(1, abs(matched$raw_cv_loss_raw), abs(matched$raw_cv_loss_psd))))
fwrite(paired_audit, file.path(out, "paired-candidate-checks.csv"))
recovery_by_dataset <- recovery[, .(equation_rmse = sqrt(mean(equation_rmse^2)),
  equation_max = max(equation_max), reference_function_rmse = sqrt(mean(function_rmse_to_reference^2))),
  by = .(replicate, mode, horizon, kind)]
recovery_summary <- recovery_by_dataset[, .(returned = .N, mean_equation_rmse = mean(equation_rmse),
  mean_equation_max = mean(equation_max), mean_reference_function_rmse = mean(reference_function_rmse)),
  by = .(mode, horizon, kind)]
fwrite(recovery_by_dataset, file.path(out, "recovery-by-dataset.csv")); fwrite(recovery_summary, file.path(out, "recovery-summary.csv"))
weight_summary <- nuisance_weights[fit_key == "outer", .(fits = .N, mean_weight = mean(weight),
  positive_fraction = mean(weight > 1e-8)), by = .(mode, horizon, kind, candidate)]
fwrite(weight_summary, file.path(out, "weight-summary.csv"))

figdir <- file.path(out, "figures"); dir.create(figdir, showWarnings = FALSE)
begin <- function(name, width = 1800, height = 1250) {
  png(file.path(figdir, paste0(name, ".png")), width = width, height = height, res = 170,
    type = if (Sys.info()[["sysname"]] == "Darwin") "quartz" else "cairo")
  par(mar = c(4.5, 4.5, 2.8, .8), mgp = c(2.5, .8, 0))
}
colors <- c(psd = "#2166AC", raw = "#D55E00")
begin("coverage"); par(mfrow = c(2, 2))
for (h in 1:2) for (method in c("sdr", "tmle")) {
  x <- summary[horizon == h & estimator == method]; setorder(x, mode)
  plot(1:2, x$coverage, xaxt = "n", ylim = c(0, 1), xlim = c(.5, 2.5), pch = 19,
    col = colors[x$mode], xlab = "", ylab = "Coverage of 95% confidence intervals",
    main = sprintf("%s; outcome t = %d", toupper(method), h + 1L))
  axis(1, 1:2, ifelse(x$mode == "psd", "PSD", "No PSD")); abline(h = .95, lty = 2, col = "gray50")
  arrows(1:2, x$coverage_mc_lower, 1:2, x$coverage_mc_upper, angle = 90, code = 3, length = .06, col = colors[x$mode])
  text(1:2, pmax(.08, x$coverage - .12), sprintf("%d/%d", round(x$coverage * x$returned), x$returned))
}
dev.off()
begin("paired-estimates"); par(mfrow = c(1, 2))
for (method in c("sdr", "tmle")) {
  x <- paired[horizon == 2 & estimator == method]; limits <- range(c(x$estimate_psd, x$estimate_raw, x$truth_psd))
  plot(x$estimate_psd, x$estimate_raw, xlim = limits, ylim = limits, asp = 1, pch = 16,
    col = adjustcolor("#2166AC", alpha.f = .5), xlab = "Estimate with PSD", ylab = "Estimate without PSD", main = toupper(method))
  abline(0, 1, lty = 2); abline(v = unique(x$truth_psd), h = unique(x$truth_psd), col = "#D55E00", lty = 3)
}
dev.off()
begin("estimation-errors"); par(mfrow = c(2, 2))
for (h in 1:2) for (method in c("sdr", "tmle")) {
  x <- results[horizon == h & estimator == method]
  boxplot(estimation_error ~ factor(mode, levels = c("psd", "raw")), data = x,
    names = c("PSD", "No PSD"), col = colors, ylab = "Estimate minus truth",
    main = sprintf("%s; outcome t = %d", toupper(method), h + 1L)); abline(h = 0, lty = 2)
}
dev.off()
begin("population-equation-errors"); par(mfrow = c(2, 2))
for (h in 1:2) for (k in c("bridge", "adjoint")) {
  x <- recovery_by_dataset[horizon == h & kind == k]
  boxplot(equation_rmse ~ factor(mode, levels = c("psd", "raw")), data = x, names = c("PSD", "No PSD"),
    col = colors, ylab = "Population defining-equation RMSE", main = sprintf("%s; t = %d", k, h + 1L))
}
dev.off()
for (r in intersect(c(1L, 41L), unique(points$replicate))) {
  begin(sprintf("r%03d-y-equals-x", r), 2400, 1350); par(mfrow = c(2, 4), mar = c(4, 4, 2.3, .5))
  for (k in c("bridge", "adjoint")) for (h in 1:2) for (mode_name in c("psd", "raw")) {
    both <- points[replicate == r & kind == k & horizon == h]
    x <- both[mode == mode_name]; limits <- range(c(both$truth, both$estimate), finite = TRUE)
    plot(x$truth, x$estimate, xlim = limits, ylim = limits, asp = 1, pch = 16, cex = .4,
      col = adjustcolor(colors[[mode_name]], alpha.f = .35), xlab = "Reference function", ylab = "Held-out estimate",
      main = sprintf("%s; t=%d; %s", k, h+1L, if (mode_name == "psd") "PSD" else "No PSD"))
    abline(0, 1, col = "#B22222", lty = 2)
  }
  dev.off()
  begin(sprintf("r%03d-adjoint-equation", r), 2000, 1300); par(mfrow = c(2, 2))
  for (h in 1:2) for (mode_name in c("psd", "raw")) {
    both <- equation_rows[replicate == r & kind == "adjoint" & horizon == h]
    x <- both[mode == mode_name]; limits <- range(c(both$true_conditional_mean, both$estimated_conditional_mean))
    plot(x$true_conditional_mean, x$estimated_conditional_mean, xlim = limits, ylim = limits, asp = 1,
      pch = 16, cex = .4, col = adjustcolor(colors[[mode_name]], alpha.f = .35),
      xlab = "Conditional mean of true loading", ylab = "Conditional mean of estimated adjoint",
      main = sprintf("t=%d; %s", h+1L, if (mode_name == "psd") "PSD" else "No PSD")); abline(0, 1, lty = 2, col = "#B22222")
  }
  dev.off()
}
fmt <- function(x, digits = 4L) formatC(x, digits = digits, format = "f")
lines <- c("# Numerical-dose comparison: PSD versus no PSD", "",
  if (complete) "All 100 planned datasets were processed for both versions." else
    sprintf("PRELIMINARY: %d of 200 dataset/version checkpoints are available.", nrow(runtimes)), "",
  "Each dataset has n = 4,000. Seeds 5203001–5203100 were specified in advance. Missingness occurs at both follow-ups. The original candidate libraries, positive penalty CV, shared splits, logistic TMLE and SDR, and one-step correction are retained. No experimental penalty-selection rules are used.", "",
  "Both versions use the U-statistic. Only the ensemble Gram's PSD projection changes, including descendant bridge-response ensembles. Without projection, all simplex faces are enumerated to find the global weight minimum. Candidate penalty CV uses the original raw scalar RKHS loss in both versions. Identical descendant bridge candidates can be reused after verifying their data, library and split signatures, and are globally reweighted for the raw criterion. Sequential regressions are refitted because their bridge responses change.", "",
  "## Estimates and coverage", "",
  "|Outcome time|Estimator|Projection|Returned / planned|Truth|Mean estimate|Bias|Empirical SD|Mean SE|95% CI coverage|", "|---|---|---|---:|---:|---:|---:|---:|---:|---:|")
for (i in seq_len(nrow(summary))) {
  x <- summary[i]; lines <- c(lines, sprintf("|%d|%s|%s|%d / 100|%s|%s|%s|%s|%s|%s%%|",
    x$horizon+1L, toupper(x$estimator), if (x$mode == "psd") "PSD" else "No PSD", x$returned,
    fmt(x$truth), fmt(x$mean_estimate), fmt(x$bias), fmt(x$empirical_sd), fmt(x$mean_se), fmt(100*x$coverage, 1L)))
}
lines <- c(lines, "", "Coverage denominators are returned estimates; missing/failed fits are disclosed separately. At 100 replications, the Monte Carlo standard error of 95% coverage is about 2.2 percentage points. Compare versions using paired differences, not independent-proportion errors.", "",
  "|Outcome time|Estimator|Paired datasets|Coverage change without PSD|Paired MC SE|Newly covered|Newly missed|", "|---|---|---:|---:|---:|---:|---:|")
for (i in seq_len(nrow(paired_summary))) {
  x <- paired_summary[i]; lines <- c(lines, sprintf("|%d|%s|%d|%s pp|%s pp|%d|%d|", x$horizon+1L,
    toupper(x$estimator), x$pairs, fmt(100*x$coverage_change,1L), fmt(100*x$coverage_change_mcse,1L), x$newly_covered, x$newly_missed))
}
lines <- c(lines, "", "![Coverage and Monte Carlo intervals](figures/coverage.png)",
  "![Paired final-outcome estimates](figures/paired-estimates.png)", "![Estimation errors](figures/estimation-errors.png)", "",
  "## Bridge and adjoint recovery", "",
  "Population conditional equations are evaluated on the exact finite DGP support with its probabilities. The adjoint loading for this evaluation uses the true treatment ratios; all fitted treatment ratios and sequential regressions are estimated. Function plots compare a specified reference solution; because solutions may be nonunique, adjoint defining-equation errors are the primary criterion.", "",
  "|Outcome time|Function|Projection|Mean population equation RMSE|Mean RMSE to reference function|", "|---|---|---|---:|---:|")
for (i in seq_len(nrow(recovery_summary))) {
  x <- recovery_summary[i]; lines <- c(lines, sprintf("|%d|%s|%s|%s|%s|", x$horizon+1L, x$kind,
    if (x$mode == "psd") "PSD" else "No PSD", fmt(x$mean_equation_rmse), fmt(x$mean_reference_function_rmse)))
}
lines <- c(lines, "", "![Population defining-equation errors](figures/population-equation-errors.png)")
for (r in intersect(c(1L, 41L), unique(points$replicate))) lines <- c(lines, "",
  sprintf("Replication %d, seed %d. All held-out points and all outer fits are retained.", r, 5203000L+r),
  sprintf("![Held-out reference versus estimate](figures/r%03d-y-equals-x.png)", r),
  sprintf("![Adjoint defining equations](figures/r%03d-adjoint-equation.png)", r))
outer_errors <- sum(nzchar(runtimes$outer_error))
lines <- c(lines, "", "## Verification, failures and runtime", "",
  sprintf("%d paired datasets have identical data and shared split hashes. %d matched ensemble fits have identical candidate predictions, CV predictions, penalty histories, fold labels and raw Grams. %d ensemble records have no counterpart (for example after a failed estimator).", nrow(paired_data), sum(paired_audit$matched), sum(!paired_audit$matched)),
  sprintf("Outer failures: %d; returned-estimator errors: %d; recorded nuisance candidate failures: %d. All attempts are retained. Failed ensembles or estimators are not replaced.", outer_errors, nrow(errors), nrow(nuisance_failures)),
  sprintf("Measured fitting wall span: %.2f hours. Total fitting time summed across workers: %.2f hours. Median dataset/version times: PSD %.1f s; no PSD %.1f s. The supervisor used eight workers. Reuse avoids repeated identical candidate fits, so these times are not a standalone optimizer benchmark.",
    (max(runtimes$finished_epoch) - min(runtimes$started_epoch))/3600, sum(runtimes$seconds)/3600,
    median(runtimes[mode == "psd"]$seconds), median(runtimes[mode == "raw"]$seconds)), "",
  "[All estimates and confidence intervals](replicates.csv), [summary](summary.csv), [paired results](paired-summary.csv), [EIF component means](results.csv), [population diagnostics](diagnostics.csv), [recovery](recovery-summary.csv), [weights](weight-summary.csv), [candidate identity checks](paired-candidate-checks.csv), [failed estimators](errors.csv), [candidate failures](nuisance_failures.csv), [runtimes and checkpoint hashes](runtimes.csv), [fitting source hashes](source-manifest.json).",
  "", "This is a limited study at one sample size. It does not establish asymptotic convergence or repair the full-study coverage. Report any observed benefit or deterioration using the actual paired results and their simulation uncertainty.")
writeLines(lines, file.path(out, "REPORT.md"))
writeLines(c(if (complete) "COMPLETE: 100 datasets, two versions" else "PRELIMINARY",
  sprintf("Dataset/version checkpoints: %d / 200; outer failures: %d; estimator errors: %d", nrow(runtimes), outer_errors, nrow(errors)),
  sprintf("Paired data/splits verified: %d; identical matched candidate records: %d", nrow(paired_data), sum(paired_audit$matched))),
  file.path(out, "VERIFICATION.txt"))
print(summary); print(paired_summary)
