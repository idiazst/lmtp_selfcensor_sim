# Synthetic pairing checks. No model fitting, external services or package installation.
source("studies/four-dose-pilot/compare_profiles.R")

test_compare_profiles <- function() {
  root <- tempfile("four-dose-pair-test-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  baseline <- file.path(root, "baseline")
  diagnostic <- file.path(root, "diagnostic")
  output <- file.path(root, "report")
  paths <- c(baseline = baseline, diagnostic = diagnostic)
  for (profile in names(paths)) {
    path <- paths[[profile]]
    dir.create(path)
    design <- data.frame(design = "full", n = 20L,
      rep = seq_len(if (profile == "baseline") 12L else 10L))
    if (profile == "baseline") design <- rbind(design,
      data.frame(design = "observed", n = 20L, rep = 1L))
    design$seed <- 7200000L + design$n + design$rep
    write.csv(design, file.path(path, "design.csv"), row.names = FALSE)
    jsonlite::write_json(list(crossfit = "outer", outer_folds = 4L, variants = "optimized"),
      file.path(path, "run-config.json"), auto_unbox = TRUE)
    writeLines(paste0(profile, "-fingerprint"), file.path(path, "source-fingerprint.txt"))
  }
  job_dir <- function(profile, rep) file.path(paths[[profile]], "jobs",
    paste0("full-n20-r", rep, "-optimized"))
  checkpoint <- function(profile, rep, method) {
    covered <- if (profile == "baseline") rep %in% c(1L, 2L, 6L, 9L, 11L) else
      rep %in% c(1L, 3L, 4L, 5L, 10L)
    failed <- if (profile == "baseline") rep %in% c(5L, 7L) else rep %in% c(6L, 7L)
    list(design = "full", n = 20L, rep = as.integer(rep), seed = 7200020L + rep,
      variant = "optimized", crossfit = "outer", outer_folds = 4L, method = method,
      data_hash = paste0("data-", rep), fold_hash = paste0("fold-", rep),
      fingerprint = paste0(profile, "-fingerprint"), elapsed = 1, warnings = character(),
      warning_counts = integer(), error = if (failed) "synthetic failure" else "",
      result = if (failed) NULL else list(
        estimates = four_dose_truth("full", 2:3) + if (covered) rep / 1000 else .5,
        se = rep(.1 + rep / 500, 2L), eif = matrix(0, 20L, 2L)))
  }
  for (profile in names(paths)) {
    present <- if (profile == "baseline") c(1:7, 9L, 11L) else c(1:7, 10L)
    for (rep in present) {
      dir.create(job_dir(profile, rep), recursive = TRUE)
      for (method in c("sdr", "tmle")) saveRDS(checkpoint(profile, rep, method),
        file.path(job_dir(profile, rep), paste0(method, ".rds")))
    }
  }
  # A retry copy is identical and must be deduplicated within its profile.
  duplicate <- file.path(baseline, "retry", "full-n20-r1-optimized")
  dir.create(duplicate, recursive = TRUE)
  for (method in c("sdr", "tmle")) stopifnot(file.copy(
    file.path(job_dir("baseline", 1L), paste0(method, ".rds")),
    file.path(duplicate, paste0(method, ".rds"))))
  result <- compare_four_dose_profiles(baseline, diagnostic, output)
  x <- result$summary
  stopifnot(nrow(x) == 4L, all(x$planned == 10L), all(x$common_success == 4L),
    all(x$both_checkpoints_present == 7L), all(x$paired_inputs_verified == 7L),
    all(x$both_attempts_complete == 7L), all(x$baseline_returned == 6L),
    all(x$diagnostic_returned == 6L), all(x$baseline_failed == 2L),
    all(x$diagnostic_failed == 2L), all(x$baseline_pending == 2L),
    all(x$diagnostic_pending == 2L), all(x$baseline_failed_only == 1L),
    all(x$diagnostic_failed_only == 1L), all(x$both_failed == 1L),
    all(x$baseline_pending_only == 1L), all(x$diagnostic_pending_only == 1L),
    all(x$both_pending == 1L), all(x$baseline_coverage == .5),
    all(x$diagnostic_coverage == .75), all(x$coverage_difference == .25),
    all(x$gain == 2L), all(x$loss == 1L), all(x$mcnemar_exact_p == 1),
    all(x$failure_aware_count == 7L), all(x$failure_aware_baseline_coverage == 3 / 7),
    all(x$failure_aware_diagnostic_coverage == 4 / 7),
    all(x$failure_aware_gain == 3L), all(x$failure_aware_loss == 2L),
    result$provenance$baseline_datasets_outside_comparison == 3L,
    all(subset(result$available, profile == "baseline")$coverage == 4 / 6),
    all(subset(result$available, profile == "diagnostic")$coverage == 5 / 6),
    nrow(result$statuses) == 20L, nrow(result$estimates) == 40L)
  exact <- profile_paired_coverage(rep(FALSE, 5L), rep(TRUE, 5L))
  stopifnot(abs(exact$mcnemar_exact_p - .0625) < 1e-12, exact$gain == 5L, exact$loss == 0L)
  check_error <- function(action, pattern) {
    err <- tryCatch({ action(); NULL }, error = identity)
    stopifnot(inherits(err, "error"), grepl(pattern, conditionMessage(err)))
  }
  # Both diagnostic methods consistently use different folds: valid within root,
  # but not a legitimate paired comparison with the baseline data split.
  for (method in c("sdr", "tmle")) {
    ck <- checkpoint("diagnostic", 1L, method)
    ck$fold_hash <- "different-folds"
    saveRDS(ck, file.path(job_dir("diagnostic", 1L), paste0(method, ".rds")))
  }
  check_error(function() compare_four_dose_profiles(baseline, diagnostic, output), "disagree on fold_hash")
  for (method in c("sdr", "tmle")) {
    ck <- checkpoint("diagnostic", 1L, method)
    ck$data_hash <- "different-data"
    saveRDS(ck, file.path(job_dir("diagnostic", 1L), paste0(method, ".rds")))
  }
  check_error(function() compare_four_dose_profiles(baseline, diagnostic, output), "disagree on data_hash")
  for (method in c("sdr", "tmle")) saveRDS(checkpoint("diagnostic", 1L, method),
    file.path(job_dir("diagnostic", 1L), paste0(method, ".rds")))
  ck <- checkpoint("diagnostic", 2L, "sdr")
  ck$fingerprint <- "mixed-profile"
  saveRDS(ck, file.path(job_dir("diagnostic", 2L), "sdr.rds"))
  check_error(function() compare_four_dose_profiles(baseline, diagnostic, output), "Conflicting numerical")
  saveRDS(checkpoint("diagnostic", 2L, "sdr"), file.path(job_dir("diagnostic", 2L), "sdr.rds"))
  dir.create(file.path(diagnostic, "mixed-config"))
  jsonlite::write_json(list(crossfit = "outer", outer_folds = 4L, variants = "optimized",
    profile = "another-profile"), file.path(diagnostic, "mixed-config", "run-config.json"),
    auto_unbox = TRUE)
  check_error(function() compare_four_dose_profiles(baseline, diagnostic, output),
    "Conflicting fitting-profile configuration")
  unlink(file.path(diagnostic, "mixed-config"), recursive = TRUE)
  self <- compare_four_dose_profiles(baseline, baseline, output)
  observed <- self$summary[self$summary$design == "observed", ]
  full <- self$summary[self$summary$design == "full", ]
  stopifnot(isTRUE(self$provenance$identical_input_root), all(full$coverage_difference == 0),
    all(full$max_abs_estimate_difference == 0), all(full$max_abs_se_difference == 0),
    all(full$gain == 0L), all(full$loss == 0L), all(full$mcnemar_exact_p == 1),
    all(observed$common_success == 0L), all(is.na(observed$coverage_difference)),
    all(is.na(observed$mcnemar_exact_p)))
  cat("Paired-profile checks passed: subset cohort, incomplete pairs, one/both failures,\n",
    "exact provenance, mixed-profile rejection, deduplication, paired discordance,\n",
    "failure-aware denominators, McNemar calculation, empty cells and self-comparison.\n", sep = "")
}
test_compare_profiles()
