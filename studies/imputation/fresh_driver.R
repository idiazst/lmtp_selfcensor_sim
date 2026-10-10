# Orchestration only: numerical functions are copied unchanged from neither/.
source_dir <- Sys.getenv("MI_LMTP_SOURCE")
source(file.path(source_dir, "study.R"))
source(file.path(source_dir, "runtime-setup.R"))
manifest <- jsonlite::fromJSON(file.path(source_dir, "manifest.json"))
for (name in names(manifest)) stopifnot(
  digest::digest(file = file.path(source_dir, name), algo = "sha256") == manifest[[name]])
settings <- jsonlite::fromJSON(file.path(source_dir, "design.json"))
out <- file.path(Sys.getenv("MI_LMTP_ROOT"), "main")
dir.create(out, recursive = TRUE)
design <- expand.grid(scenario = settings$scenarios, n = settings$sizes,
  replicate = seq_len(settings$replications), stringsAsFactors = FALSE)
write.csv(design, file.path(out, "design.csv"), row.names = FALSE)
writeLines(capture.output(sessionInfo()), file.path(out, "session.txt"))
writeLines(Sys.getenv("MI_LMTP_FINGERPRINT"), file.path(out, "fingerprint.txt"))
# Exact original bridge stage and hooks run in their own process.
status <- system2(file.path(R.home("bin"), "Rscript"),
  shQuote(file.path(source_dir, "bridge_run.R")),
  stdout = file.path(out, "bridge.log"), stderr = file.path(out, "bridge-errors.log"))
if (status != 0L) stop("Bridge/input stage failed; saved checkpoints are retained.")
keys <- sprintf("%s-n%d-r%03d.rds", design$scenario, design$n, design$replicate)
inputs <- file.path(out, "inputs/jobs", keys)
outputs <- file.path(out, "jobs", keys)
stopifnot(all(file.exists(inputs)))
corrected_hooks(); options(warn = 1)
one <- function(i) corrected_job(inputs[i], outputs[i])
if (settings$workers == 1L) invisible(lapply(seq_along(inputs), one)) else
  invisible(parallel::mclapply(seq_along(inputs), one,
    mc.cores = settings$workers, mc.preschedule = FALSE, mc.set.seed = FALSE))
stopifnot(all(file.exists(outputs)))
for (script in c("validate.R", "summarize.R")) {
  status <- system2(file.path(R.home("bin"), "Rscript"),
    c(shQuote(file.path(source_dir, script)), shQuote(out)),
    stdout = file.path(out, paste0(script, ".log")),
    stderr = file.path(out, paste0(script, "-errors.log")))
  if (status != 0L) stop("Postprocessing failed; all saved fits are retained.")
}
summary <- read.csv(file.path(out, "summary.csv"))
stopifnot(nrow(summary) == length(unique(design$scenario)) * length(unique(design$n)) * 4L,
          all(summary$completed == settings$replications))
writeLines(format(Sys.time(), tz = "UTC", usetz = TRUE), file.path(out, "COMPLETED.txt"))
