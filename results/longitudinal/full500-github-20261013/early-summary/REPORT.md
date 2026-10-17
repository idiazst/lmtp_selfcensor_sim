# Observed-history simulation: 500 replications

All 4,000 planned datasets have been processed. Failed estimators and warnings are retained.

Binary treatment and numerical dose 0–3 each use n = 500, 1,000, 4,000 and 10,000, with 500 datasets per setting. Both SDR and logistic TMLE use the one-step bridge/adjoint correction, shared training-only splits and the original positive penalty CV. The U-statistic ensemble Gram is projected to PSD. This is the original correctly specified full-study configuration; no experimental penalty rules, known-function estimators, zero-penalty runs or Gaussian mean updates are included.

The numerical package sources are the original frozen full-study archives: cmbridge 0.3.0.9020 and lmtp 1.6.0.9021. Hashes are verified before use. Seeds for the original sample sizes and first 200 replications retain their original mapping; all fits in this rerun are computed afresh on GitHub. References are used only for evaluation, never fitting or penalty selection.

## Multiplier-bootstrap check on all 500 replications

[The multiplier-bootstrap report](../multiplier-bootstrap/REPORT.md) uses these same 4,000 completed checkpoints, reconstructing the influence functions from saved fitted values, seeds and splits without refitting. Gaussian multipliers exactly reproduce the normal intervals. At t=3, +1/-1 and exponential multipliers do not resolve numerical-dose undercoverage; exponential multipliers improve the binary-treatment example. Both outcome times, all original fit failures and complete interval/reconstruction audits are reported. The earlier [Monte Carlo variance diagnostic](../variance-t3/REPORT.md) used a 447-replication snapshot; the scaled-error and variance tables below now use all 500 replications, including all recorded failures.

## Estimates and confidence intervals

Coverage below uses returned estimators as its denominator. Failed estimators, pending datasets, and coverage counting failures as producing no interval are also reported. At 500 successful replications, the simulation standard error of 95% coverage is about one percentage point. A partially completed subset may depend on fitting difficulty; it is not a final coverage study.

### Outcome at time 3

| Treatment | n | Estimator | Returned | Failed | Pending | Truth | Mean | Bias | RMSE | SD | MeanSE | Coverage | MCinterval |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 483 | 17 | 0 | 0.64975 | 0.67464 | 0.02489 | 0.45463 | 0.45442 | 0.23202 | 92.1% | [89.4%, 94.2%] |
| Binary treatment |   500 | TMLE | 483 | 17 | 0 | 0.64975 | 0.65326 | 0.00351 | 0.19550 | 0.19567 | 0.18886 | 91.7% | [88.9%, 93.9%] |
| Binary treatment |  1000 | SDR | 496 |  4 | 0 | 0.64975 | 0.66435 | 0.01460 | 0.16152 | 0.16102 | 0.12720 | 94.2% | [91.7%, 95.9%] |
| Binary treatment |  1000 | TMLE | 496 |  4 | 0 | 0.64975 | 0.65760 | 0.00785 | 0.11963 | 0.11949 | 0.11556 | 93.8% | [91.3%, 95.6%] |
| Binary treatment |  4000 | SDR | 499 |  1 | 0 | 0.64975 | 0.65146 | 0.00171 | 0.05935 | 0.05938 | 0.04917 | 94.2% | [91.8%, 95.9%] |
| Binary treatment |  4000 | TMLE | 499 |  1 | 0 | 0.64975 | 0.65032 | 0.00057 | 0.04894 | 0.04898 | 0.04681 | 95.0% | [92.7%, 96.6%] |
| Binary treatment | 10000 | SDR | 500 |  0 | 0 | 0.64975 | 0.64943 | -0.00032 | 0.04458 | 0.04462 | 0.03037 | 94.4% | [92.0%, 96.1%] |
| Binary treatment | 10000 | TMLE | 500 |  0 | 0 | 0.64975 | 0.64892 | -0.00083 | 0.03121 | 0.03123 | 0.02918 | 94.8% | [92.5%, 96.4%] |
| Numerical dose |   500 | SDR | 486 | 14 | 0 | 0.63362 | 0.59720 | -0.03642 | 0.07119 | 0.06124 | 0.05613 | 85.2% | [81.8%, 88.1%] |
| Numerical dose |   500 | TMLE | 486 | 14 | 0 | 0.63362 | 0.59672 | -0.03690 | 0.07103 | 0.06075 | 0.05695 | 86.0% | [82.6%, 88.8%] |
| Numerical dose |  1000 | SDR | 495 |  5 | 0 | 0.63362 | 0.60306 | -0.03056 | 0.04869 | 0.03794 | 0.03439 | 81.0% | [77.3%, 84.2%] |
| Numerical dose |  1000 | TMLE | 495 |  5 | 0 | 0.63362 | 0.60259 | -0.03103 | 0.04935 | 0.03841 | 0.03455 | 81.0% | [77.3%, 84.2%] |
| Numerical dose |  4000 | SDR | 499 |  1 | 0 | 0.63362 | 0.62307 | -0.01056 | 0.02346 | 0.02097 | 0.02012 | 88.2% | [85.0%, 90.7%] |
| Numerical dose |  4000 | TMLE | 499 |  1 | 0 | 0.63362 | 0.62227 | -0.01136 | 0.02330 | 0.02036 | 0.02005 | 88.0% | [84.8%, 90.5%] |
| Numerical dose | 10000 | SDR | 500 |  0 | 0 | 0.63362 | 0.62889 | -0.00474 | 0.01278 | 0.01188 | 0.01101 | 90.4% | [87.5%, 92.7%] |
| Numerical dose | 10000 | TMLE | 500 |  0 | 0 | 0.63362 | 0.62845 | -0.00517 | 0.01279 | 0.01171 | 0.01099 | 90.6% | [87.7%, 92.9%] |

### Outcome at time 2

| Treatment | n | Estimator | Returned | Failed | Pending | Truth | Mean | Bias | RMSE | SD | MeanSE | Coverage | MCinterval |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 483 | 17 | 0 | 0.90031 | 0.90063 | 0.00032 | 0.03698 | 0.03702 | 0.03534 | 94.2% | [91.7%, 96.0%] |
| Binary treatment |   500 | TMLE | 483 | 17 | 0 | 0.90031 | 0.89916 | -0.00115 | 0.03778 | 0.03781 | 0.03554 | 93.2% | [90.6%, 95.1%] |
| Binary treatment |  1000 | SDR | 496 |  4 | 0 | 0.90031 | 0.90106 | 0.00075 | 0.02375 | 0.02376 | 0.02290 | 94.0% | [91.5%, 95.7%] |
| Binary treatment |  1000 | TMLE | 496 |  4 | 0 | 0.90031 | 0.90099 | 0.00069 | 0.02462 | 0.02464 | 0.02323 | 94.0% | [91.5%, 95.7%] |
| Binary treatment |  4000 | SDR | 499 |  1 | 0 | 0.90031 | 0.90014 | -0.00016 | 0.01179 | 0.01180 | 0.01099 | 92.0% | [89.3%, 94.1%] |
| Binary treatment |  4000 | TMLE | 499 |  1 | 0 | 0.90031 | 0.90028 | -0.00003 | 0.01202 | 0.01203 | 0.01104 | 91.6% | [88.8%, 93.7%] |
| Binary treatment | 10000 | SDR | 500 |  0 | 0 | 0.90031 | 0.90059 | 0.00028 | 0.00709 | 0.00709 | 0.00689 | 93.4% | [90.9%, 95.3%] |
| Binary treatment | 10000 | TMLE | 500 |  0 | 0 | 0.90031 | 0.90057 | 0.00026 | 0.00713 | 0.00713 | 0.00690 | 94.0% | [91.6%, 95.8%] |
| Numerical dose |   500 | SDR | 486 | 14 | 0 | 0.85170 | 0.84634 | -0.00536 | 0.04602 | 0.04576 | 0.04289 | 93.6% | [91.1%, 95.5%] |
| Numerical dose |   500 | TMLE | 486 | 14 | 0 | 0.85170 | 0.84451 | -0.00719 | 0.04767 | 0.04717 | 0.04267 | 90.7% | [87.8%, 93.0%] |
| Numerical dose |  1000 | SDR | 495 |  5 | 0 | 0.85170 | 0.84932 | -0.00238 | 0.02633 | 0.02625 | 0.02691 | 96.4% | [94.3%, 97.7%] |
| Numerical dose |  1000 | TMLE | 495 |  5 | 0 | 0.85170 | 0.84879 | -0.00291 | 0.02654 | 0.02641 | 0.02683 | 96.4% | [94.3%, 97.7%] |
| Numerical dose |  4000 | SDR | 499 |  1 | 0 | 0.85170 | 0.85171 | 0.00001 | 0.01279 | 0.01280 | 0.01241 | 94.2% | [91.8%, 95.9%] |
| Numerical dose |  4000 | TMLE | 499 |  1 | 0 | 0.85170 | 0.85176 | 0.00006 | 0.01281 | 0.01282 | 0.01239 | 94.2% | [91.8%, 95.9%] |
| Numerical dose | 10000 | SDR | 500 |  0 | 0 | 0.85170 | 0.85190 | 0.00020 | 0.00787 | 0.00788 | 0.00775 | 93.6% | [91.1%, 95.4%] |
| Numerical dose | 10000 | TMLE | 500 |  0 | 0 | 0.85170 | 0.85188 | 0.00018 | 0.00789 | 0.00789 | 0.00773 | 93.8% | [91.3%, 95.6%] |

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
| Binary treatment |   500 | 2 | SDR | 483 | -0.016663 | 0.016980 |
| Binary treatment |   500 | 2 | TMLE | 483 | -0.018126 | 0.016980 |
| Binary treatment |  1000 | 2 | SDR | 496 | -0.016614 | 0.017364 |
| Binary treatment |  1000 | 2 | TMLE | 496 | -0.016679 | 0.017364 |
| Binary treatment |  4000 | 2 | SDR | 499 | -0.008381 | 0.008217 |
| Binary treatment |  4000 | 2 | TMLE | 499 | -0.008245 | 0.008217 |
| Binary treatment | 10000 | 2 | SDR | 500 | -0.006245 | 0.006528 |
| Binary treatment | 10000 | 2 | TMLE | 500 | -0.006265 | 0.006528 |
| Numerical dose |   500 | 2 | SDR | 486 | -0.017690 | 0.012326 |
| Numerical dose |   500 | 2 | TMLE | 486 | -0.019519 | 0.012326 |
| Numerical dose |  1000 | 2 | SDR | 495 | -0.018007 | 0.015626 |
| Numerical dose |  1000 | 2 | TMLE | 495 | -0.018534 | 0.015626 |
| Numerical dose |  4000 | 2 | SDR | 499 | -0.008049 | 0.008054 |
| Numerical dose |  4000 | 2 | TMLE | 499 | -0.007999 | 0.008054 |
| Numerical dose | 10000 | 2 | SDR | 500 | -0.006385 | 0.006585 |
| Numerical dose | 10000 | 2 | TMLE | 500 | -0.006406 | 0.006585 |
| Binary treatment |   500 | 3 | SDR | 483 | 0.019992 | 0.004898 |
| Binary treatment |   500 | 3 | TMLE | 483 | -0.001390 | 0.004898 |
| Binary treatment |  1000 | 3 | SDR | 496 | -0.006627 | 0.021230 |
| Binary treatment |  1000 | 3 | TMLE | 496 | -0.013376 | 0.021230 |
| Binary treatment |  4000 | 3 | SDR | 499 | -0.020994 | 0.022705 |
| Binary treatment |  4000 | 3 | TMLE | 499 | -0.022133 | 0.022705 |
| Binary treatment | 10000 | 3 | SDR | 500 | -0.019639 | 0.019323 |
| Binary treatment | 10000 | 3 | TMLE | 500 | -0.020155 | 0.019323 |
| Numerical dose |   500 | 3 | SDR | 486 | -0.037251 | 0.000832 |
| Numerical dose |   500 | 3 | TMLE | 486 | -0.037732 | 0.000832 |
| Numerical dose |  1000 | 3 | SDR | 495 | -0.041202 | 0.010640 |
| Numerical dose |  1000 | 3 | TMLE | 495 | -0.041670 | 0.010640 |
| Numerical dose |  4000 | 3 | SDR | 499 | -0.025236 | 0.014680 |
| Numerical dose |  4000 | 3 | TMLE | 499 | -0.026039 | 0.014680 |
| Numerical dose | 10000 | 3 | SDR | 500 | -0.019022 | 0.014286 |
| Numerical dose | 10000 | 3 | TMLE | 500 | -0.019456 | 0.014286 |

## Conditional equations and failures

The saved population diagnostics evaluate fitted functions over the exact finite DGP support. Adjoint solutions can be nonunique, so distance to a selected reference solution alone is not a consistency criterion. The realized category dictionary depends on observed training combinations; unseen combinations retain the original continuation rule. The enlarged sample sizes do not change those learners.

[Conditional equations and population contributions](population-error-by-outcome-time.csv), [candidate failures](nested-candidate-failures.csv.gz), [failed estimators](errors.csv), [penalties](penalty_and_weight_selections.csv.gz), [ensemble weights](ensemble_weight_summary.csv), and [runtimes](job_log.csv) retain the actual numerical records.

[All estimates and intervals](replicates.csv), [summary and simulation uncertainty](summary.csv), [coverage including failed fits](coverage-including-failures.csv), [EIF components](eif-component-means.csv), [source hashes](source-manifest.json), [checkpoint hashes](checkpoint-manifest.json), and [artifact provenance](artifact-provenance.json).

The numerical results, including any unexpected bias or undercoverage, will be reported as observed. This rerun changes replication counts, sample sizes and computing platform; it does not change the fitting criteria to obtain a desired result.

## Scaled bias, MSE and confidence-interval coverage

These calculations use the same saved completed datasets as the preceding report. They do not refit nuisances, change penalties or alter the estimators. Failed fits remain excluded from error moments and included in the separate failure table. Partial completion and the number of successful fits limit the conclusions.

Bias is the average estimate minus the true parameter. MSE is the average squared error. The scaled quantities are square root n times bias and n times MSE. MCSE denotes the standard error due to the finite number of simulation replications. The MSE is decomposed exactly into squared bias and the average squared centered error; this centered variance uses the number of returned fits as its divisor. The empirical SD and variance-calibration ratio use the usual sample-variance divisor, one less than that number.

The variance-calibration ratio is the average reported SE squared divided by the variance of estimates across replications. A ratio below one indicates smaller estimated variance than the observed empirical variance. Comparing the mean SE alone can be misleading when a few datasets have very large SEs; the square root of the average SE squared is the matching comparison.

### Outcome at time 3

| Treatment | n | Estimator | Returned | √n × bias | BiasMCSE | n × MSE | MSEMCSE | n × bias² | n × centered variance | VarianceRatio |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 483 | 0.557 | 0.462 | 103.345 | 45.470 | 0.310 | 103.035 | 0.664 |
| Binary treatment |   500 | TMLE | 483 | 0.078 | 0.199 | 19.110 | 3.680 | 0.006 | 19.103 | 1.926 |
| Binary treatment |  1000 | SDR | 496 | 0.462 | 0.229 | 26.088 | 3.303 | 0.213 | 25.875 | 0.954 |
| Binary treatment |  1000 | TMLE | 496 | 0.248 | 0.170 | 14.310 | 1.480 | 0.062 | 14.249 | 1.384 |
| Binary treatment |  4000 | SDR | 499 | 0.108 | 0.168 | 14.087 | 1.596 | 0.012 | 14.076 | 0.905 |
| Binary treatment |  4000 | TMLE | 499 | 0.036 | 0.139 | 9.580 | 0.876 | 0.001 | 9.578 | 1.167 |
| Binary treatment | 10000 | SDR | 500 | -0.032 | 0.200 | 19.872 | 6.087 | 0.001 | 19.871 | 1.082 |
| Binary treatment | 10000 | TMLE | 500 | -0.083 | 0.140 | 9.743 | 1.077 | 0.007 | 9.736 | 1.865 |
| Numerical dose |   500 | SDR | 486 | -0.814 | 0.062 | 2.534 | 0.160 | 0.663 | 1.871 | 0.985 |
| Numerical dose |   500 | TMLE | 486 | -0.825 | 0.062 | 2.522 | 0.170 | 0.681 | 1.841 | 1.015 |
| Numerical dose |  1000 | SDR | 495 | -0.966 | 0.054 | 2.371 | 0.139 | 0.934 | 1.437 | 0.847 |
| Numerical dose |  1000 | TMLE | 495 | -0.981 | 0.055 | 2.435 | 0.164 | 0.963 | 1.472 | 0.835 |
| Numerical dose |  4000 | SDR | 499 | -0.668 | 0.059 | 2.201 | 0.144 | 0.446 | 1.755 | 0.952 |
| Numerical dose |  4000 | TMLE | 499 | -0.718 | 0.058 | 2.171 | 0.141 | 0.516 | 1.655 | 1.001 |
| Numerical dose | 10000 | SDR | 500 | -0.474 | 0.053 | 1.633 | 0.099 | 0.224 | 1.409 | 0.867 |
| Numerical dose | 10000 | TMLE | 500 | -0.517 | 0.052 | 1.637 | 0.100 | 0.267 | 1.370 | 0.887 |

### Outcome at time 2

| Treatment | n | Estimator | Returned | √n × bias | BiasMCSE | n × MSE | MSEMCSE | n × bias² | n × centered variance | VarianceRatio |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 483 | 0.007 | 0.038 | 0.684 | 0.047 | 0.000 | 0.684 | 0.940 |
| Binary treatment |   500 | TMLE | 483 | -0.026 | 0.038 | 0.714 | 0.052 | 0.001 | 0.713 | 0.912 |
| Binary treatment |  1000 | SDR | 496 | 0.024 | 0.034 | 0.564 | 0.034 | 0.001 | 0.563 | 0.945 |
| Binary treatment |  1000 | TMLE | 496 | 0.022 | 0.035 | 0.606 | 0.037 | 0.000 | 0.606 | 0.903 |
| Binary treatment |  4000 | SDR | 499 | -0.010 | 0.033 | 0.556 | 0.034 | 0.000 | 0.556 | 0.871 |
| Binary treatment |  4000 | TMLE | 499 | -0.002 | 0.034 | 0.578 | 0.036 | 0.000 | 0.578 | 0.846 |
| Binary treatment | 10000 | SDR | 500 | 0.028 | 0.032 | 0.503 | 0.033 | 0.001 | 0.502 | 0.945 |
| Binary treatment | 10000 | TMLE | 500 | 0.026 | 0.032 | 0.509 | 0.033 | 0.001 | 0.508 | 0.938 |
| Numerical dose |   500 | SDR | 486 | -0.120 | 0.046 | 1.059 | 0.071 | 0.014 | 1.045 | 0.899 |
| Numerical dose |   500 | TMLE | 486 | -0.161 | 0.048 | 1.136 | 0.076 | 0.026 | 1.110 | 0.838 |
| Numerical dose |  1000 | SDR | 495 | -0.075 | 0.037 | 0.693 | 0.045 | 0.006 | 0.687 | 1.065 |
| Numerical dose |  1000 | TMLE | 495 | -0.092 | 0.038 | 0.704 | 0.046 | 0.008 | 0.696 | 1.046 |
| Numerical dose |  4000 | SDR | 499 | 0.000 | 0.036 | 0.654 | 0.041 | 0.000 | 0.654 | 0.949 |
| Numerical dose |  4000 | TMLE | 499 | 0.004 | 0.036 | 0.656 | 0.041 | 0.000 | 0.656 | 0.942 |
| Numerical dose | 10000 | SDR | 500 | 0.020 | 0.035 | 0.620 | 0.043 | 0.000 | 0.619 | 0.973 |
| Numerical dose | 10000 | TMLE | 500 | 0.018 | 0.035 | 0.622 | 0.044 | 0.000 | 0.622 | 0.965 |

### Separate calculations for bias and interval width

The following are descriptive calculations on the saved estimates, not new estimators or usable corrected intervals. Subtract mean bias means shifting every estimate by the across-replication mean error, retaining its own SE. Rescale own SE means multiplying each SE by empirical SD divided by the square root of the average SE squared: average variance is matched while each dataset's relative interval width is preserved. Use empirical SD replaces every SE by the same empirical SD. The final two columns combine bias subtraction with these width calculations. Bias and SD are estimated from these same completed replications, so these calculations assess possible explanations for coverage rather than establish a causal attribution or a validated interval correction.

The CSV also reports 95% bootstrap intervals for changes in coverage, variance ratios and scaled errors. This means resampling completed replications with replacement 2000 times and repeating the calculations, including re-estimating bias and SD each time. Estimate and SE remain paired from the same dataset. Standardized errors mean estimate minus truth divided by that dataset's reported SE; their spread and quantiles are recorded. Tail misses and the fractions of MSE contributed by the largest errors are retained. No outlier is removed.

| Treatment | n | Estimator | Actual | SubtractMeanBias | RescaleOwnSE | UseEmpiricalSD | BiasAndRescaledSE | BothChanges |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 92.1% | 89.9% | 97.3% | 97.9% | 96.7% | 98.1% |
| Binary treatment |   500 | TMLE | 91.7% | 91.1% | 78.3% | 95.7% | 78.7% | 95.7% |
| Binary treatment |  1000 | SDR | 94.2% | 93.3% | 94.4% | 93.3% | 93.5% | 93.8% |
| Binary treatment |  1000 | TMLE | 93.8% | 93.5% | 90.7% | 94.0% | 90.1% | 94.4% |
| Binary treatment |  4000 | SDR | 94.2% | 94.0% | 95.2% | 95.0% | 95.2% | 94.8% |
| Binary treatment |  4000 | TMLE | 95.0% | 94.8% | 91.8% | 95.0% | 91.8% | 95.2% |
| Binary treatment | 10000 | SDR | 94.4% | 94.6% | 94.0% | 96.8% | 94.0% | 96.8% |
| Binary treatment | 10000 | TMLE | 94.8% | 95.0% | 84.4% | 94.4% | 84.4% | 94.4% |
| Numerical dose |   500 | SDR | 85.2% | 93.8% | 85.4% | 93.0% | 93.8% | 94.9% |
| Numerical dose |   500 | TMLE | 86.0% | 95.5% | 85.8% | 93.2% | 95.3% | 94.2% |
| Numerical dose |  1000 | SDR | 81.0% | 93.7% | 83.8% | 85.9% | 95.6% | 96.0% |
| Numerical dose |  1000 | TMLE | 81.0% | 93.5% | 85.1% | 86.1% | 95.6% | 96.2% |
| Numerical dose |  4000 | SDR | 88.2% | 94.4% | 89.6% | 92.2% | 95.2% | 95.0% |
| Numerical dose |  4000 | TMLE | 88.0% | 94.6% | 88.0% | 92.0% | 94.6% | 95.0% |
| Numerical dose | 10000 | SDR | 90.4% | 93.2% | 93.6% | 93.6% | 94.6% | 94.0% |
| Numerical dose | 10000 | TMLE | 90.6% | 93.4% | 93.2% | 93.8% | 94.4% | 94.0% |


### Assessment of the current numerical-dose results

- n=500, SDR/TMLE: observed coverage 85.2/86.0%; subtracting mean bias gives 93.8/95.5%; empirical-SD widths give 93.0/93.2%. Estimated/empirical variance ratios are 0.985/1.015. The estimated mean bias contributes 26.2/27.0% of MSE.
  Subtracting mean bias produces the larger coverage improvement in this snapshot. Variance-calibration directions differ between the estimators.
- n=1,000, SDR/TMLE: observed coverage 81.0/81.0%; subtracting mean bias gives 93.7/93.5%; empirical-SD widths give 85.9/86.1%. Estimated/empirical variance ratios are 0.847/0.835. The estimated mean bias contributes 39.4/39.5% of MSE.
  Subtracting mean bias produces the larger coverage improvement in this snapshot. Reported variances are smaller than empirical variance.
- n=4,000, SDR/TMLE: observed coverage 88.2/88.0%; subtracting mean bias gives 94.4/94.6%; empirical-SD widths give 92.2/92.0%. Estimated/empirical variance ratios are 0.952/1.001. The estimated mean bias contributes 20.3/23.8% of MSE.
  Subtracting mean bias produces the larger coverage improvement in this snapshot. Variance-calibration directions differ between the estimators.
- n=10,000, SDR/TMLE: observed coverage 90.4/90.6%; subtracting mean bias gives 93.2/93.4%; empirical-SD widths give 93.6/93.8%. Estimated/empirical variance ratios are 0.867/0.887. The estimated mean bias contributes 13.7/16.3% of MSE.
  Changing interval widths produces the larger coverage improvement in this snapshot. Reported variances are smaller than empirical variance.

The explanation can change with sample size. The mean-bias calculation and the two interval-width calculations assess different features of the error distribution; their changes in coverage need not add up. Subtracting mean bias does not remove dataset-dependent nuisance errors; their variation can increase empirical variance. Nonzero bias, variation in fitted nuisance functions, nonnormal tails, and dependence between errors and reported SEs can all contribute. A variance-calibration discrepancy does not by itself identify a bug in the variance formula.

- n=10,000 SDR: estimated/empirical variance ratio 0.867, with 95% simulation interval [0.771, 0.987]; replacing SEs by the empirical SD changes coverage by 3.2 percentage points, with interval [0.8, 6.0]. Assess this result together with the completed replication count and the other coverage calculations.
- n=10,000 TMLE: estimated/empirical variance ratio 0.887, with 95% simulation interval [0.791, 1.014]; replacing SEs by the empirical SD changes coverage by 3.2 percentage points, with interval [0.6, 5.6]. Assess this result together with the completed replication count and the other coverage calculations.

Binary-treatment MSE can be strongly affected by a few large errors. The table retains them, and the CSV reports their contribution rather than silently trimming them. These partial results do not establish asymptotic convergence: square root n times bias need not be zero at these sample sizes, and n times MSE can fluctuate because of rare large errors.

Both figures show the final outcome at time t=3. Scaled-MSE plots use a logarithmic vertical axis so rare large binary-treatment errors do not hide the other sample sizes. Bars show the bootstrap simulation intervals, not causal-parameter confidence intervals.

![Scaled bias and MSE](figures/scaled-bias-mse.png)
![Variance calibration and coverage calculations](figures/bias-variance-coverage.png)

[All scaled errors, variance ratios, bootstrap intervals and tail diagnostics](bias-variance-assessment.csv).
