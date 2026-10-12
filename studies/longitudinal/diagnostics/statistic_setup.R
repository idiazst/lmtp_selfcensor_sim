# Keep the completed study's pinned runtime intact. Check those archives first,
# then load the opt-in statistic implementation from a separate library.
source("scripts/setup.R")
comparison_library <- Sys.getenv("COMPARISON_LIBRARY", ".runtime/statistic-library")
if (dir.exists(comparison_library)) .libPaths(c(comparison_library, .libPaths()))
stopifnot(as.character(packageVersion("cmbridge")) == "0.3.0.9022")
# All remaining setup expressions are the approved DGP, library and truth helpers.
for (expression in as.list(parse("studies/longitudinal/diagnostics/bridge_adjoint_setup.R"))[-1L])
  eval(expression, envir = .GlobalEnv)
stopifnot(as.character(packageVersion("cmbridge")) == "0.3.0.9022")

statistic_output <- Sys.getenv("STATISTIC_OUTPUT", "results/longitudinal/ensemble-statistic-check")
statistic_mechanisms <- strsplit(Sys.getenv("STATISTIC_MECHANISMS",
  "binary_longitudinal,discrete_dose"), ",", fixed = TRUE)[[1L]]
statistic_times <- as.integer(strsplit(Sys.getenv("STATISTIC_TIMES", "2,3"), ",", fixed = TRUE)[[1L]])
stopifnot(all(statistic_mechanisms %in% c("binary_longitudinal", "discrete_dose")),
  all(statistic_times %in% c(2L, 3L)))
