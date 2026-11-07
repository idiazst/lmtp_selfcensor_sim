# Report immutable four-dose checkpoints without fitting or replacing failures.
# Rscript coverage.R INPUT_DIRECTORY OUTPUT_DIRECTORY [EXPECTED_DESIGN_CSV]
# The optional manifest must describe the entire study, including unstarted shards.

four_dose_truth <- function(design, time) ifelse(time == 2L, 55 / 96,
  ifelse(design == "observed", 390931619 / 707788800, 379546979 / 707788800))

coverage_wilson <- function(covered, total, level = 0.95) {
  if (!total) return(c(lower = NA_real_, upper = NA_real_))
  z <- qnorm((1 + level) / 2)
  p <- covered / total
  denominator <- 1 + z^2 / total
  center <- (p + z^2 / (2 * total)) / denominator
  half <- z * sqrt(p * (1 - p) / total + z^2 / (4 * total^2)) / denominator
  c(lower = max(0, center - half), upper = min(1, center + half))
}

coverage_read_json <- function(path) {
  jsonlite::read_json(path, simplifyVector = TRUE)
}

coverage_scalar <- function(x, name, fallback = NA) {
  if (!is.list(x) || length(x[[name]]) != 1L || is.na(x[[name]])) return(fallback)
  x[[name]]
}

coverage_key <- function(x, include_method = FALSE) {
  columns <- c("design", "n", "rep", "variant", if (include_method) "method")
  do.call(paste, c(unname(x[columns]), sep = "/"))
}

coverage_expected <- function(input, expected = NULL) {
  if (is.null(expected)) expected <- file.path(input, "design.csv")
  if (!file.exists(expected)) stop("Supply the complete expected design CSV; it is required to count pending datasets.")
  x <- read.csv(expected, stringsAsFactors = FALSE)
  if (!all(c("design", "n", "rep") %in% names(x)) || !nrow(x))
    stop("Expected design must contain design, n and rep columns and at least one row.")
  x <- x[c("design", "n", "rep", if ("seed" %in% names(x)) "seed")]
  if (anyNA(x) || anyDuplicated(x[c("design", "n", "rep")]) ||
      any(!x$design %in% c("observed", "full")) ||
      any(x$n < 1 | x$n != floor(x$n) | x$rep < 1 | x$rep != floor(x$rep)))
    stop("Invalid or duplicated expected dataset identity.")
  seed <- 7200000 + x$n + x$rep
  if ("seed" %in% names(x) && any(x$seed != seed)) stop("Unexpected seed in expected design.")
  x$seed <- seed
  x
}

coverage_job_identity <- function(path) {
  pattern <- "^(observed|full)-n([0-9]+)-r([0-9]+)-(baseline|optimized)$"
  match <- regmatches(basename(path), regexec(pattern, basename(path)))[[1L]]
  if (!length(match)) return(NULL)
  data.frame(design = match[2L], n = as.integer(match[3L]), rep = as.integer(match[4L]),
             variant = match[5L], stringsAsFactors = FALSE)
}

four_dose_coverage <- function(input, output, expected = NULL) {
  input <- normalizePath(input, mustWork = TRUE)
  expected <- coverage_expected(input, expected)
  files <- list.files(input, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  configs <- lapply(files[basename(files) == "run-config.json"], coverage_read_json)
  # Shards may cover different subsets of the same design. Numerical settings may not differ.
  config_core <- function(x) list(crossfit = x$crossfit, outer_folds = x$outer_folds,
    variants = sort(as.character(x$variants)))
  cores <- lapply(configs, config_core)
  if (length(cores) && any(!vapply(cores, identical, logical(1), cores[[1L]])))
    stop("Conflicting cross-fitting configuration or variants across shards.")
  variants <- if (length(cores)) cores[[1L]]$variants else "optimized"
  if (!length(variants) || any(!variants %in% c("baseline", "optimized")) || anyDuplicated(variants))
    stop("Invalid configured variants.")
  configured_crossfit <- if (length(cores)) cores[[1L]]$crossfit else NULL
  configured_folds <- if (length(cores)) cores[[1L]]$outer_folds else NULL
  fingerprints <- unlist(lapply(files[basename(files) == "source-fingerprint.txt"],
    function(path) trimws(readLines(path, warn = FALSE))), use.names = FALSE)
  fingerprints <- fingerprints[nzchar(fingerprints)]
  if (length(unique(fingerprints)) > 1L) stop("Conflicting numerical fingerprints across shard manifests.")
  expected_jobs <- merge(expected, data.frame(variant = variants), by = NULL)
  expected_jobs$key <- coverage_key(expected_jobs)
  job_dirs <- list.dirs(input, recursive = TRUE, full.names = TRUE)
  identities <- lapply(job_dirs, coverage_job_identity)
  keep <- !vapply(identities, is.null, logical(1))
  job_dirs <- job_dirs[keep]
  identities <- identities[keep]
  names(job_dirs) <- vapply(identities, coverage_key, character(1))
  if (any(!names(job_dirs) %in% expected_jobs$key))
    stop("An input shard contains a dataset or variant outside the expected study manifest.")
  checkpoint_files <- files[basename(files) %in% c("sdr.rds", "tmle.rds")]
  if (any(!dirname(checkpoint_files) %in% job_dirs))
    stop("A method checkpoint is outside a recognized immutable dataset directory.")
  checkpoints <- new.env(parent = emptyenv())
  duplicate_copies <- 0L
  for (path in checkpoint_files) {
    job <- coverage_job_identity(dirname(path))
    method <- sub("[.]rds$", "", basename(path))
    key <- paste(coverage_key(job), method, sep = "/")
    ck <- tryCatch(readRDS(path), error = function(e) structure(list(error = conditionMessage(e)),
      class = "unreadable_checkpoint"))
    if (!inherits(ck, "unreadable_checkpoint")) {
      fields <- c("design", "n", "rep", "variant")
      if (!is.list(ck) || !all(fields %in% names(ck)) ||
          !all(vapply(fields, function(field) isTRUE(ck[[field]] == job[[field]]), logical(1))) ||
          !identical(ck$method, method) || !isTRUE(ck$seed == 7200000 + job$n + job$rep))
        stop("Checkpoint identity or seed conflicts with directory: ", path)
      fingerprint <- coverage_scalar(ck, "fingerprint", "")
      if (!nzchar(fingerprint)) stop("Checkpoint has no numerical fingerprint: ", path)
      if (any(!vapply(c("data_hash", "fold_hash"), function(field)
        nzchar(coverage_scalar(ck, field, "")), logical(1))))
        stop("Checkpoint lacks data or person-fold provenance: ", path)
      fingerprints <- unique(c(fingerprints, fingerprint))
      if (length(fingerprints) > 1L) stop("Conflicting numerical fingerprints in checkpoints.")
      if ((!is.null(configured_crossfit) && !identical(ck$crossfit, configured_crossfit)) ||
          (!is.null(configured_folds) && !isTRUE(ck$outer_folds == configured_folds)))
        stop("Checkpoint cross-fitting configuration conflicts with manifest: ", path)
      if (is.null(configured_crossfit)) configured_crossfit <- ck$crossfit
      if (is.null(configured_folds)) configured_folds <- ck$outer_folds
      if (length(ck$error) != 1L || is.na(ck$error))
        stop("Checkpoint is missing its explicit error status: ", path)
    }
    if (exists(key, checkpoints, inherits = FALSE)) {
      old <- checkpoints[[key]]
      if (!identical(old$value, ck)) stop("Conflicting immutable checkpoint copies for ", key)
      duplicate_copies <- duplicate_copies + 1L
      checkpoints[[key]]$copies <- old$copies + 1L
    } else checkpoints[[key]] <- list(value = ck, path = path, copies = 1L)
  }
  statuses <- estimates <- list()
  for (i in seq_len(nrow(expected_jobs))) {
    cell <- expected_jobs[i, ]
    directories <- unname(job_dirs[names(job_dirs) == cell$key])
    usages <- lapply(file.path(directories, "usage.json"), function(path) {
      if (!file.exists(path)) return(NULL)
      tryCatch(coverage_read_json(path), error = function(e) list(exit_code = NA_integer_))
    })
    for (usage in usages) {
      f <- coverage_scalar(usage, "fingerprint", "")
      if (nzchar(f)) {
        fingerprints <- unique(c(fingerprints, f))
        if (length(fingerprints) > 1L) stop("Conflicting numerical fingerprint in process usage records.")
      }
    }
    for (method in c("sdr", "tmle")) {
      key <- paste(cell$key, method, sep = "/")
      entry <- if (exists(key, checkpoints, inherits = FALSE)) checkpoints[[key]] else NULL
      ck <- entry$value
      error <- ""
      if (is.null(ck)) {
        present <- !vapply(usages, is.null, logical(1))
        finished <- usages[present]
        if (length(finished)) {
          codes <- vapply(finished, coverage_scalar, numeric(1), "exit_code", NA_real_)
          status <- if (any(codes == 0, na.rm = TRUE)) "missing_checkpoint" else "interrupted"
          error <- paste0("No method checkpoint; recorded process exit codes: ", paste(codes, collapse = ", "))
        } else status <- if (length(directories)) "started_unfinished" else "not_started"
      } else if (inherits(ck, "unreadable_checkpoint")) {
        status <- "unreadable_checkpoint"
        error <- ck$error
      } else if (nzchar(ck$error)) {
        status <- "fit_failed"
        error <- ck$error
      } else {
        result <- ck$result
        shape_ok <- is.list(result) && is.numeric(result$estimates) &&
          is.numeric(result$se) && length(result$estimates) == 2L && length(result$se) == 2L &&
          is.numeric(result$eif) && identical(dim(result$eif), c(as.integer(cell$n), 2L))
        valid <- shape_ok && all(is.finite(c(result$estimates, result$se, result$eif))) && all(result$se > 0)
        status <- if (valid) "returned" else "invalid_result"
        if (!valid) error <- "Nonfinite/malformed estimates or EIFs, or a nonpositive standard error."
      }
      row <- data.frame(cell[c("design", "n", "rep", "seed", "variant")], method = method,
        status = status, elapsed_seconds = coverage_scalar(ck, "elapsed", NA_real_),
        warning_events = if (is.list(ck) && length(ck$warning_counts)) sum(ck$warning_counts) else 0,
        warnings = paste(ck$warnings, collapse = " | "), error = error,
        data_hash = coverage_scalar(ck, "data_hash", NA_character_),
        fold_hash = coverage_scalar(ck, "fold_hash", NA_character_),
        checkpoint = if (is.null(entry)) "" else entry$path,
        copies = if (is.null(entry)) 0L else entry$copies, stringsAsFactors = FALSE)
      statuses[[length(statuses) + 1L]] <- row
      if (status == "returned") {
        erow <- data.frame(row[c("design", "n", "rep", "seed", "variant", "method")],
          time = 2:3, estimate = unname(ck$result$estimates), std_error = unname(ck$result$se),
          row.names = NULL)
        erow$truth <- four_dose_truth(erow$design, erow$time)
        erow$error <- erow$estimate - erow$truth
        erow$standardized_error <- erow$error / erow$std_error
        erow$ci_lower <- erow$estimate - qnorm(0.975) * erow$std_error
        erow$ci_upper <- erow$estimate + qnorm(0.975) * erow$std_error
        erow$covered <- erow$ci_lower <= erow$truth & erow$ci_upper >= erow$truth
        estimates[[length(estimates) + 1L]] <- erow
      }
    }
  }
  statuses <- do.call(rbind, statuses)
  # Both methods on a dataset must refer to the same generated data and person folds.
  for (group in split(statuses, coverage_key(statuses))) {
    for (field in c("data_hash", "fold_hash")) {
      values <- unique(group[[field]][!is.na(group[[field]])])
      if (length(values) > 1L) stop("Methods disagree on ", field, " for a dataset.")
    }
  }
  estimates <- if (length(estimates)) do.call(rbind, estimates) else data.frame(
    design = character(), n = integer(), rep = integer(), seed = integer(), variant = character(),
    method = character(), time = integer(), estimate = numeric(), std_error = numeric(),
    truth = numeric(), error = numeric(), standardized_error = numeric(), ci_lower = numeric(),
    ci_upper = numeric(), covered = logical())
  summary <- list()
  for (group in split(statuses, interaction(statuses$design, statuses$n, statuses$variant,
    statuses$method, drop = TRUE))) {
    cell <- group[1L, c("design", "n", "variant", "method")]
    for (time in 2:3) {
      fit <- estimates[estimates$design == cell$design & estimates$n == cell$n &
        estimates$variant == cell$variant & estimates$method == cell$method & estimates$time == time, ]
      successful <- nrow(fit)
      statistical_failures <- sum(group$status %in% c("fit_failed", "invalid_result"))
      infrastructure_failures <- sum(group$status %in%
        c("interrupted", "missing_checkpoint", "unreadable_checkpoint"))
      failed <- statistical_failures + infrastructure_failures
      completed_attempts <- successful + failed
      covered <- sum(fit$covered)
      ci <- coverage_wilson(covered, successful)
      ci_all <- coverage_wilson(covered, completed_attempts)
      coverage <- if (successful) covered / successful else NA_real_
      empirical_sd <- if (successful > 1L) sd(fit$estimate) else NA_real_
      mean_se <- if (successful) mean(fit$std_error) else NA_real_
      rms_se <- if (successful) sqrt(mean(fit$std_error^2)) else NA_real_
      severe <- successful >= 100L && coverage < 0.90 && ci["upper"] < 0.95
      summary[[length(summary) + 1L]] <- data.frame(cell, time = time,
        truth = four_dose_truth(cell$design, time), planned = nrow(group),
        successful = successful, statistical_failures = statistical_failures,
        infrastructure_failures = infrastructure_failures, failed = failed,
        started_unfinished = sum(group$status == "started_unfinished"),
        not_started = sum(group$status == "not_started"), completed_attempts = completed_attempts,
        covered = covered, coverage = coverage,
        coverage_mc_se = if (successful) sqrt(coverage * (1 - coverage) / successful) else NA_real_,
        coverage_mc_lower = unname(ci["lower"]), coverage_mc_upper = unname(ci["upper"]),
        coverage_including_failures = if (completed_attempts) covered / completed_attempts else NA_real_,
        failure_aware_mc_lower = unname(ci_all["lower"]), failure_aware_mc_upper = unname(ci_all["upper"]),
        mean_estimate = if (successful) mean(fit$estimate) else NA_real_,
        bias = if (successful) mean(fit$error) else NA_real_,
        bias_mc_se = empirical_sd / sqrt(successful), empirical_sd = empirical_sd,
        mean_se = mean_se, rms_se = rms_se, se_to_empirical_sd = rms_se / empirical_sd,
        rmse = if (successful) sqrt(mean(fit$error^2)) else NA_real_,
        mean_interval_width = if (successful) mean(fit$ci_upper - fit$ci_lower) else NA_real_,
        misses_below = sum(fit$ci_upper < fit$truth), misses_above = sum(fit$ci_lower > fit$truth),
        severe_undercoverage = severe,
        assessment = if (successful < 100L) "insufficient_replications" else if (severe)
          "severe_undercoverage" else if (ci["upper"] < 0.95) "undercoverage" else "no_clear_undercoverage",
        stringsAsFactors = FALSE)
    }
  }
  summary <- do.call(rbind, summary)
  summary <- summary[order(summary$design, summary$n, summary$variant, summary$method, summary$time), ]
  rownames(summary) <- NULL
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  write.csv(estimates, file.path(output, "coverage-estimates.csv"), row.names = FALSE)
  write.csv(expected, file.path(output, "coverage-design.csv"), row.names = FALSE)
  write.csv(summary, file.path(output, "coverage-summary.csv"), row.names = FALSE)
  write.csv(statuses, file.path(output, "coverage-method-status.csv"), row.names = FALSE)
  write.csv(statuses[!statuses$status %in% c("returned", "not_started", "started_unfinished"), ],
    file.path(output, "coverage-failures.csv"), row.names = FALSE)
  generated <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  alert <- list(generated_utc = generated, fingerprint = fingerprints, duplicate_copies = duplicate_copies,
    planned_datasets = nrow(expected), returned_methods = sum(statuses$status == "returned"),
    severe_undercoverage = any(summary$severe_undercoverage),
    flagged_cells = summary[summary$severe_undercoverage, c("design", "n", "variant", "method", "time",
      "successful", "coverage", "coverage_mc_lower", "coverage_mc_upper")])
  jsonlite::write_json(alert, file.path(output, "coverage-alert.json"), pretty = TRUE,
    auto_unbox = TRUE, na = "null")
  fmt <- function(x, digits = 3) ifelse(is.finite(x), formatC(x, digits = digits, format = "f"), "—")
  pct <- function(x) fmt(100 * x, 1)
  table <- c("| Design | n | Method | Time | Returned/planned | Failed | Pending | Bias | Empirical SD | RMS SE | Coverage | 95% MC interval | Failure-aware | Assessment |",
    "|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|",
    sprintf("| %s | %d | %s | %d | %d/%d | %d | %d | %s | %s | %s | %s%% | [%s, %s]%% | %s%% | %s |",
      summary$design, summary$n, paste(toupper(summary$method), summary$variant), summary$time,
      summary$successful, summary$planned, summary$failed,
      summary$not_started + summary$started_unfinished, fmt(summary$bias), fmt(summary$empirical_sd),
      fmt(summary$rms_se), pct(summary$coverage), pct(summary$coverage_mc_lower),
      pct(summary$coverage_mc_upper), pct(summary$coverage_including_failures), summary$assessment))
  report <- c("# Four-dose simulation coverage", "", paste("Generated", generated), "",
    paste0(nrow(expected), " planned datasets; ", length(variants), " variant(s); SDR and TMLE at times 2 and 3. ",
      duplicate_copies, " identical checkpoint copies deduplicated."),
    paste0("Numerical fingerprint: `", paste(fingerprints, collapse = ", "), "`."), "", table, "",
    "Coverage uses the individual Wald interval estimate ± qnorm(0.975) × reported SE. The displayed 95% Monte Carlo interval is the Wilson binomial interval for coverage, not a confidence interval for the causal mean. RMS SE is sqrt(mean(SE²)); compare it with the empirical SD to assess variance calibration. Bias and one-sided misses help distinguish variance errors from estimation bias.", "",
    "Returned-fit coverage conditions on a finite estimate, a positive finite SE and finite person-level influence functions at both times. Failure-aware coverage counts recorded statistical failures, malformed checkpoints and interrupted processes as noncoverage. Its denominator is returned methods plus those failed attempts; unstarted and unfinished jobs are excluded. Infrastructure interruptions are separately counted and can be retried with the original seed. No failed dataset is replaced by a new seed.", "",
    "Pending includes both not-started and started-unfinished datasets, separately reported in the CSV. Incomplete snapshots can be selected by fitting time, so interim coverage is provisional until the planned cohort is complete. The confidence bands are pointwise descriptive Monte Carlo intervals, not sequential or multiplicity-adjusted tests.", "",
    "A severe-undercoverage flag requires at least 100 returned replications, coverage below 90%, and a Wilson upper bound below 95%. A flag calls for investigation; it does not justify removing failed seeds, selecting favorable checkpoints or widening intervals to obtain the desired empirical coverage. Revised numerical specifications must use a separate fingerprint and report.", "",
    "[Cell summaries](coverage-summary.csv) · [Individual estimates](coverage-estimates.csv) · [All method statuses](coverage-method-status.csv) · [Failures](coverage-failures.csv) · [Machine-readable assessment](coverage-alert.json)")
  writeLines(report, file.path(output, "COVERAGE.md"))
  invisible(list(summary = summary, estimates = estimates, statuses = statuses, alert = alert))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args) %in% 2:3) stop("Usage: Rscript coverage.R INPUT_DIRECTORY OUTPUT_DIRECTORY [EXPECTED_DESIGN_CSV]")
  result <- four_dose_coverage(args[1L], args[2L], if (length(args) == 3L) args[3L] else NULL)
  print(result$summary)
}
