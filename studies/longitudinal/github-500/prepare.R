source("studies/longitudinal/github-500/config.R")
full500_prepare(Sys.getenv("FULL_OUTPUT", "work/metadata"))
stopifnot(nrow(full500_design) == 4000L, !anyDuplicated(full500_design$job),
  !anyDuplicated(full500_design$seed),
  all(full500_design[, .N, by = .(mechanism, n)]$N == 500L),
  setequal(full500_design$n, c(500L, 1000L, 4000L, 10000L)))
previous <- CJ(mechanism = full500_mechanisms, n = c(500L, 1000L, 4000L), replicate = 1:200)
previous[, seed := 5000000L + match(mechanism, full500_mechanisms) * 100000L +
  match(n, c(500L, 1000L, 4000L)) * 1000L + replicate]
joined <- merge(previous, full500_design, by = c("mechanism", "n", "replicate"))
stopifnot(all(joined$seed.x == joined$seed.y))
cat("Verified 4,000 datasets, 500 per setting, unique seeds and unchanged original seed mapping.\n")
