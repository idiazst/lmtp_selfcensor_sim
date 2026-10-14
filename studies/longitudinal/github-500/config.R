# The numerical implementation and libraries are the original full-study builds.
source("studies/longitudinal/study.R")
full500_sizes <- c(500L, 1000L, 4000L, 10000L)
full500_mechanisms <- c("binary_longitudinal", "discrete_dose")
full500_design <- CJ(mechanism = full500_mechanisms, n = full500_sizes, replicate = 1:500)
full500_design[, seed := 5000000L + match(mechanism, full500_mechanisms) * 100000L +
  match(n, full500_sizes) * 1000L + replicate]
full500_design[, job := sprintf("%s-n%d-r%03d", mechanism, n, replicate)]
full500_sources <- c("scripts/setup.R", "dependencies/package-pins.json",
  "studies/longitudinal/dgp.R", "studies/longitudinal/study.R",
  "studies/longitudinal/github-500/config.R", "studies/longitudinal/github-500/run_one.R",
  "dependencies/cmbridge_0.3.0.9020.tar.gz", "dependencies/lmtp_1.6.0.9021.tar.gz")
full500_hashes <- setNames(vapply(full500_sources, function(path)
  digest::digest(file = path, algo = "sha256"), ""), full500_sources)
full500_fingerprint <- digest::digest(list(full500_hashes, full500_design,
  cm_library(bridge = TRUE), cm_library(bridge = FALSE), sl_library, trt_library), algo = "sha256")

full500_prepare <- function(out) {
  dir.create(file.path(out, "jobs"), recursive = TRUE, showWarnings = FALSE)
  fwrite(full500_design, file.path(out, "design.csv"))
  writeLines(full500_fingerprint, file.path(out, "source-fingerprint.txt"))
  jsonlite::write_json(as.list(full500_hashes), file.path(out, "source-manifest.json"),
    pretty = TRUE, auto_unbox = TRUE)
  saveRDS(list(workers = 2L, replications = 500L, sizes = full500_sizes,
    mechanisms = full500_mechanisms, dose_levels = 0:3, all_correct = TRUE,
    learner_groups = 3L, measurement_balanced = TRUE, visits = "missing_both",
    projection = "PSD", statistic = "U", platform = "GitHub Actions"),
    file.path(out, "design-details.rds"))
  saveRDS(list(bridge = cm_library(bridge = TRUE), adjoint = cm_library(bridge = FALSE),
    regression = sl_library, ratio = trt_library, control = study_control(3L)),
    file.path(out, "original-specification.rds"))
  fwrite(data.table(estimator = c("sdr", "tmle"), beta_correct = TRUE,
    lambda_correct = TRUE, ratio_correct = TRUE, m_correct = TRUE),
    file.path(out, "specifications.csv"))
  validations <- lapply(full500_mechanisms, function(name) {
    g <- make_mechanism(name); a <- require_valid_mechanism(g)
    stopifnot(max(abs(exact_truth(g) - backward_truth(g))) < 1e-12)
    a
  })
  fwrite(rbindlist(validations), file.path(out, "dgp-assumptions.csv"))
  fwrite(rbindlist(lapply(full500_mechanisms, function(name)
    data.table(mechanism = name, horizon = 1:2, truth = exact_truth(make_mechanism(name))))),
    file.path(out, "truth.csv"))
  writeLines(capture.output(sessionInfo()), file.path(out, "session.txt"))
}
