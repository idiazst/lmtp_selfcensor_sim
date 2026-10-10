# Run study commands from the repository root (or set SIM_REPO).
repo <- normalizePath(Sys.getenv("SIM_REPO", "."), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, "dependencies/package-pins.json")))
study_library <- Sys.getenv("SIM_LIBRARY", file.path(repo, ".runtime/library"))
if (dir.exists(study_library)) .libPaths(c(study_library, .libPaths()))
stopifnot(as.character(packageVersion("cmbridge")) == "0.3.0.9020",
          as.character(packageVersion("lmtp")) == "1.6.0.9021")
pins <- jsonlite::fromJSON(file.path(repo, "dependencies/package-pins.json"))$packages
for (i in seq_len(nrow(pins))) stopifnot(
  digest::digest(file = file.path(repo, pins$path[i]), algo = "sha256") == pins$sha256[i])
options(bitmapType = "cairo")
