source_dir <- Sys.getenv("MI_LMTP_SOURCE", "/Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/studies/imputation/neither")
Sys.setenv(MI_STUDY_SOURCE = source_dir)
source(file.path(source_dir, "original-helpers.R"))
corrected_root <- Sys.getenv("MI_LMTP_ROOT", "/Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/results/imputation/neither")

# The original helper file and installed packages are retained byte for byte.
# Only assertion/diagnostic traces are installed; no numerical routine is replaced.
corrected_hooks <- function() {
  trace(".saturated_path_setup", where = asNamespace("lmtp"), print = FALSE,
    tracer = quote(get("mi_assert_support", .GlobalEnv)(X, "penalty training")))
  trace("SL.saturated_l1", where = asNamespace("lmtp"), print = FALSE,
    tracer = quote(get("mi_assert_support", .GlobalEnv)(X, "final regression")))
  trace(".saturated_penalty_selection", where = asNamespace("lmtp"), print = FALSE,
    exit = quote({
      audit <- get("mi_audit", .GlobalEnv)
      value <- returnValue()
      audit$penalties[[length(audit$penalties) + 1L]] <- value[c("scale", "status", "penalty_cv", "boundary_history")]
    }))
}

corrected_imputations <- function(old) {
  d <- old$data; m <- old$results$mi$m
  stopifnot(m == 50L)
  seed <- old$data_seed + 300000L + match(old$scenario, mi_scenarios) * 1000L
  set.seed(seed)
  ry <- d$R2 == 1L
  stopifnot(all(is.na(d$Y2) == !ry))
  X <- with(d, cbind(W, A1, W * A1))
  completed_y <- matrix(d$Y2, nrow(d), m)
  Q <- U <- numeric(m)
  # Generate all imputations BEFORE invoking lmtp, whose fitting also uses RNG.
  for (j in seq_len(m)) {
    completed_y[!ry, j] <- mice::mice.impute.logreg(d$Y2, ry, X, wy = !ry)
    complete <- d; complete$Y2 <- completed_y[, j]
    check <- mi_complete_estimate(complete)
    Q[j] <- check$estimate; U[j] <- check$variance
  }
  err <- c(estimates = max(abs(Q - old$results$mi$complete_estimates)),
    variances = max(abs(U - old$results$mi$complete_variances)))
  stopifnot(max(err) < 1e-14, all(completed_y %in% c(0, 1)),
    all(completed_y[ry, ] == d$Y2[ry]))
  list(y = completed_y, seed = seed, reconstruction_error = err,
    sha256 = digest::digest(completed_y, algo = "sha256"))
}

corrected_splits <- function(observed) {
  force(observed)
  function(ids) {
    # Stacked classifier data duplicate each person's ID; keep copies together.
    unique_ids <- sort(unique(as.character(ids)))
    rows <- as.integer(unique_ids)
    stopifnot(!anyNA(rows), all(rows >= 1L & rows <= nrow(observed)))
    labels <- mi_balanced_labels(unique_ids, observed[rows, c("W", "A1", "R2")])
    mi_audit$splits[[length(mi_audit$splits) + 1L]] <- list(ids = unique_ids, labels = labels)
    labels[match(as.character(ids), unique_ids)]
  }
}

corrected_one_fit <- function(d, old, method, seed, keep_fit = FALSE) {
  stopifnot(identical(names(d), c("W", "A1", "Y2")), !anyNA(d))
  mi_reset_audit(); set.seed(seed)
  control <- mi_control()
  control$.nested_split_function <- corrected_splits(old$data)
  args <- list(data = d, trt = "A1", outcome = "Y2", baseline = "W",
    shift = function(data, trt) rep(1, nrow(data)), mtp = FALSE,
    outcome_type = "binomial", cens = NULL,
    learners_outcome = "SL.saturated_l1_cv", learners_trt = "SL.saturated_l1_cv",
    folds = old$results$sdr$folds, learner_folds = old$results$sdr$learner_folds,
    control = control)
  fit <- switch(method, tmle = do.call(lmtp::lmtp_tmle, args),
    sdr = do.call(lmtp::lmtp_sdr, args), stop("Unknown estimator"))
  stopifnot(inherits(fit, "lmtp"), identical(fit$estimator, toupper(method)),
    identical(fit$folds, args$folds), identical(fit$learner_folds, args$learner_folds),
    !length(mi_audit$bad_support), all(is.finite(fit$estimate@eif)),
    all(fit$density_ratios[d$A1 == 0L, 1L] == 0))
  # Independent one-time-point EIF reconstruction from the saved regression fits.
  q <- q1 <- numeric(nrow(d)); epsilon <- numeric(length(fit$folds))
  for (k in seq_along(fit$folds)) {
    rows <- fit$folds[[k]]$validation_set
    nd <- d[rows, ]; shifted <- transform(nd, A1 = 1)
    model <- fit$fits_m[[k]][[1L]]
    tol <- if (method == "tmle") 1e-5 else NULL
    initial <- as.numeric(predict(model, nd, tol = tol))
    initial1 <- as.numeric(predict(model, shifted, tol = tol))
    if (method == "tmle") {
      difference <- qlogis(fit$outcome_reg[rows, 1L]) - qlogis(initial1)
      stopifnot(diff(range(difference)) < 1e-8)
      epsilon[k] <- mean(difference)
      q[rows] <- plogis(qlogis(initial) + epsilon[k])
      q1[rows] <- plogis(qlogis(initial1) + epsilon[k])
    } else {
      q[rows] <- initial; q1[rows] <- initial1
    }
  }
  score <- q1 + fit$density_ratios[, 1L] * (d$Y2 - q)
  score_error <- max(abs(score - fit$estimate@eif))
  estimate_error <- abs(mean(score) - fit$estimate@x)
  stopifnot(score_error < 1e-8, estimate_error < 1e-7)
  variance <- var(fit$estimate@eif) / nrow(d)
  stopifnot(is.finite(variance), variance > 0)
  audit <- list(support_checks = length(mi_audit$support),
    minimum_cell_count = min(unlist(lapply(mi_audit$support, `[[`, "counts"))),
    support_failures = length(mi_audit$bad_support),
    penalty_selections = length(mi_audit$penalties),
    noninterior_selections = sum(vapply(mi_audit$penalties, function(p) !grepl("^interior", p$status), TRUE)),
    selected_scales = vapply(mi_audit$penalties, `[[`, 0, "scale"),
    selected_status = vapply(mi_audit$penalties, `[[`, "", "status"),
    score_error = score_error, estimate_error = estimate_error,
    nested_split_hash = digest::digest(mi_audit$splits, algo = "sha256"))
  list(estimate = fit$estimate@x, variance = variance, audit = audit,
    first_fit = if (keep_fit) fit else NULL,
    first_audit = if (keep_fit) as.list(mi_audit) else NULL)
}

corrected_pool <- function(fits, n) {
  bad <- which(vapply(fits, function(f) !is.null(f$error), TRUE))
  if (length(bad)) return(list(error = sprintf("%d of %d completed-data fits failed; no partial pooling", length(bad), length(fits)), failed_imputations = bad))
  Q <- vapply(fits, `[[`, 0, "estimate"); U <- vapply(fits, `[[`, 0, "variance")
  p <- mice::pool.scalar(Q, U, n = n, k = 5L)
  manual_t <- mean(U) + (1 + 1 / length(Q)) * var(Q)
  stopifnot(abs(p$qbar - mean(Q)) < 1e-14, abs(p$t - manual_t) < 1e-14)
  se <- sqrt(p$t); critical <- qt(.975, p$df)
  list(estimate = p$qbar, se = se, lower = p$qbar - critical * se,
    upper = p$qbar + critical * se, df = p$df, m = length(Q),
    complete_estimates = Q, complete_variances = U, pooling = p,
    imputation_mcse = sqrt(p$b / length(Q)))
}

corrected_job <- function(input, output) {
  if (file.exists(output)) return(invisible(output))
  started <- proc.time()[3L]; old <- readRDS(input)
  stopifnot(is.null(old$results$sdr$error), is.null(old$results$tmle$error))
  imputations <- corrected_imputations(old)
  completed <- old$data[c("W", "A1", "Y2")]
  complete_fits <- list(tmle = vector("list", 50L), sdr = vector("list", 50L))
  for (j in seq_len(50L)) {
    completed$Y2 <- imputations$y[, j]
    # Same seed and outer splits for the two procedures; independent of MI RNG.
    seed <- old$data_seed + 500000L + j
    for (method in c("tmle", "sdr")) {
      warnings <- character(); t0 <- proc.time()[3L]
      fit <- tryCatch(withCallingHandlers(
        corrected_one_fit(completed, old, method, seed, keep_fit = j == 1L),
        warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }),
        error = function(e) list(error = conditionMessage(e), error_class = class(e), audit = as.list(mi_audit)))
      fit$seconds <- unname(proc.time()[3L] - t0); fit$warnings <- unique(warnings)
      complete_fits[[method]][[j]] <- fit
      if (!is.null(fit$error)) cat(basename(input), j, method, "ERROR", fit$error, "\n")
    }
  }
  results <- list()
  for (method in c("tmle", "sdr")) {
    z <- corrected_pool(complete_fits[[method]], old$n)
    z$seconds <- sum(vapply(complete_fits[[method]], `[[`, 0, "seconds"))
    results[[paste0("mi_", method)]] <- z
  }
  results$bridge_tmle <- old$results$tmle; results$bridge_sdr <- old$results$sdr
  result <- list(n = old$n, replicate = old$replicate, scenario = old$scenario, phase = old$phase,
    data_seed = old$data_seed, input = normalizePath(input), input_sha256 = digest::digest(file = input, algo = "sha256"),
    data = old$data, imputations = imputations, results = results, complete_fits = complete_fits,
    bridge_warnings = old$warnings[c("tmle", "sdr")],
    source_fingerprint = Sys.getenv("MI_LMTP_FINGERPRINT"),
    original_source_fingerprint = old$source_fingerprint,
    package_versions = old$package_versions, seconds = unname(proc.time()[3L] - started))
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  temp <- paste0(output, ".", Sys.getpid(), ".tmp")
  saveRDS(result, temp, compress = "gzip"); stopifnot(file.rename(temp, output))
  cat(format(Sys.time(), "%H:%M:%S"), basename(input),
    paste(names(results)[1:2], vapply(results[1:2], function(z) if (is.null(z$error)) sprintf("%.6f", z$estimate) else z$error, ""), collapse = "; "),
    sprintf("(%.1fs)", result$seconds), "\n"); flush.console()
  invisible(output)
}
