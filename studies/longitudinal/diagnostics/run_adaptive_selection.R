source("studies/longitudinal/diagnostics/adaptive_setup.R")
out <- adaptive_output
dir.create(file.path(out, "jobs"), recursive = TRUE, showWarnings = FALSE)
selected <- fread("results/longitudinal/ensemble-statistic-check/selected-seeds.csv")[mechanism == "discrete_dose"]
design <- selected[, CJ(time = c(2L, 3L), fold = 1:3, selection = c("robins", "syrgkanis")),
  by = .(mechanism, selected, seed, replicate)]
design[, n := 4000L]
sources <- c("studies/longitudinal/dgp.R", "studies/longitudinal/study.R",
  "studies/longitudinal/diagnostics/bridge_adjoint_setup.R",
  "studies/longitudinal/diagnostics/adaptive_setup.R",
  "studies/longitudinal/diagnostics/run_adaptive_selection.R")
package_sources <- list.files("../cmbridge/R", full.names = TRUE)
hashes <- setNames(vapply(c(sources, package_sources), function(path)
  digest::digest(file = path, algo = "sha256"), ""), c(sources, package_sources))
fingerprint <- digest::digest(list(hashes, design, adaptive_controls), algo = "sha256")
if (file.exists(file.path(out, "fingerprint.txt"))) stopifnot(readLines(file.path(out, "fingerprint.txt"))[1L] == fingerprint)
if (!identical(Sys.getenv("ADAPTIVE_PREPARED"), "true")) {
  fwrite(selected, file.path(out, "selected-seeds.csv"))
  writeLines(fingerprint, file.path(out, "fingerprint.txt"))
  fwrite(design, file.path(out, "design.csv"))
  jsonlite::write_json(as.list(hashes), file.path(out, "source-manifest.json"), pretty = TRUE, auto_unbox = TRUE)
  writeLines(capture.output(sessionInfo()), file.path(out, "session.txt"))
  fwrite(require_valid_mechanism(make_mechanism("discrete_dose")), file.path(out, "dgp-assumptions.csv"))
}
if (identical(Sys.getenv("ADAPTIVE_PREPARE_ONLY"), "true")) quit(save="no",status=0)

one <- function(i) {
  z <- design[i]; key <- sprintf("seed%d-t%d-fold%d-%s", z$seed, z$time, z$fold, z$selection)
  path <- file.path(out, "jobs", paste0(key, ".rds"))
  if (file.exists(path)) {stopifnot(readRDS(path)$fingerprint == fingerprint); return(TRUE)}
  g <- make_mechanism("discrete_dose"); set.seed(z$seed); d <- draw_data(4000L, g)
  original <- readRDS(sprintf("results/longitudinal/jobs/discrete_dose-n4000-r%03d.rds", z$replicate))
  task <- study_task(d, g, folds = original$folds, learner_folds = original$learner_folds,
    learner_groups = 3L, balance_measurement = TRUE)$task
  nu <- true_values(d, g); s <- z$time - 1L
  train <- task$folds[[z$fold]]$training_set; validation <- task$folds[[z$fold]]$validation_set
  H <- task$vars$history("A", s); A <- task$vars$A[[s]]
  B <- as.matrix(task$natural[, c(H, A), drop = FALSE])
  V <- as.matrix(cbind(task$natural[, H, drop = FALSE], d[, c(paste0("C", z$time, "_covariate"), paste0("Y", z$time))]))
  M <- d[[paste0("R", z$time)]]
  phi <- apply(nu$ratios[, seq_len(s), drop = FALSE], 1L, prod) * ifelse(M == 1L, d[[paste0("Y", z$time)]], 0)
  nested <- lmtp:::make_bridge_nested_folds(task$id[train], d[train, c("R2", "R3")], task$learner_folds[[z$fold]])
  libraries <- lapply(c(TRUE, FALSE), function(bridge) {
    library <- cm_library(bridge = bridge)
    for (j in seq_along(library)) {
      library[[j]]$control$penalty_ids <- task$id[train]
      library[[j]]$control$penalty_folds <- nested
    }
    library
  })
  cat(format(Sys.time()), "START", key, "\n"); flush.console()
  started <- proc.time()[3L]
  models <- lapply(c("bridge", "adjoint"), function(type) {
    warnings <- character()
    result <- tryCatch(withCallingHandlers({
      if (type == "bridge") fit <- cmbridge::fit_bridge_ensemble(B[train, , drop = FALSE],
        V[train, , drop = FALSE], M[train], libraries[[1L]], fold_id = task$learner_folds[[z$fold]],
        selection = z$selection, selection_control = adaptive_controls) else
        fit <- cmbridge::fit_adjoint_ensemble(B[train, , drop = FALSE], V[train, , drop = FALSE],
          M[train], phi[train], libraries[[2L]], fold_id = task$learner_folds[[z$fold]],
          selection = z$selection, selection_control = adaptive_controls)
      stopifnot(!fit$psd_projection$applied, all(is.finite(fit$weights)), all(fit$weights >= 0),
        abs(sum(fit$weights) - 1) < 1e-10)
      fit
    }, warning = function(w) {warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")}),
      error = function(e) list(error = conditionMessage(e), condition = e))
    result$captured_warnings <- unique(warnings)
    cat(format(Sys.time()), "DONE", key, type, if (is.null(result$error)) "OK" else result$error, "\n"); flush.console()
    result
  })
  names(models) <- c("bridge", "adjoint")
  result <- c(models, list(design = as.list(z), training = train, validation = validation,
    fold_id = task$learner_folds[[z$fold]], data_sha256 = digest::digest(d, algo = "sha256"),
    fingerprint = fingerprint, seconds = unname(proc.time()[3L] - started),
    package_version = as.character(packageVersion("cmbridge"))))
  temporary <- paste0(path, ".tmp"); saveRDS(result, temporary, compress = "gzip")
  stopifnot(file.rename(temporary, path))
  TRUE
}
workers <- as.integer(Sys.getenv("ADAPTIVE_WORKERS", "6"))
indices <- seq_len(nrow(design))
if (nzchar(Sys.getenv("ADAPTIVE_TASKS"))) indices <- as.integer(strsplit(Sys.getenv("ADAPTIVE_TASKS"), ",")[[1L]])
answers <- parallel::mclapply(indices, one, mc.cores = min(workers, length(indices)),
  mc.preschedule = FALSE, mc.set.seed = FALSE)
stopifnot(all(vapply(answers, isTRUE, TRUE)))
if (length(list.files(file.path(out, "jobs"), "[.]rds$")) == nrow(design))
  writeLines(format(Sys.time(), tz = "America/New_York", usetz = TRUE), file.path(out, "FITTING-COMPLETED.txt"))
