# Independent finite-support tangent check. No fitted estimator is called.
source("studies/full-history/dgp.R")
args <- commandArgs(TRUE)
output <- if (length(args)) args[1] else "work/full-history-gradient-validation"
dir.create(output, recursive = TRUE, showWarnings = FALSE)

shift_probability <- function(probability, selected, step) {
  plogis(qlogis(probability) + step * selected)
}

natural_treatment <- function(current, stage, g, direction = NULL, step = 0) {
  if (g$type == "binary") {
    probability <- c(1 - (.25 + .5 * current), .25 + .5 * current)
  } else {
    probability <- exp(g$levels * .35 * (2 * current - 1))
    probability <- probability / sum(probability)
  }
  if (!is.null(direction) && direction$component == paste0("A", stage) &&
      current == direction$current) {
    probability <- probability * exp(step * (g$levels == direction$treatment))
    probability <- probability / sum(probability)
  }
  probability
}

health_transition <- function(previous, treatment, stage, g,
                              direction = NULL, step = 0) {
  probability <- .1 + .25 * previous + .5 * treatment / max(g$levels)
  selected <- !is.null(direction) && direction$component == paste0("C", stage) &&
    previous == direction$previous && treatment == direction$treatment
  shift_probability(probability, selected, step)
}

visit_transition <- function(previous, current, stage,
                             direction = NULL, step = 0) {
  probability <- .55 + .25 * current - .1 * previous
  selected <- !is.null(direction) && direction$component == paste0("R", stage) &&
    previous == direction$previous && current == direction$current
  shift_probability(probability, selected, step)
}

# Separate enumeration of the observed-law extension and causal interventions.
tangent_population <- function(g, direction = NULL, step = 0) {
  x <- expand.grid(C1 = 0:1, A1 = g$levels, C2 = 0:1, R2 = 0:1,
                   A2 = g$levels, C3 = 0:1, R3 = 0:1)
  prior <- shift_probability(.5, !is.null(direction) &&
                              direction$component == "C1", step)
  x$p <- vapply(seq_len(nrow(x)), function(i) {
    a <- x[i, ]
    pa2 <- if (a$R2 == 1) natural_treatment(a$C2, 2, g, direction, step)[a$A2 + 1]
      else as.numeric(a$A2 == 0)
    dbinom(a$C1, 1, prior) *
      natural_treatment(a$C1, 1, g, direction, step)[a$A1 + 1] *
      dbinom(a$C2, 1, health_transition(a$C1, a$A1, 2, g, direction, step)) *
      dbinom(a$R2, 1, visit_transition(a$C1, a$C2, 2, direction, step)) * pa2 *
      dbinom(a$C3, 1, health_transition(a$C2, a$A2, 3, g, direction, step)) *
      dbinom(a$R3, 1, visit_transition(a$C2, a$C3, 3, direction, step))
  }, 0)
  x[x$p > 0, ]
}

tangent_truth <- function(g, direction = NULL, step = 0) {
  result <- c(0, 0)
  prior <- shift_probability(.5, !is.null(direction) &&
                              direction$component == "C1", step)
  policy <- function(a) if (g$type == "binary") 1 else min(a + 1, 3)
  for (c1 in 0:1) for (a1 in g$levels) for (c2 in 0:1) {
    mass <- dbinom(c1, 1, prior) *
      natural_treatment(c1, 1, g, direction, step)[a1 + 1] *
      dbinom(c2, 1, health_transition(c1, policy(a1), 2, g, direction, step))
    result[1] <- result[1] + mass * c2
    for (r2 in 0:1) for (a2 in g$levels) {
      probability <- if (r2 == 1) natural_treatment(c2, 2, g, direction, step)[a2 + 1]
        else g$continuation[a2 + 1]
      actual <- if (r2 == 1) policy(a2) else a2
      result[2] <- result[2] + mass *
        dbinom(r2, 1, visit_transition(c1, c2, 2, direction, step)) * probability *
        health_transition(c2, actual, 3, g, direction, step)
    }
  }
  result
}

observed_key <- function(p) with(p, paste(C1, A1, R2,
  ifelse(R2 == 1, C2, "missing"), A2, R3,
  ifelse(R3 == 1, C3, "missing"), sep = ":"))

reference_gradient <- function(g, p) {
  policy <- function(a) if (g$type == "binary") rep(1, length(a)) else pmin(a + 1, 3)
  ratio <- function(c, a) {
    probability <- natural_treatment(c, 1, g)
    sum(probability[policy(g$levels) == a]) / probability[a + 1]
  }
  rd1 <- mapply(ratio, p$C1, p$A1)
  rd2 <- mapply(ratio, p$C2, p$A2)
  rt2 <- mapply(function(c, a) g$continuation[a + 1] /
                  natural_treatment(c, 2, g)[a + 1], p$C2, p$A2)
  beta1 <- 1 / visit_transition(p$C1, p$C2, 2)
  beta2 <- 1 / visit_transition(p$C2, p$C3, 3)
  omega2 <- rd1 * p$R2 * (rd2 + (beta1 - 1) * rt2)
  m2 <- function(c, a) health_transition(c, a, 3, g)
  mt <- function(c) sum(g$continuation * vapply(g$levels, function(a) m2(c, a), 0))
  md <- function(c, a) m2(c, policy(a))
  m1 <- function(c, a) sum(vapply(0:1, function(nextc) {
    visit <- visit_transition(c, nextc, 2)
    continuation <- sum(natural_treatment(nextc, 2, g) *
                          vapply(g$levels, function(nexta) md(nextc, nexta), 0)) +
      (1 / visit - 1) * mt(nextc)
    dbinom(nextc, 1, health_transition(c, a, 2, g)) * visit * continuation
  }, 0))
  adjoint <- function(stage, loading) {
    current <- p[[paste0("C", stage)]]
    treatment <- p[[paste0("A", stage)]]
    future <- p[[paste0("C", stage + 1)]]
    complete <- p[[paste0("R", stage + 1)]] *
      if (stage == 1) 1 else p$R2
    result <- numeric(nrow(p))
    for (c in 0:1) {
      operator <- matrix(0, 2, length(g$levels))
      loading_mean <- numeric(2)
      for (nextc in 0:1) {
        mass <- p$p * complete * (current == c) * (future == nextc)
        operator[nextc + 1, ] <- vapply(g$levels, function(a)
          sum(mass * (treatment == a)) / sum(mass), 0)
        loading_mean[nextc + 1] <- sum(mass * loading) / sum(mass)
      }
      coefficient <- drop(t(operator) %*% solve(tcrossprod(operator), loading_mean))
      stopifnot(max(abs(operator %*% coefficient - loading_mean)) < 1e-11)
      result[current == c] <- coefficient[treatment[current == c] + 1]
    }
    result
  }
  terminal_first <- adjoint(1, rd1 * p$C2)
  bridge_first <- adjoint(1, rd1 * vapply(p$C2, mt, 0))
  bridge_second <- adjoint(2, omega2 * p$C3)
  q2 <- p$R2 * (mapply(md, p$C2, p$A2) + (beta1 - 1) * vapply(p$C2, mt, 0))
  D1 <- mapply(function(c, a) health_transition(c, policy(a), 2, g), p$C1, p$A1) +
    rd1 * (p$R2 * beta1 * p$C2 -
             mapply(function(c, a) health_transition(c, a, 2, g), p$C1, p$A1)) -
    terminal_first * (p$R2 * beta1 - 1)
  D2 <- mapply(function(c, a) m1(c, policy(a)), p$C1, p$A1) +
    rd1 * (q2 - mapply(m1, p$C1, p$A1)) +
    omega2 * (p$R3 * beta2 * p$C3 - mapply(m2, p$C2, p$A2)) -
    bridge_first * (p$R2 * beta1 - 1) -
    p$R2 * bridge_second * (p$R3 * beta2 - 1)
  sweep(cbind(D1, D2), 2, tangent_truth(g), "-")
}

directions <- function(g) {
  result <- list(list(component = "C1", label = "baseline health"))
  for (stage in 1:2) for (c in 0:1) for (a in g$levels[-1]) {
    result[[length(result) + 1]] <- list(component = paste0("A", stage),
      current = c, treatment = a, label = sprintf("A%d: C=%d, A=%d", stage, c, a))
  }
  for (stage in 2:3) for (c in 0:1) for (a in g$levels) {
    result[[length(result) + 1]] <- list(component = paste0("C", stage),
      previous = c, treatment = a, label = sprintf("C%d: previous=%d, A=%d", stage, c, a))
  }
  for (stage in 2:3) for (c in 0:1) for (nextc in 0:1) {
    result[[length(result) + 1]] <- list(component = paste0("R", stage),
      previous = c, current = nextc,
      label = sprintf("R%d: previous=%d, current=%d", stage, c, nextc))
  }
  result
}

checks <- list()
population_checks <- list()
for (mechanism in c("binary", "dose")) {
  g <- fh_mechanism(mechanism)
  p <- tangent_population(g)
  original <- fh_population(g)
  stopifnot(identical(p[, setdiff(names(p), "p")], original[, setdiff(names(original), "p")]),
            max(abs(p$p - original$p)) < 1e-13,
            max(abs(tangent_truth(g) - fh_truth(g))) < 1e-13)
  D <- reference_gradient(g, p)
  key <- observed_key(p)
  observable_error <- max(vapply(1:2, function(h)
    max(vapply(split(D[, h], key), function(x) diff(range(x)), 0)), 0))
  stopifnot(observable_error < 1e-10, max(abs(colSums(p$p * D))) < 1e-11)
  reference <- fh_gradient_check(g)
  variance <- colSums(p$p * D^2)
  stopifnot(max(abs(variance - c(reference$variance_reference_h1,
                               reference$variance_reference_h2))) < 1e-9)
  population_checks[[mechanism]] <- data.frame(mechanism = mechanism,
    horizon = 1:2, gradient_mean = colSums(p$p * D), observable_error = observable_error,
    population_gradient_variance = variance)
  base_mass <- tapply(p$p, key, sum)
  for (direction in directions(g)) for (step in c(1e-5, 5e-6)) {
    plus <- tangent_population(g, direction, step)
    minus <- tangent_population(g, direction, -step)
    stopifnot(identical(observed_key(plus), key), identical(observed_key(minus), key))
    plus_mass <- tapply(plus$p, key, sum)
    minus_mass <- tapply(minus$p, key, sum)
    observed_score <- (plus_mass - minus_mass) / (2 * step * base_mass)
    gradient_derivative <- colSums(p$p * D * as.numeric(observed_score[key]))
    causal_derivative <- (tangent_truth(g, direction, step) -
                           tangent_truth(g, direction, -step)) / (2 * step)
    checks[[length(checks) + 1]] <- data.frame(mechanism = mechanism,
      direction = direction$label, component = direction$component, step = step,
      horizon = 1:2, causal_derivative = causal_derivative,
      influence_derivative = gradient_derivative,
      absolute_error = abs(causal_derivative - gradient_derivative),
      observed_score_mean = sum(base_mass * observed_score))
  }
}
checks <- do.call(rbind, checks)
population_checks <- do.call(rbind, population_checks)
write.csv(checks, file.path(output, "population-gradient-derivatives.csv"), row.names = FALSE)
write.csv(population_checks, file.path(output, "population-gradient-observability.csv"), row.names = FALSE)
print(aggregate(absolute_error ~ mechanism + component, checks, max), row.names = FALSE)
stopifnot(max(checks$absolute_error) < 1e-7, max(abs(checks$observed_score_mean)) < 1e-8)
writeLines(c("# Exact influence-function tangent validation", "",
  "This analytical audit calls no fitted estimator and changes no study fits.",
  "It compares forward causal derivatives with E[D * observed-law score].",
  "The observed-law score marginalizes every unrecorded health value.",
  "Separate logit tilts cover baseline health, each treatment/state cell,",
  "each health transition cell and each visit-transition cell.",
  "Visit tilts preserve the treatment shadow exclusions. Policies stay fixed.",
  "Both horizons are checked at finite-difference steps 1e-5 and 5e-6.", "",
  sprintf("%d comparisons across %d generative-law directions; maximum error %.3g.",
    nrow(checks), nrow(unique(checks[c("mechanism", "direction")])), max(checks$absolute_error)),
  sprintf("Maximum observed-data measurability error: %.3g.", max(population_checks$observable_error)),
  "The population variances also agree with the separate existing reference calculation.",
  "These checks validate formulas on this finite-support family; they do not prove",
  "finite-sample nuisance fits or confidence interval calibration.", "",
  paste("Validator MD5:", unname(tools::md5sum("studies/full-history/validate-gradient.R"))),
  paste("DGP source MD5:", unname(tools::md5sum("studies/full-history/dgp.R")))),
  file.path(output, "GRADIENT_VALIDATION.md"))
