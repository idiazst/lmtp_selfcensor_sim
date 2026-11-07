# Invoked from the simulation repository root by run.py.
args <- commandArgs(TRUE)
stopifnot(length(args) == 6L)
design <- match.arg(args[1], c("observed", "full"))
n <- as.integer(args[2])
replicate <- as.integer(args[3])
variant <- match.arg(args[4], c("baseline", "optimized"))
out <- args[5]
fingerprint <- args[6]
seed <- 7200000L + n + replicate
source("studies/four-dose-pilot/common.R")
source(if (design == "observed") "studies/longitudinal/four_dose_pilot.R" else
  "studies/full-history/four_dose_pilot.R")
library(lmtp)
future::plan(future::sequential)
data.table::setDTthreads(1L)
options(cmbridge.cache_penalty_features = variant == "optimized",
        lmtp.cache_pilot_responses = variant == "optimized")

dat <- four_dose_data(n, seed, design)
crossfit <- Sys.getenv("FOUR_DOSE_CROSSFIT", "outer")
outer_folds <- as.integer(Sys.getenv("FOUR_DOSE_OUTER_FOLDS", "4"))
folds <- four_dose_folds(dat, seed, outer_folds)
data_hash <- digest::digest(dat, algo = "sha256")
fold_hash <- digest::digest(folds, algo = "sha256")
stopifnot(identical(sort(unlist(lapply(folds, "[[", "validation_set"))), seq_len(n)))
spec <- four_dose_specification(crossfit)
fit <- if (design == "observed")
  four_dose_observed_adapter(dat, folds, spec, seed, variant) else
  four_dose_full_adapter(dat, folds, spec, seed, variant)

for (method in c("sdr", "tmle")) {
  path <- file.path(out, paste0(method, ".rds"))
  if (file.exists(path)) {
    saved <- readRDS(path)
    stopifnot(saved$fingerprint == fingerprint, saved$data_hash == data_hash,
              saved$fold_hash == fold_hash, identical(saved$method, method))
    next
  }
  cat(format(Sys.time()), "START", design, n, replicate, variant, method, "\n")
  flush.console()
  warnings <- new.env(parent = emptyenv())
  fail <- ""
  set.seed(seed + if (method == "sdr") 131L else 137L)
  started <- proc.time()[["elapsed"]]
  result <- tryCatch(withCallingHandlers(fit(method), warning = function(w) {
    msg <- conditionMessage(w)
    if (!exists(msg, warnings, inherits = FALSE)) assign(msg, 0L, warnings)
    warnings[[msg]] <- warnings[[msg]] + 1L
    invokeRestart("muffleWarning")
  }), error = function(e) { fail <<- conditionMessage(e); NULL })
  elapsed <- proc.time()[["elapsed"]] - started
  warning_counts <- unlist(as.list(warnings))
  checkpoint <- list(design = design, n = n, rep = replicate, seed = seed, variant = variant,
    crossfit = crossfit, outer_folds = outer_folds,
    method = method, data_hash = data_hash, fold_hash = fold_hash, fingerprint = fingerprint,
    elapsed = elapsed, warnings = names(warning_counts), warning_counts = warning_counts,
    error = fail, result = result)
  saveRDS(checkpoint, paste0(path, ".part"))
  stopifnot(file.rename(paste0(path, ".part"), path))
  cat(format(Sys.time()), "SAVED", method, round(elapsed, 2), "seconds", fail, "\n")
  flush.console()
}
