# Complete corrected MI + lmtp comparison (combined)

1600 of 1600 datasets saved; 6400 of 6400 returned method estimates.

The MI arms run the exported standard lmtp_tmle and lmtp_sdr functions on each of 50 completed datasets, then pool estimates and complete-data EIF variances separately using Rubin's rules. R2 is excluded from completed-data analysis. Both arms use identical imputations and saved outer folds. The first three scenarios reuse the validated original estimates. The neither scenario uses newly fitted bridge estimates with identical settings.

Packages: cmbridge 0.3.0.9020, lmtp 1.6.0.9021, mice 3.19.0, from the verified original private library. Target E[Y2(1)] = 0.75.

| Scenario | n | Method | Successful / completed | Mean | Bias | MSE | RMSE | 95% coverage | Mean SE | Empirical SD |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| mar_only | 1000 | MI + TMLE | 200 / 200 | 0.7492 | -0.0008 | 0.000580 | 0.0241 | 92.0% | 0.0235 | 0.0241 |
| mar_only | 1000 | MI + SDR | 200 / 200 | 0.7492 | -0.0008 | 0.000586 | 0.0242 | 92.0% | 0.0236 | 0.0243 |
| mar_only | 1000 | Bridge TMLE | 200 / 200 | 0.6165 | -0.1335 | 0.020289 | 0.1424 | 14.0% | 0.0462 | 0.0497 |
| mar_only | 1000 | Bridge SDR | 200 / 200 | 0.6166 | -0.1334 | 0.020272 | 0.1424 | 14.5% | 0.0462 | 0.0500 |
| mar_only | 4000 | MI + TMLE | 200 / 200 | 0.7501 | 0.0001 | 0.000120 | 0.0110 | 95.5% | 0.0116 | 0.0110 |
| mar_only | 4000 | MI + SDR | 200 / 200 | 0.7501 | 0.0001 | 0.000120 | 0.0110 | 95.5% | 0.0116 | 0.0110 |
| mar_only | 4000 | Bridge TMLE | 200 / 200 | 0.6129 | -0.1371 | 0.019308 | 0.1390 | 0.0% | 0.0229 | 0.0228 |
| mar_only | 4000 | Bridge SDR | 200 / 200 | 0.6128 | -0.1372 | 0.019337 | 0.1391 | 0.0% | 0.0229 | 0.0227 |
| shadow_only | 1000 | MI + TMLE | 200 / 200 | 0.6129 | -0.1371 | 0.019812 | 0.1408 | 1.0% | 0.0304 | 0.0318 |
| shadow_only | 1000 | MI + SDR | 200 / 200 | 0.6130 | -0.1370 | 0.019783 | 0.1407 | 1.0% | 0.0304 | 0.0318 |
| shadow_only | 1000 | Bridge TMLE | 200 / 200 | 0.7506 | 0.0006 | 0.000761 | 0.0276 | 95.0% | 0.0273 | 0.0276 |
| shadow_only | 1000 | Bridge SDR | 200 / 200 | 0.7507 | 0.0007 | 0.000803 | 0.0283 | 93.5% | 0.0271 | 0.0284 |
| shadow_only | 4000 | MI + TMLE | 200 / 200 | 0.6142 | -0.1358 | 0.018656 | 0.1366 | 0.0% | 0.0151 | 0.0148 |
| shadow_only | 4000 | MI + SDR | 200 / 200 | 0.6142 | -0.1358 | 0.018673 | 0.1367 | 0.0% | 0.0151 | 0.0149 |
| shadow_only | 4000 | Bridge TMLE | 200 / 200 | 0.7497 | -0.0003 | 0.000170 | 0.0130 | 94.5% | 0.0133 | 0.0131 |
| shadow_only | 4000 | Bridge SDR | 200 / 200 | 0.7496 | -0.0004 | 0.000167 | 0.0129 | 96.0% | 0.0133 | 0.0130 |
| both | 1000 | MI + TMLE | 200 / 200 | 0.7501 | 0.0001 | 0.000658 | 0.0257 | 95.0% | 0.0253 | 0.0257 |
| both | 1000 | MI + SDR | 200 / 200 | 0.7502 | 0.0002 | 0.000669 | 0.0259 | 94.5% | 0.0254 | 0.0259 |
| both | 1000 | Bridge TMLE | 200 / 200 | 0.7540 | 0.0040 | 0.000987 | 0.0314 | 95.0% | 0.0314 | 0.0312 |
| both | 1000 | Bridge SDR | 200 / 200 | 0.7542 | 0.0042 | 0.001007 | 0.0317 | 94.0% | 0.0313 | 0.0315 |
| both | 4000 | MI + TMLE | 200 / 200 | 0.7497 | -0.0003 | 0.000149 | 0.0122 | 95.0% | 0.0126 | 0.0122 |
| both | 4000 | MI + SDR | 200 / 200 | 0.7497 | -0.0003 | 0.000149 | 0.0122 | 96.0% | 0.0126 | 0.0122 |
| both | 4000 | Bridge TMLE | 200 / 200 | 0.7503 | 0.0003 | 0.000229 | 0.0151 | 94.5% | 0.0155 | 0.0152 |
| both | 4000 | Bridge SDR | 200 / 200 | 0.7502 | 0.0002 | 0.000229 | 0.0151 | 94.5% | 0.0155 | 0.0152 |
| neither | 1000 | MI + TMLE | 200 / 200 | 0.6621 | -0.0879 | 0.008562 | 0.0925 | 8.0% | 0.0272 | 0.0289 |
| neither | 1000 | MI + SDR | 200 / 200 | 0.6622 | -0.0878 | 0.008556 | 0.0925 | 8.0% | 0.0273 | 0.0291 |
| neither | 1000 | Bridge TMLE | 200 / 200 | 0.6637 | -0.0863 | 0.008784 | 0.0937 | 28.5% | 0.0352 | 0.0367 |
| neither | 1000 | Bridge SDR | 200 / 200 | 0.6639 | -0.0861 | 0.008775 | 0.0937 | 28.5% | 0.0352 | 0.0370 |
| neither | 4000 | MI + TMLE | 200 / 200 | 0.6636 | -0.0864 | 0.007626 | 0.0873 | 0.0% | 0.0135 | 0.0129 |
| neither | 4000 | MI + SDR | 200 / 200 | 0.6636 | -0.0864 | 0.007636 | 0.0874 | 0.0% | 0.0136 | 0.0129 |
| neither | 4000 | Bridge TMLE | 200 / 200 | 0.6634 | -0.0866 | 0.007775 | 0.0882 | 0.0% | 0.0174 | 0.0166 |
| neither | 4000 | Bridge SDR | 200 / 200 | 0.6633 | -0.0867 | 0.007794 | 0.0883 | 0.0% | 0.0174 | 0.0166 |

MAR only: MI targets 0.75; the violated shadow restriction implies bridge target 0.6126667. Shadow only: bridge targets 0.75; MAR imputation implies target 0.6140584. Both assumptions: both population functionals equal 0.75. Neither assumption: both population functionals equal 0.6637440. The causal estimand remains 0.75 in every scenario. Saturated model classes avoid additional functional-form restrictions; finite-sample estimation and regularization remain.

Coverage is among returned estimates. summary.csv also reports failures counted as noncovering, Monte Carlo errors, interval widths, and imputation Monte Carlo variability. The pilot is an implementation check, not a precise performance assessment.

MI diagnostics: 160000 completed-data API calls; 0 failed calls; maximum imputation reconstruction error 0; maximum reconstructed EIF error 8.88e-16; 0 failed support assertions; 0 noninterior regression selections.

Bridge diagnostics retained: 46 conditional-moment candidate failures and 27385 recorded Landweber iteration-limit stops. These did not necessarily prevent a returned final estimate and are not evidence that every candidate converged to tolerance.

The earlier MI + saturated-standardization arm is excluded from this comparison. These results use MI followed by the exported standard lmtp estimators.

![Estimates](estimates.png)

![Coverage](coverage.png)
