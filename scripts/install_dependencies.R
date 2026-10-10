# Frozen dependencies are for simulations; package development happens elsewhere.
args <- commandArgs(trailingOnly = TRUE)
library <- if (length(args)) args[1L] else ".runtime/library"
dir.create(library, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(normalizePath(library), .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))
needed <- c("remotes", "jsonlite", "digest", "data.table", "ggplot2", "earth")
missing <- needed[!vapply(needed, requireNamespace, TRUE, quietly = TRUE)]
if (length(missing)) install.packages(missing, lib = library)
pins <- jsonlite::fromJSON("dependencies/package-pins.json")$packages
for (i in seq_len(nrow(pins))) {
  archive <- pins$path[i]
  stopifnot(digest::digest(file = archive, algo = "sha256") == pins$sha256[i])
  remotes::install_local(archive, lib = library, dependencies = NA, upgrade = "never")
}
if (!requireNamespace("mice", quietly = TRUE) || as.character(packageVersion("mice")) != "3.19.0")
  remotes::install_version("mice", version = "3.19.0", lib = library,
    dependencies = NA, upgrade = "never")
stopifnot(as.character(packageVersion("cmbridge")) == "0.3.0.9020",
          as.character(packageVersion("lmtp")) == "1.6.0.9021",
          as.character(packageVersion("mice")) == "3.19.0")
writeLines(capture.output(sessionInfo()), file.path(library, "session-info.txt"))
