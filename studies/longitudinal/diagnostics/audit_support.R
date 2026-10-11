# Read-only support audit; no model fitting or package changes.
source("studies/longitudinal/diagnostics/bridge_adjoint_setup.R")
out <- Sys.getenv("DIAGNOSTIC_OUTPUT", "results/longitudinal/bridge-adjoint-seed-check")
paths <- list.files(file.path(out, "jobs"), "\\.rds$", full.names = TRUE)
support <- list()
for (path in paths) {
  x <- readRDS(path)
  if (!is.null(x$error)) next
  for (type in c("bridge", "adjoint")) {
    model <- x[[type]]$candidates$sieve_md
    if (is.null(model) || is.null(model$target_spec$levels)) next
    z <- x$population_points[function_name == type]
    missing <- !z$cell %in% model$target_spec$levels
    support[[length(support) + 1L]] <- data.table(
      selected = x$design$selected, seed = x$design$seed, n = x$design$n,
      time = x$design$time, fold = x$design$fold, function_name = type,
      population_target_cells = nrow(z), unseen_target_cells = sum(missing),
      probability_unseen_target = sum(z$probability[missing]) / sum(z$probability),
      sieve_weight = x[[type]]$weights["sieve_md"])
  }
}
support <- rbindlist(support)
fwrite(support, file.path(out, "sieve-support-by-fold.csv"))
print(support[time == 3L, .(mean_unseen_cells = mean(unseen_target_cells),
  mean_probability_unseen_target = mean(probability_unseen_target)),
  by = .(selected, seed, n, function_name)])
