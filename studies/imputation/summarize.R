# Delegate reporting to the validated four-scenario implementation.
repo <- normalizePath(Sys.getenv("SIM_REPO", "."))
if (!length(commandArgs(trailingOnly = TRUE))) stop("Supply the result directory")
source(file.path(repo, "studies/imputation/neither/summarize.R"))
