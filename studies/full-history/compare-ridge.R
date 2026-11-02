# Matched diagnostic comparison; never pools different fitting specifications.
args <- commandArgs(TRUE)
if (length(args) != 2) stop("Supply reference and sensitivity result directories.")
reference_root <- args[1]
sensitivity_root <- args[2]
read_records <- function(root) {
  paths <- list.files(root, "[.]rds$", recursive = TRUE, full.names = TRUE)
  records <- lapply(paths[grepl("/jobs/", paths)], readRDS)
  if (!length(records)) stop("No checkpoint records found.")
  specifications <- lapply(records, function(x)
    x$manifest[setdiff(names(x$manifest), c("run", "commit"))])
  if (!all(vapply(specifications, identical, TRUE, specifications[[1]])))
    stop("Each input directory must contain one frozen specification.")
  records
}
reference <- read_records(reference_root)
sensitivity <- read_records(sensitivity_root)
rm <- reference[[1]]$manifest
sm <- sensitivity[[1]]$manifest
fields <- c("lmtp", "cmbridge", "control", "sl", "randomizer", "ratio_draws", "k")
stopifnot(identical(rm[fields], sm[fields]),
          identical(rm$sources["studies/full-history/dgp.R"],
                    sm$sources["studies/full-history/dgp.R"]))
rl <- rm$library
sl <- sm$library
reference_ridge <- rl$sieve_md$control$lambda
sensitivity_ridge <- sl$sieve_md$control$lambda
stopifnot(is.finite(reference_ridge), reference_ridge > 0,
          is.finite(sensitivity_ridge), sensitivity_ridge > 0)
rl$sieve_md$control$lambda <- NULL
sl$sieve_md$control$lambda <- NULL
if (!identical(rl, sl)) stop("Libraries differ in more than the ridge penalty.")

rows <- function(records) do.call(rbind, lapply(records, function(x)
  do.call(rbind, x$results)))
key <- c("mechanism", "n", "replicate", "method", "horizon", "seed")
r <- rows(reference)
s <- rows(sensitivity)
if (anyDuplicated(r[key]) || anyDuplicated(s[key])) stop("Duplicate checkpoints.")
paired <- merge(s, r, by = key, all.x = TRUE, suffixes = c(".sensitivity", ".reference"))
stopifnot(all(is.finite(paired$truth.reference)),
          max(abs(paired$truth.sensitivity - paired$truth.reference)) < 1e-12)
paired$valid_pair <- with(paired, is.finite(estimate.sensitivity) &
  is.finite(estimate.reference) & is.finite(std.error.sensitivity) &
  is.finite(std.error.reference))
paired$estimate_change <- paired$estimate.sensitivity - paired$estimate.reference
paired$se_change <- paired$std.error.sensitivity - paired$std.error.reference
write.csv(paired, file.path(sensitivity_root, "paired-ridge-comparison.csv"), row.names = FALSE)
groups <- split(paired, with(paired, interaction(mechanism, n, method, horizon, drop = TRUE)))
summary <- do.call(rbind, lapply(groups, function(x) {
  z <- x[x$valid_pair, ]
  count <- nrow(z)
  coverage <- function(suffix) if (count) mean(
    z[[paste0("conf.low.", suffix)]] <= z$truth.reference &
    z[[paste0("conf.high.", suffix)]] >= z$truth.reference) else NA_real_
  data.frame(mechanism = x$mechanism[1], n = x$n[1], method = x$method[1],
    horizon = x$horizon[1], attempted_pairs = nrow(x), valid_pairs = count,
    failed_pairs = sum(!x$valid_pair),
    mean_estimate_change = if (count) mean(z$estimate_change) else NA_real_,
    estimate_change_mcse = if (count > 1) sd(z$estimate_change) / sqrt(count) else NA_real_,
    mean_se_change = if (count) mean(z$se_change) else NA_real_,
    se_change_mcse = if (count > 1) sd(z$se_change) / sqrt(count) else NA_real_,
    reference_rms_se = if (count) sqrt(mean(z$std.error.reference^2)) else NA_real_,
    sensitivity_rms_se = if (count) sqrt(mean(z$std.error.sensitivity^2)) else NA_real_,
    reference_empirical_sd = if (count > 1) sd(z$estimate.reference) else NA_real_,
    sensitivity_empirical_sd = if (count > 1) sd(z$estimate.sensitivity) else NA_real_,
    reference_bias = if (count) mean(z$estimate.reference - z$truth.reference) else NA_real_,
    sensitivity_bias = if (count) mean(z$estimate.sensitivity - z$truth.reference) else NA_real_,
    reference_coverage = coverage("reference"), sensitivity_coverage = coverage("sensitivity"))
}))
rownames(summary) <- NULL
write.csv(summary, file.path(sensitivity_root, "paired-ridge-summary.csv"), row.names = FALSE)

components <- function(records) do.call(rbind, lapply(records, function(x) {
  do.call(rbind, lapply(names(x$details), function(method) {
    d <- x$details[[method]]
    data.frame(mechanism = x$mechanism, n = x$n, replicate = x$replicate,
      seed = x$seed, method = method, horizon = seq_along(d$sequential_variance),
      sequential = d$sequential_variance, bridge = d$bridge_variance,
      covariance_twice = 2 * d$cross_covariance)
  }))
}))
component_pairs <- merge(components(sensitivity), components(reference), by = key,
  all.x = TRUE, suffixes = c(".sensitivity", ".reference"))
write.csv(component_pairs, file.path(sensitivity_root, "paired-score-components.csv"), row.names = FALSE)
lines <- c("# Matched positive-ridge comparison", "",
  sprintf("Reference ridge: %g; sensitivity ridge: %g.", reference_ridge, sensitivity_ridge),
  paste("Reference run:", rm$run, "; sensitivity run:", sm$run),
  "Package versions, DGP hash, folds/control, SL learners, randomizer and k match.",
  "The declared libraries differ only in their strictly positive ridge penalty.",
  "The run.R source changed to expose this explicit study input; fitting archives are unchanged.",
  "Rows are paired by mechanism, n, replication, estimator, horizon and seed.",
  "No different specifications or overlapping seeds are pooled as independent data.",
  "Only currently available sensitivity checkpoints are compared. A full cell has 100 pairs.",
  "Use paired SE changes to assess regularization; partial-cell coverage is descriptive only.", "",
  paste(capture.output(print(summary, digits = 5, row.names = FALSE)), collapse = "\n"), "",
  paste("Comparison source MD5:", unname(tools::md5sum("studies/full-history/compare-ridge.R"))))
writeLines(lines, file.path(sensitivity_root, "PAIRED_RIDGE.md"))
cat(paste(lines, collapse = "\n"), "\n")
