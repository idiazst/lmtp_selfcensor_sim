source_dir <- Sys.getenv("MI_LMTP_SOURCE")
Sys.setenv(MI_STUDY_SOURCE = source_dir)
source(file.path(source_dir, "original-helpers.R"))
phase <- Sys.getenv("MI_LMTP_PHASE")
out <- file.path(Sys.getenv("MI_LMTP_ROOT"), phase)
design <- read.csv(file.path(out, "design.csv"))
inputs <- file.path(out, "inputs")
mi_install_audit_hooks()
options(warn = 1)
workers <- min(as.integer(Sys.getenv("MI_LMTP_WORKERS", "8")), nrow(design))
runner <- function(i) {
  z <- design[i, ]
  mi_job(z$n, z$replicate, z$scenario, phase, inputs)
}
if (workers == 1L) invisible(lapply(seq_len(nrow(design)), runner)) else
  invisible(parallel::mclapply(seq_len(nrow(design)), runner,
    mc.cores = workers, mc.preschedule = FALSE, mc.set.seed = FALSE))
paths <- file.path(inputs, "jobs", sprintf("%s-n%d-r%03d.rds",
  design$scenario, design$n, design$replicate))
stopifnot(all(file.exists(paths)))
for (path in paths) {
  x <- readRDS(path)
  if (any(vapply(x$results, function(z) !is.null(z$error), TRUE)))
    stop("Bridge/input checkpoint contains a failure: ", path)
}
writeLines(format(Sys.time(), tz = "America/New_York", usetz = TRUE),
  file.path(out, "BRIDGE-COMPLETED.txt"))
