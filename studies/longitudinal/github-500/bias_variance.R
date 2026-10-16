# Postprocessing only: no nuisance fitting, tuning or estimator changes.
augment_bias_variance_report <- function(outdir, bootstrap_draws = 2000L) {
  library(data.table)
  x <- fread(file.path(outdir, "replicates.csv"))
  stopifnot(nrow(x) > 0L, all(is.finite(x$estimate)), all(is.finite(x$se)), all(x$se > 0))
  keys <- c("mechanism", "n", "horizon", "estimator", "scenario")
  stopifnot(!anyDuplicated(x[, c(keys, "replicate"), with = FALSE]))
  setorderv(x, c(keys, "replicate"))
  critical <- qnorm(.975)
  set.seed(708614L) # Only the uncertainty calculation uses this stream.
  a <- x[, {
    error <- estimate - truth; average_error <- mean(error)
    empirical_sd <- sd(error); centered <- error - average_error
    actual <- abs(error) <= critical * se
    remove_bias <- abs(centered) <= critical * se
    empirical_width <- abs(error) <= critical * empirical_sd
    remove_bias_empirical_width <- abs(centered) <= critical * empirical_sd
    se_scale <- empirical_sd / sqrt(mean(se^2))
    rescaled_se <- abs(error) <= critical * se * se_scale
    remove_bias_rescaled_se <- abs(centered) <= critical * se * se_scale
    squared <- error^2
    sampled <- matrix(sample.int(.N, .N * bootstrap_draws, replace = TRUE), .N)
    be <- matrix(error[sampled], .N); bs <- matrix(se[sampled], .N)
    bb <- colMeans(be)
    bc <- sweep(be, 2L, bb, "-")
    bsd <- sqrt(colSums(bc^2) / (.N - 1L))
    valid <- is.finite(bsd) & bsd > 0
    boot_actual <- colMeans(abs(be) <= critical * bs)
    boot_centered <- colMeans(abs(bc) <= critical * bs)
    boot_width <- colMeans(abs(be) <= matrix(critical * bsd, .N, bootstrap_draws, byrow = TRUE))
    boot_both <- colMeans(abs(bc) <= matrix(critical * bsd, .N, bootstrap_draws, byrow = TRUE))
    boot_scale <- bsd / sqrt(colMeans(bs^2))
    boot_scaled_se <- sweep(bs, 2L, boot_scale, "*")
    boot_rescaled <- colMeans(abs(be) <= critical * boot_scaled_se)
    boot_centered_rescaled <- colMeans(abs(bc) <= critical * boot_scaled_se)
    boot_variance_ratio <- colMeans(bs^2) / bsd^2
    interval <- function(v) unname(quantile(v[valid & is.finite(v)], c(.025, .975)))
    vr <- interval(boot_variance_ratio)
    cb <- interval(boot_centered - boot_actual)
    cw <- interval(boot_width - boot_actual)
    cc <- interval(boot_both - boot_actual)
    mc_width_coverage_interval <- interval(boot_width)
    centered_mc_width_coverage_interval <- interval(boot_both)
    cr <- interval(boot_rescaled - boot_actual)
    ccr <- interval(boot_centered_rescaled - boot_actual)
    scaled_bias_interval <- interval(sqrt(n[1L]) * bb)
    scaled_mse_interval <- interval(n[1L] * colMeans(be^2))
    q <- unname(quantile(error / se, c(.025, .5, .975)))
    list(returned = .N, bias = average_error, root_n_bias = sqrt(n[1L]) * average_error,
      root_n_bias_mcse = sqrt(n[1L]) * empirical_sd / sqrt(.N),
      n_mse = n[1L] * mean(squared), n_mse_mcse = n[1L] * sd(squared) / sqrt(.N),
      root_n_bias_mc_lower = scaled_bias_interval[1L], root_n_bias_mc_upper = scaled_bias_interval[2L],
      n_mse_mc_lower = scaled_mse_interval[1L], n_mse_mc_upper = scaled_mse_interval[2L],
      n_squared_bias = n[1L] * average_error^2,
      n_centered_variance = n[1L] * mean(centered^2),
      bias_fraction_mse = average_error^2 / mean(squared), empirical_sd = empirical_sd,
      mean_se = mean(se), sqrt_mean_estimated_variance = sqrt(mean(se^2)),
      variance_ratio = mean(se^2) / empirical_sd^2,
      variance_ratio_mc_lower = vr[1L], variance_ratio_mc_upper = vr[2L],
      sqrt_variance_ratio = sqrt(mean(se^2)) / empirical_sd,
      bias_in_empirical_sd = average_error / empirical_sd,
      actual_coverage = mean(actual), remove_mean_bias_coverage = mean(remove_bias),
      empirical_sd_coverage = mean(empirical_width),
      remove_mean_bias_empirical_sd_coverage = mean(remove_bias_empirical_width),
      empirical_sd_coverage_mc_lower = mc_width_coverage_interval[1L],
      empirical_sd_coverage_mc_upper = mc_width_coverage_interval[2L],
      remove_mean_bias_empirical_sd_coverage_mc_lower = centered_mc_width_coverage_interval[1L],
      remove_mean_bias_empirical_sd_coverage_mc_upper = centered_mc_width_coverage_interval[2L],
      se_rescaling_factor = se_scale, rescaled_own_se_coverage = mean(rescaled_se),
      remove_mean_bias_rescaled_own_se_coverage = mean(remove_bias_rescaled_se),
      remove_bias_change_mc_lower = cb[1L], remove_bias_change_mc_upper = cb[2L],
      empirical_sd_change_mc_lower = cw[1L], empirical_sd_change_mc_upper = cw[2L],
      both_change_mc_lower = cc[1L], both_change_mc_upper = cc[2L],
      rescaled_se_change_mc_lower = cr[1L], rescaled_se_change_mc_upper = cr[2L],
      bias_rescaled_se_change_mc_lower = ccr[1L], bias_rescaled_se_change_mc_upper = ccr[2L],
      remove_bias_newly_covered = sum(!actual & remove_bias),
      remove_bias_newly_missed = sum(actual & !remove_bias),
      empirical_sd_newly_covered = sum(!actual & empirical_width),
      empirical_sd_newly_missed = sum(actual & !empirical_width),
      intervals_below_truth = sum(upper < truth), intervals_above_truth = sum(lower > truth),
      mean_error_over_se = mean(error / se), sd_error_over_se = sd(error / se),
      sd_centered_error_over_se = sd(centered / se),
      error_over_se_q025 = q[1L], error_over_se_median = q[2L], error_over_se_q975 = q[3L],
      largest_error_share_mse = max(squared) / sum(squared),
      largest_five_errors_share_mse = sum(sort(squared, decreasing = TRUE)[seq_len(min(5L, .N))]) / sum(squared),
      bootstrap_draws = bootstrap_draws)
  }, by = keys]
  stopifnot(max(abs(a$n_mse - a$n_squared_bias - a$n_centered_variance)) < 1e-9)
  base <- fread(file.path(outdir, "summary.csv"))
  comparison <- merge(base[, c(keys, "rmse", "root_n_bias"), with = FALSE], a,
    by = keys, suffixes = c("_original", "_new"))
  stopifnot(max(abs(comparison$n_mse - comparison$n * comparison$rmse^2)) < 1e-9,
    max(abs(comparison$root_n_bias_original - comparison$root_n_bias_new)) < 1e-9)
  for (field in intersect(names(base), setdiff(names(a), c(keys, "returned", "bias", "empirical_sd", "mean_se", "root_n_bias", "root_n_bias_mcse")))) {
    base[, (field) := NULL]
  }
  add <- a[, setdiff(names(a), c("returned", "bias", "empirical_sd", "mean_se", "root_n_bias", "root_n_bias_mcse")), with = FALSE]
  base <- merge(base, add, by = keys, all.x = TRUE)
  fwrite(base, file.path(outdir, "summary.csv"))
  fwrite(a, file.path(outdir, "bias-variance-assessment.csv"))
  table <- function(dt) {
    dt <- as.data.frame(dt)
    c(paste0("| ", paste(names(dt), collapse = " | "), " |"),
      paste0("| ", paste(rep("---", ncol(dt)), collapse = " | "), " |"),
      apply(dt, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |")), "")
  }
  labels <- c(binary_longitudinal = "Binary treatment", discrete_dose = "Numerical dose")
  lines <- c("## Scaled bias, MSE and confidence-interval coverage", "",
    "These calculations use the same saved completed datasets as the preceding report. They do not refit nuisances, change penalties or alter the estimators. Failed fits remain excluded from error moments and included in the separate failure table. Partial completion and the number of successful fits limit the conclusions.", "",
    "Bias is the average estimate minus the true parameter. MSE is the average squared error. The scaled quantities are square root n times bias and n times MSE. MCSE denotes the standard error due to the finite number of simulation replications. The MSE is decomposed exactly into squared bias and the average squared centered error; this centered variance uses the number of returned fits as its divisor. The empirical SD and variance-calibration ratio use the usual sample-variance divisor, one less than that number.", "",
    "The variance-calibration ratio is the average reported SE squared divided by the variance of estimates across replications. A ratio below one indicates smaller estimated variance than the observed empirical variance. Comparing the mean SE alone can be misleading when a few datasets have very large SEs; the square root of the average SE squared is the matching comparison.", "")
  for (h in 2:1) {
    b <- a[horizon == h][order(mechanism, n, estimator)]
    lines <- c(lines, sprintf("### Outcome at time %d", h + 1L), "",
      table(b[, .(Treatment = labels[mechanism], n, Estimator = toupper(estimator), Returned = returned,
        `√n × bias` = sprintf("%.3f", root_n_bias), BiasMCSE = sprintf("%.3f", root_n_bias_mcse),
        `n × MSE` = sprintf("%.3f", n_mse), MSEMCSE = sprintf("%.3f", n_mse_mcse),
        `n × bias²` = sprintf("%.3f", n_squared_bias), `n × centered variance` = sprintf("%.3f", n_centered_variance),
        VarianceRatio = sprintf("%.3f", variance_ratio))]))
  }
  lines <- c(lines, "### Separate calculations for bias and interval width", "",
    "The following are descriptive calculations on the saved estimates, not new estimators or usable corrected intervals. Subtract mean bias means shifting every estimate by the across-replication mean error, retaining its own SE. Rescale own SE means multiplying each SE by empirical SD divided by the square root of the average SE squared: average variance is matched while each dataset's relative interval width is preserved. Use empirical SD replaces every SE by the same empirical SD. The final two columns combine bias subtraction with these width calculations. Bias and SD are estimated from these same completed replications, so these calculations assess possible explanations for coverage rather than establish a causal attribution or a validated interval correction.", "",
    sprintf("The CSV also reports 95%% bootstrap intervals for changes in coverage, variance ratios and scaled errors. This means resampling completed replications with replacement %d times and repeating the calculations, including re-estimating bias and SD each time. Estimate and SE remain paired from the same dataset. Standardized errors mean estimate minus truth divided by that dataset's reported SE; their spread and quantiles are recorded. Tail misses and the fractions of MSE contributed by the largest errors are retained. No outlier is removed.", bootstrap_draws), "")
  b <- a[horizon == 2L][order(mechanism, n, estimator)]
  lines <- c(lines, table(b[, .(Treatment = labels[mechanism], n, Estimator = toupper(estimator),
    Actual = sprintf("%.1f%%", 100 * actual_coverage),
    SubtractMeanBias = sprintf("%.1f%%", 100 * remove_mean_bias_coverage),
    RescaleOwnSE = sprintf("%.1f%%", 100 * rescaled_own_se_coverage),
    UseEmpiricalSD = sprintf("%.1f%%", 100 * empirical_sd_coverage),
    BiasAndRescaledSE = sprintf("%.1f%%", 100 * remove_mean_bias_rescaled_own_se_coverage),
    BothChanges = sprintf("%.1f%%", 100 * remove_mean_bias_empirical_sd_coverage))]), "",
    "### Assessment of the current numerical-dose results", "")
  for (size in c(500L, 1000L, 4000L, 10000L)) {
    b <- a[mechanism == "discrete_dose" & horizon == 2L & n == size][order(estimator)]
    if (nrow(b) != 2L) next
    pair <- function(field, scale = 1, digits = 1L) paste(sprintf(paste0("%.", digits, "f"), scale * b[[field]]), collapse = "/")
    lines <- c(lines, sprintf("- n=%s, SDR/TMLE: observed coverage %s%%; subtracting mean bias gives %s%%; empirical-SD widths give %s%%. Estimated/empirical variance ratios are %s. The estimated mean bias contributes %s%% of MSE.",
      format(size, big.mark = ","), pair("actual_coverage", 100), pair("remove_mean_bias_coverage", 100),
      pair("empirical_sd_coverage", 100), pair("variance_ratio", 1, 3L), pair("bias_fraction_mse", 100)))
    bias_change <- mean(b$remove_mean_bias_coverage - b$actual_coverage)
    width_change <- mean(b$empirical_sd_coverage - b$actual_coverage)
    interpretation <- if (bias_change > max(0, width_change))
      "Subtracting mean bias produces the larger coverage improvement in this snapshot." else if (width_change > max(0, bias_change))
      "Changing interval widths produces the larger coverage improvement in this snapshot." else if (max(bias_change, width_change) > 0)
      "The two calculations produce similar coverage improvements in this snapshot." else
      "Neither calculation improves aggregate coverage in this snapshot."
    calibration <- if (all(b$variance_ratio < 1)) "Reported variances are smaller than empirical variance." else if (all(b$variance_ratio > 1))
      "Reported variances are larger than empirical variance." else "Variance-calibration directions differ between the estimators."
    lines <- c(lines, paste(" ", interpretation, calibration))
  }
  lines <- c(lines, "",
    "The explanation can change with sample size. The mean-bias calculation and the two interval-width calculations assess different features of the error distribution; their changes in coverage need not add up. Subtracting mean bias does not remove dataset-dependent nuisance errors; their variation can increase empirical variance. Nonzero bias, variation in fitted nuisance functions, nonnormal tails, and dependence between errors and reported SEs can all contribute. A variance-calibration discrepancy does not by itself identify a bug in the variance formula.", "")
  b <- a[mechanism == "discrete_dose" & horizon == 2L & n == 10000L][order(estimator)]
  for (i in seq_len(nrow(b))) lines <- c(lines, sprintf("- n=10,000 %s: estimated/empirical variance ratio %.3f, with 95%% simulation interval [%.3f, %.3f]; replacing SEs by the empirical SD changes coverage by %.1f percentage points, with interval [%.1f, %.1f]. %s",
    toupper(b$estimator[i]), b$variance_ratio[i], b$variance_ratio_mc_lower[i], b$variance_ratio_mc_upper[i],
    100 * (b$empirical_sd_coverage[i] - b$actual_coverage[i]), 100*b$empirical_sd_change_mc_lower[i], 100*b$empirical_sd_change_mc_upper[i],
    if (b$variance_ratio_mc_lower[i] <= 1 && b$variance_ratio_mc_upper[i] >= 1 &&
        b$empirical_sd_change_mc_lower[i] <= 0 && b$empirical_sd_change_mc_upper[i] >= 0)
      "Both intervals include no discrepancy or no improvement, so the point estimates are suggestive rather than conclusive." else
      "Assess this result together with the completed replication count and the other coverage calculations."))
  lines <- c(lines, "",
    "Binary-treatment MSE can be strongly affected by a few large errors. The table retains them, and the CSV reports their contribution rather than silently trimming them. These partial results do not establish asymptotic convergence: square root n times bias need not be zero at these sample sizes, and n times MSE can fluctuate because of rare large errors.", "",
    "Both figures show the final outcome at time t=3. Scaled-MSE plots use a logarithmic vertical axis so rare large binary-treatment errors do not hide the other sample sizes. Bars show the bootstrap simulation intervals, not causal-parameter confidence intervals.", "",
    "![Scaled bias and MSE](figures/scaled-bias-mse.png)",
    "![Variance calibration and coverage calculations](figures/bias-variance-coverage.png)", "",
    "[All scaled errors, variance ratios, bootstrap intervals and tail diagnostics](bias-variance-assessment.csv).")
  directory <- file.path(outdir, "figures"); dir.create(directory, showWarnings = FALSE)
  begin <- function(name, width = 2100L, height = 1500L) {
    png(file.path(directory, paste0(name, ".png")), width = width, height = height, res = 170,
      type = if (Sys.info()[["sysname"]] == "Darwin") "quartz" else "cairo")
    par(mar = c(4.8, 4.5, 3, 1), mgp = c(2.7, .8, 0))
  }
  colors <- c(sdr = "#2166AC", tmle = "#D55E00")
  begin("scaled-bias-mse"); par(mfrow = c(2, 2))
  for (name in names(labels)) for (field in c("root_n_bias", "n_mse")) {
    b <- a[mechanism == name & horizon == 2L]
    limits <- if (field == "root_n_bias") range(b$root_n_bias_mc_lower, b$root_n_bias_mc_upper, 0) else range(b$n_mse_mc_lower, b$n_mse_mc_upper)
    plot(NA, xlim = log10(range(b$n)), ylim = limits, log = if (field == "n_mse") "y" else "", xaxt = "n", xlab = "Sample size",
      ylab = if (field == "root_n_bias") "Square root n times bias" else "n times MSE", main = labels[[name]])
    axis(1, log10(sort(unique(b$n))), format(sort(unique(b$n)), big.mark = ","))
    if (field == "root_n_bias") abline(h = 0, lty = 2, col = "grey60")
    for (method in names(colors)) {
      d <- b[estimator == method][order(n)]
      lines(log10(d$n), d[[field]], type = "b", pch = if (method == "sdr") 16 else 17, col = colors[[method]])
      arrows(log10(d$n), d[[paste0(field, "_mc_lower")]], log10(d$n),
        d[[paste0(field, "_mc_upper")]], angle = 90, code = 3, length = .04, col = colors[[method]])
    }
    legend("topright", toupper(names(colors)), col = colors, lty = 1, pch = c(16,17), bty = "n")
  }
  dev.off()
  begin("bias-variance-coverage", 2250L, 1400L); par(mfrow = c(2, 3))
  fields <- c("actual_coverage", "remove_mean_bias_coverage", "rescaled_own_se_coverage", "empirical_sd_coverage")
  cc <- c("#333333", "#0072B2", "#009E73", "#D55E00")
  for (method in names(colors)) {
    b <- a[mechanism == "discrete_dose" & horizon == 2L & estimator == method][order(n)]
    plot(log10(b$n), b$variance_ratio, type = "b", ylim = range(b$variance_ratio_mc_lower, b$variance_ratio_mc_upper, 1), xaxt = "n", xlab = "Sample size",
      ylab = "Mean estimated variance / empirical variance", main = paste(toupper(method), "variance"))
    axis(1, log10(b$n), format(b$n, big.mark = ",")); abline(h = 1, lty = 2, col = "grey50")
    arrows(log10(b$n), b$variance_ratio_mc_lower, log10(b$n), b$variance_ratio_mc_upper,
      angle = 90, code = 3, length = .04)
    for (j in 1:2) {
      d <- if (j == 1L) b[n <= 1000L] else b[n >= 4000L]
      plot(NA, xlim = range(log10(d$n)) + c(-.04,.04), ylim = c(.75, 1), xaxt = "n", xlab = "Sample size",
        ylab = "Fraction of intervals containing truth", main = paste(toupper(method), "coverage"))
      axis(1, log10(d$n), format(d$n, big.mark = ",")); abline(h = .95, lty = 2, col = "grey60")
      for (k in seq_along(fields)) lines(log10(d$n), d[[fields[k]]], type = "b", col = cc[k], pch = k + 14L)
      if (j == 2L) legend("bottomleft", c("Actual", "Subtract mean bias", "Rescale own SE", "Empirical SD"), col = cc, lty = 1, pch = 15:18, bty = "n", cex = .72)
    }
  }
  dev.off()
  report <- file.path(outdir, "REPORT.md")
  original <- paste(readLines(report), collapse = "\n")
  marker <- "## Scaled bias, MSE and confidence-interval coverage"
  if (grepl(marker, original, fixed = TRUE)) original <- strsplit(original, marker, fixed = TRUE)[[1L]][1L]
  writeLines(c(trimws(original), "", lines), report)
  completed_file <- file.path(outdir, "job_log.csv")
  checkpoint_count <- if (file.exists(completed_file)) nrow(fread(completed_file)) else NA_integer_
  writeLines(c("# Scaled errors and variance assessment", "",
    sprintf("Companion analysis of %d completed dataset checkpoints. Each table states the number of returned estimators. The full study plans 4,000 datasets; incomplete counts are preliminary.", checkpoint_count), "",
    lines[-1L]), file.path(outdir, "BIAS-VARIANCE.md"))
  jsonlite::write_json(list(
    estimates_sha256 = digest::digest(file = file.path(outdir, "replicates.csv"), algo = "sha256"),
    analysis_source_sha256 = digest::digest(file = "studies/longitudinal/github-500/bias_variance.R", algo = "sha256"),
    bootstrap_seed = 708614L, bootstrap_draws = bootstrap_draws, completed_checkpoints = checkpoint_count,
    fitting_changes = FALSE), file.path(outdir, "bias-variance-provenance.json"), pretty = TRUE, auto_unbox = TRUE)
  invisible(a)
}

if (sys.nframe() == 0L) augment_bias_variance_report(Sys.getenv("SIM_OUTPUT", "work/report"))
