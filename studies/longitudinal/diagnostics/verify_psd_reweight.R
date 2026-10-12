source("studies/longitudinal/diagnostics/psd_setup.R")
set.seed(77518L)
n <- 300L; H <- rbinom(n, 1, .5); A <- rbinom(n, 1, .5)
Y <- rbinom(n, 1, .2 + .6*A); M <- rbinom(n, 1, .4 + .2*Y)
B <- cbind(H, A); V <- cbind(H, Y); V[M == 0, ] <- NA_real_
labels <- rep(1:3, length.out = n)
fit <- cmbridge::fit_bridge_ensemble(B, V, M, cm_library(bridge = TRUE), fold_id = labels)
reweighted <- psd_reweight_bridge(fit, B, V, M)
fresh <- cmbridge::fit_bridge_ensemble(B, V, M, cm_library(bridge = TRUE),
  fold_id = labels, project_psd = FALSE)
differences <- c(weights = max(abs(fresh$weights - reweighted$weights)),
  predictions = max(abs(predict(fresh, V[M == 1, , drop = FALSE]) - predict(reweighted, V[M == 1, , drop = FALSE]))),
  raw_gram = max(abs(fresh$raw_gram - reweighted$raw_gram)),
  training_loss = abs(fresh$moment_loss - reweighted$moment_loss),
  cv_loss = abs(fresh$cv_loss - reweighted$cv_loss))
stopifnot(max(differences) < 1e-12)

# Verify that the response-engine signature and split replay accept exactly
# the same DGP data and training rows, and retain the reweighted cache entries.
g <- make_mechanism("discrete_dose"); set.seed(884L); d <- draw_data(600L, g)
prepared <- study_task(d, g, learner_groups = 3L, balance_measurement = TRUE)
task <- prepared$task; args <- study_arguments(g); fold <- 1L
rows <- task$folds[[fold]]$training_set
nested <- lmtp:::make_bridge_nested_folds(task$id[rows], d[rows, args$measurement, drop = FALSE], task$learner_folds[[fold]])
canonical <- list(response_nuisance_cache = new.env(parent = emptyenv()), nested_split_function = nested)
original <- d; original$..bridge_row <- seq_len(nrow(d))
engine <- lmtp:::bridge_response_engine(original, prepared$encoded, task, fold, args$measurement,
  args$health, cm_library(bridge = TRUE), sl_library, trt_library, TRUE, study_control(3L), "sdr", nested, canonical)
get("fit_beta", environment(engine$response))(rows, 2L)
psd_project <- FALSE
fitted <- list(response_nuisance_cache = new.env(parent = emptyenv()), nested_split_function = nested)
count <- psd_restore_response_cache(fitted, canonical, task, d, g, fold)
stopifnot(count == 1L)
new_engine <- lmtp:::bridge_response_engine(original, prepared$encoded, task, fold, args$measurement,
  args$health, cm_library(bridge = TRUE), sl_library, trt_library, TRUE, study_control(3L), "sdr", nested, fitted)
model <- get("fit_beta", environment(new_engine$response))(rows, 2L)
stopifnot(identical(model$fit_provenance, "shared candidates, globally reweighted without PSD"),
  !model$psd_projection$applied, length(ls(fitted$response_nuisance_cache$beta)) == 1L)
fwrite(data.table(check = c(names(differences), "verified_cache_entries"),
  value = c(differences, count)), ".runtime/psd-reweight-verification.csv")
cat("Shared-candidate reweighting and exact response-cache reuse verified.\n")
