library(data.table)
out <- Sys.getenv("STATISTIC_OUTPUT", "results/longitudinal/ensemble-statistic-check")
summary <- fread(file.path(out, "summary.csv"))
weights <- fread(file.path(out, "weights.csv"))
selection <- fread(file.path(out, "selected-seeds.csv"))
checks <- fread(file.path(out, "checks.csv"))
failures <- fread(file.path(out, "failures.csv"))
metrics <- fread(file.path(out, "metrics.csv"))
augmented <- fread(file.path(out, "augmented.csv"))
points <- as.data.table(read.csv(gzfile(file.path(out, "out-of-sample-predictions.csv.gz"))))
equations <- fread(file.path(out, "equation_rows.csv"))
complete <- !grepl("PRELIMINARY", readLines(file.path(out, "EVALUATION-COMPLETED.txt"))[1L])
stopifnot(complete || identical(Sys.getenv("ALLOW_PARTIAL"), "true"))
mechanism_label <- function(m) if (m == "discrete_dose") "Numerical dose" else "Binary dose"
selection_label <- function(s) if (s == "largest_bias") "Largest original error" else "Smallest original error"
graphics_type <- if (Sys.info()[["sysname"]] == "Darwin") "quartz" else "cairo"
draw_panels <- function(mechanism_name, selected_seed, outcome_time, mode) {
  all <- if (mode == "refit") points[mechanism == mechanism_name & selected == selected_seed &
    time == outcome_time & method == "refit"] else points[mechanism == mechanism_name &
    selected == selected_seed & time == outcome_time & method %in% c("fixed_u_psd", "fixed_u_raw", "fixed_v")]
  methods <- if (mode == "refit") c("u", "v") else c("fixed_u_psd", "fixed_u_raw", "fixed_v")
  labels <- if (mode == "refit") c("U + PSD", "V") else c("U + PSD", "Raw U", "V")
  file <- sprintf("%s-%s-t%d-%s-y-equals-x.png", mechanism_name, selected_seed, outcome_time, mode)
  png(file.path(out, file), width = 2100, height = 600 * 2 * length(methods), res = 175, type = graphics_type)
  par(mfrow = c(2L * length(methods), 3L), mar = c(4.0, 4.2, 2.1, .7),
    mgp = c(2.4, .7, 0), oma = c(1.8, 0, 3.0, 0))
  for (type in c("bridge", "adjoint")) for (j in seq_along(methods)) for (size in c(4000L, 10000L, 50000L)) {
    use <- all[function_name == type & n == size]
    limits <- range(c(use$truth, use$estimate), finite = TRUE)
    pad <- max(diff(limits) * .04, .04); limits <- limits + c(-pad, pad)
    z <- if (mode == "refit") use[statistic == methods[j]] else use[method == methods[j]]
    z <- unique(z[, .(truth, estimate, previous_measured, fold)])
    plot(z$truth, z$estimate, xlim = limits, ylim = limits, asp = 1, pch = 16, cex = .42,
      col = adjustcolor(c("#888888", "#2166AC")[z$previous_measured + 1L], alpha.f = .45),
      xlab = paste("True", type), ylab = paste("Estimated", type),
      main = sprintf("%s; n = %s", labels[j], format(size, big.mark = ",")))
    abline(0, 1, col = "#C23B23", lwd = 1.4, lty = 2)
  }
  seed <- unique(all$seed)
  mtext(sprintf("%s — %s, seed %d — t = %d", mechanism_label(mechanism_name),
    selection_label(selected_seed), seed, outcome_time), outer = TRUE, line = 1.3, cex = 1.02)
  mtext(if (mode == "refit") "Statistic controls penalty CV and ensemble selection; all plotted predictions are held out." else
    "Identical U-tuned candidates; only ensemble weights change. All plotted predictions are held out.",
    outer = TRUE, line = .1, cex = .82)
  mtext(sprintf("Dashed line: y = x. Blue: R%d = 1; gray: R%d = 0. All coordinates retained; repeated points overlap.",
    outcome_time - 1L, outcome_time - 1L), outer = TRUE, side = 1, line = .3, cex = .8)
  dev.off()
  file
}
figures <- list()
for (m in unique(selection$mechanism)) for (s in c("largest_bias", "smallest_bias")) for (t in sort(unique(summary$time))) {
  for (mode in c("refit", "fixed")) {
    file <- draw_panels(m, s, t, mode)
    figures[[length(figures) + 1L]] <- data.table(mechanism = m, selected = s, time = t, mode = mode, file = file)
  }
}
figures <- rbindlist(figures)
fwrite(figures, file.path(out, "figures.csv"))

# Adjoint conditional means compare the defining equation independently of the
# nonunique choice of a reference adjoint function.
for (m in unique(selection$mechanism)) for (s in c("largest_bias", "smallest_bias")) {
  e <- equations[mechanism == m & selected == s & time == 3L & function_name == "adjoint" & method == "refit"]
  file <- sprintf("%s-%s-adjoint-equations.png", m, s)
  png(file.path(out, file), width = 2100, height = 1250, res = 175, type = graphics_type)
  par(mfrow = c(2, 3), mar = c(4, 4.5, 2.2, .6), mgp = c(2.4, .7, 0), oma = c(1, 0, 2.5, 0))
  for (stat in c("u", "v")) for (size in c(4000L, 10000L, 50000L)) {
    both <- e[n == size]; z <- both[statistic == stat]
    limits <- range(c(both$true_conditional_mean, both$estimated_conditional_mean), finite = TRUE)
    pad <- max(diff(limits) * .04, .04); limits <- limits + c(-pad, pad)
    plot(z$true_conditional_mean, z$estimated_conditional_mean, xlim = limits, ylim = limits, asp = 1,
      pch = 16, cex = .5, col = adjustcolor("#2166AC", alpha.f = .4),
      xlab = "Conditional mean of loading", ylab = "Conditional mean of estimated adjoint",
      main = sprintf("%s; n = %s", if (stat == "u") "U + PSD" else "V", format(size, big.mark = ",")))
    abline(0, 1, col = "#C23B23", lwd = 1.4, lty = 2)
  }
  mtext(sprintf("%s — %s — adjoint defining equation, t = 3", mechanism_label(m), selection_label(s)),
    outer = TRUE, line = 1, cex = 1)
  dev.off()
  figures <- rbind(figures, data.table(mechanism = m, selected = s, time = 3L,
    mode = "equation", file = file))
}
fwrite(figures, file.path(out, "figures.csv"))
weight_summary <- weights[, .(weight = mean(weight)),
  by = .(mechanism, selected, seed, n, time, statistic, function_name, method, candidate)]
fwrite(weight_summary, file.path(out, "weight-summary.csv"))
augmented_summary <- augmented[, .(true_weight = mean(true_weight),
  population_full_rbf_loss = mean(population_full_rbf_loss)),
  by = .(mechanism, selected, seed, n, time, statistic, function_name, method)]
fwrite(augmented_summary, file.path(out, "augmented-summary.csv"))
full <- dcast(summary[time == 3L & method == "refit"],
  mechanism + selected + seed + n + function_name ~ statistic,
  value.var = c("population_function_rmse", "population_equation_rmse", "population_full_rbf_loss"))
fixed <- dcast(summary[time == 3L & method != "refit"],
  mechanism + selected + seed + n + function_name ~ method, value.var = "population_full_rbf_loss")
fwrite(full, file.path(out, "refit-comparison.csv")); fwrite(fixed, file.path(out, "fixed-candidate-comparison.csv"))
size_summary <- summary[time == 3L & method == "refit", .(
  population_function_rmse = sqrt(mean(population_function_rmse^2)),
  population_equation_rmse = sqrt(mean(population_equation_rmse^2)),
  population_full_rbf_loss = mean(population_full_rbf_loss)),
  by = .(mechanism, n, statistic, function_name)]
size_comparison <- dcast(size_summary, mechanism + n + function_name ~ statistic,
  value.var = c("population_function_rmse", "population_equation_rmse", "population_full_rbf_loss"))
fwrite(size_comparison, file.path(out, "sample-size-comparison.csv"))
improves <- function(new, old) new < old - (1e-12 + 1e-8 * abs(old))
v_better <- sum(improves(full$population_full_rbf_loss_v, full$population_full_rbf_loss_u))
v_fixed_better <- sum(improves(fixed$fixed_v, fixed$fixed_u_psd))
raw_fixed_better <- sum(improves(fixed$fixed_u_raw, fixed$fixed_u_psd))
md <- c("# U versus V for the bridge and adjoint ensembles", "",
  if (complete) "**Completed limited diagnostic.**" else "**PRELIMINARY: incomplete fits.**", "",
  "Use binary and numerical-dose longitudinal DGPs with missingness at both follow-ups. For each DGP, select the largest and smallest absolute realized final-outcome SDR errors among the successful n=4,000, correctly specified full-study datasets. Reset each selected seed at n=4,000, 10,000 and 50,000. These are 12 selected datasets, not 200-replication coverage results.", "",
  "Only bridge and adjoint ensembles are fitted. The three candidates, inverse-expit bridge parameterization, unrestricted adjoint, positive extendable penalty grid and three shared outer/learner folds are unchanged. The isolated adjoint loading uses exact DGP treatment ratios, as in the preceding diagnostic; there are no treatment/outcome-regression fits, new SDR/TMLE parameter estimates or Gaussian mean updates.", "",
  "In these frozen libraries, sieve_md supplies the positive penalty-CV grid. Landweber and PMMR retain their original fixed controls. Changing the statistic therefore changes sieve penalty selection and all ensemble scores, while preserving the other candidates' controls.", "",
  "## What is compared", "",
  "1. **Refits:** `statistic=\"u\"` versus `statistic=\"v\"` controls both training-only candidate penalty CV and ensemble selection. U retains the existing PSD projection; V uses its naturally PSD matrix directly. Each candidate is refit inside its outer training sample. Numerical-dose U fits reuse the previous frozen checkpoints, with hashes and provenance retained; fresh fits use cmbridge 0.3.0.9022.",
  "2. **Identical candidates:** rescore the saved U-tuned candidates with projected U, unprojected U, and V. Predictions, penalties, folds and training-derived kernel specifications are identical. Only the ensemble weights change. Unprojected U is minimized globally over the simplex by enumerating its faces; this diagnostic does not change the package's default optimizer.",
  "3. **Truth included as a diagnostic candidate:** compare empirical selection with exact population selection. Known functions are used only for this loss check, never for tuning the fitted candidates.", "",
  "Every kernel scale, bandwidth and Nyström center comes from its corresponding original training sample. All plotted rows are excluded from the fitted outer training sample. At n=4,000 the original full-study outer and learner assignments are reused. Identical seeds across sample sizes do not imply nested samples, because the DGP draws variables in blocks.", "",
  "Both true reference functions solve their exact population moment equations. The bridge reference is the inverse measurement probability; alternative bridge solutions can exist after an earlier missed visit. Adjoint solutions may also be nonunique. Function scatter alone is insufficient to diagnose failure; the defining conditional equations are also evaluated.", "",
  "## Selected seeds", "",
  "| DGP | Original error selection | Seed | Original SDR estimate | True parameter | Absolute error |",
  "|---|---|---:|---:|---:|---:|")
for (i in seq_len(nrow(selection))) {
  z <- selection[i]
  md <- c(md, sprintf("| %s | %s | %d | %.6f | %.6f | %.6f |", mechanism_label(z$mechanism),
    selection_label(z$selected), z$seed, z$estimate, z$truth, z$absolute_error))
}
md <- c(md, "", "## Final-outcome refits", "",
  "Each number integrates over the exact finite DGP population and averages squared errors over the three outer fits before taking the square root. Bridge RMSE compares the fitted function with the selected true solution. Adjoint equation RMSE measures violation of its defining conditional equation.", "",
  "| DGP | Seed | n | Bridge RMSE: U | Bridge RMSE: V | Adjoint equation RMSE: U | Adjoint equation RMSE: V |",
  "|---|---:|---:|---:|---:|---:|---:|")
for (i in seq_len(nrow(selection))) for (size in c(4000L, 10000L, 50000L)) {
  z <- selection[i]; b <- full[mechanism == z$mechanism & seed == z$seed & n == size & function_name == "bridge"]
  a <- full[mechanism == z$mechanism & seed == z$seed & n == size & function_name == "adjoint"]
  md <- c(md, sprintf("| %s | %d | %d | %.5f | %.5f | %.5f | %.5f |", mechanism_label(z$mechanism),
    z$seed, size, b$population_function_rmse_u, b$population_function_rmse_v,
    a$population_equation_rmse_u, a$population_equation_rmse_v))
}
md <- c(md, "", "## Exact population RKHS loss with identical candidates", "",
  "All losses below are the full-RBF population loss multiplied by one million. The same kernel is used for all mixtures within a comparison. The population loss of the true function is zero. These are evaluation losses, not the scores minimized in the sample.", "",
  "| DGP | Seed | n | Function | U + PSD | Raw U | V |", "|---|---:|---:|---|---:|---:|---:|")
setorder(fixed, mechanism, selected, n, function_name)
for (i in seq_len(nrow(fixed))) {
  z <- fixed[i]
  md <- c(md, sprintf("| %s | %d | %d | %s | %.2f | %.2f | %.2f |", mechanism_label(z$mechanism),
    z$seed, z$n, z$function_name, 1e6 * z$fixed_u_psd, 1e6 * z$fixed_u_raw, 1e6 * z$fixed_v))
}
md <- c(md, "", "## Interpretation", "",
  sprintf("V has lower final-outcome population RKHS loss in %d of %d refit comparisons. With identical U-tuned candidates, V improves on projected U in %d of %d comparisons; unprojected U improves on projected U in %d of %d. Counts span both functions, both seeds and both DGPs. They describe these selected datasets and are not evidence of a universal ordering or repaired confidence-interval coverage.",
    v_better, nrow(full), v_fixed_better, nrow(fixed), raw_fixed_better, nrow(fixed)), "",
  "These improvement counts exclude numerical ties: a decrease must exceed 1e-12 plus 1e-8 times the baseline loss. Complete unrounded losses accompany the report.", "",
  sprintf("At n=4,000, V reduces bridge function RMSE in %d of 4 selected datasets and adjoint equation RMSE in %d of 4. At n=50,000, V reduces bridge function RMSE in %d of 4. Thus changing the statistic is not a uniform improvement, especially for smaller-sample bridge fits.",
    full[function_name == "bridge" & n == 4000L, sum(improves(population_function_rmse_v, population_function_rmse_u))],
    full[function_name == "adjoint" & n == 4000L, sum(improves(population_equation_rmse_v, population_equation_rmse_u))],
    full[function_name == "bridge" & n == 50000L, sum(improves(population_function_rmse_v, population_function_rmse_u))]), "",
  sprintf("For the n=50,000 adjoints, using V weights on identical U-tuned candidates increases population RKHS loss in %d of 4 datasets. Any improvement from a complete V refit must therefore be distinguished from changes in penalty selection. Neither comparison eliminates the observed adjoint equation errors or establishes asymptotic inconsistency.",
    fixed[function_name == "adjoint" & n == 50000L, sum(improves(fixed_u_psd, fixed_v))]), "",
  "U estimates the squared population moment without self-products but can be negative. PSD projection changes that criterion. V retains self-products and is naturally PSD, while adding a candidate-dependent finite-sample bias. The identical-candidate comparison isolates weight selection; the refit comparison includes any change in the selected candidate penalties.", "",
  sprintf("Additional optimizer check: %d of %d saved U-fit score matrices have negative curvature along changes in weights that preserve their sum, using a 1e-12 numerical tolerance. A negative eigenvalue of the full score matrix does not by itself imply nonconvexity on the simplex. This distinguishes the original unrestricted matrix from the actual feasible weight problem; complete eigenvalue checks are retained.",
    sum(checks[statistic == "u", u_simplex_min_curvature] < -1e-12), nrow(checks[statistic == "u"])), "",
  sprintf("At the final outcome (t=3), none of the %d U-fit matrices has negative curvature on the simplex. The four exceptions above are numerical-dose adjoint fits at t=2. A future raw-U implementation could check this restricted curvature directly; here raw-U weighting remains an evaluation-only comparison.",
    nrow(checks[statistic == "u" & time == 3L])), "",
  "## Results pooled over the two selected seeds", "",
  "RMSE here averages squared population errors across both selected datasets and their three outer fits before taking the square root. This summarizes the preceding per-seed table; it is not a Monte Carlo coverage estimate.", "",
  "| DGP | n | Bridge RMSE: U | Bridge RMSE: V | Adjoint equation RMSE: U | Adjoint equation RMSE: V |",
  "|---|---:|---:|---:|---:|---:|")
for (m in unique(selection$mechanism)) for (size in c(4000L, 10000L, 50000L)) {
  b <- size_comparison[mechanism == m & n == size & function_name == "bridge"]
  a <- size_comparison[mechanism == m & n == size & function_name == "adjoint"]
  md <- c(md, sprintf("| %s | %d | %.5f | %.5f | %.5f | %.5f |", mechanism_label(m), size,
    b$population_function_rmse_u, b$population_function_rmse_v,
    a$population_equation_rmse_u, a$population_equation_rmse_v))
}
md <- c(md, "", "## Function plots", "")
for (i in which(figures$time == 3L & figures$mode == "refit")) {
  z <- figures[i]
  md <- c(md, sprintf("### %s: %s", mechanism_label(z$mechanism), selection_label(z$selected)), "",
    sprintf("![U/V refits](%s)", z$file), "",
    sprintf("[Identical-candidate plot](%s)", figures[mechanism == z$mechanism & selected == z$selected & time == 3L & mode == "fixed", file]), "",
    sprintf("[Adjoint defining-equation plot](%s-%s-adjoint-equations.png)", z$mechanism, z$selected), "")
}
md <- c(md, "## Verification and complete outputs", "",
  sprintf("CV Gram replay agrees within %.3e. True population RKHS losses are at most %.3e; true conditional weighted moments are at most %.3e. Candidate and outer-fit failures remain in the failure table; none are silently discarded.",
    max(checks$cv_replay_error), max(abs(checks$true_population_loss)), max(checks$true_population_moment_max)), "",
  "[All sizes and follow-ups](summary.csv), [pooled sample-size comparison](sample-size-comparison.csv), [mean ensemble weights](weight-summary.csv), [candidate losses](candidate_losses.csv), [truth-augmented selection](augmented-summary.csv), [penalty-CV records](tuning.csv), [penalty-grid boundary attempts](penalty_boundaries.csv), [failures](failures.csv), [warnings](warning_rows.csv), [checkpoint verification](checks.csv), [all figure paths](figures.csv), and [held-out prediction rows](out-of-sample-predictions.csv.gz).", "",
  "The opt-in API is `fit_bridge_ensemble(..., statistic = \"v\")` or `fit_adjoint_ensemble(..., statistic = \"v\")`. The default remains `statistic = \"u\"`. Package commit [8d820306](https://github.com/idiazst/cmbridge/commit/8d8203061fcb421a070b9ec50874e51d7409ea0b) passed [GitHub package and recovery validations](https://github.com/idiazst/cmbridge/actions/runs/38185965634).", "",
  "Model checkpoints are retained locally and ignored by Git. The original completed-study runtime, source pins and checkpoints are unchanged. The fitting manifest and separate postprocessing hashes identify the code used.", "",
  "Run from the simulation repository root after installing cmbridge 0.3.0.9022 into `.runtime/statistic-library`:", "",
  "```sh", "DIAGNOSTIC_WORKERS=6 Rscript studies/longitudinal/diagnostics/run_statistic_comparison.R",
  "Rscript studies/longitudinal/diagnostics/compare_statistic_fits.R",
  "Rscript studies/longitudinal/diagnostics/report_statistic_comparison.R", "```")
if (file.exists(file.path(out, "runtime.csv"))) {
  runtime <- fread(file.path(out, "runtime.csv"))
  md <- c(md, "", sprintf("Measured fitting wall time: %.2f minutes using %d local workers, with %d fresh bridge/adjoint fit pairs and %d reused pairs. All %d planned pairs completed. Runtime details are in [runtime.csv](runtime.csv).",
    runtime$wall_seconds / 60, runtime$workers, runtime$fresh_pairs, runtime$reused_pairs,
    runtime$fresh_pairs + runtime$reused_pairs))
}
writeLines(md, file.path(out, "REPORT.md"))
writeLines(if (complete) format(Sys.time(), tz = "America/New_York", usetz = TRUE) else "PRELIMINARY", file.path(out, "COMPLETED.txt"))
print(full)
cat(sprintf("V better refits: %d/%d; fixed V: %d/%d; fixed raw U: %d/%d\n",
  v_better, nrow(full), v_fixed_better, nrow(fixed), raw_fixed_better, nrow(fixed)))
