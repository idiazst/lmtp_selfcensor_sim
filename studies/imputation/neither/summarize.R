args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(args[1L])
old_root <- "/Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/.runtime"
.libPaths(c(file.path(old_root, "library"), .Library), include.site = FALSE)
files <- list.files(file.path(root, "jobs"), "\\.rds$", full.names = TRUE)
if (!length(files)) stop("No completed corrected datasets")
methods <- c("mi_tmle", "mi_sdr", "bridge_tmle", "bridge_sdr")
labels <- c("MI + TMLE", "MI + SDR", "Bridge TMLE", "Bridge SDR")
scenarios <- intersect(c("mar_only", "shadow_only", "both", "neither"), unique(vapply(files, function(p) readRDS(p)$scenario, "")))
rows <- audits <- list(); fingerprints <- character()
for (path in files) {
  x <- readRDS(path); fingerprints <- c(fingerprints, x$source_fingerprint)
  for (method in methods) {
    r <- x$results[[method]]
    error <- if (is.null(r$error)) "" else r$error
    take <- function(name) if (!nzchar(error) && !is.null(r[[name]])) r[[name]] else NA_real_
    is_mi <- startsWith(method, "mi_")
    if (is_mi) {
      fits <- x$complete_fits[[sub("mi_", "", method)]]
      good <- Filter(function(z) is.null(z$error), fits)
      a <- lapply(good, `[[`, "audit")
      total <- function(nm) sum(vapply(a, `[[`, 0, nm))
      maximum <- function(nm) if (length(a)) max(vapply(a, `[[`, 0, nm)) else NA_real_
      diagnostic <- data.frame(completed_data_calls = length(fits),
        failed_calls = length(fits) - length(good), support_checks = total("support_checks"),
        support_failures = total("support_failures") + sum(vapply(Filter(function(z) !is.null(z$error), fits), function(z) length(z$audit$bad_support), 0L)),
        minimum_cell_count = if (length(a)) min(vapply(a, `[[`, 0, "minimum_cell_count")) else NA_real_,
        penalty_selections = total("penalty_selections"), noninterior_selections = total("noninterior_selections"),
        score_error = maximum("score_error"), estimate_error = maximum("estimate_error"),
        reconstruction_error = max(x$imputations$reconstruction_error),
        candidate_failures = 0L, landweber_iteration_stops = 0L)
      warnings <- unique(unlist(lapply(fits, `[[`, "warnings")))
    } else {
      a <- r$audit
      candidates <- unlist(lapply(a$cm, `[[`, "candidates"), recursive = FALSE)
      solver_rows <- Filter(function(z) !is.null(z$solver$stopped_by_tolerance), candidates)
      diagnostic <- data.frame(completed_data_calls = 0L, failed_calls = 0L,
        support_checks = length(a$support), support_failures = length(a$bad_support),
        minimum_cell_count = min(unlist(lapply(a$support, `[[`, "counts"))),
        penalty_selections = length(a$penalties),
        noninterior_selections = sum(vapply(a$penalties, function(z) !grepl("^interior", z$status), TRUE)),
        score_error = r$score_error, estimate_error = r$estimate_error, reconstruction_error = NA_real_,
        candidate_failures = sum(vapply(a$cm, function(z) length(z$failures), 0L)),
        landweber_iteration_stops = sum(vapply(solver_rows, function(z) !isTRUE(z$solver$stopped_by_tolerance), TRUE)))
      warnings <- x$bridge_warnings[[sub("bridge_", "", method)]]
    }
    rows[[length(rows) + 1L]] <- data.frame(scenario = x$scenario, n = x$n,
      replicate = x$replicate, method = method, estimate = take("estimate"),
      se = take("se"), lower = take("lower"), upper = take("upper"), truth = .75,
      covered = if (nzchar(error)) NA else r$lower <= .75 && r$upper >= .75,
      seconds = r$seconds, error = error, imputation_mcse = take("imputation_mcse"),
      warnings = paste(unique(warnings), collapse = " | "))
    audits[[length(audits) + 1L]] <- cbind(data.frame(scenario = x$scenario, n = x$n,
      replicate = x$replicate, method = method), diagnostic)
  }
}
stopifnot(all(nzchar(fingerprints)))
writeLines(unique(fingerprints), file.path(root, "source-fingerprints.txt"))
r <- do.call(rbind, rows); audit <- do.call(rbind, audits)
stopifnot(!anyDuplicated(r[c("scenario", "n", "replicate", "method")]))
write.csv(r, file.path(root, "replicates.csv"), row.names = FALSE)
write.csv(audit, file.path(root, "audit-summary.csv"), row.names = FALSE)
groups <- split(r, interaction(r$scenario, r$n, r$method, drop = TRUE))
summary <- do.call(rbind, lapply(groups, function(z) {
  s <- z[!nzchar(z$error), ]; n <- nrow(s); total <- nrow(z)
  coverage <- if (n) mean(s$covered) else NA_real_
  data.frame(scenario = z$scenario[1], n = z$n[1], method = z$method[1],
    completed = total, successful = n, failures = total - n,
    mean_estimate = if (n) mean(s$estimate) else NA,
    bias = if (n) mean(s$estimate - .75) else NA,
    bias_mcse = if (n > 1) sd(s$estimate) / sqrt(n) else NA,
    empirical_sd = if (n > 1) sd(s$estimate) else NA,
    mean_se = if (n) mean(s$se) else NA,
    mse = if (n) mean((s$estimate - .75)^2) else NA,
    mse_mcse = if (n > 1) sd((s$estimate - .75)^2) / sqrt(n) else NA,
    rmse = if (n) sqrt(mean((s$estimate - .75)^2)) else NA,
    coverage = coverage, coverage_mcse = if (n) sqrt(coverage * (1 - coverage) / n) else NA,
    covering_fraction_including_failures = sum(s$covered) / total,
    mean_interval_width = if (n) mean(s$upper - s$lower) else NA,
    mean_seconds = mean(z$seconds),
    mean_imputation_mcse_over_se = if (n && any(is.finite(s$imputation_mcse))) mean(s$imputation_mcse / s$se) else NA)
}))
summary <- summary[order(match(summary$scenario, scenarios), summary$n, match(summary$method, methods)), ]
row.names(summary) <- NULL
write.csv(summary, file.path(root, "summary.csv"), row.names = FALSE)
pair <- merge(r[r$method == "mi_tmle", ], r[r$method == "mi_sdr", ], by = c("scenario", "n", "replicate"), suffixes = c("_tmle", "_sdr"))
pair$difference_tmle_minus_sdr <- pair$estimate_tmle - pair$estimate_sdr
write.csv(pair[c("scenario", "n", "replicate", "difference_tmle_minus_sdr")], file.path(root, "paired-mi-differences.csv"), row.names = FALSE)
design <- read.csv(file.path(root, "design.csv")); complete <- length(files) == nrow(design)
status <- if (complete) "Complete" else "Preliminary"
md <- c(paste0("# ", status, " corrected MI + lmtp comparison (", basename(root), ")"), "",
  sprintf("%d of %d datasets saved; %d of %d returned method estimates.", length(files), nrow(design), sum(!nzchar(r$error)), nrow(r)), "",
  "The MI arms run the exported standard lmtp_tmle and lmtp_sdr functions on each of 50 completed datasets, then pool estimates and complete-data EIF variances separately using Rubin's rules. R2 is excluded from completed-data analysis. Both arms use identical imputations and saved outer folds. The first three scenarios reuse the validated original estimates. The neither scenario uses newly fitted bridge estimates with identical settings.", "",
  "Packages: cmbridge 0.3.0.9020, lmtp 1.6.0.9021, mice 3.19.0, from the verified original private library. Target E[Y2(1)] = 0.75.", "",
  "| Scenario | n | Method | Successful / completed | Mean | Bias | MSE | RMSE | 95% coverage | Mean SE | Empirical SD |",
  "|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|")
for (i in seq_len(nrow(summary))) {
  z <- summary[i, ]
  md <- c(md, sprintf("| %s | %d | %s | %d / %d | %.4f | %.4f | %.6f | %.4f | %.1f%% | %.4f | %.4f |",
    z$scenario, z$n, labels[match(z$method, methods)], z$successful, z$completed,
    z$mean_estimate, z$bias, z$mse, z$rmse, 100 * z$coverage, z$mean_se, z$empirical_sd))
}
md <- c(md, "", "MAR only: MI targets 0.75; the violated shadow restriction implies bridge target 0.6126667. Shadow only: bridge targets 0.75; MAR imputation implies target 0.6140584. Both assumptions: both population functionals equal 0.75. Neither assumption: both population functionals equal 0.6637440. The causal estimand remains 0.75 in every scenario. Saturated model classes avoid additional functional-form restrictions; finite-sample estimation and regularization remain.", "",
  "Coverage is among returned estimates. summary.csv also reports failures counted as noncovering, Monte Carlo errors, interval widths, and imputation Monte Carlo variability. The pilot is an implementation check, not a precise performance assessment.", "",
  sprintf("MI diagnostics: %d completed-data API calls; %d failed calls; maximum imputation reconstruction error %.3g; maximum reconstructed EIF error %.3g; %d failed support assertions; %d noninterior regression selections.",
    sum(audit$completed_data_calls), sum(audit$failed_calls), max(audit$reconstruction_error, na.rm = TRUE),
    max(audit$score_error[startsWith(audit$method, "mi_")], na.rm = TRUE),
    sum(audit$support_failures[startsWith(audit$method, "mi_")]), sum(audit$noninterior_selections[startsWith(audit$method, "mi_")])), "",
  sprintf("Bridge diagnostics retained: %d conditional-moment candidate failures and %d recorded Landweber iteration-limit stops. These did not necessarily prevent a returned final estimate and are not evidence that every candidate converged to tolerance.", sum(audit$candidate_failures), sum(audit$landweber_iteration_stops)), "",
  "The original MI + saturated-standardization arm is excluded from this corrected comparison; its output remains under mi-comparison-v1.", "",
  "![Estimates](estimates.png)", "", "![Coverage](coverage.png)")
writeLines(md, file.path(root, "REPORT.md"))
colors <- c("#176B9A", "#62B4CF", "#9C4828", "#DD995A")
png(file.path(root, "estimates.png"), width = 600 * length(scenarios), height = 1200, res = 160, type = "quartz")
par(mfrow = c(length(unique(r$n)), length(scenarios)), mar = c(4.5, 4, 3, 1), oma = c(0, 0, 2, 0))
limits <- range(c(.6, .75, r$estimate), na.rm = TRUE)
for (n in sort(unique(r$n))) for (scenario in scenarios) {
  z <- r[r$n == n & r$scenario == scenario & !nzchar(r$error), ]
  boxplot(lapply(methods, function(m) z$estimate[z$method == m]),
    names = c("MI\nTMLE", "MI\nSDR", "Bridge\nTMLE", "Bridge\nSDR"),
    las = 1, col = colors, ylim = limits, ylab = "Estimated counterfactual mean", main = paste(scenario, "n =", n))
  abline(h = .75, lty = 2, lwd = 2, col = "#333333")
  targets <- switch(scenario, mar_only = .6126666667, shadow_only = .6140583554, neither = .663743991454513, both = .75)
  if (any(targets != .75)) abline(h = targets, lty = 3, col = "#777777")
}
mtext(paste(status, basename(root), "results; dashed: truth; dotted: invalid-assumption target"), outer = TRUE)
dev.off()
png(file.path(root, "coverage.png"), width = 550 * length(scenarios), height = 750, res = 150, type = "quartz")
par(mfrow = c(1, length(scenarios)), mar = c(4, 4, 3, 1), oma = c(0, 0, 2, 0))
for (scenario in scenarios) {
  plot(range(r$n), c(0, 1), type = "n", xlab = "Sample size", ylab = "95% interval coverage", main = scenario)
  abline(h = .95, lty = 2, col = "#555555")
  for (j in seq_along(methods)) {
    z <- summary[summary$scenario == scenario & summary$method == methods[j], ]
    lines(z$n, z$coverage, type = "b", pch = 14 + j, col = colors[j], lwd = 2)
    z <- z[is.finite(z$coverage_mcse) & z$coverage_mcse > 0, ]
    if (nrow(z)) arrows(z$n, pmax(0, z$coverage - 1.96 * z$coverage_mcse), z$n,
      pmin(1, z$coverage + 1.96 * z$coverage_mcse), angle = 90, code = 3, length = .04, col = colors[j])
  }
  legend("bottomright", labels, col = colors, pch = 15:18, lty = 1, bty = "n", cex = .8)
}
mtext(paste(status, basename(root), "coverage; bars: Monte Carlo uncertainty"), outer = TRUE)
dev.off()
print(summary)
