source("scripts/setup.R")
.libPaths(c(".runtime/inverse-penalty-library", .libPaths()))
stopifnot(as.character(packageVersion("cmbridge")) == "0.3.0.9027")
for (expression in as.list(parse("studies/longitudinal/diagnostics/bridge_adjoint_setup.R"))[-1L])
  eval(expression, envir = .GlobalEnv)
penalty_output <- Sys.getenv("PENALTY_OUTPUT", "results/longitudinal/inverse-penalty-n4000")
penalty_rules <- c("gcv", "lcurve", "quasiopt")
penalty_controls <- list(trace_probes = 8L, trace_step = 1e-4,
  max_extensions = 6L, iteration_grid = unique(round(exp(seq(log(2), log(4000), length.out = 25L)))))
