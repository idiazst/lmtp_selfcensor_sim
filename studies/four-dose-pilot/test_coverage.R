# Deterministic checks of interim coverage reporting. No nuisance fits are run.
# Invoke from the repository root with Rscript studies/four-dose-pilot/test_coverage.R.
source("studies/four-dose-pilot/coverage.R")

test_coverage <- function() {
  root <- tempfile("four-dose-coverage-test-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  input <- file.path(root, "input")
  output <- file.path(root, "report")
  dir.create(input)
  design <- rbind(data.frame(design = "observed", n = 20L, rep = seq_len(105L)),
                  data.frame(design = "full", n = 20L, rep = 1L))
  design$seed <- 7200000L + design$n + design$rep
  write.csv(design, file.path(input, "design.csv"), row.names = FALSE)
  config <- list(crossfit = "outer", outer_folds = 4L, variants = "optimized",
                 designs = c("observed", "full"), sizes = 20L, replicates = seq_len(105L))
  jsonlite::write_json(config, file.path(input, "run-config.json"), auto_unbox = TRUE)
  writeLines("test-source-fingerprint", file.path(input, "source-fingerprint.txt"))
  job_dir <- function(rep, shard = "shard-1") file.path(input, shard, "jobs",
    paste0("observed-n20-r", rep, "-optimized"))
  checkpoint <- function(rep, method) {
    truth <- four_dose_truth("observed", 2:3)
    covered <- rep <= if (method == "sdr") 80L else 95L
    list(design = "observed", n = 20L, rep = as.integer(rep), seed = 7200020L + rep,
      variant = "optimized", crossfit = "outer", outer_folds = 4L, method = method,
      data_hash = paste0("data-", rep), fold_hash = paste0("fold-", rep),
      fingerprint = "test-source-fingerprint", elapsed = 1, warnings = character(),
      warning_counts = integer(), error = "", result = list(
        estimates = truth + if (covered) 0 else 1, se = rep(0.1, 2L), eif = matrix(0, 20L, 2L)))
  }
  for (rep in seq_len(101L)) {
    directory <- job_dir(rep)
    dir.create(directory, recursive = TRUE)
    for (method in c("sdr", "tmle")) {
      ck <- checkpoint(rep, method)
      if (rep == 101L) {
        ck$error <- "test statistical failure"
        ck$result <- NULL
      }
      saveRDS(ck, file.path(directory, paste0(method, ".rds")))
    }
  }
  # An interrupted process counts separately from statistical failures.
  dir.create(job_dir(102L), recursive = TRUE)
  jsonlite::write_json(list(exit_code = 1L, fingerprint = "test-source-fingerprint"),
    file.path(job_dir(102L), "usage.json"), auto_unbox = TRUE)
  dir.create(job_dir(103L), recursive = TRUE)
  # One complete shard copied from a retry must not double the denominator.
  dir.create(job_dir(1L, "shard-duplicate"), recursive = TRUE)
  for (method in c("sdr", "tmle")) stopifnot(file.copy(
    file.path(job_dir(1L), paste0(method, ".rds")),
    file.path(job_dir(1L, "shard-duplicate"), paste0(method, ".rds"))))
  result <- four_dose_coverage(input, output)
  sdr <- subset(result$summary, design == "observed" & method == "sdr")
  tmle <- subset(result$summary, design == "observed" & method == "tmle")
  full <- subset(result$summary, design == "full")
  stopifnot(nrow(result$estimates) == 400L, nrow(result$statuses) == 212L,
    result$alert$duplicate_copies == 2L, isTRUE(result$alert$severe_undercoverage),
    all(sdr$planned == 105L), all(sdr$successful == 100L),
    all(sdr$statistical_failures == 1L), all(sdr$infrastructure_failures == 1L),
    all(sdr$started_unfinished == 1L), all(sdr$not_started == 2L),
    all(sdr$completed_attempts == 102L), all(sdr$coverage == 0.8),
    all(sdr$coverage_including_failures == 80 / 102), all(sdr$severe_undercoverage),
    all(tmle$coverage == 0.95), !any(tmle$severe_undercoverage),
    all(full$successful == 0L), all(full$not_started == 1L), all(is.na(full$coverage)),
    !any(full$severe_undercoverage),
    all(abs(sdr$bias - 0.2) < 1e-12), all(abs(sdr$rms_se - 0.1) < 1e-12),
    abs(coverage_wilson(95, 100)["lower"] - 0.8882495) < 1e-6,
    abs(coverage_wilson(95, 100)["upper"] - 0.9784563) < 1e-6)
  check_error <- function(action, pattern) {
    err <- tryCatch({ action(); NULL }, error = identity)
    stopifnot(inherits(err, "error"), grepl(pattern, conditionMessage(err)))
  }
  duplicate <- file.path(job_dir(1L, "shard-duplicate"), "sdr.rds")
  bad <- checkpoint(1L, "sdr")
  bad$result$estimates[1L] <- bad$result$estimates[1L] + 1
  saveRDS(bad, duplicate)
  check_error(function() four_dose_coverage(input, output), "Conflicting immutable")
  bad <- checkpoint(1L, "sdr")
  bad$fingerprint <- "different-source"
  saveRDS(bad, duplicate)
  check_error(function() four_dose_coverage(input, output), "Conflicting numerical")
  bad <- checkpoint(1L, "sdr")
  bad$seed <- 2L
  saveRDS(bad, duplicate)
  check_error(function() four_dose_coverage(input, output), "identity or seed")
  saveRDS(checkpoint(1L, "sdr"), duplicate)
  config$outer_folds <- 3L
  jsonlite::write_json(config, file.path(input, "shard-duplicate", "run-config.json"), auto_unbox = TRUE)
  check_error(function() four_dose_coverage(input, output), "Conflicting cross-fitting")
  unlink(file.path(input, "shard-duplicate", "run-config.json"))
  bad <- checkpoint(2L, "tmle")
  bad$data_hash <- "wrong-data"
  saveRDS(bad, file.path(job_dir(2L), "tmle.rds"))
  check_error(function() four_dose_coverage(input, output), "Methods disagree on data_hash")
  saveRDS(checkpoint(2L, "tmle"), file.path(job_dir(2L), "tmle.rds"))
  # A nonpositive SE is retained as an invalid result, never silently dropped.
  bad <- checkpoint(2L, "tmle")
  bad$result$se[1L] <- 0
  saveRDS(bad, file.path(job_dir(2L), "tmle.rds"))
  result <- four_dose_coverage(input, output)
  tmle <- subset(result$summary, design == "observed" & method == "tmle")
  stopifnot(all(tmle$successful == 99L), all(tmle$statistical_failures == 2L),
    all(tmle$assessment == "insufficient_replications"))
  cat("Coverage checks passed: exact denominators, failure/pending distinctions, Wilson intervals,\n",
      "severe-undercoverage threshold, empty cells, duplicate deduplication, immutable conflicts,\n",
      "cross-method provenance, numerical fingerprint/configuration/seed rejection and invalid SEs.\n", sep = "")
}
test_coverage()
