# Single source of truth for all four assumption scenarios.
repo <- normalizePath(Sys.getenv("SIM_REPO", "."))
source(file.path(repo, "studies/imputation/neither/dgp.R"))
