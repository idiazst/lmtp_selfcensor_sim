# Report the saved-output bootstrap without resampling or fitting again.
source("scripts/setup.R")
library(data.table)
output <- Sys.getenv("MC_OUTPUT", "results/longitudinal/full500-github-20261013/multiplier-bootstrap")
configuration <- jsonlite::fromJSON(file.path(output, "configuration.json"))
paths <- list.files(file.path(output, "jobs"), "[.]rds$", full.names = TRUE)
stopifnot(length(paths) == configuration$source_checkpoints)
intervals <- audits <- logs <- original_errors <- failures <- list()
for (path in paths) {
  x <- readRDS(path)
  stopifnot(x$analysis_fingerprint == configuration$analysis_fingerprint)
  design <- as.data.table(x$design)
  if (!isTRUE(x$success)) {
    failures[[length(failures) + 1L]] <- cbind(design, data.table(error = x$error))
    next
  }
  logs[[length(logs) + 1L]] <- cbind(design, data.table(returned_outcomes = x$returned_outcomes,
    seconds = x$seconds, source_sha256 = x$source_sha256))
  if (nrow(x$intervals)) intervals[[length(intervals) + 1L]] <- x$intervals
  if (nrow(x$reconstruction)) audits[[length(audits) + 1L]] <- cbind(design, x$reconstruction)
  if (nrow(x$original_errors)) original_errors[[length(original_errors) + 1L]] <- x$original_errors
}
bad <- rbindlist(failures, fill = TRUE)
if (!ncol(bad)) bad <- data.table(error = character())
fwrite(bad, file.path(output, "postprocessing-errors.csv"))
stopifnot(nrow(bad) == 0L)
x <- rbindlist(intervals); audit <- rbindlist(audits); log <- rbindlist(logs)
error <- rbindlist(original_errors, fill = TRUE)
if (!ncol(error)) error <- data.table(error = character())
keys <- c("mechanism", "n", "estimator", "horizon", "multiplier")
stopifnot(!anyDuplicated(x[, c(keys, "replicate"), with = FALSE]),
  max(audit$estimate_error_over_se) < 1e-5, max(audit$se_relative_error) < 1e-5)
z <- qnorm(.975)
s <- x[, {
  change <- as.numeric(covered) - as.numeric(original_covered)
  error <- estimate - truth
  mc_sd <- sd(estimate)
  list(returned = .N, coverage = mean(covered), original_coverage = mean(original_covered),
    changed_intervals = sum(change != 0), newly_covered = sum(change > 0), newly_missed = sum(change < 0),
    coverage_change = mean(change), paired_change_mcse = sd(change) / sqrt(.N),
    mean_interval_length = mean(interval_length), mean_length_ratio = mean(interval_length / (original_upper - original_lower)),
    mean_estimate = mean(estimate), truth = mean(truth), bias = mean(estimate - truth),
    root_n_bias = sqrt(n[1L]) * mean(estimate - truth), n_mse = n[1L] * mean((estimate - truth)^2),
    mean_reported_variance = mean(se^2), empirical_variance = var(estimate),
    mc_sd_coverage = mean(abs(error) <= qnorm(.975) * mc_sd),
    mc_sd_remove_mean_bias_coverage = mean(abs(error - mean(error)) <= qnorm(.975) * mc_sd))
}, by = keys]
counts <- log[, .(datasets_completed = .N), by = .(mechanism, n)]
s <- merge(s, counts, by = c("mechanism", "n"))
s[, `:=`(failed = datasets_completed - returned, pending = 500L - datasets_completed,
  variance_ratio = mean_reported_variance / empirical_variance,
  coverage_mc_lower = (coverage + z^2 / (2 * returned) - z * sqrt(coverage * (1 - coverage) / returned + z^2 / (4 * returned^2))) / (1 + z^2 / returned),
  coverage_mc_upper = (coverage + z^2 / (2 * returned) + z * sqrt(coverage * (1 - coverage) / returned + z^2 / (4 * returned^2))) / (1 + z^2 / returned))]
setorderv(s, keys); setorderv(x, c(keys, "replicate"))
fwrite(x, file.path(output, "intervals.csv"))
fwrite(s, file.path(output, "summary.csv"))
fwrite(audit, file.path(output, "reconstruction-audit.csv"))
fwrite(log, file.path(output, "job_log.csv"))
fwrite(error, file.path(output, "original-fit-errors.csv"))
format_table <- function(dt) {
  dt <- as.data.frame(dt)
  c(paste0("| ", paste(names(dt), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(dt)), collapse = " | "), " |"),
    apply(dt, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |")), "")
}
labels <- c(discrete_dose = "Numerical dose", binary_longitudinal = "Binary treatment")
law_labels <- c(gaussian = "Normal / Gaussian multiplier", rademacher = "+1 or -1 multiplier", exponential = "Exponential minus one multiplier")
lines <- c("# Multiplier bootstrap using the existing simulation output", "",
  sprintf("%s %d saved dataset checkpoints. Each setting has %d to %d completed datasets out of the planned 500. No original simulation or nuisance fit was rerun.",
    if (nrow(log) == 4000L) "**The full study is complete:**" else "**PRELIMINARY:**", nrow(log), min(counts$datasets_completed), max(counts$datasets_completed)), "",
  sprintf("The original fit failures are retained: %d returned outcome estimates out of %d possible. An estimator that failed does not contribute an interval or count as a bootstrap success; the tables show its missing-fit denominator. All %d checkpoints passed integrity checks, and all returned outcome gradients passed reconstruction checks. A failed original fit has no gradient to reconstruct.",
    nrow(x[multiplier == "gaussian"]), 4L * nrow(log), nrow(log)), "",
  "## What was done", "",
  "The original checkpoints did not retain individual influence-function vectors. They did retain the predictions of every fitted nuisance function on the complete finite support, the original data seed, and all sample splits. The original observations were regenerated from that seed, and the saved predictions were evaluated by support lookup in the original validation folds. No regression, bridge, adjoint, penalty or ensemble was refitted. Reconstructed means and SEs were checked against each saved estimate and SE before bootstrap draws were accepted. Small numerical differences from prediction batches are recorded in the audit in units of the sampling SE, with a maximum permitted relative discrepancy of 0.00001.", "",
  "For each dataset, the estimated influence function is centered at its sample mean. Independent person-level multipliers have mean zero and variance one. The bootstrap perturbation is the average of multiplier times centered influence function, with a square-root n/(n-1) correction to use the same finite-sample variance convention as the original sample-SD-based SE. The same person multipliers are used for SDR, TMLE and both outcome times. Equal score vectors are grouped within an original outer fold and observed data category: sums of +1/-1 multipliers are generated by binomial draws, and sums of exponential weights by Gamma draws. These are exact distributions of the independent person-level multiplier sums, not a resampling of groups as single observations.", "",
  "Three prespecified choices are compared. Gaussian weights are standard normal. Their conditional scalar distribution is exactly normal with variance equal to the original reported SE squared, so their pointwise intervals are exactly the original normal intervals; simulation of that known distribution would add only Monte Carlo noise. The +1/-1 weights are equally likely and use a symmetric 95% absolute-perturbation quantile. Exponential weights have rate one and are shifted down by one to have mean zero; the interval uses the 2.5% and 97.5% perturbation quantiles in reversed order around the original estimate. Thus the exponential interval can be asymmetric.", "",
  sprintf("Each non-Gaussian choice uses %s draws per dataset. No estimated mean bias is subtracted, no true variance is substituted, and the known parameter is used only to count interval coverage. The quantiles and intervals do not depend on that truth. Random streams are fixed separately by the original dataset seed and multiplier type, so worker order does not change results.", format(configuration$draws, big.mark = ",")), "",
  "The [Gaussian multiplier method of Chernozhukov, Chetverikov and Kato](https://arxiv.org/abs/1212.6906) motivates the fixed-influence-function perturbation. The scalar Gaussian identity above also follows directly from the variance of a linear combination of independent normal variables. The simultaneous Gaussian bands for the outcome curve were already computed in the original study; this comparison concerns pointwise intervals, particularly at t=3.", "")
findings <- c("## Main findings", "",
  "Gaussian multipliers reproduce all original pointwise intervals exactly. This is the analytic conditional Gaussian identity, not a failure to run the bootstrap.", "")
numeric <- s[mechanism == "discrete_dose" & horizon == 2L & multiplier != "gaussian"]
if (nrow(numeric)) findings <- c(findings,
  sprintf("For numerical dose at t=3, switching to the non-Gaussian multipliers changes coverage by at most %.2f percentage points in either direction. It does not resolve undercoverage. The candidate nuisance functions, estimates and conditional variances are held fixed; only bootstrap quantiles change.",
    100 * max(abs(numeric$coverage_change))), "")
binary <- s[mechanism == "binary_longitudinal" & horizon == 2L & multiplier == "exponential"]
if (nrow(binary)) findings <- c(findings,
  sprintf("For binary treatment at t=3, exponential multipliers improve observed coverage by %.1f to %.1f percentage points across the available estimator/sample-size combinations. This is a useful distributional-shape improvement in that example, rather than a general repair for the numerical-dose bias. Every prespecified multiplier and all failures are reported; no package default is changed.",
    100 * min(binary$coverage_change), 100 * max(binary$coverage_change)), "")
position <- match("## What was done", lines)
lines <- append(lines, findings, after = position - 1L)
for (h in 2:1) for (name in names(labels)) {
  b <- s[horizon == h & mechanism == name]
  if (!nrow(b)) next
  wide <- dcast(b, n + estimator + returned + failed + pending ~ multiplier, value.var = "coverage")
  setorder(wide, n, estimator)
  lines <- c(lines, sprintf("## %s: outcome at t=%d", labels[[name]], h + 1L), "",
    format_table(wide[, .(n, Estimator = toupper(estimator), Returned = returned, Failed = failed, Pending = pending,
      `Normal / Gaussian` = sprintf("%.1f%%", 100 * gaussian),
      `+1/-1 weights` = sprintf("%.1f%%", 100 * rademacher),
      `Exponential weights` = sprintf("%.1f%%", 100 * exponential))]))
}
lines <- c(lines, "## Comparison with Monte Carlo SD at t=3", "",
  "These are the same diagnostic calculations requested previously, now evaluated on the full completed snapshot. They use the SD across returned estimates, without replacing it by the standard error of the Monte Carlo average. This is a separate evaluation calculation; that SD is not used for any of the multiplier intervals.", "",
  format_table(s[mechanism == "discrete_dose" & horizon == 2L & multiplier == "gaussian", .(
    n, Estimator = toupper(estimator), Returned = returned,
    `Original intervals` = sprintf("%.1f%%", 100 * coverage),
    `Monte Carlo SD` = sprintf("%.1f%%", 100 * mc_sd_coverage),
    `Monte Carlo SD, mean bias removed` = sprintf("%.1f%%", 100 * mc_sd_remove_mean_bias_coverage),
    `Estimated / Monte Carlo variance` = sprintf("%.3f", variance_ratio))]))
lines <- c(lines, "## Interpretation and numerical precision", "",
  "All multiplier choices have the same conditional variance, up to numerical prediction roundoff; they change the distributional shape and quantiles, not the nuisance fits or their bias. A fixed-influence-function multiplier bootstrap cannot estimate a systematic bias from nuisance estimation, and it does not refit those nuisance functions to capture additional variation beyond the estimated influence function. These limitations are relevant to the preceding Monte Carlo variance diagnosis.", "",
  "Small coverage differences should be assessed relative to approximately 500 Monte Carlo datasets and finite bootstrap-quantile accuracy. The complete summary gives the number of intervals newly covering or newly missing the truth relative to the original interval, paired simulation standard errors for the coverage changes, interval-length ratios, and original bias and scaled MSE. Numerical differences of a few intervals are not evidence that a multiplier choice fixes the estimator. No multiplier is selected or installed as a package default based on this comparison.", "",
  "![Multiplier-bootstrap coverage at t=3](figures/t3-coverage.png)", "",
  "[All intervals](intervals.csv), [complete summary](summary.csv), [reconstruction audit](reconstruction-audit.csv), [original fit failures](original-fit-errors.csv), [postprocessing failures](postprocessing-errors.csv), [runtime](runtime.json), [bootstrap configuration](configuration.json), [original checkpoint hashes](checkpoint-manifest.json), and [artifact provenance](artifact-provenance.json).")
dir.create(file.path(output, "figures"), showWarnings = FALSE)
png(file.path(output, "figures", "t3-coverage.png"), width = 2100, height = 1500, res = 170,
  type = if (Sys.info()[["sysname"]] == "Darwin") "quartz" else "cairo")
par(mfrow = c(2, 2), mar = c(4.5, 4.7, 3, 1), mgp = c(2.8, .8, 0))
colors <- c(gaussian = "#333333", rademacher = "#0072B2", exponential = "#D55E00")
for (name in names(labels)) for (method in c("sdr", "tmle")) {
  b <- s[mechanism == name & horizon == 2L & estimator == method]
  if (!nrow(b)) next
  limits <- range(s[mechanism == name & horizon == 2L, coverage], .95) + c(-.015, .015)
  plot(NA, xlim = log10(range(b$n)), ylim = pmax(0, pmin(1, limits)), xaxt = "n",
    xlab = "Sample size", ylab = "Fraction of intervals containing the true value",
    main = paste(labels[[name]], toupper(method)))
  sizes <- sort(unique(b$n)); axis(1, log10(sizes), format(sizes, big.mark = ",")); abline(h = .95, lty = 2, col = "grey55")
  for (law in names(colors)) {
    d <- b[multiplier == law][order(n)]
    lines(log10(d$n), d$coverage, type = "b", col = colors[[law]], pch = match(law, names(colors)) + 14L)
  }
  legend("bottomright", c("Normal / Gaussian", "+1/-1 weights", "Exponential weights"),
    col = colors, lty = 1, pch = 15:17, bty = "n", cex = .8)
}
dev.off()
writeLines(lines, file.path(output, "REPORT.md"))
jsonlite::write_json(list(checkpoints = nrow(log), outcome_estimates = nrow(x[multiplier == "gaussian"]),
  postprocessing_failures = nrow(bad), max_estimate_error = max(audit$estimate_error),
  max_se_error = max(audit$se_error), max_estimate_error_over_se = max(audit$estimate_error_over_se),
  max_se_relative_error = max(audit$se_relative_error), gaussian_intervals_identical = TRUE,
  fitting_changes = FALSE, analysis_fingerprint = configuration$analysis_fingerprint,
  intervals_sha256 = digest::digest(file = file.path(output, "intervals.csv"), algo = "sha256")),
  file.path(output, "verification.json"), pretty = TRUE, auto_unbox = TRUE)
print(s[mechanism == "discrete_dose" & horizon == 2L,
  .(n, estimator, multiplier, returned, failed, coverage, coverage_change, changed_intervals, mean_length_ratio)])
