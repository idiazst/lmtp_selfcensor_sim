source("scripts/setup.R")
.libPaths(c(".runtime/adaptive-library", .libPaths()))
stopifnot(as.character(packageVersion("cmbridge")) == "0.3.0.9025")
for (expression in as.list(parse("studies/longitudinal/diagnostics/bridge_adjoint_setup.R"))[-1L])
  eval(expression, envir = .GlobalEnv)
adaptive_output <- Sys.getenv("ADAPTIVE_OUTPUT", "results/longitudinal/adaptive-selection-n4000")
adaptive_controls <- list(bootstrap_draws = 199L, noise_probability = .95,
  projection_basis = "cell_linear", critic_ridge = 1e-6)
