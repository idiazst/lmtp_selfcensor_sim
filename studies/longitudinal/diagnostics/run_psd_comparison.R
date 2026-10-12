source("studies/longitudinal/diagnostics/psd_setup.R")
dir.create(file.path(psd_output, "jobs"), recursive = TRUE, showWarnings = FALSE)
design <- data.table(mechanism = "discrete_dose", n = 4000L,
  replicate = 1:100, seed = 5203000L + 1:100)
sources <- c("studies/longitudinal/dgp.R", "studies/longitudinal/study.R", "scripts/setup.R",
  "studies/longitudinal/diagnostics/bridge_adjoint_setup.R",
  "studies/longitudinal/diagnostics/psd_setup.R",
  "studies/longitudinal/diagnostics/psd_shared_fits.R",
  "studies/longitudinal/diagnostics/run_psd_comparison.R",
  list.files("../cmbridge/R", full.names = TRUE), list.files("../lmtp/R", full.names = TRUE),
  "../cmbridge/DESCRIPTION", "../lmtp/DESCRIPTION")
hashes <- setNames(vapply(sources, function(path) digest::digest(file = path, algo = "sha256"), ""), sources)
fingerprint <- digest::digest(list(hashes, design, cm_library(bridge = TRUE), cm_library(bridge = FALSE)), algo = "sha256")
if (file.exists(file.path(psd_output, "fingerprint.txt")))
  stopifnot(readLines(file.path(psd_output, "fingerprint.txt"))[1L] == fingerprint)
fwrite(design, file.path(psd_output, "design.csv"))
writeLines(fingerprint, file.path(psd_output, "fingerprint.txt"))
jsonlite::write_json(as.list(hashes), file.path(psd_output, "source-manifest.json"), pretty = TRUE, auto_unbox = TRUE)
if (identical(Sys.getenv("PSD_PREPARE_ONLY"), "true")) {
  writeLines(capture.output(sessionInfo()), file.path(psd_output, "session.txt"))
  fwrite(require_valid_mechanism(make_mechanism("discrete_dose")), file.path(psd_output, "dgp-assumptions.csv"))
  saveRDS(list(bridge = cm_library(bridge = TRUE), adjoint = cm_library(bridge = FALSE),
    regression = sl_library, ratio = trt_library, control = original_study_control(3L)),
    file.path(psd_output, "original-specification.rds"))
  quit(save = "no", status = 0)
}
indices <- if (nzchar(Sys.getenv("PSD_TASKS"))) as.integer(strsplit(Sys.getenv("PSD_TASKS"), ",")[[1L]]) else 1:100
stopifnot(all(indices %in% 1:100))
for (i in indices) {
  z <- design[i]
  canonical_references <- NULL; canonical_data <- NULL
  for (mode in c("psd", "raw")) {
    path <- file.path(psd_output, "jobs", sprintf("r%03d-%s.rds", i, mode))
    if (file.exists(path)) {
      stopifnot(identical(readRDS(path)$fingerprint, fingerprint)); next
    }
    psd_project <- mode == "psd"
    references <- vector("list", 3L); task_reference <- NULL
    reused_response_models <- integer(3L)
    callback <- function(fitted, task, p, pt, g, fold) {
      if (!psd_project && !is.null(canonical_references))
        reused_response_models[fold] <<- psd_restore_response_cache(fitted,
          canonical_references[[fold]], task, canonical_data, g, fold)
      references[[fold]] <<- fitted; task_reference <<- task
    }
    started <- Sys.time(); warnings <- character()
    cat(format(started), "START", i, mode, "\n"); flush.console()
    answer <- tryCatch(withCallingHandlers({
      result <- run_dataset(z$mechanism, z$n, z$replicate, z$seed, store_scores = TRUE,
        nuisance_callback = callback)
      g <- make_mechanism("discrete_dose"); pt <- study_task(result$population, g)$task
      audit <- psd_audit(references, task_reference, result$data, result$population, pt, g)
      c(result, audit)
    }, warning = function(w) {warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")}),
      error = function(e) list(design = as.list(z), outer_error = conditionMessage(e), condition = e))
    answer$mode <- mode; answer$fingerprint <- fingerprint; answer$warnings <- unique(warnings)
    answer$started <- started; answer$finished <- Sys.time()
    answer$seconds <- as.numeric(difftime(answer$finished, answer$started, units = "secs"))
    answer$reused_response_models <- sum(reused_response_models)
    if (is.null(answer$outer_error)) {
      answer$data_sha256 <- digest::digest(answer$data, algo = "sha256")
      answer$folds_sha256 <- digest::digest(list(answer$folds, answer$learner_folds), algo = "sha256")
    }
    temporary <- paste0(path, ".tmp"); saveRDS(answer, temporary, compress = "gzip")
    stopifnot(file.rename(temporary, path))
    if (mode == "psd" && is.null(answer$outer_error)) {
      canonical_references <- references; canonical_data <- answer$data
    }
    cat(format(Sys.time()), "DONE", i, mode, sprintf("%.1fs", answer$seconds),
      if (is.null(answer$outer_error)) paste("estimator errors:", nrow(answer$errors)) else answer$outer_error, "\n")
    flush.console(); rm(answer, references); gc()
    references <- vector("list", 3L)
  }
}
