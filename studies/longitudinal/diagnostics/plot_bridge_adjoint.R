library(data.table)
out <- Sys.getenv("DIAGNOSTIC_OUTPUT", "results/longitudinal/bridge-adjoint-seed-check")
paths <- list.files(file.path(out, "jobs"), "\\.rds$", full.names = TRUE)
objects <- lapply(paths, readRDS)
stopifnot(length(objects) == 36L, all(vapply(objects, function(x) is.null(x$error), TRUE)))
points <- population <- equations <- metrics <- weights <- failures <- list()
for (x in objects) {
  add <- function(d) {
    d <- copy(as.data.table(d))
    for (name in c("selected", "seed", "n", "time", "fold")) d[, (name) := x$design[[name]]]
    d
  }
  points[[length(points) + 1L]] <- add(x$sample_points)
  population[[length(population) + 1L]] <- add(x$population_points)
  for (type in c("bridge", "adjoint")) {
    model <- x[[type]]; z <- x$population_points[function_name == type]
    eq <- x$equations[[type]]
    eq[, function_name := type]
    equations[[length(equations) + 1L]] <- add(eq)
    weights[[length(weights) + 1L]] <- add(data.table(function_name = type,
      candidate = names(model$weights), weight = unname(model$weights)))
    if (length(model$candidate_failures)) for (failure in model$candidate_failures)
      failures[[length(failures) + 1L]] <- add(data.table(function_name = type,
        candidate = failure$candidate, scope = failure$scope,
        training_n = failure$training_n, error = failure$message))
    for (previous_level in c(NA_integer_, 0L, 1L)) {
      use <- if (is.na(previous_level)) z else z[previous_measured == previous_level]
      if (!nrow(use)) next
      metrics[[length(metrics) + 1L]] <- add(data.table(function_name = type,
        previous_measured = previous_level,
        population_rmse_to_reference = sqrt(sum(use$probability * (use$estimate - use$truth)^2) / sum(use$probability)),
        population_equation_rmse = sqrt(sum(eq$probability * eq$residual^2) / sum(eq$probability)),
        population_equation_max_error = max(abs(eq$residual)),
        seconds_for_bridge_and_adjoint = x$seconds,
        candidate_failures = length(model$candidate_failures)))
    }
  }
}
points <- rbindlist(points); population <- rbindlist(population)
equations <- rbindlist(equations, fill = TRUE); metrics <- rbindlist(metrics)
weights <- rbindlist(weights); failures <- rbindlist(failures, fill = TRUE)
# Every plotted observation is predicted by a model excluding its outer fold.
for (z in split(points, by = c("seed", "n", "time", "function_name"), keep.by = TRUE))
  stopifnot(!anyDuplicated(z$row), if (z$function_name[1L] == "adjoint") nrow(z) == z$n[1L] else TRUE)
connection <- gzfile(file.path(out, "out-of-sample-predictions.csv.gz"), "wt")
write.csv(points, connection, row.names = FALSE); close(connection)
fwrite(population, file.path(out, "population-predictions.csv"))
fwrite(equations, file.path(out, "population-equations.csv"))
fwrite(metrics, file.path(out, "metrics-by-fold.csv"))
fwrite(weights, file.path(out, "ensemble-weights.csv"))
fwrite(failures, file.path(out, "candidate-failures.csv"))
summary <- metrics[is.na(previous_measured), .(
  population_rmse_to_reference = sqrt(mean(population_rmse_to_reference^2)),
  population_equation_rmse = sqrt(mean(population_equation_rmse^2)),
  population_equation_max_error = max(population_equation_max_error),
  candidate_failures = sum(candidate_failures)),
  by = .(selected, seed, n, time, function_name)]
fwrite(summary, file.path(out, "summary.csv"))
graphics_type <- if (Sys.info()[["sysname"]] == "Darwin") "quartz" else "cairo"
colors <- c("#8B8B8B", "#2166AC")
for (selection in unique(points$selected)) for (outcome_time in c(2L, 3L)) {
  path <- file.path(out, sprintf("%s-time%d-y-equals-x.png", selection, outcome_time))
  png(path, width = 2100, height = 1280, res = 175, type = graphics_type)
  par(mfrow = c(2, 3), mar = c(4.2, 4.8, 2.5, 1), oma = c(2.2, 0, 3.5, 0))
  for (type in c("bridge", "adjoint")) {
    all <- points[selected == selection & time == outcome_time & function_name == type]
    limits <- range(c(all$truth, all$estimate), finite = TRUE)
    pad <- max(diff(limits) * .04, .04); limits <- limits + c(-pad, pad)
    for (size in c(4000L, 10000L, 50000L)) {
      z <- unique(all[n == size, .(truth, estimate, previous_measured, fold)])
      plot(z$truth, z$estimate, xlim = limits, ylim = limits, asp = 1,
        pch = 16, cex = .55, col = adjustcolor(colors[z$previous_measured + 1L], alpha.f = .5),
        xlab = if (type == "bridge") "True bridge (selected solution)" else "True adjoint (selected solution)",
        ylab = paste("Estimated", type), main = sprintf("n = %s", format(size, big.mark = ",")))
      abline(0, 1, col = "#C23B23", lwd = 1.6, lty = 2)
    }
  }
  seed <- unique(points[selected == selection, seed])
  mtext(sprintf("%s absolute final-estimate error: seed %d — outcome at t = %d",
    if (selection == "largest_bias") "Largest" else "Smallest", seed, outcome_time), outer = TRUE, line = 1.1, cex = 1.08)
  mtext("Held-out predictions; dashed line y = x. References are valid solutions, not necessarily unique.",
    outer = TRUE, line = -.2, cex = .9)
  mtext(sprintf("Blue: R%d = 1     Gray: R%d = 0. All observations are included; repeated coordinates overlap.",
    outcome_time - 1L, outcome_time - 1L), outer = TRUE, side = 1, line = .4, cex = .9)
  dev.off()
}
# Conditional means have a unique target even when individual adjoints do not.
png(file.path(out, "adjoint-defining-equations.png"), width = 2100, height = 1280, res = 175, type = graphics_type)
par(mfrow = c(2, 3), mar = c(4.2, 4.8, 2.5, 1), oma = c(1, 0, 3, 0))
for (selection in c("largest_bias", "smallest_bias")) {
  all <- equations[selected == selection & time == 3L & function_name == "adjoint"]
  limits <- range(c(all$true_conditional_mean, all$estimated_conditional_mean), finite = TRUE)
  pad <- max(diff(limits) * .04, .04); limits <- limits + c(-pad, pad)
  for (size in c(4000L, 10000L, 50000L)) {
    z <- all[n == size]
    plot(z$true_conditional_mean, z$estimated_conditional_mean,
      xlim = limits, ylim = limits, asp = 1, pch = 16, cex = .5,
      col = adjustcolor("#2166AC", alpha.f = .4), xlab = "Conditional mean of loading",
      ylab = "Conditional mean of estimated adjoint",
      main = sprintf("%s error, n = %s", if (selection == "largest_bias") "Largest" else "Smallest", format(size, big.mark = ",")))
    abline(0, 1, col = "#C23B23", lwd = 1.6, lty = 2)
  }
}
mtext("Adjoint defining equation, final outcome (t = 3)", outer = TRUE, line = 1, cex = 1.1)
dev.off()
selection <- fread(file.path(out, "selected-seeds.csv"))
md <- c("# Numerical-dose bridge and adjoint diagnostic", "",
  "The lowest longitudinal coverage was 82.4% for the SDR final outcome at n=1,000. Select the largest and smallest absolute realized errors among its 199 successful n=4,000 replications, then generate one dataset at each of n=4,000, 10,000 and 50,000 from each selected seed.", "",
  "These are six selected-data diagnostics, not a new coverage or convergence study. Each sample size resets the same data seed; datasets are not required to be nested. The original n=4,000 outer/learner splits are reused. Three outer folds and the original training-only penalty/ensemble folds are retained. Predictions in the function plots are held out. Model libraries, positive-penalty CV, links, kernels and failure rules match the frozen study. No package was edited.", "",
  "Only bridge and adjoint ensembles are fitted, for both follow-ups. For this isolated diagnostic, the adjoint loading uses exact treatment ratios calculated from the DGP. There are no treatment/outcome-regression fits and no new SDR/TMLE parameter estimates. This differs from the full study's estimated treatment-ratio loading.", "",
  "The bridge reference is the inverse measurement probability, a valid solution contained in the bridge class. It remains a valid solution at histories with a missed visit; the older constant reference there is another solution. The adjoint reference is the previously specified minimum-Euclidean-norm solution. Both satisfy the exact population equations before any model is fitted. Adjoint solutions can be nonunique even when the earlier visit was observed. Distance from this reference alone is not a failure criterion; exact population conditional-equation errors are also reported.", "",
  "| Selected n=4,000 dataset | Seed | Original SDR estimate | Absolute error |", "|---|---:|---:|---:|")
for (i in seq_len(nrow(selection))) md <- c(md, sprintf("| %s | %d | %.9f | %.9f |",
  selection$selected[i], selection$seed[i], selection$estimate[i], selection$absolute_error[i]))
md <- c(md, "", "## Final-outcome checks", "",
  "RMSE to reference and defining-equation RMSE use the exact population support and probabilities, averaged over the three outer fits. Maximum equation error includes every positive-probability history. Internal candidate failures are retained.", "",
  "| Selected seed | n | Function | RMSE to selected solution | Equation RMSE | Max equation error | Candidate failures |",
  "|---|---:|---|---:|---:|---:|---:|")
for (i in which(summary$time == 3L)) {
  z <- summary[i]
  md <- c(md, sprintf("| %d | %d | %s | %.5f | %.5f | %.5f | %d |",
    z$seed, z$n, z$function_name, z$population_rmse_to_reference, z$population_equation_rmse,
    z$population_equation_max_error, z$candidate_failures))
}
for (selected in c("largest_bias", "smallest_bias")) md <- c(md, "",
  sprintf("![%s error, final outcome](%s-time3-y-equals-x.png)", selected, selected))
md <- c(md, "", "![Adjoint defining equations](adjoint-defining-equations.png)", "",
  "First-follow-up plots: [largest error](largest_bias-time2-y-equals-x.png), [smallest error](smallest_bias-time2-y-equals-x.png). Complete weights, failures, fold-specific metrics, population predictions and equations accompany this report. Compressed held-out predictions retain every plotted row.")
writeLines(md, file.path(out, "REPORT.md"))
writeLines(format(Sys.time(), tz = "America/New_York", usetz = TRUE), file.path(out, "COMPLETED.txt"))
print(summary)
