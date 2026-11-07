# Install the exact study package sources; matching version numbers alone are insufficient.
target <- Sys.getenv("R_LIBS_USER", ".runtime/four-dose-outer-library")
if (grepl(.Platform$path.sep, target, fixed = TRUE))
  stop("The GitHub installer needs a single writable R_LIBS_USER directory.")
dir.create(target, recursive = TRUE, showWarnings = FALSE)
target <- normalizePath(target)
.libPaths(c(target, .libPaths()))
options(repos = c(CRAN = Sys.getenv("RSPM", "https://cloud.r-project.org")))
needed <- c("remotes", "jsonlite", "digest")
missing <- needed[!vapply(needed, requireNamespace, TRUE, quietly = TRUE)]
if (length(missing)) install.packages(missing, lib = target)
root <- Sys.getenv("FOUR_DOSE_SOURCE_ROOT", "dependencies/four-dose")
manifest <- jsonlite::fromJSON(file.path(root, "manifest.json"), simplifyVector = FALSE)
for (package in c("cmbridge", "lmtp")) {
  pin <- manifest$packages[[package]]
  source <- file.path(root, package)
  for (file in names(pin$files)) {
    actual <- digest::digest(file = file.path(source, file), algo = "sha256")
    if (!identical(actual, pin$files[[file]])) stop("Source checksum mismatch: ", package, "/", file)
  }
  marker <- file.path(target, paste0("four-dose-", package, ".sha256"))
  cached <- file.exists(marker) && identical(readLines(marker, warn = FALSE), pin$sha256) &&
    dir.exists(file.path(target, package))
  if (!cached) {
    remotes::install_deps(source, lib = target, dependencies = NA, upgrade = "never")
    status <- system2(file.path(R.home("bin"), "R"),
                      c("CMD", "INSTALL", "--no-multiarch", "-l", shQuote(target), shQuote(source)))
    if (status != 0L) stop("Installation failed for ", package)
    writeLines(pin$sha256, marker)
  }
}
Sys.setenv(FOUR_DOSE_SOURCE_ROOT = root)
source("studies/four-dose-pilot/check_installed.R")
cat("Frozen package installation verified.\n")
