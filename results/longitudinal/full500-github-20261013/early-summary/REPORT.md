# Observed-history simulation: 500 replications

**PRELIMINARY: 760 of 4,000 datasets have been processed.**

Binary treatment and numerical dose 0–3 each use n = 500, 1,000, 4,000 and 10,000, with 500 datasets per setting. Both SDR and logistic TMLE use the one-step bridge/adjoint correction, shared training-only splits and the original positive penalty CV. The U-statistic ensemble Gram is projected to PSD. This is the original correctly specified full-study configuration; no experimental penalty rules, known-function estimators, zero-penalty runs or Gaussian mean updates are included.

The numerical package sources are the original frozen full-study archives: cmbridge 0.3.0.9020 and lmtp 1.6.0.9021. Hashes are verified before use. Seeds for the original sample sizes and first 200 replications retain their original mapping; all fits in this rerun are computed afresh on GitHub. References are used only for evaluation, never fitting or penalty selection.

## Estimates and confidence intervals

Coverage below uses returned estimators as its denominator. Failed estimators, pending datasets, and coverage counting failures as producing no interval are also reported. At 500 successful replications, the simulation standard error of 95% coverage is about one percentage point. A partially completed subset may depend on fitting difficulty; it is not a final coverage study.

### Outcome at time 3

| Treatment | n | Estimator | Returned | Failed | Pending | Truth | Mean | Bias | RMSE | SD | MeanSE | Coverage | MCinterval |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 93 | 2 | 405 | 0.64975 | 0.73521 | 0.08546 | 0.70847 | 0.70711 | 0.22667 | 92.5% | [85.3%, 96.3%] |
| Binary treatment |   500 | TMLE | 93 | 2 | 405 | 0.64975 | 0.67828 | 0.02853 | 0.24437 | 0.24402 | 0.19387 | 93.5% | [86.6%, 97.0%] |
| Binary treatment |  1000 | SDR | 95 | 0 | 405 | 0.64975 | 0.67626 | 0.02651 | 0.17594 | 0.17485 | 0.13859 | 95.8% | [89.7%, 98.4%] |
| Binary treatment |  1000 | TMLE | 95 | 0 | 405 | 0.64975 | 0.66609 | 0.01635 | 0.13543 | 0.13515 | 0.12504 | 93.7% | [86.9%, 97.1%] |
| Binary treatment |  4000 | SDR | 95 | 0 | 405 | 0.64975 | 0.64971 | -0.00003 | 0.05416 | 0.05444 | 0.05146 | 95.8% | [89.7%, 98.4%] |
| Binary treatment |  4000 | TMLE | 95 | 0 | 405 | 0.64975 | 0.64913 | -0.00062 | 0.04674 | 0.04698 | 0.04940 | 96.8% | [91.1%, 98.9%] |
| Binary treatment | 10000 | SDR | 95 | 0 | 405 | 0.64975 | 0.65688 | 0.00713 | 0.06728 | 0.06725 | 0.03745 | 94.7% | [88.3%, 97.7%] |
| Binary treatment | 10000 | TMLE | 95 | 0 | 405 | 0.64975 | 0.65344 | 0.00369 | 0.03799 | 0.03801 | 0.03505 | 95.8% | [89.7%, 98.4%] |
| Numerical dose |   500 | SDR | 94 | 1 | 405 | 0.63362 | 0.59342 | -0.04020 | 0.07378 | 0.06220 | 0.05715 | 84.0% | [75.3%, 90.1%] |
| Numerical dose |   500 | TMLE | 94 | 1 | 405 | 0.63362 | 0.58941 | -0.04421 | 0.07660 | 0.06289 | 0.05719 | 84.0% | [75.3%, 90.1%] |
| Numerical dose |  1000 | SDR | 93 | 2 | 405 | 0.63362 | 0.60586 | -0.02776 | 0.04750 | 0.03875 | 0.03443 | 82.8% | [73.9%, 89.1%] |
| Numerical dose |  1000 | TMLE | 93 | 2 | 405 | 0.63362 | 0.60572 | -0.02790 | 0.04718 | 0.03825 | 0.03453 | 82.8% | [73.9%, 89.1%] |
| Numerical dose |  4000 | SDR | 95 | 0 | 405 | 0.63362 | 0.62517 | -0.00845 | 0.02087 | 0.01918 | 0.02078 | 92.6% | [85.6%, 96.4%] |
| Numerical dose |  4000 | TMLE | 95 | 0 | 405 | 0.63362 | 0.62415 | -0.00948 | 0.02095 | 0.01879 | 0.02070 | 92.6% | [85.6%, 96.4%] |
| Numerical dose | 10000 | SDR | 95 | 0 | 405 | 0.63362 | 0.62906 | -0.00456 | 0.01307 | 0.01231 | 0.01101 | 88.4% | [80.4%, 93.4%] |
| Numerical dose | 10000 | TMLE | 95 | 0 | 405 | 0.63362 | 0.62870 | -0.00492 | 0.01304 | 0.01214 | 0.01099 | 88.4% | [80.4%, 93.4%] |

### Outcome at time 2

| Treatment | n | Estimator | Returned | Failed | Pending | Truth | Mean | Bias | RMSE | SD | MeanSE | Coverage | MCinterval |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 93 | 2 | 405 | 0.90031 | 0.90243 | 0.00212 | 0.03465 | 0.03477 | 0.03511 | 97.8% | [92.5%, 99.4%] |
| Binary treatment |   500 | TMLE | 93 | 2 | 405 | 0.90031 | 0.90244 | 0.00213 | 0.03528 | 0.03541 | 0.03517 | 94.6% | [88.0%, 97.7%] |
| Binary treatment |  1000 | SDR | 95 | 0 | 405 | 0.90031 | 0.90227 | 0.00196 | 0.02565 | 0.02571 | 0.02270 | 91.6% | [84.3%, 95.7%] |
| Binary treatment |  1000 | TMLE | 95 | 0 | 405 | 0.90031 | 0.90192 | 0.00161 | 0.02601 | 0.02609 | 0.02302 | 92.6% | [85.6%, 96.4%] |
| Binary treatment |  4000 | SDR | 95 | 0 | 405 | 0.90031 | 0.90010 | -0.00021 | 0.01196 | 0.01202 | 0.01101 | 91.6% | [84.3%, 95.7%] |
| Binary treatment |  4000 | TMLE | 95 | 0 | 405 | 0.90031 | 0.90049 | 0.00018 | 0.01232 | 0.01238 | 0.01106 | 89.5% | [81.7%, 94.2%] |
| Binary treatment | 10000 | SDR | 95 | 0 | 405 | 0.90031 | 0.89984 | -0.00046 | 0.00716 | 0.00718 | 0.00691 | 92.6% | [85.6%, 96.4%] |
| Binary treatment | 10000 | TMLE | 95 | 0 | 405 | 0.90031 | 0.89984 | -0.00047 | 0.00716 | 0.00718 | 0.00692 | 92.6% | [85.6%, 96.4%] |
| Numerical dose |   500 | SDR | 94 | 1 | 405 | 0.85170 | 0.84309 | -0.00861 | 0.04820 | 0.04768 | 0.04296 | 93.6% | [86.8%, 97.0%] |
| Numerical dose |   500 | TMLE | 94 | 1 | 405 | 0.85170 | 0.84183 | -0.00988 | 0.05163 | 0.05095 | 0.04269 | 88.3% | [80.2%, 93.3%] |
| Numerical dose |  1000 | SDR | 93 | 2 | 405 | 0.85170 | 0.85094 | -0.00077 | 0.02642 | 0.02655 | 0.02733 | 97.8% | [92.5%, 99.4%] |
| Numerical dose |  1000 | TMLE | 93 | 2 | 405 | 0.85170 | 0.85044 | -0.00126 | 0.02670 | 0.02682 | 0.02724 | 98.9% | [94.2%, 99.8%] |
| Numerical dose |  4000 | SDR | 95 | 0 | 405 | 0.85170 | 0.85335 | 0.00165 | 0.01238 | 0.01234 | 0.01242 | 94.7% | [88.3%, 97.7%] |
| Numerical dose |  4000 | TMLE | 95 | 0 | 405 | 0.85170 | 0.85343 | 0.00173 | 0.01233 | 0.01227 | 0.01239 | 94.7% | [88.3%, 97.7%] |
| Numerical dose | 10000 | SDR | 95 | 0 | 405 | 0.85170 | 0.85284 | 0.00114 | 0.00797 | 0.00792 | 0.00777 | 91.6% | [84.3%, 95.7%] |
| Numerical dose | 10000 | TMLE | 95 | 0 | 405 | 0.85170 | 0.85280 | 0.00110 | 0.00798 | 0.00795 | 0.00776 | 92.6% | [85.6%, 96.4%] |

## Scientific graphs

![Binary treatment: bias](figures/binary_longitudinal-bias.png)
![Binary treatment: root-n-bias](figures/binary_longitudinal-root-n-bias.png)
![Binary treatment: coverage](figures/binary_longitudinal-coverage.png)
![Binary treatment: standard-errors](figures/binary_longitudinal-standard-errors.png)
![Numerical dose: bias](figures/discrete_dose-bias.png)
![Numerical dose: root-n-bias](figures/discrete_dose-root-n-bias.png)
![Numerical dose: coverage](figures/discrete_dose-coverage.png)
![Numerical dose: standard-errors](figures/discrete_dose-standard-errors.png)
![Mean estimates and true means](figures/correctly-specified-curves.png)

## Mean EIF components

The mean sequential component is evaluated at the true parameter. Its sum with the mean bridge/adjoint component equals the mean estimation error. Both components are estimated with the same training-only splits.

| Treatment | n | Outcome | Estimator | Returned | Sequential | BridgeAdjoint |
| --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | 2 | SDR | 93 | -0.018095 | 0.020218 |
| Binary treatment |   500 | 2 | TMLE | 93 | -0.018086 | 0.020218 |
| Binary treatment |  1000 | 2 | SDR | 95 | -0.011575 | 0.013532 |
| Binary treatment |  1000 | 2 | TMLE | 95 | -0.011925 | 0.013532 |
| Binary treatment |  4000 | 2 | SDR | 95 | -0.007959 | 0.007754 |
| Binary treatment |  4000 | 2 | TMLE | 95 | -0.007571 | 0.007754 |
| Binary treatment | 10000 | 2 | SDR | 95 | -0.006847 | 0.006383 |
| Binary treatment | 10000 | 2 | TMLE | 95 | -0.006851 | 0.006383 |
| Numerical dose |   500 | 2 | SDR | 94 | -0.019874 | 0.011264 |
| Numerical dose |   500 | 2 | TMLE | 94 | -0.021141 | 0.011264 |
| Numerical dose |  1000 | 2 | SDR | 93 | -0.018149 | 0.017384 |
| Numerical dose |  1000 | 2 | TMLE | 93 | -0.018645 | 0.017384 |
| Numerical dose |  4000 | 2 | SDR | 95 | -0.006773 | 0.008419 |
| Numerical dose |  4000 | 2 | TMLE | 95 | -0.006688 | 0.008419 |
| Numerical dose | 10000 | 2 | SDR | 95 | -0.006463 | 0.007605 |
| Numerical dose | 10000 | 2 | TMLE | 95 | -0.006507 | 0.007605 |
| Binary treatment |   500 | 3 | SDR | 93 | 0.069603 | 0.015858 |
| Binary treatment |   500 | 3 | TMLE | 93 | 0.012677 | 0.015858 |
| Binary treatment |  1000 | 3 | SDR | 95 | 0.001760 | 0.024755 |
| Binary treatment |  1000 | 3 | TMLE | 95 | -0.008407 | 0.024755 |
| Binary treatment |  4000 | 3 | SDR | 95 | -0.025115 | 0.025082 |
| Binary treatment |  4000 | 3 | TMLE | 95 | -0.025702 | 0.025082 |
| Binary treatment | 10000 | 3 | SDR | 95 | -0.013097 | 0.020229 |
| Binary treatment | 10000 | 3 | TMLE | 95 | -0.016541 | 0.020229 |
| Numerical dose |   500 | 3 | SDR | 94 | -0.043058 | 0.002858 |
| Numerical dose |   500 | 3 | TMLE | 94 | -0.047068 | 0.002858 |
| Numerical dose |  1000 | 3 | SDR | 93 | -0.041184 | 0.013425 |
| Numerical dose |  1000 | 3 | TMLE | 93 | -0.041326 | 0.013425 |
| Numerical dose |  4000 | 3 | SDR | 95 | -0.023159 | 0.014705 |
| Numerical dose |  4000 | 3 | TMLE | 95 | -0.024182 | 0.014705 |
| Numerical dose | 10000 | 3 | SDR | 95 | -0.018764 | 0.014200 |
| Numerical dose | 10000 | 3 | TMLE | 95 | -0.019120 | 0.014200 |

## Conditional equations and failures

The saved population diagnostics evaluate fitted functions over the exact finite DGP support. Adjoint solutions can be nonunique, so distance to a selected reference solution alone is not a consistency criterion. The realized category dictionary depends on observed training combinations; unseen combinations retain the original continuation rule. The enlarged sample sizes do not change those learners.

[Conditional equations and population contributions](population-error-by-outcome-time.csv), [candidate failures](nested-candidate-failures.csv), [failed estimators](errors.csv), [penalties](penalty_and_weight_selections.csv.gz), [ensemble weights](ensemble_weight_summary.csv), and [runtimes](job_log.csv) retain the actual numerical records.

[All estimates and intervals](replicates.csv), [summary and simulation uncertainty](summary.csv), [coverage including failed fits](coverage-including-failures.csv), [EIF components](eif-component-means.csv), [source hashes](source-manifest.json), [checkpoint hashes](checkpoint-manifest.json), and [artifact provenance](artifact-provenance.json).

The numerical results, including any unexpected bias or undercoverage, will be reported as observed. This rerun changes replication counts, sample sizes and computing platform; it does not change the fitting criteria to obtain a desired result.
