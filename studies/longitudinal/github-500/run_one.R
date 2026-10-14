source("studies/longitudinal/github-500/config.R")
job_name <- Sys.getenv("FULL_JOB")
z <- full500_design[job == job_name]
stopifnot(nrow(z) == 1L)
out <- Sys.getenv("FULL_OUTPUT", "work/shard")
dir.create(file.path(out, "jobs"), recursive = TRUE, showWarnings = FALSE)
path <- file.path(out, "jobs", paste0(job_name, ".rds"))
if (file.exists(path)) {
  previous <- readRDS(path)
  stopifnot(identical(previous$fingerprint, full500_fingerprint),
    previous$design$seed == z$seed, previous$design$n == z$n,
    previous$design$mechanism == z$mechanism, previous$design$replicate == z$replicate)
  cat("Verified existing checkpoint; no refit:", job_name, "\n")
  quit(save = "no", status = 0L)
}
started <- Sys.time(); recorded_warnings <- character()
cat(format(started), "START", job_name, "seed", z$seed, "\n"); flush.console()
answer <- tryCatch(withCallingHandlers(
  run_dataset(z$mechanism, z$n, z$replicate, z$seed, all_correct = TRUE,
    dose_max = 3L, learner_groups = 3L, balance_measurement = TRUE, visits = "missing_both",
    nuisance_callback = function(...) invisible(NULL)),
  warning = function(w) {
    recorded_warnings <<- c(recorded_warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  }), error = function(e) list(design = as.list(z[, .(mechanism, n, replicate, seed)]),
    errors = data.table(error = conditionMessage(e)), condition = e))
answer$fingerprint <- full500_fingerprint
answer$started <- started; answer$finished <- Sys.time()
answer$seconds <- as.numeric(difftime(answer$finished, started, units = "secs"))
answer$job_warnings <- unique(recorded_warnings)
answer$provenance <- list(run_id = Sys.getenv("GITHUB_RUN_ID"),
  run_attempt = Sys.getenv("GITHUB_RUN_ATTEMPT"), commit = Sys.getenv("GITHUB_SHA"),
  platform = Sys.info(), R = R.version.string,
  cmbridge = as.character(packageVersion("cmbridge")), lmtp = as.character(packageVersion("lmtp")))
tmp <- paste0(path, ".tmp")
saveRDS(answer, tmp, compress = "xz")
stopifnot(file.rename(tmp, path))
cat(format(Sys.time()), "SAVED", job_name, sprintf("%.1fs", answer$seconds),
  "recorded estimator errors", if (is.null(answer$errors)) 0L else nrow(answer$errors), "\n")
