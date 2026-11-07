# Four-dose runtime tests

## Full GitHub study

The authorized full study uses 500 replications for each of the observed- and full-history designs at n = 1,000, 4,000 and 10,000, giving 3,000 datasets. Each dataset returns SDR and TMLE at outcome times 2 and 3. The study label is `four-dose-20261106-v1`. The numerical specification is the optimized four-outer-fold configuration tested below. Exact package sources are frozen in `dependencies/four-dose/`, including the local fitting revisions, and checked by content hash and installed function bodies.

The `four-dose.yml` GitHub workflow splits the study into cohorts 1–250 and 251–500. Each cohort uses at most ten runners; each runner fits two datasets concurrently and saves every method result or statistical failure. Infrastructure retries retain completed methods and reuse the original seeds. The study fingerprint uses the full grid, so every shard has the same identity. Different numerical revisions require separate study labels and output directories.

During the active run, collect completed artifacts and inspect coverage every two hours:

```sh
python3 studies/four-dose-pilot/artifacts.py --study four-dose-20261106-v1 --target results/four-dose-full-v1
Rscript --vanilla studies/four-dose-pilot/coverage.R results/four-dose-full-v1 results/four-dose-full-v1
```

The report includes empirical coverage of the nominal 95% Wald intervals, Wilson Monte Carlo intervals, bias, empirical SD, mean and RMS reported SE, and all pending and failed fits. A severe-undercoverage flag requires at least 100 successful fits in a design/sample-size/method/outcome cell, coverage below 90%, and a Wilson upper bound below 95%. Interim findings remain provisional because completion times may select the returned datasets. Investigate flagged cells by separating estimation bias, variance miscalibration and numerical failures. Preserve all original checkpoints; evaluate a corrected estimator under a new fingerprint and confirm any changes on additional seeds. Do not replace statistical failures with favorable replications.

Use the root of the simulation repository as the working directory. Both designs use the common latent-state law in `common.R`, and the fitting adapters receive only recorded data.

## Active four-fold configuration

Split people into four fixed outer folds. For each held-out fold, use the other three blocks for fitting and inner validation. Training bridge and ratio arrays reuse the candidates' out-of-fold predictions with the fitted ensemble weights. Each needed parent outcome regression is fitted on each inner-fold complement to generate out-of-fold training responses. Learner validation then uses those fixed responses, without recursively rebuilding the ancestor nuisances. All nuisance fits, selection and ensemble weights exclude the outer-held-out people.

The revised test contains exactly two n = 1,000 datasets, one per design, with seed 7201001. Each returns SDR and TMLE estimates at both outcome times. The completed [results](../../results/four-dose-outer-pilot/REPORT.md) are separate from the superseded recursive pilot. Future sample-size options start at 1,000.

## Learners and implementation

The outcome and ratio library contains a ridge linear learner, a piecewise-linear spline learner with two knots and a dose–health interaction when available, and an intercept. The first two encode additional indicators for four-level doses and use a fixed ridge penalty of 0.02. Bridge and adjoint ensembles contain sieve minimum-distance, Landweber and PMMR candidates. The sieve retains its 41 initial positive regularization values and adaptive grid extensions. Ordinary regularization selection operates on fixed responses within each candidate's training sample. Gaussian Nyström validation uses 100 centers. All randomizer copies of an individual remain in that person's fold.

The optimized implementation caches repeated scoring features and predictions, evaluates the four distinct full-history continuation doses once each, and retains five independent continuation draws per person for density-ratio classification. Source and configuration hashes, installed-function verification, warnings, failures, estimates, standard errors and individual influence functions are saved. Population truths are used only for evaluation.

The observed-history adapter retains the historical applied bridge prediction interval of −100 to 100. The full-history estimator uses the fixed interval of −100 to 100 for recursive pseudo-outcomes and records a failure if it is exceeded. The new two-dataset test returned both methods without hitting that bound.

## Run or resume

Install the revised local packages into an isolated library and run the two datasets:

```sh
mkdir -p .runtime/four-dose-outer-library
export R_LIBS_USER="$PWD/.runtime/four-dose-outer-library:$PWD/.runtime/library"
R CMD INSTALL -l .runtime/four-dose-outer-library ../cmbridge
R CMD INSTALL -l .runtime/four-dose-outer-library ../lmtp
Rscript --vanilla studies/four-dose-pilot/check_data.R
python3 studies/four-dose-pilot/run.py
Rscript --vanilla studies/four-dose-pilot/report.R results/four-dose-outer-pilot
```

The default run uses two workers, n = 1,000, one dataset per design, the optimized variant and four outer folds. The seed formula is `7200000 + n + replicate`. A completed method or recorded statistical failure is preserved on resume. Infrastructure failures use the same seed, and an installed-function check prevents an old package build from being used after an installation failure. New numerical settings need a fresh output directory.

Each R process has one numerical thread. The coordinator measures process wall time and peak RSS, and uses file locks and atomic method checkpoints. SDR precedes TMLE so the second method reuses shared fits. This implementation requires Python file locks and `wait4` (macOS or Linux).

## Superseded pilot

The [earlier pilot](../../results/four-dose-pilot/REPORT.md) used three outer folds and recursive response refitting at n = 500 and 10,000. Its successful baseline/optimized comparisons used a tolerance of `1e-7 * max(1, abs(baseline))` for estimates, standard errors and each influence-function entry. All n = 500 full-history fits failed with unstable bridge extrapolation. On the user's instruction, the two unfinished old variants were stopped and that algorithm was replaced. Its completed results and failures remain in the separate archive.

The earlier timings used three workers initially and five after checking memory. The new two-dataset test ran with two workers. They differ in sample size and fitting algorithm, so the two result sets do not constitute a paired speed comparison.
