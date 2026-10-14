# Scaled errors and variance assessment

Companion analysis of 760 completed dataset checkpoints. Each table states the number of returned estimators. The full study plans 4,000 datasets; incomplete counts are preliminary.


These calculations use the same saved completed datasets as the preceding report. They do not refit nuisances, change penalties or alter the estimators. Failed fits remain excluded from error moments and included in the separate failure table. Partial completion and the number of successful fits limit the conclusions.

Bias is the average estimate minus the true parameter. MSE is the average squared error. The scaled quantities are square root n times bias and n times MSE. MCSE denotes the standard error due to the finite number of simulation replications. The MSE is decomposed exactly into squared bias and the average squared centered error; this centered variance uses the number of returned fits as its divisor. The empirical SD and variance-calibration ratio use the usual sample-variance divisor, one less than that number.

The variance-calibration ratio is the average reported SE squared divided by the variance of estimates across replications. A ratio below one indicates smaller estimated variance than the observed empirical variance. Comparing the mean SE alone can be misleading when a few datasets have very large SEs; the square root of the average SE squared is the matching comparison.

### Outcome at time 3

| Treatment | n | Estimator | Returned | √n × bias | BiasMCSE | n × MSE | MSEMCSE | n × bias² | n × centered variance | VarianceRatio |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 93 | 1.911 | 1.640 | 250.967 | 223.667 | 3.652 | 247.315 | 0.328 |
| Binary treatment |   500 | TMLE | 93 | 0.638 | 0.566 | 29.859 | 17.722 | 0.407 | 29.452 | 1.523 |
| Binary treatment |  1000 | SDR | 95 | 0.838 | 0.567 | 30.955 | 7.288 | 0.703 | 30.252 | 1.073 |
| Binary treatment |  1000 | TMLE | 95 | 0.517 | 0.438 | 18.342 | 5.295 | 0.267 | 18.074 | 1.472 |
| Binary treatment |  4000 | SDR | 95 | -0.002 | 0.353 | 11.731 | 2.856 | 0.000 | 11.731 | 1.222 |
| Binary treatment |  4000 | TMLE | 95 | -0.039 | 0.305 | 8.739 | 1.822 | 0.002 | 8.737 | 1.493 |
| Binary treatment | 10000 | SDR | 95 | 0.713 | 0.690 | 45.261 | 28.995 | 0.509 | 44.753 | 1.084 |
| Binary treatment | 10000 | TMLE | 95 | 0.369 | 0.390 | 14.429 | 4.037 | 0.136 | 14.293 | 2.671 |
| Numerical dose |   500 | SDR | 94 | -0.899 | 0.143 | 2.722 | 0.411 | 0.808 | 1.914 | 1.067 |
| Numerical dose |   500 | TMLE | 94 | -0.989 | 0.145 | 2.934 | 0.521 | 0.977 | 1.956 | 1.010 |
| Numerical dose |  1000 | SDR | 93 | -0.878 | 0.127 | 2.256 | 0.315 | 0.771 | 1.486 | 0.814 |
| Numerical dose |  1000 | TMLE | 93 | -0.882 | 0.125 | 2.226 | 0.320 | 0.778 | 1.447 | 0.840 |
| Numerical dose |  4000 | SDR | 95 | -0.535 | 0.124 | 1.742 | 0.224 | 0.286 | 1.456 | 1.214 |
| Numerical dose |  4000 | TMLE | 95 | -0.599 | 0.122 | 1.756 | 0.227 | 0.359 | 1.397 | 1.256 |
| Numerical dose | 10000 | SDR | 95 | -0.456 | 0.126 | 1.708 | 0.235 | 0.208 | 1.499 | 0.806 |
| Numerical dose | 10000 | TMLE | 95 | -0.492 | 0.125 | 1.700 | 0.235 | 0.242 | 1.458 | 0.826 |

### Outcome at time 2

| Treatment | n | Estimator | Returned | √n × bias | BiasMCSE | n × MSE | MSEMCSE | n × bias² | n × centered variance | VarianceRatio |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 93 | 0.047 | 0.081 | 0.600 | 0.073 | 0.002 | 0.598 | 1.055 |
| Binary treatment |   500 | TMLE | 93 | 0.048 | 0.082 | 0.622 | 0.075 | 0.002 | 0.620 | 1.024 |
| Binary treatment |  1000 | SDR | 95 | 0.062 | 0.083 | 0.658 | 0.093 | 0.004 | 0.654 | 0.795 |
| Binary treatment |  1000 | TMLE | 95 | 0.051 | 0.085 | 0.676 | 0.098 | 0.003 | 0.674 | 0.793 |
| Binary treatment |  4000 | SDR | 95 | -0.013 | 0.078 | 0.572 | 0.079 | 0.000 | 0.572 | 0.843 |
| Binary treatment |  4000 | TMLE | 95 | 0.012 | 0.080 | 0.607 | 0.085 | 0.000 | 0.607 | 0.802 |
| Binary treatment | 10000 | SDR | 95 | -0.046 | 0.074 | 0.512 | 0.070 | 0.002 | 0.510 | 0.927 |
| Binary treatment | 10000 | TMLE | 95 | -0.047 | 0.074 | 0.512 | 0.069 | 0.002 | 0.510 | 0.932 |
| Numerical dose |   500 | SDR | 94 | -0.193 | 0.110 | 1.161 | 0.195 | 0.037 | 1.124 | 0.832 |
| Numerical dose |   500 | TMLE | 94 | -0.221 | 0.118 | 1.333 | 0.226 | 0.049 | 1.284 | 0.720 |
| Numerical dose |  1000 | SDR | 93 | -0.024 | 0.087 | 0.698 | 0.087 | 0.001 | 0.698 | 1.074 |
| Numerical dose |  1000 | TMLE | 93 | -0.040 | 0.088 | 0.713 | 0.086 | 0.002 | 0.711 | 1.045 |
| Numerical dose |  4000 | SDR | 95 | 0.104 | 0.080 | 0.613 | 0.083 | 0.011 | 0.602 | 1.021 |
| Numerical dose |  4000 | TMLE | 95 | 0.110 | 0.080 | 0.608 | 0.082 | 0.012 | 0.596 | 1.026 |
| Numerical dose | 10000 | SDR | 95 | 0.114 | 0.081 | 0.634 | 0.094 | 0.013 | 0.621 | 0.968 |
| Numerical dose | 10000 | TMLE | 95 | 0.110 | 0.082 | 0.638 | 0.096 | 0.012 | 0.625 | 0.958 |

### Separate calculations for bias and interval width

The following are descriptive calculations on the saved estimates, not new estimators or usable corrected intervals. Subtract mean bias means shifting every estimate by the across-replication mean error, retaining its own SE. Rescale own SE means multiplying each SE by empirical SD divided by the square root of the average SE squared: average variance is matched while each dataset's relative interval width is preserved. Use empirical SD replaces every SE by the same empirical SD. The final two columns combine bias subtraction with these width calculations. Bias and SD are estimated from these same completed replications, so these calculations assess possible explanations for coverage rather than establish a causal attribution or a validated interval correction.

The CSV also reports 95% bootstrap intervals for changes in coverage, variance ratios and scaled errors. This means resampling completed replications with replacement 2000 times and repeating the calculations, including re-estimating bias and SD each time. Estimate and SE remain paired from the same dataset. Standardized errors mean estimate minus truth divided by that dataset's reported SE; their spread and quantiles are recorded. Tail misses and the fractions of MSE contributed by the largest errors are retained. No outlier is removed.

| Treatment | n | Estimator | Actual | SubtractMeanBias | RescaleOwnSE | UseEmpiricalSD | BiasAndRescaledSE | BothChanges |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 92.5% | 87.1% | 100.0% | 97.8% | 96.8% | 98.9% |
| Binary treatment |   500 | TMLE | 93.5% | 92.5% | 88.2% | 97.8% | 84.9% | 97.8% |
| Binary treatment |  1000 | SDR | 95.8% | 96.8% | 93.7% | 93.7% | 94.7% | 93.7% |
| Binary treatment |  1000 | TMLE | 93.7% | 93.7% | 91.6% | 95.8% | 91.6% | 96.8% |
| Binary treatment |  4000 | SDR | 95.8% | 95.8% | 90.5% | 96.8% | 90.5% | 96.8% |
| Binary treatment |  4000 | TMLE | 96.8% | 97.9% | 89.5% | 95.8% | 88.4% | 95.8% |
| Binary treatment | 10000 | SDR | 94.7% | 91.6% | 94.7% | 96.8% | 89.5% | 96.8% |
| Binary treatment | 10000 | TMLE | 95.8% | 93.7% | 71.6% | 93.7% | 73.7% | 94.7% |
| Numerical dose |   500 | SDR | 84.0% | 93.6% | 83.0% | 93.6% | 92.6% | 95.7% |
| Numerical dose |   500 | TMLE | 84.0% | 94.7% | 84.0% | 92.6% | 94.7% | 96.8% |
| Numerical dose |  1000 | SDR | 82.8% | 94.6% | 84.9% | 87.1% | 94.6% | 95.7% |
| Numerical dose |  1000 | TMLE | 82.8% | 93.5% | 86.0% | 88.2% | 94.6% | 95.7% |
| Numerical dose |  4000 | SDR | 92.6% | 95.8% | 90.5% | 93.7% | 94.7% | 95.8% |
| Numerical dose |  4000 | TMLE | 92.6% | 95.8% | 90.5% | 92.6% | 94.7% | 95.8% |
| Numerical dose | 10000 | SDR | 88.4% | 88.4% | 92.6% | 93.7% | 89.5% | 92.6% |
| Numerical dose | 10000 | TMLE | 88.4% | 88.4% | 92.6% | 93.7% | 90.5% | 92.6% |


### Assessment of the current numerical-dose results

- n=500, SDR/TMLE: observed coverage 84.0/84.0%; subtracting mean bias gives 93.6/94.7%; empirical-SD widths give 93.6/92.6%. Estimated/empirical variance ratios are 1.067/1.010. The estimated mean bias contributes 29.7/33.3% of MSE.
  Subtracting mean bias produces the larger coverage improvement in this snapshot. Reported variances are larger than empirical variance.
- n=1,000, SDR/TMLE: observed coverage 82.8/82.8%; subtracting mean bias gives 94.6/93.5%; empirical-SD widths give 87.1/88.2%. Estimated/empirical variance ratios are 0.814/0.840. The estimated mean bias contributes 34.2/35.0% of MSE.
  Subtracting mean bias produces the larger coverage improvement in this snapshot. Reported variances are smaller than empirical variance.
- n=4,000, SDR/TMLE: observed coverage 92.6/92.6%; subtracting mean bias gives 95.8/95.8%; empirical-SD widths give 93.7/92.6%. Estimated/empirical variance ratios are 1.214/1.256. The estimated mean bias contributes 16.4/20.5% of MSE.
  Subtracting mean bias produces the larger coverage improvement in this snapshot. Reported variances are larger than empirical variance.
- n=10,000, SDR/TMLE: observed coverage 88.4/88.4%; subtracting mean bias gives 88.4/88.4%; empirical-SD widths give 93.7/93.7%. Estimated/empirical variance ratios are 0.806/0.826. The estimated mean bias contributes 12.2/14.2% of MSE.
  Changing interval widths produces the larger coverage improvement in this snapshot. Reported variances are smaller than empirical variance.

The explanation can change with sample size. The mean-bias calculation and the two interval-width calculations assess different features of the error distribution; their changes in coverage need not add up. Subtracting mean bias does not remove dataset-dependent nuisance errors; their variation can increase empirical variance. Nonzero bias, variation in fitted nuisance functions, nonnormal tails, and dependence between errors and reported SEs can all contribute. A variance-calibration discrepancy does not by itself identify a bug in the variance formula.

- n=10,000 SDR: estimated/empirical variance ratio 0.806, with 95% simulation interval [0.627, 1.128]; replacing SEs by the empirical SD changes coverage by 5.3 percentage points, with interval [-1.1, 14.7]. Both intervals include no discrepancy or no improvement, so the point estimates are suggestive rather than conclusive.
- n=10,000 TMLE: estimated/empirical variance ratio 0.826, with 95% simulation interval [0.637, 1.155]; replacing SEs by the empirical SD changes coverage by 5.3 percentage points, with interval [-1.1, 13.7]. Both intervals include no discrepancy or no improvement, so the point estimates are suggestive rather than conclusive.

Binary-treatment MSE can be strongly affected by a few large errors. The table retains them, and the CSV reports their contribution rather than silently trimming them. These partial results do not establish asymptotic convergence: square root n times bias need not be zero at these sample sizes, and n times MSE can fluctuate because of rare large errors.

Both figures show the final outcome at time t=3. Scaled-MSE plots use a logarithmic vertical axis so rare large binary-treatment errors do not hide the other sample sizes. Bars show the bootstrap simulation intervals, not causal-parameter confidence intervals.

![Scaled bias and MSE](figures/scaled-bias-mse.png)
![Variance calibration and coverage calculations](figures/bias-variance-coverage.png)

[All scaled errors, variance ratios, bootstrap intervals and tail diagnostics](bias-variance-assessment.csv).
