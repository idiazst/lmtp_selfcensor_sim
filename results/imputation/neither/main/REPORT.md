# Complete corrected MI + lmtp comparison (main)

400 of 400 datasets saved; 1600 of 1600 returned method estimates.

The MI arms run the exported standard lmtp_tmle and lmtp_sdr functions on each of 50 completed datasets, then pool estimates and complete-data EIF variances separately using Rubin's rules. R2 is excluded from completed-data analysis. Both arms use identical imputations and saved outer folds. The first three scenarios reuse the validated original estimates. The neither scenario uses newly fitted bridge estimates with identical settings.

Packages: cmbridge 0.3.0.9020, lmtp 1.6.0.9021, mice 3.19.0, from the verified original private library. Target E[Y2(1)] = 0.75.

| Scenario | n | Method | Successful / completed | Mean | Bias | MSE | RMSE | 95% coverage | Mean SE | Empirical SD |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
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

MI diagnostics: 40000 completed-data API calls; 0 failed calls; maximum imputation reconstruction error 0; maximum reconstructed EIF error 4.44e-16; 0 failed support assertions; 0 noninterior regression selections.

Bridge diagnostics retained: 1 conditional-moment candidate failures and 627 recorded Landweber iteration-limit stops. These did not necessarily prevent a returned final estimate and are not evidence that every candidate converged to tolerance.

The earlier MI + saturated-standardization arm is excluded from this comparison. These results use MI followed by the exported standard lmtp estimators.

![Estimates](estimates.png)

![Coverage](coverage.png)
