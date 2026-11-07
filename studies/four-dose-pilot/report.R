# Summarize pilot checkpoints without fitting or imputing missing runs.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !dir.exists(args[1L])) stop("Usage: Rscript report.R OUTPUT_DIRECTORY")
output <- normalizePath(args[1L])
methods <- c("sdr", "tmle")
config_path <- file.path(output, "run-config.json")
config <- if (file.exists(config_path)) jsonlite::read_json(config_path, simplifyVector = TRUE) else NULL
variants <- if (is.null(config$variants)) c("baseline", "optimized") else config$variants
if (!length(variants) || anyDuplicated(variants) || any(!variants %in% c("baseline", "optimized")))
  stop("The run configuration must specify distinct baseline and/or optimized variants.")
variants <- c("baseline", "optimized")[c("baseline", "optimized") %in% variants]
paired_mode <- all(c("baseline", "optimized") %in% variants)
analysis_variant <- if ("optimized" %in% variants) "optimized" else variants[1L]
tolerance <- 1e-7
design_path <- file.path(output, "design.csv")
design <- if (file.exists(design_path)) {
  read.csv(design_path, stringsAsFactors = FALSE)[c("design", "n", "rep")]
} else if (!is.null(config)) {
  expand.grid(design = config$designs, n = config$sizes, rep = config$replicates,
    stringsAsFactors = FALSE)
} else expand.grid(design = c("observed", "full"), n = c(500L, 10000L),
  rep = 1:3, stringsAsFactors = FALSE)
if (!nrow(design) || anyNA(design) || anyDuplicated(design) ||
    any(!design$design %in% c("observed", "full")) ||
    any(design$n < 1 | design$n != floor(design$n) | design$rep < 1 | design$rep != floor(design$rep)))
  stop("The planned dataset manifest is invalid.")
dirs <- list.dirs(file.path(output, "jobs"), recursive = FALSE, full.names = TRUE)
methods_log <- estimates <- comparisons <- timings <- candidates <- list()

safe_read <- function(path, reader) {
  if (!file.exists(path)) return(NULL)
  tryCatch(reader(path), error = identity)
}

method_status <- function(checkpoint, usage, cell, variant, method) {
  if (is.null(checkpoint)) {
    if (is.null(usage)) return("pending")
    if (inherits(usage, "error") || !identical(as.integer(usage$exit_code), 0L))
      return("interrupted")
    return("missing checkpoint")
  }
  if (inherits(checkpoint, "error")) return("unreadable checkpoint")
  if (!isTRUE(checkpoint$design == cell$design && checkpoint$n == cell$n &&
              checkpoint$rep == cell$rep && checkpoint$variant == variant &&
              checkpoint$method == method) || length(checkpoint$error) != 1L ||
      is.na(checkpoint$error)) return("invalid checkpoint")
  if (nzchar(checkpoint$error)) return("fit failed")
  result <- checkpoint$result
  if (length(result$estimates) != 2L || length(result$se) != 2L ||
      !identical(dim(result$eif), c(as.integer(cell$n), 2L)) ||
      any(!is.finite(c(result$estimates, result$se, result$eif)))) return("invalid result")
  "returned"
}

field <- function(x, name, fallback) {
  if (is.null(x) || inherits(x, "error") || length(x[[name]]) != 1L) return(fallback)
  x[[name]]
}

error_text <- function(x) {
  if (inherits(x, "error")) return(conditionMessage(x))
  field(x, "error", "")
}

diagnostic_summary <- function(x) {
  if (inherits(x, "condition"))
    return(list(class = class(x), message = conditionMessage(x)))
  if (is.data.frame(x) || !is.list(x)) return(x)
  lapply(x, diagnostic_summary)
}

compare_numbers <- function(a, b) {
  delta <- abs(b - a)
  c(maximum = max(delta), pass = all(delta <= tolerance * pmax(1, abs(a))))
}

candidate_failures <- function(x, path = "") {
  if (!is.list(x) || inherits(x, "condition")) return(list())
  failures <- list()
  for (i in seq_along(x)) {
    name <- names(x)[i]
    label <- if (length(name) && nzchar(name)) name else as.character(i)
    if (label %in% c("candidate_failures", "failures")) {
      for (f in x[[i]]) failures[[length(failures) + 1L]] <- data.frame(
        fit_scope = path, candidate = field(f, "candidate", ""),
        training_scope = field(f, "scope", ""), message = field(f, "message", ""))
    } else if (is.list(x[[i]]) && !is.data.frame(x[[i]])) {
      failures <- c(failures, candidate_failures(x[[i]], paste0(path, "/", label)))
    }
  }
  failures
}

tuning_values <- function(x, field_name, path = "") {
  if (!is.list(x) || is.data.frame(x)) return(numeric())
  values <- numeric()
  if ("weights" %in% names(x)) {
    if (field_name == "weights") {
      values <- x$weights
      names(values) <- paste(path, names(values), sep = "/")
    } else {
      for (candidate in names(x$penalties)) {
        penalty <- x$penalties[[candidate]]
        scale <- if (is.list(penalty)) penalty$selected$scale else penalty
        # Keep the candidate's key even when it has no selected penalty.
        values[paste(path, candidate, sep = "/")] <- if (length(scale)) scale else NA_real_
      }
    }
    return(values)
  }
  for (i in seq_along(x)) {
    label <- names(x)[i]
    if (!length(label) || !nzchar(label)) label <- as.character(i)
    values <- c(values, tuning_values(x[[i]], field_name, paste(path, label, sep = "/")))
  }
  values
}

for (i in seq_len(nrow(design))) {
  cell <- design[i, ]
  checkpoints <- usage <- status <- stamped <- list()
  for (variant in variants) {
    pattern <- sprintf("^%s-n%d-r0*%d-%s$", cell$design, cell$n, cell$rep, variant)
    directory <- dirs[grepl(pattern, basename(dirs))]
    if (length(directory) > 1L) stop("Duplicate job directory for ", pattern)
    if (!length(directory)) directory <- file.path(output, "jobs", paste0("unstarted-", i, "-", variant))
    stat <- safe_read(file.path(directory, "usage.json"), jsonlite::read_json)
    usage[variant] <- list(stat)
    for (method in methods) {
      key <- paste(variant, method)
      ck <- safe_read(file.path(directory, paste0(method, ".rds")), readRDS)
      checkpoints[key] <- list(ck)
      status[[key]] <- method_status(ck, stat, cell, variant, method)
      method_row <- data.frame(cell, variant, method, status = status[[key]],
        seed = field(ck, "seed", NA_integer_), elapsed_s = field(ck, "elapsed", NA_real_),
        data_hash = field(ck, "data_hash", NA_character_),
        fold_hash = field(ck, "fold_hash", NA_character_),
        fingerprint = field(ck, "fingerprint", NA_character_),
        warning_events = if (is.list(ck) && !inherits(ck, "error") &&
          "warning_counts" %in% names(ck)) sum(ck$warning_counts) else NA_integer_,
        warnings = if (!is.null(ck) && !inherits(ck, "error")) paste(unique(ck$warnings), collapse = " | ") else "",
        error = error_text(ck))
      stamped[key] <- list(method_row)
      methods_log[[length(methods_log) + 1L]] <- method_row
      if (status[[key]] == "returned") {
        estimates[[length(estimates) + 1L]] <- data.frame(design = cell$design, n = cell$n,
          rep = cell$rep, variant, method, time = 2:3,
          estimate = ck$result$estimates, std_error = ck$result$se)
        for (item in candidate_failures(ck$result$diagnostics))
          candidates[[length(candidates) + 1L]] <- data.frame(cell, variant, method, item)
      }
    }
  }
  for (method in if (paired_mode) methods else character()) {
    keys <- paste(variants, method)
    statuses <- unlist(status[keys], use.names = FALSE)
    ref <- checkpoints[[keys[1L]]]
    opt <- checkpoints[[keys[2L]]]
    row <- data.frame(cell, method, baseline_status = statuses[1L], optimized_status = statuses[2L],
      comparable_inputs = NA, estimate_max_abs = NA_real_, se_max_abs = NA_real_,
      eif_max_abs = NA_real_, numeric_match = NA, diagnostics_match = NA,
      weights_max_abs = NA_real_, weight_keys_match = NA, selected_scales_match = NA,
      warnings_match = NA, warning_counts_match = NA, warnings_baseline_only = "",
      warnings_optimized_only = "", fit_errors_match = NA, candidate_failures_match = NA,
      candidate_failures_base = NA_integer_, candidate_failures_opt = NA_integer_,
      diagnostic_difference = "")
    if (!is.null(ref) && !is.null(opt) && !inherits(ref, "error") && !inherits(opt, "error")) {
      a <- stamped[[keys[1L]]]
      z <- stamped[[keys[2L]]]
      fields <- c("seed", "data_hash", "fold_hash", "fingerprint")
      row$comparable_inputs <- all(!is.na(a[fields]) & !is.na(z[fields])) &&
        all(a[fields] == z[fields])
      row$warnings_match <- identical(sort(unique(ref$warnings)), sort(unique(opt$warnings)))
      row$warnings_baseline_only <- paste(setdiff(ref$warnings, opt$warnings), collapse = " | ")
      row$warnings_optimized_only <- paste(setdiff(opt$warnings, ref$warnings), collapse = " | ")
      if ("warning_counts" %in% names(ref) && "warning_counts" %in% names(opt)) {
        ordered_counts <- function(ck) ck$warning_counts[sort(names(ck$warning_counts))]
        row$warning_counts_match <- identical(ordered_counts(ref), ordered_counts(opt))
      }
      row$fit_errors_match <- identical(ref$error, opt$error)
      if (all(statuses == "returned") && row$comparable_inputs) {
        delta <- vapply(c("estimates", "se", "eif"), function(name)
          compare_numbers(ref$result[[name]], opt$result[[name]]), c(maximum = 0, pass = 0))
        row[, c("estimate_max_abs", "se_max_abs", "eif_max_abs")] <- as.list(delta["maximum", ])
        row$numeric_match <- all(delta["pass", ] == 1)
        # Cache counters, elapsed time and the number of quadrature nodes differ by design.
        scientific_fields <- c("bridge", "adjoint", "bounds", "targeting")
        diagnostic <- function(ck) diagnostic_summary(ck$result$diagnostics[
          intersect(scientific_fields, names(ck$result$diagnostics))])
        diff <- all.equal(diagnostic(ref), diagnostic(opt), tolerance = tolerance)
        row$diagnostics_match <- isTRUE(diff)
        if (!isTRUE(diff)) row$diagnostic_difference <- paste(head(diff, 8), collapse = " | ")
        models <- function(ck) ck$result$diagnostics[c("bridge", "adjoint")]
        w_base <- tuning_values(models(ref), "weights")
        w_opt <- tuning_values(models(opt), "weights")
        row$weight_keys_match <- setequal(names(w_base), names(w_opt))
        if (row$weight_keys_match && length(w_base))
          row$weights_max_abs <- max(abs(w_base - w_opt[names(w_base)]))
        scales <- function(ck) {
          scales <- tuning_values(models(ck), "scales")
          if (length(scales)) scales[order(names(scales))] else scales
        }
        row$selected_scales_match <- identical(scales(ref), scales(opt))
        failures_ref <- candidate_failures(models(ref))
        failures_opt <- candidate_failures(models(opt))
        row$candidate_failures_base <- length(failures_ref)
        row$candidate_failures_opt <- length(failures_opt)
        row$candidate_failures_match <- identical(failures_ref, failures_opt)
      }
    }
    comparisons[[length(comparisons) + 1L]] <- row
  }
  for (variant in variants) {
    stat <- usage[[variant]]
    successful <- all(unlist(status[paste(variant, methods)], use.names = FALSE) == "returned")
    fit_seconds <- vapply(stamped[paste(variant, methods)], function(x) x$elapsed_s, 0)
    resumed <- !is.null(stat) && !inherits(stat, "error") && length(stat$resumed_methods) > 0L
    timings[[length(timings) + 1L]] <- data.frame(cell, variant, both_methods_returned = successful,
      resumed = resumed,
      fit_s = sum(fit_seconds), wall_s = field(stat, "wall_seconds", NA_real_),
      peak_mib = field(stat, "max_rss_bytes", NA_real_) / 1024^2,
      exit_code = field(stat, "exit_code", NA_integer_))
  }
}

methods_log <- do.call(rbind, methods_log)
comparisons <- if (length(comparisons)) do.call(rbind, comparisons) else data.frame()
timings <- do.call(rbind, timings)
estimates <- if (length(estimates)) do.call(rbind, estimates) else
  data.frame(design = character(), n = integer(), rep = integer(), variant = character(),
             method = character(), time = integer(), estimate = numeric(), std_error = numeric())
# Exact policy means verified in studies/full-history/verify_four_dose_design.py.
truth <- function(design, time) ifelse(time == 2L, 55 / 96,
  ifelse(design == "observed", 390931619 / 707788800, 379546979 / 707788800))
estimates$truth <- truth(estimates$design, estimates$time)
estimates$error <- estimates$estimate - estimates$truth
estimates$standardized_error <- ifelse(estimates$std_error > 0,
  estimates$error / estimates$std_error, NA_real_)
cells <- unique(design[c("design", "n")])
estimate_cells <- merge(cells, data.frame(time = 2:3), by = NULL)
estimate_summary <- do.call(rbind, lapply(seq_len(nrow(estimate_cells)), function(i) {
  cell <- estimate_cells[i, ]
  planned <- sum(design$design == cell$design & design$n == cell$n)
  result <- data.frame(cell, variant = analysis_variant, planned, truth = truth(cell$design, cell$time))
  for (method in methods) {
    rows <- estimates[estimates$design == cell$design & estimates$n == cell$n &
      estimates$time == cell$time & estimates$variant == analysis_variant & estimates$method == method, ]
    statuses <- methods_log$status[methods_log$design == cell$design & methods_log$n == cell$n &
      methods_log$variant == analysis_variant & methods_log$method == method]
    values <- list(returned = nrow(rows), failed = sum(!statuses %in% c("returned", "pending")),
      pending = sum(statuses == "pending"),
      mean_estimate = if (nrow(rows)) mean(rows$estimate) else NA_real_,
      mean_reported_se = if (nrow(rows)) mean(rows$std_error) else NA_real_)
    result[paste0(method, "_", names(values))] <- values
  }
  result
}))
estimate_summary <- estimate_summary[order(estimate_summary$design, estimate_summary$n,
  estimate_summary$time), ]
candidates <- if (length(candidates)) do.call(rbind, candidates) else
  data.frame(design = character(), n = integer(), rep = integer(), variant = character(),
    method = character(), fit_scope = character(), candidate = character(),
    training_scope = character(), message = character())

join_keys <- c("design", "n", "rep")
completion <- design
completion$status <- vapply(seq_len(nrow(design)), function(i) {
  cell <- design[i, ]
  statuses <- methods_log$status[methods_log$design == cell$design & methods_log$n == cell$n &
    methods_log$rep == cell$rep]
  if (length(statuses) == length(variants) * length(methods) && all(statuses == "returned"))
    "successful complete" else if (any(!statuses %in% c("returned", "pending"))) "failed" else "pending"
}, character(1))
completion_summary <- do.call(rbind, lapply(split(completion,
  list(completion$design, completion$n), drop = TRUE), function(group)
  data.frame(design = group$design[1L], n = group$n[1L], planned = nrow(group),
    returned = sum(group$status == "successful complete"), failed = sum(group$status == "failed"),
    pending = sum(group$status == "pending"))))
method_timing <- do.call(rbind, lapply(split(methods_log,
  list(methods_log$design, methods_log$n, methods_log$variant, methods_log$method), drop = TRUE), function(group) {
  returned <- group$status == "returned"
  measured <- returned & is.finite(group$elapsed_s)
  data.frame(design = group$design[1L], n = group$n[1L], variant = group$variant[1L],
    method = group$method[1L], planned = nrow(group), returned = sum(returned),
    failed = sum(!group$status %in% c("returned", "pending")), pending = sum(group$status == "pending"),
    timed_methods = sum(measured), mean_elapsed_s = if (any(measured)) mean(group$elapsed_s[measured]) else NA_real_,
    total_elapsed_s = if (any(measured)) sum(group$elapsed_s[measured]) else NA_real_)
}))
job_timing <- do.call(rbind, lapply(split(timings,
  list(timings$design, timings$n, timings$variant), drop = TRUE), function(group) {
  measured <- group$both_methods_returned & !group$resumed & group$exit_code %in% 0L &
    is.finite(group$wall_s) & group$wall_s > 0
  jobs <- group[measured, ]
  data.frame(design = group$design[1L], n = group$n[1L], variant = group$variant[1L],
    planned = nrow(group), timed_jobs = nrow(jobs),
    mean_wall_min = if (nrow(jobs)) mean(jobs$wall_s) / 60 else NA_real_,
    total_wall_min = if (nrow(jobs)) sum(jobs$wall_s) / 60 else NA_real_,
    max_peak_mib = if (nrow(jobs) && all(is.finite(jobs$peak_mib))) max(jobs$peak_mib) else NA_real_)
}))
if (paired_mode) {
paired <- merge(subset(timings, variant == "baseline", select = -variant),
  subset(timings, variant == "optimized", select = -variant), by = join_keys, suffixes = c("_base", "_opt"))
for (i in seq_len(nrow(paired))) {
  row <- paired[i, ]
  match <- comparisons[comparisons$design == row$design & comparisons$n == row$n &
                         comparisons$rep == row$rep, ]
  statuses <- c(match$baseline_status, match$optimized_status)
  paired$completion_status[i] <- if (length(statuses) == 4L && all(statuses == "returned")) {
    "successful complete"
  } else if (any(!statuses %in% c("returned", "pending"))) {
    "failed"
  } else "pending"
  paired$primary_match[i] <- nrow(match) == 2L && all(match$numeric_match %in% TRUE)
  paired$equivalent[i] <- paired$primary_match[i] && all(match$diagnostics_match %in% TRUE)
}
fresh <- !paired$resumed_base & !paired$resumed_opt &
  paired$exit_code_base %in% 0L & paired$exit_code_opt %in% 0L &
  is.finite(paired$wall_s_base) & is.finite(paired$wall_s_opt) &
  paired$wall_s_base > 0 & paired$wall_s_opt > 0
paired$timed_primary <- fresh & paired$primary_match
paired$timed <- fresh & paired$equivalent
paired$primary_wall_speedup <- ifelse(paired$timed_primary, paired$wall_s_base / paired$wall_s_opt, NA_real_)
paired$wall_speedup <- ifelse(paired$timed, paired$primary_wall_speedup, NA_real_)

timing_summary <- function(jobs) {
  available <- function(values, fn) if (length(values) && all(is.finite(values))) fn(values) else NA_real_
  base <- available(jobs$wall_s_base, mean)
  opt <- available(jobs$wall_s_opt, mean)
  data.frame(timed_pairs = nrow(jobs), baseline_wall_min = base / 60,
    optimized_wall_min = opt / 60, wall_speedup = base / opt,
    baseline_total_min = available(jobs$wall_s_base, sum) / 60,
    optimized_total_min = available(jobs$wall_s_opt, sum) / 60,
    peak_mib_base = available(jobs$peak_mib_base, mean), peak_mib_opt = available(jobs$peak_mib_opt, mean),
    max_peak_mib_base = available(jobs$peak_mib_base, max), max_peak_mib_opt = available(jobs$peak_mib_opt, max))
}
summary <- do.call(rbind, lapply(split(paired, list(paired$design, paired$n), drop = TRUE), function(group) {
  strict <- timing_summary(group[group$timed, ])
  primary <- timing_summary(group[group$timed_primary, ])
  names(primary) <- paste0("primary_", names(primary))
  data.frame(design = group$design[1L], n = group$n[1L], planned = nrow(group),
    returned_pairs = sum(group$both_methods_returned_base & group$both_methods_returned_opt),
    failed_pairs = sum(group$completion_status == "failed"),
    pending_pairs = sum(group$completion_status == "pending"),
    primary_pairs = sum(group$primary_match), equivalent_pairs = sum(group$equivalent),
    primary, strict, worker_hours_100_reps = if (strict$timed_pairs >= 3L && strict$timed_pairs == nrow(group))
      strict$optimized_wall_min * 100 / 60 else NA_real_)
}))
write.csv(comparisons, file.path(output, "equivalence.csv"), row.names = FALSE)
write.csv(paired, file.path(output, "paired-runtime.csv"), row.names = FALSE)
write.csv(summary, file.path(output, "runtime-summary.csv"), row.names = FALSE)
}
write.csv(methods_log, file.path(output, "method-status.csv"), row.names = FALSE)
write.csv(estimates, file.path(output, "estimates.csv"), row.names = FALSE)
write.csv(estimate_summary, file.path(output, "estimate-summary.csv"), row.names = FALSE)
write.csv(candidates, file.path(output, "candidate-failures.csv"), row.names = FALSE)
write.csv(completion_summary, file.path(output, "completion-summary.csv"), row.names = FALSE)
write.csv(method_timing, file.path(output, "method-timing.csv"), row.names = FALSE)
write.csv(timings, file.path(output, "job-timing.csv"), row.names = FALSE)
write.csv(job_timing, file.path(output, "job-runtime-summary.csv"), row.names = FALSE)

fmt <- function(x) ifelse(is.finite(x), formatC(x, digits = 2, format = "f"), "—")
fmt_estimate <- function(x) ifelse(is.finite(x), formatC(x, digits = 4, format = "f"), "—")
estimate_table <- c("| Design | n | Time | Truth | SDR returned | SDR mean estimate | SDR mean reported SE | TMLE returned | TMLE mean estimate | TMLE mean reported SE |",
  "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
  sprintf("| %s | %d | %d | %s | %d/%d | %s | %s | %d/%d | %s | %s |",
    estimate_summary$design, estimate_summary$n, estimate_summary$time,
    fmt_estimate(estimate_summary$truth), estimate_summary$sdr_returned, estimate_summary$planned,
    fmt_estimate(estimate_summary$sdr_mean_estimate), fmt_estimate(estimate_summary$sdr_mean_reported_se),
    estimate_summary$tmle_returned, estimate_summary$planned, fmt_estimate(estimate_summary$tmle_mean_estimate),
    fmt_estimate(estimate_summary$tmle_mean_reported_se)))
runtime_table <- function(prefix) {
  get_number <- function(name) summary[[paste0(prefix, name)]]
  c("| Design | n | Timed pairs | Baseline mean min/dataset | Optimized mean min/dataset | Speedup | Baseline max MiB | Optimized max MiB |",
    "|---|---:|---:|---:|---:|---:|---:|---:|",
    sprintf("| %s | %d | %d/%d | %s | %s | %s | %s | %s |", summary$design, summary$n,
      get_number("timed_pairs"), summary$planned, fmt(get_number("baseline_wall_min")), fmt(get_number("optimized_wall_min")),
      fmt(get_number("wall_speedup")), fmt(get_number("max_peak_mib_base")), fmt(get_number("max_peak_mib_opt"))))
}
completion_unit <- if (paired_mode) "pairs" else "datasets"
completion_table <- c(paste0("| Design | n | Successful complete ", completion_unit,
  " | Failed ", completion_unit, " | Pending ", completion_unit, " |"),
  "|---|---:|---:|---:|---:|",
  sprintf("| %s | %d | %d/%d | %d/%d | %d/%d |", completion_summary$design, completion_summary$n,
    completion_summary$returned, completion_summary$planned, completion_summary$failed,
    completion_summary$planned, completion_summary$pending, completion_summary$planned))
weight_deltas <- comparisons$weights_max_abs[is.finite(comparisons$weights_max_abs)]
max_weight <- if (length(weight_deltas)) format(max(weight_deltas), digits = 5) else "unavailable"
count_disagreements <- function(x) sprintf("%d/%d", sum(x %in% FALSE), sum(!is.na(x)))
status_counts <- table(methods_log$status)
equivalence_report <- if (paired_mode) c(
  paste0("Across ", nrow(comparisons), " planned method pairs, ", sum(comparisons$numeric_match %in% TRUE),
    " have matching estimates, SEs and person-level influence functions at tolerance 1e-7 × max(1, |baseline|) elementwise. ",
    sum(comparisons$diagnostics_match %in% TRUE), " also pass the original diagnostic comparison: R's all.equal with tolerance 1e-7 on bridge/adjoint weights, tuning and failures, propagation bounds and targeting (when available)."),
  paste0("Largest absolute change in a matched ensemble weight: ", max_weight,
    ". Among checked method pairs, disagreements/checked were ",
    count_disagreements(comparisons$selected_scales_match), " for selected penalty values, ",
    count_disagreements(comparisons$weight_keys_match), " for available weight keys, ",
    count_disagreements(comparisons$candidate_failures_match), " for candidate failures, ",
    count_disagreements(comparisons$fit_errors_match), " for method error messages, ",
    count_disagreements(comparisons$warnings_match), " for warning messages and ",
    count_disagreements(comparisons$warning_counts_match), " for warning frequencies."),
  "", "## Timings where both methods matched on the primary outputs", "",
  runtime_table("primary_"), "",
  "## Timings where both methods also passed the strict diagnostic comparison", "",
  runtime_table(""), "",
  "Each timing table uses fresh, successful process measurements on matched data, folds, seeds and source fingerprint. A pair can contribute to both tables. Runtime is mean wall minutes per dataset for each variant, including both methods; speedup is the ratio of the means, and memory is the largest individual process peak RSS (MiB). Total worker minutes remain in the CSV summaries. Partially resumed processes are excluded. Jobs with statistical failures are retained in the status and comparison files.",
  "", "[Equivalence diagnostics](equivalence.csv) · [Paired per-dataset timings](paired-runtime.csv) · [Paired cell summaries](runtime-summary.csv)",
  "", "A cell's 100-replication worker-hour projection is reported only after all planned pairs, with a minimum of three, pass the strict comparison and have valid timings. It extrapolates the mean observed wall time per job on the measured hardware. Intermediate sample sizes and parallel throughput require separate measurement.") else
    paste0("Only the ", analysis_variant, " variant was configured. Paired equivalence and speedup comparisons are not available.")
method_table <- c("| Design | n | Variant | Method | Returned | Mean fit seconds |",
  "|---|---:|---|---|---:|---:|",
  sprintf("| %s | %d | %s | %s | %d/%d | %s |", method_timing$design, method_timing$n,
    method_timing$variant, toupper(method_timing$method), method_timing$returned,
    method_timing$planned, fmt(method_timing$mean_elapsed_s)))
job_table <- c("| Design | n | Variant | Timed datasets | Mean wall min/dataset | Max peak MiB |",
  "|---|---:|---|---:|---:|---:|",
  sprintf("| %s | %d | %s | %d/%d | %s | %s |", job_timing$design, job_timing$n,
    job_timing$variant, job_timing$timed_jobs, job_timing$planned,
    fmt(job_timing$mean_wall_min), fmt(job_timing$max_peak_mib)))
report <- c("# Four-dose runtime pilot", "",
  paste0(nrow(design), " planned datasets; variants: ", paste(variants, collapse = ", "),
    ". Each variant fits SDR and TMLE at times 2 and 3."),
  if (!is.null(config)) paste0("Configuration: ", config$crossfit, " cross-fitting with ",
    config$outer_folds, " outer person folds.") else character(),
  "", if (is.null(config))
    "Measurements were collected on a shared workstation, with three concurrent workers initially and five after large-task peak RSS was observed to be about 2.1 GiB. Wall times reflect this changing concurrency and other workstation activity." else
    "Measurements were collected on a shared workstation. Concurrent fitting processes and other workstation activity affect wall time.",
  "", completion_table, "",
  paste0("Successful completion requires both methods under every configured variant. A failed ",
    if (paired_mode) "pair" else "dataset", " has at least one method or checkpoint failure; all other incomplete ",
    completion_unit, " are pending. Completion does not imply numerical or diagnostic agreement."),
  "", paste0("Method checkpoints: ", paste(paste(as.integer(status_counts), names(status_counts)), collapse = ", "), "."),
  paste0(nrow(candidates), " candidate failure records in returned-method diagnostics. ",
    sum(methods_log$warning_events > 0, na.rm = TRUE), " method checkpoints recorded warnings."),
  "", paste0("## ", tools::toTitleCase(analysis_variant), " estimates compared with truth"), "",
  estimate_table, "",
  "The exact policy mean at time 2 is 55/96 in both designs. At time 3 it is 390931619/707788800 for observed history and 379546979/707788800 for full history, as verified in studies/full-history/verify_four_dose_design.py.",
  paste0("Means use only returned ", analysis_variant, " fits. Mean reported SE is the average of the individual fits' standard errors; it is not the standard error of the displayed mean estimate. Cells with no returned estimates show a zero count and an em dash. All failures and pending runs remain in the status files, with method-specific counts in estimate-summary.csv. These few datasets provide descriptive checks, without establishing bias or coverage."),
  "Individual estimates.csv rows include truth, error = estimate − truth and standardized_error = error / reported SE (undefined for a nonpositive SE).", "",
  "## Method fitting times", "", method_table, "",
  "Method times are measured elapsed seconds for returned fits and exclude process startup. SDR runs before TMLE, so shared nuisance fits can make TMLE faster. Each method produces both time points. Failed-fit times remain in method-status.csv.",
  "", "## Process times and memory", "", job_table, "",
  "Process times include both methods and startup. Only fresh successful jobs with both methods returned contribute; partially resumed processes are excluded. Memory is maximum individual process peak RSS. Total worker minutes remain in job-runtime-summary.csv.",
  "", equivalence_report, "",
  "[Method status, warnings and errors](method-status.csv) · [Candidate failures](candidate-failures.csv) · [Individual estimates and standardized errors](estimates.csv) · [Estimates compared with truth](estimate-summary.csv) · [Method times](method-timing.csv) · [Process measurements](job-timing.csv) · [Process summaries](job-runtime-summary.csv)")
writeLines(report, file.path(output, "REPORT.md"))
