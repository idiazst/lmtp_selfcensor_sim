# Compare two immutable fitting profiles on the diagnostic profile's planned seeds.
# Run from the repository root:
# Rscript studies/four-dose-pilot/compare_profiles.R BASELINE_ROOT DIAGNOSTIC_ROOT OUTPUT_DIR
# Different fingerprints across profiles are intentional. Each profile is validated
# independently, and paired generated data and person folds must agree exactly.
source("studies/four-dose-pilot/coverage.R")

profile_dataset_key <- function(x) paste(x$design, x$n, x$rep, sep = "/")
profile_method_key <- function(x) paste(profile_dataset_key(x), x$method, sep = "/")
profile_failed <- function(status) !status %in% c("returned", "not_started", "started_unfinished")
profile_pending <- function(status) status %in% c("not_started", "started_unfinished")
profile_mean <- function(x) if (length(x)) mean(x) else NA_real_
profile_sd <- function(x) if (length(x) > 1L) sd(x) else NA_real_
profile_cor <- function(x, y) if (length(x) > 1L && sd(x) > 0 && sd(y) > 0) cor(x, y) else NA_real_

profile_validate_configs <- function(root) {
  files <- list.files(root, pattern = "^run-config[.]json$", recursive = TRUE, full.names = TRUE)
  configs <- lapply(files, function(path) {
    x <- coverage_read_json(path)
    # Execution subsets may differ across shards; fitting settings may not.
    x[c("sizes", "replicates", "designs", "study_replicates")] <- NULL
    if (is.null(x$profile)) x$profile <- "baseline"
    x$variants <- sort(as.character(x$variants))
    x[sort(names(x))]
  })
  if (length(configs) && any(!vapply(configs, identical, logical(1), configs[[1L]])))
    stop("Conflicting fitting-profile configuration within ", root)
  invisible(if (length(configs)) configs[[1L]] else NULL)
}

profile_paired_coverage <- function(baseline, diagnostic) {
  stopifnot(length(baseline) == length(diagnostic), !anyNA(baseline), !anyNA(diagnostic))
  count <- length(baseline)
  gains <- sum(!baseline & diagnostic)
  losses <- sum(baseline & !diagnostic)
  both <- sum(baseline & diagnostic)
  neither <- sum(!baseline & !diagnostic)
  delta <- as.integer(diagnostic) - as.integer(baseline)
  difference <- profile_mean(delta)
  mc_se <- profile_sd(delta) / sqrt(count)
  baseline_ci <- coverage_wilson(sum(baseline), count)
  diagnostic_ci <- coverage_wilson(sum(diagnostic), count)
  list(count = count, baseline_covered = sum(baseline), diagnostic_covered = sum(diagnostic),
    baseline_coverage = profile_mean(baseline), diagnostic_coverage = profile_mean(diagnostic),
    baseline_mc_lower = unname(baseline_ci["lower"]), baseline_mc_upper = unname(baseline_ci["upper"]),
    diagnostic_mc_lower = unname(diagnostic_ci["lower"]), diagnostic_mc_upper = unname(diagnostic_ci["upper"]),
    coverage_difference = difference, coverage_difference_mc_se = mc_se,
    coverage_difference_mc_lower = max(-1, difference - qnorm(.975) * mc_se),
    coverage_difference_mc_upper = min(1, difference + qnorm(.975) * mc_se),
    gain = gains, loss = losses, both_cover = both, neither_cover = neither,
    mcnemar_exact_p = if (!count) NA_real_ else if (gains + losses)
      binom.test(gains, gains + losses, p = .5)$p.value else 1)
}

profile_estimate_metrics <- function(estimate, se, truth) {
  count <- length(estimate)
  error <- estimate - truth
  list(count = count, mean_estimate = profile_mean(estimate), bias = profile_mean(error),
    bias_mc_se = profile_sd(estimate) / sqrt(count), empirical_sd = profile_sd(estimate),
    mean_se = profile_mean(se), rms_se = sqrt(profile_mean(se^2)),
    rmse = sqrt(profile_mean(error^2)), mean_interval_width = 2 * qnorm(.975) * profile_mean(se))
}

compare_four_dose_profiles <- function(baseline_root, diagnostic_root, output) {
  baseline_root <- normalizePath(baseline_root, mustWork = TRUE)
  diagnostic_root <- normalizePath(diagnostic_root, mustWork = TRUE)
  baseline_config <- profile_validate_configs(baseline_root)
  diagnostic_config <- profile_validate_configs(diagnostic_root)
  baseline_design <- coverage_expected(baseline_root)
  diagnostic_design <- coverage_expected(diagnostic_root)
  matched <- match(profile_dataset_key(diagnostic_design), profile_dataset_key(baseline_design))
  if (anyNA(matched)) stop("Every diagnostic planned dataset must also appear in the baseline planned manifest.")
  if (any(diagnostic_design$seed != baseline_design$seed[matched]))
    stop("The two planned manifests specify different seeds for a paired dataset.")
  temporary <- tempfile("four-dose-profile-validation-")
  dir.create(temporary)
  on.exit(unlink(temporary, recursive = TRUE), add = TRUE)
  baseline <- four_dose_coverage(baseline_root, file.path(temporary, "baseline"))
  diagnostic <- four_dose_coverage(diagnostic_root, file.path(temporary, "diagnostic"))
  baseline_variants <- unique(baseline$statuses$variant)
  diagnostic_variants <- unique(diagnostic$statuses$variant)
  if (length(baseline_variants) != 1L || length(diagnostic_variants) != 1L)
    stop("Each input root must contain exactly one configured variant; compare one profile at a time.")
  baseline_status <- baseline$statuses[profile_dataset_key(baseline$statuses) %in%
    profile_dataset_key(diagnostic_design), ]
  diagnostic_status <- diagnostic$statuses
  by <- c("design", "n", "rep", "method")
  paired <- merge(baseline_status, diagnostic_status, by = by,
    suffixes = c("_baseline", "_diagnostic"), all = TRUE, sort = TRUE)
  if (nrow(paired) != 2L * nrow(diagnostic_design) || anyNA(paired$status_baseline) ||
      anyNA(paired$status_diagnostic)) stop("Expected exactly two method rows for every paired planned dataset.")
  paired$both_checkpoints_present <- paired$copies_baseline > 0 & paired$copies_diagnostic > 0
  paired$paired_inputs_verified <- TRUE
  for (field in c("seed", "data_hash", "fold_hash")) {
    a <- paired[[paste0(field, "_baseline")]]
    b <- paired[[paste0(field, "_diagnostic")]]
    available <- !is.na(a) & !is.na(b)
    disagree <- available & a != b
    if (any(disagree)) stop("Paired profiles disagree on ", field, " for ",
      paste(profile_method_key(paired[disagree, ]), collapse = ", "))
    paired$paired_inputs_verified <- paired$paired_inputs_verified & available
  }
  paired$baseline_failed <- profile_failed(paired$status_baseline)
  paired$diagnostic_failed <- profile_failed(paired$status_diagnostic)
  paired$baseline_pending <- profile_pending(paired$status_baseline)
  paired$diagnostic_pending <- profile_pending(paired$status_diagnostic)
  paired$common_success <- paired$status_baseline == "returned" & paired$status_diagnostic == "returned"
  if (any(paired$common_success & !paired$paired_inputs_verified))
    stop("A successful pair lacks exact data/fold provenance.")
  paired$both_attempts_complete <- !paired$baseline_pending & !paired$diagnostic_pending
  paired$pair_status <- ifelse(paired$baseline_pending & paired$diagnostic_pending, "both_pending",
    ifelse(paired$baseline_pending, "baseline_pending_only",
    ifelse(paired$diagnostic_pending, "diagnostic_pending_only",
    ifelse(paired$common_success, "both_successful",
    ifelse(paired$baseline_failed & paired$diagnostic_failed, "both_failed",
    ifelse(paired$baseline_failed, "baseline_failed_only", "diagnostic_failed_only"))))))
  estimates <- merge(paired, data.frame(time = 2:3), by = NULL)
  result_fields <- c("design", "n", "rep", "method", "time", "estimate", "std_error", "truth",
    "error", "standardized_error", "ci_lower", "ci_upper", "covered")
  b <- baseline$estimates[result_fields]
  d <- diagnostic$estimates[result_fields]
  identity <- c(by, "time")
  names(b)[!names(b) %in% identity] <- paste0(names(b)[!names(b) %in% identity], "_baseline")
  names(d)[!names(d) %in% identity] <- paste0(names(d)[!names(d) %in% identity], "_diagnostic")
  estimates <- merge(estimates, b, by = identity, all.x = TRUE, sort = TRUE)
  estimates <- merge(estimates, d, by = identity, all.x = TRUE, sort = TRUE)
  estimates$truth <- four_dose_truth(estimates$design, estimates$time)
  estimates$estimate_difference <- ifelse(estimates$common_success,
    estimates$estimate_diagnostic - estimates$estimate_baseline, NA_real_)
  estimates$se_difference <- ifelse(estimates$common_success,
    estimates$std_error_diagnostic - estimates$std_error_baseline, NA_real_)
  estimates$coverage_difference <- ifelse(estimates$common_success,
    as.integer(estimates$covered_diagnostic) - as.integer(estimates$covered_baseline), NA_integer_)
  summaries <- list()
  independent <- list()
  groups <- split(estimates, interaction(estimates$design, estimates$n, estimates$method,
    estimates$time, drop = TRUE))
  for (x in groups) {
    cell <- x[1L, c("design", "n", "method", "time")]
    common <- x[x$common_success, ]
    complete <- x[x$both_attempts_complete, ]
    complete_b <- complete$covered_baseline %in% TRUE
    complete_d <- complete$covered_diagnostic %in% TRUE
    coverage <- profile_paired_coverage(common$covered_baseline, common$covered_diagnostic)
    failaware <- profile_paired_coverage(complete_b, complete_d)
    names(failaware) <- paste0("failure_aware_", names(failaware))
    bmetrics <- profile_estimate_metrics(common$estimate_baseline, common$std_error_baseline, common$truth)
    dmetrics <- profile_estimate_metrics(common$estimate_diagnostic, common$std_error_diagnostic, common$truth)
    names(bmetrics) <- paste0("baseline_", names(bmetrics))
    names(dmetrics) <- paste0("diagnostic_", names(dmetrics))
    delta <- common$estimate_difference
    se_delta <- common$se_difference
    summaries[[length(summaries) + 1L]] <- data.frame(cell, planned = nrow(x),
      both_checkpoints_present = sum(x$both_checkpoints_present),
      paired_inputs_verified = sum(x$paired_inputs_verified), common_success = nrow(common),
      both_attempts_complete = nrow(complete),
      baseline_returned = sum(x$status_baseline == "returned"),
      diagnostic_returned = sum(x$status_diagnostic == "returned"),
      baseline_failed = sum(x$baseline_failed), diagnostic_failed = sum(x$diagnostic_failed),
      baseline_pending = sum(x$baseline_pending), diagnostic_pending = sum(x$diagnostic_pending),
      baseline_failed_only = sum(x$pair_status == "baseline_failed_only"),
      diagnostic_failed_only = sum(x$pair_status == "diagnostic_failed_only"),
      both_failed = sum(x$pair_status == "both_failed"),
      baseline_pending_only = sum(x$pair_status == "baseline_pending_only"),
      diagnostic_pending_only = sum(x$pair_status == "diagnostic_pending_only"),
      both_pending = sum(x$pair_status == "both_pending"), coverage, bmetrics, dmetrics, failaware,
      mean_estimate_difference = profile_mean(delta),
      sd_estimate_difference = profile_sd(delta),
      estimate_difference_mc_se = profile_sd(delta) / sqrt(length(delta)),
      max_abs_estimate_difference = if (length(delta)) max(abs(delta)) else NA_real_,
      estimate_correlation = profile_cor(common$estimate_baseline, common$estimate_diagnostic),
      mean_se_difference = profile_mean(se_delta), sd_se_difference = profile_sd(se_delta),
      se_difference_mc_se = profile_sd(se_delta) / sqrt(length(se_delta)),
      mean_se_ratio = profile_mean(common$std_error_diagnostic / common$std_error_baseline),
      max_abs_se_difference = if (length(se_delta)) max(abs(se_delta)) else NA_real_,
      se_correlation = profile_cor(common$std_error_baseline, common$std_error_diagnostic),
      row.names = NULL, check.names = FALSE)
    for (profile in c("baseline", "diagnostic")) {
      success <- x[[paste0("status_", profile)]] == "returned"
      values <- x[success, ]
      covered <- values[[paste0("covered_", profile)]]
      ci <- coverage_wilson(sum(covered), nrow(values))
      metrics <- profile_estimate_metrics(values[[paste0("estimate_", profile)]],
        values[[paste0("std_error_", profile)]], values$truth)
      independent[[length(independent) + 1L]] <- data.frame(cell, profile = profile,
        planned = nrow(x), failed = sum(x[[paste0(profile, "_failed")]]),
        pending = sum(x[[paste0(profile, "_pending")]]), metrics,
        coverage = profile_mean(covered), coverage_mc_lower = unname(ci["lower"]),
        coverage_mc_upper = unname(ci["upper"]), row.names = NULL)
    }
  }
  summary <- do.call(rbind, summaries)
  summary <- summary[order(summary$design, summary$n, summary$method, summary$time), ]
  independent <- do.call(rbind, independent)
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  write.csv(diagnostic_design, file.path(output, "paired-design.csv"), row.names = FALSE)
  write.csv(paired, file.path(output, "paired-method-status.csv"), row.names = FALSE)
  write.csv(paired[paired$baseline_failed | paired$diagnostic_failed, ],
    file.path(output, "paired-failures.csv"), row.names = FALSE)
  write.csv(estimates, file.path(output, "paired-estimates.csv"), row.names = FALSE)
  write.csv(summary, file.path(output, "paired-summary.csv"), row.names = FALSE)
  write.csv(independent, file.path(output, "profile-available-summary.csv"), row.names = FALSE)
  provenance <- list(generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    baseline_root = baseline_root, diagnostic_root = diagnostic_root,
    baseline_fingerprint = baseline$alert$fingerprint, diagnostic_fingerprint = diagnostic$alert$fingerprint,
    baseline_config = baseline_config, diagnostic_config = diagnostic_config,
    baseline_variant = baseline_variants, diagnostic_variant = diagnostic_variants,
    baseline_total_planned_datasets = nrow(baseline_design),
    diagnostic_planned_datasets = nrow(diagnostic_design),
    compared_planned_datasets = nrow(diagnostic_design),
    baseline_datasets_outside_comparison = nrow(baseline_design) - nrow(diagnostic_design),
    identical_input_root = identical(baseline_root, diagnostic_root))
  jsonlite::write_json(provenance, file.path(output, "paired-provenance.json"),
    pretty = TRUE, auto_unbox = TRUE, na = "null")
  fmt <- function(x, digits = 3) ifelse(is.finite(x), formatC(x, digits = digits, format = "f"), "—")
  pct <- function(x) fmt(100 * x, 1)
  ci_text <- function(est, lower, upper) paste0(pct(est), "% [", pct(lower), ", ", pct(upper), "]")
  completion <- summary[summary$time == 2L, ]
  completion_table <- c("| Design | n | Method | Common successes/planned | Baseline returned/failed/pending | Diagnostic returned/failed/pending | Both failed |",
    "|---|---:|---|---:|---:|---:|---:|",
    sprintf("| %s | %d | %s | %d/%d | %d/%d/%d | %d/%d/%d | %d |",
      completion$design, completion$n, toupper(completion$method), completion$common_success,
      completion$planned, completion$baseline_returned, completion$baseline_failed,
      completion$baseline_pending, completion$diagnostic_returned, completion$diagnostic_failed,
      completion$diagnostic_pending, completion$both_failed))
  performance_table <- c("| Design | n | Method | Time | Bias baseline / diagnostic | SD baseline / diagnostic | RMS SE baseline / diagnostic | Baseline coverage [95% MC interval] | Diagnostic coverage [95% MC interval] |",
    "|---|---:|---|---:|---:|---:|---:|---|---|",
    sprintf("| %s | %d | %s | %d | %s / %s | %s / %s | %s / %s | %s | %s |",
      summary$design, summary$n, toupper(summary$method), summary$time,
      fmt(summary$baseline_bias), fmt(summary$diagnostic_bias),
      fmt(summary$baseline_empirical_sd), fmt(summary$diagnostic_empirical_sd),
      fmt(summary$baseline_rms_se), fmt(summary$diagnostic_rms_se),
      ci_text(summary$baseline_coverage, summary$baseline_mc_lower, summary$baseline_mc_upper),
      ci_text(summary$diagnostic_coverage, summary$diagnostic_mc_lower, summary$diagnostic_mc_upper)))
  difference_table <- c("| Design | n | Method | Time | Coverage difference (points) | Gain / loss | Exact McNemar p | Mean estimate difference | Mean SE difference | Estimate correlation |",
    "|---|---:|---|---:|---:|---:|---:|---:|---:|---:|",
    sprintf("| %s | %d | %s | %d | %s | %d / %d | %s | %s | %s | %s |",
      summary$design, summary$n, toupper(summary$method), summary$time,
      pct(summary$coverage_difference), summary$gain, summary$loss,
      fmt(summary$mcnemar_exact_p, 4), fmt(summary$mean_estimate_difference, 5),
      fmt(summary$mean_se_difference, 5), fmt(summary$estimate_correlation, 4)))
  failure_table <- c("| Design | n | Method | Time | Both attempts complete/planned | Baseline failure-aware coverage | Diagnostic failure-aware coverage | Gain / loss |",
    "|---|---:|---|---:|---:|---:|---:|---:|",
    sprintf("| %s | %d | %s | %d | %d/%d | %s%% | %s%% | %d / %d |",
      summary$design, summary$n, toupper(summary$method), summary$time,
      summary$both_attempts_complete, summary$planned, pct(summary$failure_aware_baseline_coverage),
      pct(summary$failure_aware_diagnostic_coverage), summary$failure_aware_gain, summary$failure_aware_loss))
  report <- c("# Paired fitting-profile comparison", "", paste("Generated", provenance$generated_utc), "",
    paste0("The comparison cohort is the diagnostic profile's ", nrow(diagnostic_design),
      " planned datasets. The baseline has ", nrow(baseline_design), " planned datasets in total; ",
      nrow(baseline_design) - nrow(diagnostic_design), " outside this cohort are excluded from this comparison."),
    paste0("Baseline fingerprint: `", paste(provenance$baseline_fingerprint, collapse = ", "), "`."),
    paste0("Diagnostic fingerprint: `", paste(provenance$diagnostic_fingerprint, collapse = ", "), "`."),
    "Each input root was independently checked for conflicting numerical fingerprints/configurations and duplicate checkpoints. For every available paired checkpoint, seed, generated-data hash and person-fold hash must agree. Differing numerical fingerprints across the two profiles are intentional.",
    if (provenance$identical_input_root) "Both inputs are the same root. This is an identity check, not a comparison of different numerical methods." else character(),
    "", "## Completion and failures", "", completion_table, "",
    "Failed includes recorded fit failures, invalid results, unreadable/missing checkpoints and interrupted processes. Pending includes unstarted and started-unfinished jobs. The complete status and failure tables retain every planned seed, including failures on either side. A returned method supplies both outcomes.",
    "", "## Common successful pairs", "", performance_table, "",
    "All statistics in this table use the same successful datasets for both profiles within each method. Intervals are unmodified estimate ± qnorm(0.975) × reported SE. Coverage intervals are pointwise Wilson Monte Carlo intervals. RMS SE is sqrt(mean(SE²)). Different methods can have different common-success subsets.",
    "", difference_table, "",
    "Differences are diagnostic minus baseline. A gain means only the diagnostic interval covers; a loss means only the baseline interval covers. The exact McNemar value is a two-sided binomial test of equal gain/loss probabilities conditional on discordance. It is descriptive here, without adjustment for repeated looks, several outcomes or data-dependent profile development. The CSV also provides paired Monte Carlo SEs and normal-approximation intervals for coverage differences; these can be degenerate when there is no observed discordance.",
    "", "## Paired coverage including failures", "", failure_table, "",
    "This table uses datasets with completed attempts for both profiles, counting a failed method as noncoverage. It includes one-sided and two-sided failures. A pending result on either side excludes that pair from this denominator. Thus it neither treats unfinished jobs as failures nor hides completed failures behind the common-success restriction. Wilson intervals and paired discordance statistics for this denominator are in paired-summary.csv.",
    "", "The common-success analysis can be selected by numerical failures or fitting time. Compare failure rates and the failure-aware results alongside bias, empirical SD, reported SE, RMSE and interval width; increased coverage alone does not establish a better estimator. profile-available-summary.csv separately describes each profile's returned fits within the planned comparison cohort, which may use different seeds and must not be interpreted as a paired comparison. Original checkpoints are retained unchanged, and numerically different profiles are never pooled.",
    "", "[Paired summaries](paired-summary.csv) · [Individual paired estimates](paired-estimates.csv) · [All paired statuses](paired-method-status.csv) · [Failed seeds](paired-failures.csv) · [Each profile's available results](profile-available-summary.csv) · [Planned cohort](paired-design.csv) · [Provenance](paired-provenance.json)")
  writeLines(report, file.path(output, "PAIRED-COMPARISON.md"))
  invisible(list(summary = summary, statuses = paired, estimates = estimates,
    available = independent, provenance = provenance))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L) stop("Usage: Rscript compare_profiles.R BASELINE_ROOT DIAGNOSTIC_ROOT OUTPUT_DIR")
  result <- compare_four_dose_profiles(args[1L], args[2L], args[3L])
  print(result$summary[c("design", "n", "method", "time", "planned", "common_success",
    "baseline_coverage", "diagnostic_coverage", "coverage_difference", "gain", "loss",
    "baseline_failed", "diagnostic_failed", "baseline_pending", "diagnostic_pending")])
}
