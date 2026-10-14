source("studies/longitudinal/github-500/config.R")
outdir <- Sys.getenv("SIM_OUTPUT", "work/report")
full500_prepare(outdir)
paths <- list.files(file.path(outdir, "jobs"), "[.]rds$", full.names = TRUE)
manifest <- jsonlite::fromJSON(file.path(outdir, "checkpoint-manifest.json"), simplifyVector = FALSE)
stopifnot(length(paths) == length(manifest), length(paths) <= 4000L)
for (path in paths) {
  key <- sub("[.]rds$", "", basename(path)); z <- full500_design[job == key]
  x <- readRDS(path)
  stopifnot(nrow(z) == 1L, digest::digest(file = path, algo = "sha256") == manifest[[basename(path)]]$sha256,
    identical(x$fingerprint, full500_fingerprint), x$design$seed == z$seed,
    x$design$n == z$n, x$design$mechanism == z$mechanism, x$design$replicate == z$replicate)
  if (!is.null(x$results) && nrow(x$results)) stopifnot(
    !anyDuplicated(x$results[, .(estimator, horizon)]),
    all(is.finite(as.matrix(x$results[, .(estimate, truth, se, lower, upper)]))),
    all(x$results$se > 0))
  if (is.null(x$errors) || !nrow(x$errors)) stopifnot(nrow(x$results) == 4L)
}
if (!length(paths)) {
  writeLines("No fitting checkpoints have returned. The 4,000-dataset plan is not complete.",
    file.path(outdir, "REPORT.md"))
  writeLines("Completed datasets: 0 of 4,000; no returned estimators.", file.path(outdir, "STATUS.txt"))
  quit(save = "no", status = 0)
}
source("studies/longitudinal/summarize.R", local = new.env(parent = globalenv()))
s <- fread(file.path(outdir, "summary.csv"))
completed <- fread(file.path(outdir, "job_log.csv"))
estimates <- fread(file.path(outdir, "replicates.csv"))
counts <- estimates[, .(intervals_covering = sum(covered)),
  by = .(mechanism, n, horizon, estimator, scenario)]
availability <- merge(s, counts, by = c("mechanism", "n", "horizon", "estimator", "scenario"), all.x = TRUE)
availability[is.na(intervals_covering), intervals_covering := 0L]
availability[, coverage_including_failures := intervals_covering / datasets_completed]
fwrite(availability, file.path(outdir, "coverage-including-failures.csv"))
population <- fread(file.path(outdir, "population_diagnostics.csv"))
if (nrow(population)) {
  per_dataset <- population[, lapply(.SD, function(z) sum(z * fold_weight)),
    by = .(mechanism, n, replicate, horizon, estimator),
    .SDcols = c("population_bias", "sequential_remainder", "bridge_remainder",
      "bridge_equation_max_error", "adjoint_equation_max_error")]
  pm <- per_dataset[, c(list(returned = .N), lapply(.SD, mean)),
    by = .(mechanism, n, horizon, estimator),
    .SDcols = c("population_bias", "sequential_remainder", "bridge_remainder",
      "bridge_equation_max_error", "adjoint_equation_max_error")]
  fwrite(pm, file.path(outdir, "population-error-by-outcome-time.csv"))
}
writeLines(sprintf("Verified %d of 4,000 checkpoint hashes, source fingerprints, seed/configuration mappings and returned results. All checkpoints retained, including errors.",
  length(paths)), file.path(outdir, "VERIFICATION.txt"))
table <- function(x) {
  x <- as.data.frame(x)
  if (!nrow(x)) return(character())
  c(paste0("| ", paste(names(x), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(x)), collapse = " | "), " |"),
    apply(x, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |")), "")
}
labels <- c(binary_longitudinal = "Binary treatment", discrete_dose = "Numerical dose")
lines <- c("# Observed-history simulation: 500 replications", "",
  if (length(paths) == 4000L) "All 4,000 planned datasets have been processed. Failed estimators and warnings are retained." else
    sprintf("**PRELIMINARY: %d of 4,000 datasets have been processed.**", length(paths)), "",
  "Binary treatment and numerical dose 0–3 each use n = 500, 1,000, 4,000 and 10,000, with 500 datasets per setting. Both SDR and logistic TMLE use the one-step bridge/adjoint correction, shared training-only splits and the original positive penalty CV. The U-statistic ensemble Gram is projected to PSD. This is the original correctly specified full-study configuration; no experimental penalty rules, known-function estimators, zero-penalty runs or Gaussian mean updates are included.", "",
  "The numerical package sources are the original frozen full-study archives: cmbridge 0.3.0.9020 and lmtp 1.6.0.9021. Hashes are verified before use. Seeds for the original sample sizes and first 200 replications retain their original mapping; all fits in this rerun are computed afresh on GitHub. References are used only for evaluation, never fitting or penalty selection.", "",
  "## Estimates and confidence intervals", "",
  "Coverage below uses returned estimators as its denominator. Failed estimators, pending datasets, and coverage counting failures as producing no interval are also reported. At 500 successful replications, the simulation standard error of 95% coverage is about one percentage point. A partially completed subset may depend on fitting difficulty; it is not a final coverage study.", "")
for (h in 2:1) {
  lines <- c(lines, sprintf("### Outcome at time %d", h + 1L), "")
  z <- s[horizon == h][order(mechanism, n, estimator)]
  lines <- c(lines, table(z[, .(Treatment = labels[mechanism], n,
    Estimator = toupper(estimator), Returned = successful, Failed = failed, Pending = pending,
    Truth = sprintf("%.5f", truth), Mean = sprintf("%.5f", mean_estimate),
    Bias = sprintf("%.5f", bias), RMSE = sprintf("%.5f", rmse),
    SD = sprintf("%.5f", empirical_sd), MeanSE = sprintf("%.5f", mean_se),
    Coverage = sprintf("%.1f%%", 100 * coverage),
    MCinterval = sprintf("[%.1f%%, %.1f%%]", 100 * coverage_mc_lower, 100 * coverage_mc_upper))]))
}
lines <- c(lines, "## Scientific graphs", "")
for (name in full500_mechanisms) for (metric in c("bias", "root-n-bias", "coverage", "standard-errors"))
  lines <- c(lines, sprintf("![%s: %s](figures/%s-%s.png)", labels[[name]], metric, name, metric))
lines <- c(lines, "![Mean estimates and true means](figures/correctly-specified-curves.png)", "",
  "## Mean EIF components", "",
  "The mean sequential component is evaluated at the true parameter. Its sum with the mean bridge/adjoint component equals the mean estimation error. Both components are estimated with the same training-only splits.", "")
components <- fread(file.path(outdir, "eif-component-means.csv"))
lines <- c(lines, table(components[order(horizon, mechanism, n, estimator), .(
  Treatment = labels[mechanism], n, Outcome = horizon + 1L, Estimator = toupper(estimator),
  Returned = successful, Sequential = sprintf("%.6f", mean_sequential_eif),
  BridgeAdjoint = sprintf("%.6f", mean_bridge_adjoint_eif))]),
  "## Conditional equations and failures", "",
  "The saved population diagnostics evaluate fitted functions over the exact finite DGP support. Adjoint solutions can be nonunique, so distance to a selected reference solution alone is not a consistency criterion. The realized category dictionary depends on observed training combinations; unseen combinations retain the original continuation rule. The enlarged sample sizes do not change those learners.", "",
  "[Conditional equations and population contributions](population-error-by-outcome-time.csv), [candidate failures](nested-candidate-failures.csv), [failed estimators](errors.csv), [penalties](penalty_and_weight_selections.csv), [ensemble weights](ensemble_weight_summary.csv), and [runtimes](job_log.csv) retain the actual numerical records.", "",
  "[All estimates and intervals](replicates.csv), [summary and simulation uncertainty](summary.csv), [coverage including failed fits](coverage-including-failures.csv), [EIF components](eif-component-means.csv), [source hashes](source-manifest.json), [checkpoint hashes](checkpoint-manifest.json), and [artifact provenance](artifact-provenance.json).", "",
  "The numerical results, including any unexpected bias or undercoverage, will be reported as observed. This rerun changes replication counts, sample sizes and computing platform; it does not change the fitting criteria to obtain a desired result.")
writeLines(lines, file.path(outdir, "REPORT.md"))
source("studies/longitudinal/github-500/bias_variance.R")
augment_bias_variance_report(outdir)
# Preserve complete tables in the artifacts while avoiding duplicate large CSVs.
status <- system2("python3", c("scripts/compress_tables.py", shQuote(outdir)))
stopifnot(status == 0L)
for (path in list.files(outdir, "[.]csv[.]gz$", full.names = TRUE)) {
  original <- sub("[.]gz$", "", path)
  if (file.exists(original)) unlink(original)
}
