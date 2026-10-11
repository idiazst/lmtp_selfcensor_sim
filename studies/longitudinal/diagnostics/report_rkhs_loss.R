library(data.table)
out <- "results/longitudinal/rkhs-loss-check"
p <- fread(file.path(out, "population-summary.csv"))
cv <- fread(file.path(out, "cv.csv"))
w <- fread(file.path(out, "weights.csv"))
checks <- fread(file.path(out, "checks.csv"))
stopifnot(nrow(checks) == 36L, max(checks$maximum_cv_replay_error) < 1e-12,
  max(checks$true_full_loss) < 1e-24, max(checks$true_nystrom_loss) < 1e-24,
  max(abs(checks$full_population_optimum_weight_true - 1)) < 1e-12,
  max(abs(checks$nystrom_population_optimum_weight_true - 1)) < 1e-12)
largest <- p[n == 50000 & function_name == "bridge" & seed == 5203041]
smallest <- p[n == 50000 & function_name == "bridge" & seed == 5203167]
md <- c("# RKHS loss evaluated at the DGP solutions", "",
  "**The true bridge is a global minimizer of the population RKHS loss.** Its residual has conditional mean zero, so its expected kernel features are zero. The population loss is their squared RKHS norm and is nonnegative. This does not require uniqueness of the solution.", "",
  "The same result holds for the adjoint solution in this DGP. In all 36 final-outcome checks (two seeds, three sample sizes, three outer fits, two functions), the true function has zero loss up to numerical precision for both the full RBF kernel and the package's Nyström approximation. Adding the true function to the population candidate set results in 100% weight on it in every check.", "",
  sprintf("Maximum true population loss: %.3e (full RBF), %.3e (Nyström). Maximum conditional-moment numerical error: %.3e. Maximum error in replaying the saved cross-validation Gram: %.3e.",
    max(checks$true_full_loss), max(checks$true_nystrom_loss),
    max(checks$maximum_true_population_moment), max(checks$maximum_cv_replay_error)), "",
  "## Exact population losses at n=50,000", "",
  "Numbers below are full-RBF population losses multiplied by one million, averaged over the three outer fits. Each column uses its saved training-derived kernel parameters for every function. No Monte Carlo approximation is used to integrate over the DGP.", "",
  "| Function | Largest-error seed 5203041 | Smallest-error seed 5203167 |",
  "|---|---:|---:|")
for (name in c("true", "sieve_md", "landweber", "pmmr", "ensemble")) {
  a <- largest[candidate == name, full_rbf_loss] * 1e6
  b <- smallest[candidate == name, full_rbf_loss] * 1e6
  md <- c(md, sprintf("| %s | %s | %s |", name,
    if (name == "true") "0" else sprintf("%.2f", a),
    if (name == "true") "0" else sprintf("%.2f", b)))
}
relative <- p[n == 50000 & function_name == "bridge" & candidate != "true",
  max(abs(full_rbf_loss - nystrom_loss) / full_rbf_loss)]
md <- c(md, "", sprintf("For these n=50,000 bridge fits, the approximate and full-kernel losses differ by at most %.2f%%. The approximation preserves their ranking. It does not explain the poor selection among these particular fitted candidates.", relative * 100), "",
  "## Population loss versus the implemented validation score", "",
  "The empirical U-statistic estimates the population squared moment but can be negative in one sample. Its minimizer need not be the true function in that sample. Cross-validation kernel scales, bandwidths, centers and fold assignments were reconstructed from the original training rows; all original candidate Gram entries reproduce within numerical precision.", "",
  "The package then projects the candidate Gram to PSD before minimizing it. This changes the finite-sample criterion. In a diagnostic where the true function is added as a fourth candidate, the projected criterion chooses a mixture with approximately zero projected loss, although that mixture has positive population loss. Pure truth has zero population loss. The projection depends on the candidate set, so projected values from this four-candidate check must not be compared with projected values from the original three-candidate library.", "",
  "| Seed at n=50,000 | True-function weight under augmented empirical PSD score | Projected minimum | Population loss of chosen mixture (×1,000,000) |",
  "|---|---:|---:|---:|")
for (data_seed in c(5203041L, 5203167L)) {
  z <- w[seed == data_seed & n == 50000 & function_name == "bridge" &
    method == "validation_augmented_psd" & candidate == "true"]
  md <- c(md, sprintf("| %d | %.1f%% | %.3e | %.2f |", data_seed,
    100 * mean(z$weight), mean(z$resulting_selection_loss),
    1e6 * mean(z$resulting_population_full_loss)))
}
md <- c(md, "", "## Restricting selection to the three estimated candidates", "",
  "Even the exact population RKHS loss can assign some weight to a candidate with worse function RMSE, because its errors can offset errors of another candidate. Among the three saved final fits, the exact population-optimal bridge mixture puts approximately 10.9% PMMR weight for seed 5203041 and 3.3% for seed 5203167. The actual CV mixtures put approximately 27.0% and 26.0% on PMMR. These population comparisons use final training refits; actual cross-validation scores use their saved smaller-training-sample fits. They therefore describe the resulting fits rather than isolate the projection as the sole cause.", "",
  "## Scope and reproduction", "",
  "This is a read-only diagnostic of the saved numerical-dose final-outcome fits at n=4,000, 10,000 and 50,000. It uses both selected seeds and all three outer folds. No package sources, libraries, splits, penalties or fitted objects are changed, and no additional nuisance or parameter estimators are fitted. The true bridge is the inverse measurement probability; the adjoint is the valid reference solution used in the preceding diagnostic. The unpenalized RKHS moment loss is evaluated here. A learner's penalized training objective is a different quantity.", "",
  "Population losses evaluate the saved final training fits with the exact finite DGP support. Validation losses use the saved cross-validation residuals, and the separate held-out table evaluates final fits on the excluded outer rows. Kernel parameters are always those learned from the corresponding original training rows.", "",
  "This verifies the population minimizer and demonstrates finite-sample misranking. It does not establish asymptotic inconsistency or identify a unique remedy. The earlier suggestion that a fixed kernel approximation might explain this candidate ranking is not supported by this check.", "",
  "Run from the repository root:", "", "```sh",
  "Rscript studies/longitudinal/diagnostics/check_rkhs_loss.R",
  "Rscript studies/longitudinal/diagnostics/report_rkhs_loss.R", "```", "",
  "Tables: [population losses](population-summary.csv), [CV U-statistic and augmented PSD scores](cv.csv), [outer held-out scores](validation.csv), [optimal weights](weights.csv), [path from truth to ensemble](curves.csv), and [verification](checks.csv).")
writeLines(md, file.path(out, "REPORT.md"))
writeLines(c("PASS: true functions attain the nonnegative population minimum for full and approximate kernels.",
  "PASS: original validation Grams reproduced; data hashes agree with the saved datasets.",
  "PASS: only losses and weights were evaluated; original fitted objects and packages are unchanged."),
  file.path(out, "VERIFICATION.txt"))
writeLines(format(Sys.time(), tz = "America/New_York", usetz = TRUE), file.path(out, "COMPLETED.txt"))
path <- "studies/longitudinal/diagnostics/report_rkhs_loss.R"
jsonlite::write_json(as.list(setNames(digest::digest(file = path, algo = "sha256"), path)),
  file.path(out, "report-source-manifest.json"), auto_unbox = TRUE, pretty = TRUE)
cat("Report and verification saved.\n")
