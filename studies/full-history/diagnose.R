# Read-only inference audit: no fitting, replacement seeds or interval changes.
args <- commandArgs(TRUE)
root <- if (length(args)) args[1] else "work/full-history"
rows <- read.csv(file.path(root, "estimates.csv"), stringsAsFactors = FALSE)
required <- c("mechanism", "n", "method", "horizon", "estimate", "truth",
              "std.error", "conf.low", "conf.high")
stopifnot(all(required %in% names(rows)))
paths <- list.files(root, "[.]rds$", recursive = TRUE, full.names = TRUE)
paths <- paths[grepl("/jobs/", paths)]
records <- lapply(paths, readRDS)
specifications <- lapply(records, function(record) {
  record$manifest[setdiff(names(record$manifest), c("run", "commit"))]
})
if (length(specifications) &&
    any(!vapply(specifications, identical, TRUE, specifications[[1]]))) {
  stop("Inference audit requires one frozen fitting specification.")
}

wilson_interval <- function(successes, total) {
  if (!total) return(c(NA_real_, NA_real_))
  z <- qnorm(.975)
  p <- successes / total
  center <- (p + z^2 / (2 * total)) / (1 + z^2 / total)
  radius <- z * sqrt(p * (1 - p) / total + z^2 / (4 * total^2)) /
    (1 + z^2 / total)
  c(max(0, center - radius), min(1, center + radius))
}

groups <- split(rows, with(rows, interaction(mechanism, n, method, horizon,
                                             drop = TRUE)))
audit <- do.call(rbind, lapply(groups, function(group) {
  valid <- is.finite(group$estimate) & is.finite(group$std.error) &
    group$std.error >= 0 & is.finite(group$conf.low) &
    is.finite(group$conf.high) & group$conf.low <= group$conf.high
  good <- group[valid, ]
  count <- nrow(good)
  errors <- good$estimate - good$truth
  covered <- good$conf.low <= good$truth & good$conf.high >= good$truth
  coverage <- if (count) mean(covered) else NA_real_
  interval <- wilson_interval(sum(covered), count)
  empirical_sd <- if (count > 1) sd(errors) else NA_real_
  rms_se <- if (count) sqrt(mean(good$std.error^2)) else NA_real_
  standardized <- errors[good$std.error > 0] / good$std.error[good$std.error > 0]
  data.frame(
    mechanism = group$mechanism[1], n = group$n[1],
    method = group$method[1], horizon = group$horizon[1],
    attempted = nrow(group), returned = count, failed = sum(!valid),
    bias = if (count) mean(errors) else NA_real_,
    bias_mcse = empirical_sd / sqrt(count), empirical_sd = empirical_sd,
    rms_se = rms_se, rms_se_over_sd = rms_se / empirical_sd,
    coverage = coverage,
    coverage_mcse = if (count) sqrt(coverage * (1 - coverage) / count) else NA_real_,
    coverage_mc_low = interval[1], coverage_mc_high = interval[2],
    interval_below_truth = if (count) mean(good$conf.high < good$truth) else NA_real_,
    interval_above_truth = if (count) mean(good$conf.low > good$truth) else NA_real_,
    standardized_mean = if (length(standardized)) mean(standardized) else NA_real_,
    standardized_sd = if (length(standardized) > 1) sd(standardized) else NA_real_
  )
}))
rownames(audit) <- NULL
write.csv(audit, file.path(root, "inference-diagnostics.csv"), row.names = FALSE)

components <- do.call(rbind, lapply(records, function(record) {
  do.call(rbind, lapply(names(record$details), function(method) {
    detail <- record$details[[method]]
    result <- record$results[[method]]
    if (is.null(detail) || is.null(result)) return(NULL)
    result <- result[order(result$horizon), ]
    reconstructed <- detail$sequential_variance + detail$bridge_variance +
      2 * detail$cross_covariance
    reported <- record$n * result$std.error^2
    data.frame(
      mechanism = record$mechanism, n = record$n,
      replicate = record$replicate, method = method, horizon = result$horizon,
      sequential_variance = detail$sequential_variance,
      bridge_variance = detail$bridge_variance,
      twice_cross_covariance = 2 * detail$cross_covariance,
      reconstructed_gradient_variance = reconstructed,
      reported_gradient_variance = reported,
      relative_difference = abs(reported - reconstructed) /
        pmax(1, abs(reported), abs(reconstructed))
    )
  }))
}))
if (!is.null(components)) {
  write.csv(components, file.path(root, "score-variance.csv"), row.names = FALSE)
}

label <- if (length(records)) records[[1]]$manifest$specification else NULL
if (is.null(label) && length(records)) {
  sl <- records[[1]]$manifest$sl
  label <- if (identical(sl, "SL.saturated_l1")) "sieve-diagnostic" else
    if ("SL.saturated_l1_cv" %in% sl) "ensemble" else "saved specification"
}
lines <- c(
  "# Full-history inference diagnostics", "",
  paste("Specification:", if (is.null(label)) "see original report" else label), "",
  "Bias MCSE is empirical SD divided by the square root of returned replications.",
  "RMS SE is sqrt(mean(reported SE squared)); its ratio to empirical SD compares variances.",
  "Coverage MC limits are pointwise 95% Wilson intervals over returned replications.",
  "They describe simulation uncertainty and do not change any estimator interval.",
  "Cells share datasets across horizons and methods; these are not simultaneous tests.",
  "Failure counts are retained. Coverage describes the returned estimates only.", "",
  if (!is.null(components)) sprintf(
    "Largest relative difference between n * SE^2 and Var(sequential + bridge correction): %.3g.",
    max(components$relative_difference)) else
    "No saved score components available for the variance identity check.", "",
  paste(capture.output(print(audit, digits = 4, row.names = FALSE)), collapse = "\n"), "",
  "## Provenance", "",
  paste("Fitting run IDs:", paste(unique(vapply(records, function(record)
    as.character(record$manifest$run), "")), collapse = ", ")),
  paste("Estimates MD5:", unname(tools::md5sum(file.path(root, "estimates.csv")))),
  paste("Audit source MD5:", unname(tools::md5sum("studies/full-history/diagnose.R")))
)
writeLines(lines, file.path(root, "INFERENCE.md"))
cat(paste(lines, collapse = "\n"), "\n")
