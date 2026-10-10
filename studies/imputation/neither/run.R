source(file.path(Sys.getenv("MI_LMTP_SOURCE"), "study.R"))
source(file.path(source_dir, "runtime-setup.R"))
manifest <- jsonlite::fromJSON(file.path(source_dir, "manifest.json"))
hashes <- vapply(names(manifest), function(p)
  digest::digest(file = file.path(source_dir, p), algo = "sha256"), "")
stopifnot(identical(unname(hashes), unname(unlist(manifest))))
library_manifest <- jsonlite::fromJSON(file.path(mi_root, "library-sha256.json"))
hashes <- vapply(names(library_manifest), function(p)
  digest::digest(file = file.path(mi_root, "library", p), algo = "sha256"), "")
stopifnot(identical(unname(hashes), unname(unlist(library_manifest))))
phase <- Sys.getenv("MI_LMTP_PHASE", "pilot")
stopifnot(phase %in% c("pilot", "main"))
out <- file.path(corrected_root, phase)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
writeLines(as.character(Sys.getpid()), file.path(out, "run.pid"))
writeLines(capture.output(sessionInfo()), file.path(out, "session.txt"))
writeLines(sprintf("All %d installed files match the original SHA256 manifest.",
  length(hashes)), file.path(out, "LIBRARY-VERIFIED.txt"))
design <- expand.grid(scenario = "neither", n = c(1000L, 4000L),
  replicate = seq_len(if (phase == "pilot") 2L else 200L), stringsAsFactors = FALSE)
write.csv(design, file.path(out, "design.csv"), row.names = FALSE)
Sys.setenv(MI_AUDIT_OUT = out)
status <- system2(file.path(R.home("bin"), "Rscript"),
  shQuote(file.path(source_dir, "audit_population.R")),
  stdout = file.path(out, "population-audit.log"), stderr = file.path(out, "population-audit-errors.log"))
stopifnot(status == 0L)
# Bridge instrumentation and completed-data instrumentation run in separate R
# processes so each uses the exact hooks from its original validated stage.
status <- system2(file.path(R.home("bin"), "Rscript"),
  shQuote(file.path(source_dir, "bridge_run.R")),
  stdout = file.path(out, "bridge.log"), stderr = file.path(out, "bridge-errors.log"))
if (status != 0L) stop("Bridge/input stage failed; inspect bridge-errors.log")
keys <- sprintf("%s-n%d-r%03d.rds", design$scenario, design$n, design$replicate)
inputs <- file.path(out, "inputs", "jobs", keys)
outputs <- file.path(out, "jobs", keys)
stopifnot(all(file.exists(inputs)))
workers <- min(as.integer(Sys.getenv("MI_LMTP_WORKERS", "8")), length(inputs))
corrected_hooks(); options(warn = 1)
runner <- function(i) corrected_job(inputs[i], outputs[i])
if (workers == 1L) invisible(lapply(seq_along(inputs), runner)) else
  invisible(parallel::mclapply(seq_along(inputs), runner,
    mc.cores = workers, mc.preschedule = FALSE, mc.set.seed = FALSE))
if (!all(file.exists(outputs))) stop("Missing dataset checkpoints; inspect worker errors and resume")
writeLines(format(Sys.time(), tz = "America/New_York", usetz = TRUE),
  file.path(out, "FITTING-COMPLETED.txt"))
for (script in c("validate.R", "summarize.R")) {
  label <- sub("\\.R$", "", script)
  status <- system2(file.path(R.home("bin"), "Rscript"),
    c(shQuote(file.path(source_dir, script)), shQuote(out)),
    stdout = file.path(out, paste0(label, ".log")),
    stderr = file.path(out, paste0(label, "-errors.log")))
  if (status != 0L) stop("Fitting finished but ", script, " failed")
}
for (name in c("summary.csv", "replicates.csv", "audit-summary.csv", "REPORT.md",
    "VALIDATION.md", "estimates.png", "coverage.png"))
  stopifnot(file.exists(file.path(out, name)), file.info(file.path(out, name))$size > 0)
summary <- read.csv(file.path(out, "summary.csv"))
stopifnot(nrow(summary) == 8L, all(summary$failures == 0L),
  all(summary$completed == if (phase == "pilot") 2L else 200L))
writeLines(format(Sys.time(), tz = "America/New_York", usetz = TRUE),
  file.path(out, "COMPLETED.txt"))
