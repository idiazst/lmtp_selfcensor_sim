target <- ".runtime/library"
dir.create(target, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(normalizePath(target), .libPaths()))
options(repos = c(CRAN = Sys.getenv("RSPM", "https://cloud.r-project.org")))
needed <- c("remotes", "jsonlite", "digest", "data.table", "ggplot2", "earth")
missing <- needed[!vapply(needed, requireNamespace, TRUE, quietly = TRUE)]
if (length(missing)) install.packages(missing, lib = target)
pins <- jsonlite::fromJSON("dependencies/package-pins.json")$packages
for (i in seq_len(nrow(pins))) {
  stopifnot(digest::digest(file = pins$path[i], algo = "sha256") == pins$sha256[i])
  if (!requireNamespace(pins$package[i], quietly = TRUE) ||
      as.character(packageVersion(pins$package[i])) != pins$version[i])
    remotes::install_local(pins$path[i], lib = target, dependencies = NA, upgrade = "never")
}
stopifnot(as.character(packageVersion("cmbridge")) == "0.3.0.9020",
  as.character(packageVersion("lmtp")) == "1.6.0.9021", requireNamespace("earth", quietly = TRUE))
