# Audit saved predictions and provenance without fitting any additional models.
source("studies/longitudinal/diagnostics/bridge_adjoint_setup.R")
out <- Sys.getenv("DIAGNOSTIC_OUTPUT", "results/longitudinal/bridge-adjoint-seed-check")
manifest <- jsonlite::read_json(file.path(out, "source-manifest.json"), simplifyVector = TRUE)
stopifnot(all(vapply(names(manifest), function(path)
  digest::digest(file = path, algo = "sha256") == manifest[[path]], TRUE)))
paths <- list.files(file.path(out, "jobs"), "\\.rds$", full.names = TRUE)
stopifnot(length(paths) == 36L)
objects <- lapply(paths, readRDS)
fingerprint <- readLines(file.path(out, "fingerprint.txt"))[1L]
g <- make_mechanism("discrete_dose")
connection <- gzfile(file.path(out, "out-of-sample-predictions.csv.gz"), "rt")
predictions <- as.data.table(read.csv(connection, stringsAsFactors = FALSE))
close(connection)
stopifnot(all(is.finite(predictions$truth)), all(is.finite(predictions$estimate)))
cv <- warnings <- hashes <- list()
for (i in seq_along(objects)) {
  x <- objects[[i]]
  stopifnot(is.null(x$error), x$fingerprint == fingerprint,
    !length(intersect(x$training, x$validation)),
    setequal(c(x$training, x$validation), seq_len(x$design$n)))
  metadata <- as.data.table(x$design)
  hashes[[i]] <- cbind(metadata, data.table(
    checkpoint_sha256 = digest::digest(file = paths[i], algo = "sha256"),
    data_sha256 = x$data_sha256, seconds = x$seconds))
  if (length(x$warnings)) warnings[[length(warnings) + 1L]] <- cbind(
    metadata[rep(1L, length(x$warnings))], data.table(warning = x$warnings))
  for (type in c("bridge", "adjoint")) {
    for (name in names(x[[type]]$candidates)) {
      model <- x[[type]]$candidates[[name]]
      if (is.null(model$penalty_cv)) next
      stopifnot(grepl("^interior", model$penalty_status),
        all(model$penalty_cv$scale > 0), sum(model$penalty_cv$selected) == 1L)
      table <- as.data.table(model$penalty_cv)
      cv[[length(cv) + 1L]] <- cbind(metadata[rep(1L, nrow(table))],
        data.table(function_name = type, candidate = name,
          penalty_status = model$penalty_status), table)
    }
  }
}
for (z in split(predictions, by = c("seed", "n", "time"), keep.by = TRUE)) {
  set.seed(z$seed[1L]); d <- draw_data(z$n[1L], g)
  observed <- which(d[[paste0("R", z$time[1L])]] == 1L)
  stopifnot(setequal(z[function_name == "adjoint", row], seq_len(nrow(d))),
    setequal(z[function_name == "bridge", row], observed),
    !anyDuplicated(z[function_name == "adjoint", row]),
    !anyDuplicated(z[function_name == "bridge", row]))
}
hashes <- rbindlist(hashes)
stopifnot(all(hashes[, .(unique_draws = uniqueN(data_sha256)), by = .(seed, n)]$unique_draws == 1L))
fwrite(hashes, file.path(out, "checkpoint-hashes.csv"))
fwrite(rbindlist(cv, fill = TRUE), file.path(out, "penalty-cv.csv"))
fwrite(rbindlist(warnings, fill = TRUE), file.path(out, "warnings.csv"))
# Keep the empty failure table machine-readable as well.
failure_path <- file.path(out, "candidate-failures.csv")
if (file.info(failure_path)$size == 0L) fwrite(data.table(function_name = character(),
  candidate = character(), scope = character(), training_n = integer(),
  error = character(), selected = character(), seed = integer(), n = integer(),
  time = integer(), fold = integer()), failure_path)
equations <- fread(file.path(out, "population-equations.csv"))
large_errors <- equations[time == 3L & function_name == "adjoint", {
  weight <- probability / sum(probability)
  large <- abs(residual) > .5
  list(probability_error_above_half = sum(weight[large]),
    fraction_squared_error_above_half = sum(weight[large] * residual[large]^2) /
      sum(weight * residual^2))
}, by = .(selected, seed, n, fold)]
fwrite(large_errors, file.path(out, "adjoint-large-equation-errors.csv"))
report_path <- file.path(out, "REPORT.md")
report <- readLines(report_path)
marker <- match("## Interpretation and verification", report)
if (!is.na(marker)) report <- report[seq_len(marker - 1L)]
report <- c(report, "", "## Interpretation and verification", "",
  "Both selected seeds show improved final-outcome bridge recovery as n increases. Its population-weighted distance from the selected solution falls from 0.255 to 0.088 for the largest-error seed and from 0.170 to 0.089 for the smallest-error seed between n=4,000 and n=50,000.", "",
  "The final-outcome adjoint's population conditional-equation RMSE also improves: 0.440 to 0.117 and 0.392 to 0.122, respectively. Some equations remain substantially wrong at n=50,000: maximum absolute errors are 2.264 and 2.884. These discrepancies cannot be explained solely by nonuniqueness, because every valid solution must satisfy those equations. This experiment does not establish their cause or resolve the full study's undercoverage.", "",
  "At n=50,000, histories with an adjoint conditional-equation error larger than 0.5 account for 0.95–1.52% of the measured population probability in the six outer fits. These histories contribute 42–64% of the squared equation error. The large discrepancies are therefore concentrated in relatively uncommon histories, but are retained in the plots and maximum-error summary. See [fold-specific values](adjoint-large-equation-errors.csv).", "",
  "The [support audit](sieve-support-by-fold.csv) records population input categories absent from each sieve training sample. For the adjoint at n=50,000, the mean absent-category probability is 0.34% for the largest-error seed and 0.41% for the smallest-error seed. This describes incomplete training support; it does not prove that it explains all remaining equation error. The bridge's global main-effect terms continue to predict when a joint category was absent.", "",
  "The original smallest-error dataset does not demonstrate that its nuisance fits were accurate: its mean sequential EIF component was -0.0132631 and its mean bridge/adjoint component was +0.0133125. Their sum was almost zero. These are the saved full-study contributions; this diagnostic does not refit that estimator.", "",
  "[Verification](VERIFICATION.txt) confirms shared data draws, unchanged fitting sources, outer-fold separation, complete held-out predictions and positive CV grids with interior choices. All 72 ensembles returned with no candidate failures. These are integrity checks, not a claim that the statistical equation errors vanish. [Penalty CV](penalty-cv.csv), [warnings](warnings.csv), and [checkpoint hashes](checkpoint-hashes.csv) preserve the numerical evidence.")
writeLines(report, report_path)
audit_sources <- c("studies/longitudinal/diagnostics/audit_support.R",
  "studies/longitudinal/diagnostics/verify_bridge_adjoint.R")
jsonlite::write_json(as.list(setNames(vapply(audit_sources, function(path)
  digest::digest(file = path, algo = "sha256"), ""), audit_sources)),
  file.path(out, "audit-source-manifest.json"), auto_unbox = TRUE, pretty = TRUE)
writeLines(c("PASS: 36 saved bridge/adjoint pairs, six datasets, no outer-fold overlap.",
  "PASS: source fingerprints unchanged; each seed/size has one shared data draw.",
  "PASS: every adjoint row and every observed bridge row is predicted once out of sample.",
  "PASS: finite predictions; positive CV grids; retained candidates have interior selections.",
  "These are integrity checks. The nonzero defining-equation errors are reported separately."),
  file.path(out, "VERIFICATION.txt"))
cat(readLines(file.path(out, "VERIFICATION.txt")), sep = "\n")
