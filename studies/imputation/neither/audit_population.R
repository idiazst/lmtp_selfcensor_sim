# Deterministic enumeration only: no random data, model fitting, or simulation.
args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grepl("^--file=", args)])
root <- dirname(normalizePath(script))
source(file.path(root, "dgp.R"))
tol <- 1e-10
summary_rows <- bridge_rows <- list()

for (scenario in mi_scenarios) {
  pop <- mi_population(scenario)
  stopifnot(abs(sum(pop$probability) - 1) < tol,
    all(pop$probability > 0), all(pop$rho > 0 & pop$rho < 1))
  beta <- lambda <- matrices <- list()
  observed_mu <- weighted_mu <- numeric(2)
  for (w in 0:1) {
    # M[a,y] = P(Y=y,R=1 | A=a,W=w).
    M <- outer(0:1, 0:1, Vectorize(function(a, y)
      dbinom(y, 1, mi_outcome_probability(w, a)) *
        mi_response_probability(w, a, y, scenario)))
    stopifnot(qr(M)$rank == 2L)
    b <- as.vector(solve(M, c(1, 1)))
    stopifnot(all(b > 1), max(abs(M %*% b - 1)) < tol)
    g <- c(1 - mi_treatment_probability(w), mi_treatment_probability(w))
    joint <- sweep(M, 1, g, `*`)
    posterior <- t(joint) / colSums(joint)
    ratio <- c(0, 1 / g[2])
    phi <- (0:1) * as.vector(posterior %*% ratio)
    lam <- as.vector(solve(posterior, phi))
    stopifnot(max(abs(posterior %*% lam - phi)) < tol)
    observed_mu[w + 1L] <- M[2, 2] / sum(M[2, ])
    weighted_mu[w + 1L] <- M[2, 2] * b[2]
    beta[[w + 1L]] <- b
    lambda[[w + 1L]] <- lam
    matrices[[w + 1L]] <- M
    for (y in 0:1) bridge_rows[[length(bridge_rows) + 1L]] <- data.frame(
      scenario = scenario, W = w, Y = y, beta = b[y + 1L],
      inverse_expit_coefficient_value = -log(b[y + 1L] - 1),
      operator_determinant = det(M),
      operator_min_singular_value = min(svd(M)$d))
  }
  # Fixed quadratic bases contain every function of two binary variables,
  # including the required interactions; no training dictionary is needed.
  support <- expand.grid(value = 0:1, W = 0:1)
  X <- with(support, cbind(1, W, value, W * value))
  stopifnot(qr(X)$rank == 4L)
  for (v in list(-log(unlist(beta) - 1), unlist(lambda)))
    stopifnot(max(abs(X %*% solve(X, v) - v)) < tol)
  shadow_gap <- max(vapply(0:1, function(w) max(abs(
    mi_response_probability(w, 1, 0:1, scenario) -
      mi_response_probability(w, 0, 0:1, scenario))), numeric(1)))
  mar_gap <- max(vapply(0:1, function(w) max(abs(
    mi_response_probability(w, 0:1, 1, scenario) -
      mi_response_probability(w, 0:1, 0, scenario))), numeric(1)))
  truth <- mean(mi_outcome_probability(0:1, 1))
  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    scenario = scenario, truth = truth,
    missing_fraction = sum(pop$probability[pop$R2 == 0]),
    mar_holds = mar_gap < tol, shadow_holds = shadow_gap < tol,
    mar_response_contrast = mar_gap, shadow_response_contrast = shadow_gap,
    mi_population_limit = mean(observed_mu),
    bridge_population_limit = mean(weighted_mu),
    mi_bias = mean(observed_mu) - truth,
    bridge_bias = mean(weighted_mu) - truth,
    min_bridge = min(unlist(beta)), max_bridge = max(unlist(beta)))
}
out <- do.call(rbind, summary_rows)
stopifnot(max(abs(out$missing_fraction - .35)) < tol,
  identical(out$mar_holds, c(TRUE, FALSE, TRUE, FALSE)),
  identical(out$shadow_holds, c(FALSE, TRUE, TRUE, FALSE)),
  abs(out$mi_bias[1]) < tol, out$bridge_bias[1] < -.1,
  out$mi_bias[2] < -.1, abs(out$bridge_bias[2]) < tol,
  max(abs(unlist(out[3, c("mi_bias", "bridge_bias")]))) < tol,
  out$mi_bias[4] < -.05, out$bridge_bias[4] < -.05,
  abs(out$mi_bias[4] - out$bridge_bias[4]) < tol,
  abs(out$mar_response_contrast[4] - .3) < tol,
  abs(out$shadow_response_contrast[4] - .15) < tol)
output_dir <- Sys.getenv("MI_AUDIT_OUT", root)
write.csv(out, file.path(output_dir, "population-audit.csv"), row.names = FALSE)
write.csv(do.call(rbind, bridge_rows), file.path(output_dir, "population-bridges.csv"), row.names = FALSE)
print(out, digits = 9, row.names = FALSE)
cat("PASS: exact finite-support audit. No Monte Carlo simulation was run.\n")
