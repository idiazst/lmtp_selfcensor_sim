# Reconstruct gradients from immutable saved fits and bootstrap them. No refits.
source("studies/longitudinal/github-500/config.R")
source("studies/longitudinal/github-500/multiplier_functions.R")
run_dataset <- function(...) stop("Refitting is disabled in multiplier postprocessing.")
input <- Sys.getenv("MC_INPUT", ".runtime/full500-variance-t3")
output <- Sys.getenv("MC_OUTPUT", "results/longitudinal/full500-github-20261013/multiplier-bootstrap")
workers <- as.integer(Sys.getenv("MC_WORKERS", "6"))
draws <- as.integer(Sys.getenv("MC_DRAWS", "9999"))
limit <- as.integer(Sys.getenv("MC_LIMIT", "0"))
stopifnot(workers >= 1L, workers <= 8L, draws >= 999L, limit >= 0L)
dir.create(file.path(output, "jobs"), recursive = TRUE, showWarnings = FALSE)
manifest <- jsonlite::fromJSON(file.path(input, "checkpoint-manifest.json"), simplifyVector = FALSE)
paths <- list.files(file.path(input, "jobs"), "[.]rds$", full.names = TRUE)
if (limit > 0L) paths <- head(paths, limit)
stopifnot(length(paths) > 0L, length(paths) <= 4000L)
algorithm <- list(draws = draws, seed_offset = 1200000000L,
  exponential_seed_offset = 10000000L, normalization = "sqrt(n/(n-1))/n",
  multipliers = c("gaussian", "rademacher", "exponential"),
  conditional_quantiles = c("exact Gaussian", "symmetric 95% absolute Rademacher", "equal-tailed exponential"),
  core_sha256 = digest::digest(file = "studies/longitudinal/github-500/multiplier_functions.R", algo = "sha256"),
  fitting_fingerprint = full500_fingerprint)
analysis_fingerprint <- digest::digest(algorithm, algo = "sha256")
started <- Sys.time()
jsonlite::write_json(c(algorithm, list(started = format(started, tz = "UTC", usetz = TRUE),
  analysis_fingerprint = analysis_fingerprint, workers = workers,
  source_checkpoints = length(paths), fitting_changes = FALSE)), file.path(output, "configuration.json"),
  pretty = TRUE, auto_unbox = TRUE)

one <- function(path) {
  job_name <- sub("[.]rds$", "", basename(path))
  target <- file.path(output, "jobs", paste0(job_name, ".rds"))
  expected <- full500_design[job == job_name]
  source_hash <- digest::digest(file = path, algo = "sha256")
  stopifnot(nrow(expected) == 1L, source_hash == manifest[[basename(path)]]$sha256)
  if (file.exists(target)) {
    existing <- readRDS(target)
    stopifnot(identical(existing$analysis_fingerprint, analysis_fingerprint),
      identical(existing$source_sha256, source_hash))
    return(invisible(existing$success))
  }
  began <- Sys.time()
  answer <- tryCatch({
    x <- readRDS(path)
    stopifnot(identical(x$fingerprint, full500_fingerprint),
      x$design$seed == expected$seed, x$design$n == expected$n,
      x$design$mechanism == expected$mechanism, x$design$replicate == expected$replicate)
    recovered <- recover_saved_gradients(x)
    intervals <- multiplier_intervals(recovered, expected$n, expected$seed, draws = draws)
    original_errors <- if (!is.null(x$errors)) copy(as.data.table(x$errors)) else data.table()
    list(success = TRUE, intervals = intervals, reconstruction = recovered$audit,
      cells = recovered$cells, original_errors = original_errors,
      returned_outcomes = nrow(recovered$results), design = as.list(expected))
  }, error = function(e) list(success = FALSE, error = conditionMessage(e), design = as.list(expected)))
  answer$analysis_fingerprint <- analysis_fingerprint
  answer$source_sha256 <- source_hash
  answer$seconds <- as.numeric(difftime(Sys.time(), began, units = "secs"))
  tmp <- paste0(target, ".tmp")
  saveRDS(answer, tmp, compress = "gzip")
  stopifnot(file.rename(tmp, target))
  if (!answer$success) cat("Postprocessing failure:", job_name, answer$error, "\n", file = stderr())
  invisible(answer$success)
}
# Separate processes share no RNG stream; every dataset and law has a fixed seed.
chunks <- split(paths, rep(seq_len(min(workers, length(paths))), length.out = length(paths)))
completed <- parallel::mclapply(chunks, function(chunk) {
  statuses <- vapply(chunk, one, logical(1))
  all(statuses)
}, mc.cores = min(workers, length(chunks)), mc.set.seed = FALSE)
stopifnot(all(vapply(completed, isTRUE, logical(1))))
for (name in c("checkpoint-manifest.json", "artifact-provenance.json"))
  stopifnot(file.copy(file.path(input, name), file.path(output, name), overwrite = TRUE))
jsonlite::write_json(list(started = format(started, tz = "UTC", usetz = TRUE),
  finished = format(Sys.time(), tz = "UTC", usetz = TRUE),
  wall_seconds = as.numeric(difftime(Sys.time(), started, units = "secs")),
  datasets = length(paths), workers = workers, fitting_changes = FALSE),
  file.path(output, "runtime.json"), pretty = TRUE, auto_unbox = TRUE)
cat("Bootstrap postprocessing finished for", length(paths), "saved datasets.\n")
