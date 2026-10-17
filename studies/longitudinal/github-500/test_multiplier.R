# Exact small-vector checks; no DGP, nuisance or estimator is fitted.
library(data.table)
source("studies/longitudinal/github-500/multiplier_functions.R")
person_score <- c(-2, -2, 1, 1, 2)
counts <- c(2L, 2L, 1L)
values <- c(-2, 1, 2)
n <- length(person_score)
scale <- sqrt(n / (n - 1L)) / n
person_weights <- as.matrix(expand.grid(rep(list(c(-1, 1)), n)))
person_errors <- as.vector(person_weights %*% person_score) * scale
group_counts <- as.matrix(expand.grid(0:2, 0:2, 0:1))
group_errors <- as.vector(sweep(2 * group_counts, 2L, counts, "-") %*% values) * scale
group_probabilities <- apply(group_counts, 1L, function(z) prod(dbinom(z, counts, .5)))
grid <- sort(unique(c(person_errors, group_errors)))
for (point in grid) stopifnot(abs(mean(person_errors <= point + 1e-12) -
  sum(group_probabilities[group_errors <= point + 1e-12])) < 1e-12)
se <- sd(person_score) / sqrt(n)
stopifnot(abs(sum(group_probabilities * group_errors)) < 1e-12,
  abs(sum(group_probabilities * group_errors^2) - se^2) < 1e-12,
  abs(scale^2 * sum(counts * values^2) - se^2) < 1e-12)
base <- data.table(mechanism = "fixed_vector_unit_check", n = n, replicate = 1L, seed = 73L,
  estimator = "sdr", horizon = 2L, scenario = "unit_check", truth = 0, estimate = .3, se = se,
  lower = .3 - qnorm(.975) * se, upper = .3 + qnorm(.975) * se)
input <- list(results = base, cells = list(count = counts, centered_score = matrix(values, ncol = 1L)))
a <- multiplier_intervals(input, n, 73L, draws = 9999L)
stopifnot(nrow(a) == 3L, all(a$lower < a$upper),
  a[multiplier == "gaussian", max(abs(lower - original_lower), abs(upper - original_upper))] < 1e-12)
# Changing the known evaluation target cannot change any fitted interval.
input$results <- copy(base); input$results[, truth := 999]
b <- multiplier_intervals(input, n, 73L, draws = 9999L)
stopifnot(identical(a$lower, b$lower), identical(a$upper, b$upper))
# Basic interval inversion is location equivariant for every multiplier law.
input$results <- copy(base)
input$results[, `:=`(estimate = estimate + 100, lower = lower + 100, upper = upper + 100)]
c <- multiplier_intervals(input, n, 73L, draws = 9999L)
stopifnot(max(abs(c$lower - a$lower - 100)) < 1e-12, max(abs(c$upper - a$upper - 100)) < 1e-12)
cat("Exact grouped Rademacher law, variance normalization, Gaussian identity, truth independence and interval inversion pass.\n")
