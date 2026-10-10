# Complete corrected MI + lmtp comparison (main)

1200 of 1200 datasets saved; 4800 of 4800 returned method estimates.

The MI arms run the exported standard lmtp_tmle and lmtp_sdr functions on each of 50 completed datasets, then pool estimates and complete-data EIF variances separately using Rubin's rules. R2 is excluded from completed-data analysis. Both arms use identical imputations and saved outer folds. Bridge estimates are reused exactly from the original run.

Packages: cmbridge 0.3.0.9020, lmtp 1.6.0.9021, mice 3.19.0, from the verified original private library. Target E[Y2(1)] = 0.75.

| Scenario | n | Method | Successful / completed | Mean | Bias | RMSE | 95% coverage | Mean SE | Empirical SD |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|
| mar_only | 1000 | MI + TMLE | 200 / 200 | 0.7492 | -0.0008 | 0.0241 | 92.0% | 0.0235 | 0.0241 |
| mar_only | 1000 | MI + SDR | 200 / 200 | 0.7492 | -0.0008 | 0.0242 | 92.0% | 0.0236 | 0.0243 |
| mar_only | 1000 | Bridge TMLE | 200 / 200 | 0.6165 | -0.1335 | 0.1424 | 14.0% | 0.0462 | 0.0497 |
| mar_only | 1000 | Bridge SDR | 200 / 200 | 0.6166 | -0.1334 | 0.1424 | 14.5% | 0.0462 | 0.0500 |
| mar_only | 4000 | MI + TMLE | 200 / 200 | 0.7501 | 0.0001 | 0.0110 | 95.5% | 0.0116 | 0.0110 |
| mar_only | 4000 | MI + SDR | 200 / 200 | 0.7501 | 0.0001 | 0.0110 | 95.5% | 0.0116 | 0.0110 |
| mar_only | 4000 | Bridge TMLE | 200 / 200 | 0.6129 | -0.1371 | 0.1390 | 0.0% | 0.0229 | 0.0228 |
| mar_only | 4000 | Bridge SDR | 200 / 200 | 0.6128 | -0.1372 | 0.1391 | 0.0% | 0.0229 | 0.0227 |
| shadow_only | 1000 | MI + TMLE | 200 / 200 | 0.6129 | -0.1371 | 0.1408 | 1.0% | 0.0304 | 0.0318 |
| shadow_only | 1000 | MI + SDR | 200 / 200 | 0.6130 | -0.1370 | 0.1407 | 1.0% | 0.0304 | 0.0318 |
| shadow_only | 1000 | Bridge TMLE | 200 / 200 | 0.7506 | 0.0006 | 0.0276 | 95.0% | 0.0273 | 0.0276 |
| shadow_only | 1000 | Bridge SDR | 200 / 200 | 0.7507 | 0.0007 | 0.0283 | 93.5% | 0.0271 | 0.0284 |
| shadow_only | 4000 | MI + TMLE | 200 / 200 | 0.6142 | -0.1358 | 0.1366 | 0.0% | 0.0151 | 0.0148 |
| shadow_only | 4000 | MI + SDR | 200 / 200 | 0.6142 | -0.1358 | 0.1367 | 0.0% | 0.0151 | 0.0149 |
| shadow_only | 4000 | Bridge TMLE | 200 / 200 | 0.7497 | -0.0003 | 0.0130 | 94.5% | 0.0133 | 0.0131 |
| shadow_only | 4000 | Bridge SDR | 200 / 200 | 0.7496 | -0.0004 | 0.0129 | 96.0% | 0.0133 | 0.0130 |
| both | 1000 | MI + TMLE | 200 / 200 | 0.7501 | 0.0001 | 0.0257 | 95.0% | 0.0253 | 0.0257 |
| both | 1000 | MI + SDR | 200 / 200 | 0.7502 | 0.0002 | 0.0259 | 94.5% | 0.0254 | 0.0259 |
| both | 1000 | Bridge TMLE | 200 / 200 | 0.7540 | 0.0040 | 0.0314 | 95.0% | 0.0314 | 0.0312 |
| both | 1000 | Bridge SDR | 200 / 200 | 0.7542 | 0.0042 | 0.0317 | 94.0% | 0.0313 | 0.0315 |
| both | 4000 | MI + TMLE | 200 / 200 | 0.7497 | -0.0003 | 0.0122 | 95.0% | 0.0126 | 0.0122 |
| both | 4000 | MI + SDR | 200 / 200 | 0.7497 | -0.0003 | 0.0122 | 96.0% | 0.0126 | 0.0122 |
| both | 4000 | Bridge TMLE | 200 / 200 | 0.7503 | 0.0003 | 0.0151 | 94.5% | 0.0155 | 0.0152 |
| both | 4000 | Bridge SDR | 200 / 200 | 0.7502 | 0.0002 | 0.0151 | 94.5% | 0.0155 | 0.0152 |

MAR only: MI targets 0.75; the violated shadow restriction implies bridge target 0.6126667. Shadow only: bridge targets 0.75; MAR imputation implies target 0.6140584. Both assumptions: all target 0.75. Saturated model classes avoid additional functional-form restrictions; finite-sample estimation and regularization remain.

Coverage is among returned estimates. summary.csv also reports failures counted as noncovering, Monte Carlo errors, interval widths, and imputation Monte Carlo variability. The pilot is an implementation check, not a precise performance assessment.

MI diagnostics: 120000 completed-data API calls; 0 failed calls; maximum imputation reconstruction error 0; maximum reconstructed EIF error 8.88e-16; 0 failed support assertions; 0 noninterior regression selections.

Original bridge diagnostics retained: 45 conditional-moment candidate failures and 26758 recorded Landweber iteration-limit stops. These did not necessarily prevent a returned final estimate and are not evidence that every candidate converged to tolerance.

The original MI + saturated-standardization arm is excluded from this corrected comparison; its output remains under mi-comparison-v1.

![Estimates](estimates.png)

![Coverage](coverage.png)
