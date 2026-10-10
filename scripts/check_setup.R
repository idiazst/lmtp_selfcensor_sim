source('scripts/setup.R')
source('studies/longitudinal/dgp.R')
truth <- audits <- list()
for (name in c('binary_longitudinal', 'discrete_dose')) {
  g <- make_mechanism(name)
  audit <- require_valid_mechanism(g)
  stopifnot(max(abs(exact_truth(g) - backward_truth(g))) < 1e-12)
  truth[[name]] <- data.frame(mechanism = name, outcome_time = 2:3, truth = exact_truth(g))
  audits[[name]] <- audit
  set.seed(101)
  d <- draw_data(1000L, g)
  stopifnot(all(vapply(d, function(x) all(is.na(x) | x == floor(x)), TRUE)),
    any(d$R2 == 0), any(d$R3 == 0), all(d$A2_policy[d$R2 == 0] == 0),
    all(d$A2_other[d$R2 == 0] == 0))
}
dir.create('results/longitudinal/design-checks', showWarnings = FALSE)
write.csv(do.call(rbind, truth), 'results/longitudinal/design-checks/truth.csv', row.names = FALSE)
write.csv(do.call(rbind, audits), 'results/longitudinal/design-checks/assumptions.csv', row.names = FALSE)
print(do.call(rbind, truth))
cat('Approved DGP assumptions, discrete variables, deterministic missed-visit treatment and independent truth calculations pass.\n')
