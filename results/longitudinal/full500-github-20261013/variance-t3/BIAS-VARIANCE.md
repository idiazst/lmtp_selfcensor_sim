# Scaled errors and variance assessment

Companion analysis of 3576 completed dataset checkpoints. Each table states the number of returned estimators. The full study plans 4,000 datasets; incomplete counts are preliminary.


These calculations use the same saved completed datasets as the preceding report. They do not refit nuisances, change penalties or alter the estimators. Failed fits remain excluded from error moments and included in the separate failure table. Partial completion and the number of successful fits limit the conclusions.

Bias is the average estimate minus the true parameter. MSE is the average squared error. The scaled quantities are square root n times bias and n times MSE. MCSE denotes the standard error due to the finite number of simulation replications. The MSE is decomposed exactly into squared bias and the average squared centered error; this centered variance uses the number of returned fits as its divisor. The empirical SD and variance-calibration ratio use the usual sample-variance divisor, one less than that number.

The variance-calibration ratio is the average reported SE squared divided by the variance of estimates across replications. A ratio below one indicates smaller estimated variance than the observed empirical variance. Comparing the mean SE alone can be misleading when a few datasets have very large SEs; the square root of the average SE squared is the matching comparison.

### Outcome at time 3

| Treatment | n | Estimator | Returned | √n × bias | BiasMCSE | n × MSE | MSEMCSE | n × bias² | n × centered variance | VarianceRatio |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 432 | 0.432 | 0.492 | 104.575 | 50.444 | 0.187 | 104.388 | 0.563 |
| Binary treatment |   500 | TMLE | 432 | 0.045 | 0.214 | 19.821 | 4.094 | 0.002 | 19.819 | 1.343 |
| Binary treatment |  1000 | SDR | 443 | 0.644 | 0.243 | 26.570 | 3.604 | 0.415 | 26.155 | 0.987 |
| Binary treatment |  1000 | TMLE | 443 | 0.360 | 0.181 | 14.545 | 1.605 | 0.129 | 14.416 | 1.442 |
| Binary treatment |  4000 | SDR | 446 | 0.117 | 0.181 | 14.570 | 1.765 | 0.014 | 14.556 | 0.900 |
| Binary treatment |  4000 | TMLE | 446 | 0.043 | 0.148 | 9.769 | 0.960 | 0.002 | 9.767 | 1.174 |
| Binary treatment | 10000 | SDR | 447 | 0.013 | 0.215 | 20.667 | 6.795 | 0.000 | 20.667 | 1.049 |
| Binary treatment | 10000 | TMLE | 447 | -0.033 | 0.148 | 9.733 | 1.170 | 0.001 | 9.732 | 1.857 |
| Numerical dose |   500 | SDR | 434 | -0.817 | 0.065 | 2.522 | 0.174 | 0.667 | 1.855 | 0.977 |
| Numerical dose |   500 | TMLE | 434 | -0.820 | 0.065 | 2.507 | 0.185 | 0.673 | 1.834 | 1.002 |
| Numerical dose |  1000 | SDR | 443 | -0.973 | 0.057 | 2.362 | 0.149 | 0.946 | 1.415 | 0.861 |
| Numerical dose |  1000 | TMLE | 443 | -0.983 | 0.057 | 2.419 | 0.177 | 0.967 | 1.452 | 0.848 |
| Numerical dose |  4000 | SDR | 446 | -0.625 | 0.062 | 2.086 | 0.147 | 0.391 | 1.696 | 0.991 |
| Numerical dose |  4000 | TMLE | 446 | -0.677 | 0.060 | 2.050 | 0.142 | 0.459 | 1.592 | 1.047 |
| Numerical dose | 10000 | SDR | 447 | -0.457 | 0.056 | 1.600 | 0.105 | 0.209 | 1.391 | 0.878 |
| Numerical dose | 10000 | TMLE | 447 | -0.500 | 0.055 | 1.600 | 0.106 | 0.250 | 1.350 | 0.901 |

### Outcome at time 2

| Treatment | n | Estimator | Returned | √n × bias | BiasMCSE | n × MSE | MSEMCSE | n × bias² | n × centered variance | VarianceRatio |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 432 | 0.010 | 0.039 | 0.669 | 0.047 | 0.000 | 0.668 | 0.963 |
| Binary treatment |   500 | TMLE | 432 | -0.017 | 0.040 | 0.683 | 0.051 | 0.000 | 0.683 | 0.955 |
| Binary treatment |  1000 | SDR | 443 | 0.042 | 0.035 | 0.548 | 0.035 | 0.002 | 0.546 | 0.969 |
| Binary treatment |  1000 | TMLE | 443 | 0.042 | 0.037 | 0.597 | 0.038 | 0.002 | 0.596 | 0.913 |
| Binary treatment |  4000 | SDR | 446 | -0.026 | 0.036 | 0.570 | 0.037 | 0.001 | 0.570 | 0.852 |
| Binary treatment |  4000 | TMLE | 446 | -0.019 | 0.037 | 0.596 | 0.039 | 0.000 | 0.596 | 0.822 |
| Binary treatment | 10000 | SDR | 447 | 0.020 | 0.035 | 0.531 | 0.036 | 0.000 | 0.531 | 0.894 |
| Binary treatment | 10000 | TMLE | 447 | 0.018 | 0.035 | 0.537 | 0.036 | 0.000 | 0.536 | 0.888 |
| Numerical dose |   500 | SDR | 434 | -0.145 | 0.049 | 1.056 | 0.075 | 0.021 | 1.035 | 0.903 |
| Numerical dose |   500 | TMLE | 434 | -0.186 | 0.050 | 1.121 | 0.082 | 0.035 | 1.086 | 0.852 |
| Numerical dose |  1000 | SDR | 443 | -0.048 | 0.039 | 0.671 | 0.044 | 0.002 | 0.669 | 1.094 |
| Numerical dose |  1000 | TMLE | 443 | -0.066 | 0.039 | 0.684 | 0.046 | 0.004 | 0.680 | 1.070 |
| Numerical dose |  4000 | SDR | 446 | 0.009 | 0.039 | 0.667 | 0.045 | 0.000 | 0.667 | 0.927 |
| Numerical dose |  4000 | TMLE | 446 | 0.014 | 0.039 | 0.669 | 0.045 | 0.000 | 0.668 | 0.922 |
| Numerical dose | 10000 | SDR | 447 | 0.029 | 0.037 | 0.623 | 0.047 | 0.001 | 0.622 | 0.972 |
| Numerical dose | 10000 | TMLE | 447 | 0.027 | 0.037 | 0.626 | 0.047 | 0.001 | 0.625 | 0.964 |

### Separate calculations for bias and interval width

The following are descriptive calculations on the saved estimates, not new estimators or usable corrected intervals. Subtract mean bias means shifting every estimate by the across-replication mean error, retaining its own SE. Rescale own SE means multiplying each SE by empirical SD divided by the square root of the average SE squared: average variance is matched while each dataset's relative interval width is preserved. Use empirical SD replaces every SE by the same empirical SD. The final two columns combine bias subtraction with these width calculations. Bias and SD are estimated from these same completed replications, so these calculations assess possible explanations for coverage rather than establish a causal attribution or a validated interval correction.

The CSV also reports 95% bootstrap intervals for changes in coverage, variance ratios and scaled errors. This means resampling completed replications with replacement 2000 times and repeating the calculations, including re-estimating bias and SD each time. Estimate and SE remain paired from the same dataset. Standardized errors mean estimate minus truth divided by that dataset's reported SE; their spread and quantiles are recorded. Tail misses and the fractions of MSE contributed by the largest errors are retained. No outlier is removed.

| Treatment | n | Estimator | Actual | SubtractMeanBias | RescaleOwnSE | UseEmpiricalSD | BiasAndRescaledSE | BothChanges |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment |   500 | SDR | 92.1% | 91.2% | 98.4% | 97.9% | 97.9% | 98.1% |
| Binary treatment |   500 | TMLE | 91.4% | 91.0% | 86.8% | 96.1% | 86.8% | 96.1% |
| Binary treatment |  1000 | SDR | 94.6% | 93.9% | 94.6% | 93.2% | 93.9% | 93.9% |
| Binary treatment |  1000 | TMLE | 94.4% | 93.5% | 90.7% | 93.9% | 90.1% | 94.8% |
| Binary treatment |  4000 | SDR | 93.9% | 93.7% | 95.1% | 94.8% | 94.8% | 94.8% |
| Binary treatment |  4000 | TMLE | 94.8% | 94.4% | 91.3% | 95.3% | 91.0% | 95.3% |
| Binary treatment | 10000 | SDR | 94.6% | 94.6% | 94.4% | 97.1% | 94.2% | 97.1% |
| Binary treatment | 10000 | TMLE | 95.1% | 95.3% | 84.8% | 94.9% | 84.3% | 94.9% |
| Numerical dose |   500 | SDR | 85.0% | 93.8% | 85.3% | 93.5% | 94.2% | 94.7% |
| Numerical dose |   500 | TMLE | 86.2% | 95.2% | 86.2% | 93.5% | 94.9% | 94.2% |
| Numerical dose |  1000 | SDR | 81.7% | 93.5% | 83.5% | 85.6% | 95.5% | 95.9% |
| Numerical dose |  1000 | TMLE | 81.9% | 93.5% | 85.3% | 86.0% | 95.3% | 96.4% |
| Numerical dose |  4000 | SDR | 89.5% | 94.2% | 89.5% | 92.4% | 94.8% | 94.6% |
| Numerical dose |  4000 | TMLE | 89.2% | 95.3% | 88.6% | 91.7% | 94.6% | 93.9% |
| Numerical dose | 10000 | SDR | 90.6% | 92.8% | 93.5% | 93.3% | 94.2% | 93.7% |
| Numerical dose | 10000 | TMLE | 91.1% | 92.8% | 93.5% | 94.0% | 93.7% | 93.7% |


### Assessment of the current numerical-dose results

- n=500, SDR/TMLE: observed coverage 85.0/86.2%; subtracting mean bias gives 93.8/95.2%; empirical-SD widths give 93.5/93.5%. Estimated/empirical variance ratios are 0.977/1.002. The estimated mean bias contributes 26.4/26.8% of MSE.
  Subtracting mean bias produces the larger coverage improvement in this snapshot. Variance-calibration directions differ between the estimators.
- n=1,000, SDR/TMLE: observed coverage 81.7/81.9%; subtracting mean bias gives 93.5/93.5%; empirical-SD widths give 85.6/86.0%. Estimated/empirical variance ratios are 0.861/0.848. The estimated mean bias contributes 40.1/40.0% of MSE.
  Subtracting mean bias produces the larger coverage improvement in this snapshot. Reported variances are smaller than empirical variance.
- n=4,000, SDR/TMLE: observed coverage 89.5/89.2%; subtracting mean bias gives 94.2/95.3%; empirical-SD widths give 92.4/91.7%. Estimated/empirical variance ratios are 0.991/1.047. The estimated mean bias contributes 18.7/22.4% of MSE.
  Subtracting mean bias produces the larger coverage improvement in this snapshot. Variance-calibration directions differ between the estimators.
- n=10,000, SDR/TMLE: observed coverage 90.6/91.1%; subtracting mean bias gives 92.8/92.8%; empirical-SD widths give 93.3/94.0%. Estimated/empirical variance ratios are 0.878/0.901. The estimated mean bias contributes 13.1/15.6% of MSE.
  Changing interval widths produces the larger coverage improvement in this snapshot. Reported variances are smaller than empirical variance.

The explanation can change with sample size. The mean-bias calculation and the two interval-width calculations assess different features of the error distribution; their changes in coverage need not add up. Subtracting mean bias does not remove dataset-dependent nuisance errors; their variation can increase empirical variance. Nonzero bias, variation in fitted nuisance functions, nonnormal tails, and dependence between errors and reported SEs can all contribute. A variance-calibration discrepancy does not by itself identify a bug in the variance formula.

- n=10,000 SDR: estimated/empirical variance ratio 0.878, with 95% simulation interval [0.781, 1.007]; replacing SEs by the empirical SD changes coverage by 2.7 percentage points, with interval [0.0, 6.0]. Both intervals include no discrepancy or no improvement, so the point estimates are suggestive rather than conclusive.
- n=10,000 TMLE: estimated/empirical variance ratio 0.901, with 95% simulation interval [0.795, 1.039]; replacing SEs by the empirical SD changes coverage by 2.9 percentage points, with interval [-0.4, 5.4]. Both intervals include no discrepancy or no improvement, so the point estimates are suggestive rather than conclusive.

Binary-treatment MSE can be strongly affected by a few large errors. The table retains them, and the CSV reports their contribution rather than silently trimming them. These partial results do not establish asymptotic convergence: square root n times bias need not be zero at these sample sizes, and n times MSE can fluctuate because of rare large errors.

Both figures show the final outcome at time t=3. Scaled-MSE plots use a logarithmic vertical axis so rare large binary-treatment errors do not hide the other sample sizes. Bars show the bootstrap simulation intervals, not causal-parameter confidence intervals.

![Scaled bias and MSE](figures/scaled-bias-mse.png)
![Variance calibration and coverage calculations](figures/bias-variance-coverage.png)

[All scaled errors, variance ratios, bootstrap intervals and tail diagnostics](bias-variance-assessment.csv).
