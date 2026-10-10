library(data.table)
design <- fread(file.path(outdir, "design.csv"))
manifest <- jsonlite::fromJSON(file.path(outdir, "checkpoint-manifest.json"), simplifyVector = FALSE)
paths <- list.files(file.path(outdir, "jobs"), "\\.rds$", full.names = TRUE)
stopifnot(length(paths) == nrow(design), length(paths) == length(manifest))
fingerprint <- readLines(file.path(outdir, "source-fingerprint.txt"))[1L]
success <- failed <- 0L
for (path in paths) {
  key <- sub("\\.rds$", "", basename(path)); config <- design[job == key]
  x <- readRDS(path)
  stopifnot(nrow(config) == 1L,
    digest::digest(file = path, algo = "sha256") == manifest[[basename(path)]]$sha256,
    identical(x$fingerprint, fingerprint), x$design$seed == config$seed,
    x$design$n == config$n, x$design$mechanism == config$mechanism,
    x$design$replicate == config$replicate)
  bad <- !is.null(x$errors) && nrow(x$errors) > 0L
  if (bad) failed <- failed + 1L else {
    success <- success + 1L
    stopifnot(nrow(x$results) == 4L,
      !anyDuplicated(x$results[, .(estimator, horizon)]),
      setequal(x$results$estimator, c("sdr", "tmle")),
      setequal(x$results$horizon, 1:2),
      all(is.finite(as.matrix(x$results[, .(estimate, truth, se, lower, upper)]))),
      all(x$results$se > 0))
  }
}
writeLines(sprintf("Verified %d datasets: %d successful, %d with failures; hashes, seeds, configuration and results checked.",
  length(paths), success, failed), file.path(outdir, "VERIFICATION.txt"))
