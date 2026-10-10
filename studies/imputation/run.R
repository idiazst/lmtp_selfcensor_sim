# Thin entry point to the validated frozen workflow; never refit an active run.
argv <- commandArgs(trailingOnly = TRUE)
mode <- if (length(argv)) argv[1L] else "main"
stopifnot(mode %in% c("main", "pilot", "status"))
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]))
repo <- normalizePath(Sys.getenv("SIM_REPO", dirname(dirname(dirname(script)))))
root <- file.path(repo, "results/imputation/neither")
if (mode == "status") {
  for (phase in c("pilot", "main")) {
    out <- file.path(root, phase)
    cat(phase, ":", length(list.files(file.path(out, "inputs/jobs"), "[.]rds$")),
      "bridge checkpoints,", length(list.files(file.path(out, "jobs"), "[.]rds$")),
      "four-method checkpoints; validated:", file.exists(file.path(out, "COMPLETED.txt")), "\n")
  }
  cat("Combined validated:", file.exists(file.path(root, "combined/COMPLETED.txt")), "\n")
  quit(save = "no", status = 0L)
}
phase <- file.path(root, mode)
if (dir.exists(file.path(phase, "running.lock")))
  stop("This phase is already running. No duplicate was started; use the status command.")
complete <- if (mode == "main") file.path(root, "combined/COMPLETED.txt") else file.path(phase, "COMPLETED.txt")
if (file.exists(complete)) {
  cat("Already completed and validated. Results:", file.path(repo, "results/imputation/REPORT.md"), "\n")
  quit(save = "no", status = 0L)
}
launcher <- file.path(phase, "run-study.sh")
if (!file.exists(launcher)) stop("No frozen phase exists. See studies/imputation/PLAN.md for preparation and baseline requirements.")
quit(save = "no", status = system2("/bin/sh", shQuote(launcher)))
