if (!exists("penalty_output", inherits = TRUE))
  source("studies/longitudinal/diagnostics/penalty_setup.R", local = TRUE)
g <- make_mechanism("discrete_dose"); p <- enumerate_data(g)
task <- study_task(p, g)$task; truth <- true_values(p, g)
classes <- list()
for (t in 2:3) {
 s <- t - 1L; H <- task$vars$history("A", s); A <- task$vars$A[[s]]
 measured <- p[[paste0("R", t)]] == 1L
 B <- as.matrix(task$natural[, c(H, A), drop = FALSE])
 V <- as.matrix(cbind(task$natural[, H, drop = FALSE], p[, c(paste0("C", t, "_covariate"), paste0("Y", t))]))
 spec <- cmbridge:::.fit_basis_spec(V[measured, , drop = FALSE], "poly", 1L)
 design <- cmbridge:::.eval_basis_spec(V[measured, , drop = FALSE], spec)
 eta <- -log(truth$beta[measured, s] - 1)
 projection <- lm.fit(design, eta)
 classes[[length(classes) + 1L]] <- data.table(time = t, function_name = "bridge", candidate = "landweber",
  basis = "additive inverse-expit", parameters = ncol(design), rank = projection$rank,
  function_eta_max_error = max(abs(projection$residuals)), equation_rmse = NA_real_, equation_max_error = NA_real_)
 # A population range check asks whether ANY member solves the adjoint
 # equation, rather than whether a particular nonunique reference is additive.
 loading <- apply(truth$ratios[, seq_len(s), drop = FALSE], 1L, prod) * ifelse(measured, p[[paste0("Y", t)]], 0)
 critic_spec <- cmbridge:::.fit_basis_spec(V[measured, , drop = FALSE], "cell")
 Q <- cmbridge:::.eval_basis_spec(V[measured, , drop = FALSE], critic_spec)[, -1L, drop = FALSE]
 mass <- as.numeric(crossprod(Q, p$probability[measured]))
 rhs <- as.numeric(crossprod(Q, p$probability[measured] * loading[measured])) / mass
 for (candidate in c("landweber", "sieve_md")) {
  spec <- cmbridge:::.fit_basis_spec(B[measured, , drop = FALSE], if(candidate == "landweber") "bs" else "cell",
    degree = 3L, df = 6L)
  design <- cmbridge:::.eval_basis_spec(B[measured, , drop = FALSE], spec)
  operator <- sweep(crossprod(Q, p$probability[measured] * design), 1L, mass, `/`)
  projection <- lm.wfit(operator, rhs, mass)
  classes[[length(classes) + 1L]] <- data.table(time = t, function_name = "adjoint", candidate = candidate,
    basis = if(candidate == "landweber") "additive spline" else "joint categories", parameters = ncol(design),
    rank = projection$rank, function_eta_max_error = NA_real_,
    equation_rmse = sqrt(sum(mass * projection$residuals^2) / sum(mass)),
    equation_max_error = max(abs(projection$residuals)))
 }
}
# The six fitted PMMR feature spaces are fixed across penalty rules. Check
# their population equation ranges, using the actual trained feature maps.
for (seed in c(5203041L, 5203167L)) for (fold in 1:3) {
 path <- file.path(penalty_output, "jobs", sprintf("seed%d-t3-fold%d-gcv.rds", seed, fold))
 fit <- readRDS(path)$adjoint$candidates$pmmr
 stopifnot(!is.null(fit))
 design <- cmbridge:::.nystrom_apply(cmbridge:::.scale_apply(B[measured, , drop = FALSE], fit$target_scale),
   fit$target_nystrom)
 operator <- sweep(crossprod(Q, p$probability[measured] * design), 1L, mass, `/`)
 projection <- lm.wfit(operator, rhs, mass, tol = 1e-12)
 alternative <- lm.wfit(operator, rhs, mass, tol = 1e-14)
 stopifnot(projection$rank == ncol(design), max(abs(projection$residuals - alternative$residuals)) < 1e-8)
 classes[[length(classes) + 1L]] <- data.table(time = 3L, function_name = "adjoint", candidate = "pmmr",
   basis = "actual Nystrom features", seed = seed, fold = fold, parameters = ncol(design), rank = projection$rank,
   function_eta_max_error = NA_real_, equation_rmse = sqrt(sum(mass * projection$residuals^2) / sum(mass)),
   equation_max_error = max(abs(projection$residuals)))
}
classes <- rbindlist(classes, fill = TRUE)
fwrite(classes, file.path(penalty_output, "function-class-check.csv"))
stopifnot(all(classes[function_name == "bridge", function_eta_max_error] < 1e-10),
          all(classes[candidate == "sieve_md", equation_max_error] < 1e-10))
print(classes)
