# Read-only matched comparisons across separately labeled nuisance libraries.
args <- commandArgs(TRUE)
if (length(args) < 2) stop('Supply the main report and one or more comparison reports.')
main_root <- args[1]
read_report <- function(root) {
  m <- readRDS(file.path(root, 'specification.rds'))
  x <- read.csv(file.path(root, 'estimates.csv'), colClasses = c(error = 'character'))
  key <- c('mechanism', 'n', 'replicate', 'method', 'horizon', 'seed')
  if (anyDuplicated(x[key])) stop('Duplicate estimates in an input report.')
  list(manifest = m, rows = x, root = root)
}
main <- read_report(main_root)
main$rows <- main$rows[main$rows$n == 10000, ]
key <- c('mechanism', 'n', 'replicate', 'method', 'horizon', 'seed')
comparisons <- lapply(args[-1], function(root) {
  other <- read_report(root)
  fields <- c('lmtp', 'cmbridge', 'control', 'randomizer', 'ratio_draws', 'k')
  stopifnot(identical(main$manifest[fields], other$manifest[fields]),
    identical(main$manifest$sources['studies/full-history/dgp.R'],
      other$manifest$sources['studies/full-history/dgp.R']))
  z <- merge(main$rows, other$rows, by = key, all.x = TRUE,
    suffixes = c('.main', '.comparison'))
  stopifnot(nrow(z) == nrow(main$rows), all(is.finite(z$truth.comparison)),
    max(abs(z$truth.main - z$truth.comparison)) < 1e-12)
  z$comparison_specification <- other$manifest$specification
  z$comparison_run <- other$manifest$run
  z$valid_pair <- with(z, is.finite(estimate.main) & is.finite(estimate.comparison) &
    is.finite(std.error.main) & is.finite(std.error.comparison) &
    is.finite(conf.low.main) & is.finite(conf.high.main) &
    is.finite(conf.low.comparison) & is.finite(conf.high.comparison))
  z$estimate_change <- z$estimate.main - z$estimate.comparison
  z$se_change <- z$std.error.main - z$std.error.comparison
  z$covered_main <- with(z, conf.low.main <= truth.main & conf.high.main >= truth.main)
  z$covered_comparison <- with(z,
    conf.low.comparison <= truth.comparison & conf.high.comparison >= truth.comparison)
  z$coverage_change <- as.integer(z$covered_main) - as.integer(z$covered_comparison)
  z
})
paired <- do.call(rbind, comparisons)
write.csv(paired, file.path(main_root, 'paired-specification-comparison.csv'), row.names = FALSE)
groups <- split(paired, with(paired,
  interaction(comparison_specification, mechanism, n, method, horizon, drop = TRUE)))
summary <- do.call(rbind, lapply(groups, function(x) {
  z <- x[x$valid_pair, ]
  n <- nrow(z)
  average <- function(value) if (n) mean(value) else NA_real_
  mcse <- function(value) if (n > 1) sd(value) / sqrt(n) else NA_real_
  data.frame(comparison_specification = x$comparison_specification[1],
    comparison_run = x$comparison_run[1], mechanism = x$mechanism[1],
    n = x$n[1], method = x$method[1], horizon = x$horizon[1],
    attempted_pairs = nrow(x), valid_pairs = n, failed_pairs = sum(!x$valid_pair),
    main_bias = average(z$estimate.main - z$truth.main),
    comparison_bias = average(z$estimate.comparison - z$truth.comparison),
    mean_estimate_change = average(z$estimate_change),
    estimate_change_mcse = mcse(z$estimate_change),
    main_rms_se = sqrt(average(z$std.error.main^2)),
    comparison_rms_se = sqrt(average(z$std.error.comparison^2)),
    mean_se_change = average(z$se_change), se_change_mcse = mcse(z$se_change),
    main_coverage = average(z$covered_main),
    comparison_coverage = average(z$covered_comparison),
    coverage_change = average(z$coverage_change),
    coverage_change_mcse = mcse(z$coverage_change),
    gained_coverage = sum(z$coverage_change == 1), lost_coverage = sum(z$coverage_change == -1))
}))
rownames(summary) <- NULL
write.csv(summary, file.path(main_root, 'paired-specification-summary.csv'), row.names = FALSE)
lines <- c('# Matched large-sample specification comparisons', '',
  paste('Main specification:', main$manifest$specification, '; run:', main$manifest$run),
  'All differences are main ensemble minus the named comparison, at n=10000.',
  'Only the same mechanism/replication/method/horizon/seed is paired; all truths agree.',
  'The fitting libraries are distinct. Package versions, DGP hash, folds/control and randomizer match.',
  'The run.R source hash differs for the explicit ridge-input diagnostic; package archives are unchanged.',
  'Each comparison uses the matching first 100 reference seeds, not all 500 precision-study seeds.',
  'Specifications are never pooled and overlapping seeds do not increase independent replication counts.',
  'Coverage-change MCSE uses within-seed indicator differences. No discordance does not establish equivalence.', '',
  paste(capture.output(print(summary, digits = 5, row.names = FALSE)), collapse = '\n'), '',
  paste('Main estimates MD5:', unname(tools::md5sum(file.path(main_root, 'estimates.csv')))),
  paste('Comparison source MD5:', unname(tools::md5sum('studies/full-history/compare-specifications.R'))))
writeLines(lines, file.path(main_root, 'PAIRED_SPECIFICATIONS.md'))
cat(paste(lines, collapse = '\n'), '\n')
