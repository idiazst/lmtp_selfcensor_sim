# Prevent a failed installation from silently using a previous lazy-loaded build.
check_sources <- function(package, files) {
  ns <- asNamespace(package)
  source_env <- new.env(parent = ns)
  source_root <- Sys.getenv("FOUR_DOSE_SOURCE_ROOT", "..")
  for (file in files) sys.source(file.path(source_root, package, "R", file), source_env)
  for (name in ls(source_env, all.names = TRUE)) {
    expected <- source_env[[name]]
    if (!is.function(expected)) next
    installed <- get(name, ns, inherits = FALSE)
    if (!identical(body(expected), body(installed)))
      stop("Installed ", package, ":::", name, " differs from the source build.")
  }
}
check_sources("cmbridge", c("ensemble.R", "basis.R"))
check_sources("lmtp", c("bridge_curve.R", "bridge_response.R", "curve.R",
                        "full_history.R", "full_history_engine.R", "sl.R"))
cat("Installed numerical functions match the source build.\n")
