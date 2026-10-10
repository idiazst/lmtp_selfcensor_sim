# Observed-history simulation results

The planned datasets have finished. Failed fits and warnings are retained and counted.

Completed 1,200 of 1,200 planned datasets.


Both two-time mechanisms use n =   500, 1,000, 4,000, with 200 replications per sample size and 80 parallel R workers. The numerical dose takes values 0, 1, 2, and 3, with the policy increasing it by one, capped at 3.

Bridge candidates are sieve minimum distance with fixed intercept and all main effects plus joint-category deviations, preconditioned Landweber with fixed intercept and all main effects, and PMMR with Gaussian features. The first two inverse-expit classes contain a valid bridge solution for both mechanisms; all three bridge candidates use the inverse-expit parameterization. Adjoint candidates are a saturated joint-category sieve, Landweber with splines, and PMMR, all with an unrestricted identity link. Saturated L1 is excluded from the cmbridge libraries. Outcome regressions combine saturated L1, MARS, and a mean; treatment-ratio classification combines saturated L1 and a mean. MARS is used only for outcome regressions. SDR and TMLE share generated data, sample assignments, and bridge and adjoint fits. Both receive the one-step bridge correction. Positive sieve ridge and L1 penalties are chosen by cross-validation inside the fitting samples. This study does not assess robustness under deliberate misspecification.

Bridge sieve ridge penalizes link coefficients after main-effect column scaling, with category deviations receiving 100 times the main-effect penalty; the intercept is unpenalized. Adjoint sieve ridge penalizes centered function values. Gaussian kernel U-statistics select ensemble weights and sieve penalties, retaining every history and treatment predictor. The ensemble Gram matrix is projected to positive semidefinite before weight optimization. Failed or nonfinite tuning trials cannot be selected, failed candidates receive zero weight, and these events are recorded. A boundary penalty minimum must become interior after extending the grid, or the candidate fails. cmbridge fits are not clipped after fitting; the estimator applies the previously approved wider bridge interval [-100,100].

Both follow-up health vectors can be missing. Bridge and adjoint functions are estimated for both outcome times. At a missed intermediate visit, treatment follows the deterministic rule and the final outcome equals the observed baseline outcome.

The [frozen simulation plan](../../studies/longitudinal/PLAN.md) gives the conditional distributions, true parameters, learners, and sample-splitting construction.

Coverage uncertainty describes variation due to the finite number of replications; it is not a confidence interval for the causal parameter.

## Mean of each EIF component

For each replication, average the two EIF components over the outer validation observations, using the known true parameter in the sequential component. Then average these sample means over successful replications. Their sum is the mean estimation error.

### Outcome at time 3

| Mechanism | n | Estimator | Successful | Mean sequential EIF | Mean bridge/adjoint EIF |
| --- | --- | --- | --- | --- | --- |
| Two-time binary treatment |  500 | SDR | 191 | -0.009037 | 0.011921 |
| Two-time binary treatment |  500 | TMLE | 191 | -0.008229 | 0.011921 |
| Two-time binary treatment | 1000 | SDR | 197 | 0.005286 | 0.024632 |
| Two-time binary treatment | 1000 | TMLE | 197 | -0.009464 | 0.024632 |
| Two-time binary treatment | 4000 | SDR | 199 | -0.023894 | 0.023229 |
| Two-time binary treatment | 4000 | TMLE | 199 | -0.023443 | 0.023229 |
| Two-time numerical dose |  500 | SDR | 192 | -0.032799 | -0.001762 |
| Two-time numerical dose |  500 | TMLE | 192 | -0.032242 | -0.001762 |
| Two-time numerical dose | 1000 | SDR | 199 | -0.039891 | 0.012560 |
| Two-time numerical dose | 1000 | TMLE | 199 | -0.039947 | 0.012560 |
| Two-time numerical dose | 4000 | SDR | 199 | -0.024779 | 0.014977 |
| Two-time numerical dose | 4000 | TMLE | 199 | -0.025500 | 0.014977 |

### Outcome at time 2

| Mechanism | n | Estimator | Successful | Mean sequential EIF | Mean bridge/adjoint EIF |
| --- | --- | --- | --- | --- | --- |
| Two-time binary treatment |  500 | SDR | 191 | -0.021198 | 0.018219 |
| Two-time binary treatment |  500 | TMLE | 191 | -0.020617 | 0.018219 |
| Two-time binary treatment | 1000 | SDR | 197 | -0.016799 | 0.018476 |
| Two-time binary treatment | 1000 | TMLE | 197 | -0.016769 | 0.018476 |
| Two-time binary treatment | 4000 | SDR | 199 | -0.007995 | 0.008134 |
| Two-time binary treatment | 4000 | TMLE | 199 | -0.007774 | 0.008134 |
| Two-time numerical dose |  500 | SDR | 192 | -0.022807 | 0.011623 |
| Two-time numerical dose |  500 | TMLE | 192 | -0.024157 | 0.011623 |
| Two-time numerical dose | 1000 | SDR | 199 | -0.017090 | 0.018266 |
| Two-time numerical dose | 1000 | TMLE | 199 | -0.017660 | 0.018266 |
| Two-time numerical dose | 4000 | SDR | 199 | -0.008064 | 0.007776 |
| Two-time numerical dose | 4000 | TMLE | 199 | -0.008055 | 0.007776 |

[Component means](eif-component-means.csv) and [means for each replication](eif-component-means-by-replication.csv) retain the numerical values.

## Outcome at time 3

### Two-time binary treatment

| n | Estimator | Successful | Failed | Pending | Truth | Mean | Bias | SD | RMSE | Mean SE | Interval length | Coverage | Coverage uncertainty | Warnings |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  500 | SDR | 191 | 9 | 0 | 0.64975 | 0.65263 | 0.00288 | 0.41355 | 0.41248 | 0.23183 | 0.90874 | 0.921 | [0.874, 0.952] | 191 |
|  500 | TMLE | 191 | 9 | 0 | 0.64975 | 0.65344 | 0.00369 | 0.17022 | 0.16982 | 0.17904 | 0.70181 | 0.927 | [0.881, 0.956] | 191 |
| 1000 | SDR | 197 | 3 | 0 | 0.64975 | 0.67967 | 0.02992 | 0.17277 | 0.17491 | 0.13485 | 0.52862 | 0.949 | [0.909, 0.972] | 197 |
| 1000 | TMLE | 197 | 3 | 0 | 0.64975 | 0.66492 | 0.01517 | 0.12189 | 0.12252 | 0.12202 | 0.47832 | 0.949 | [0.909, 0.972] | 197 |
| 4000 | SDR | 199 | 1 | 0 | 0.64975 | 0.64908 | -0.00066 | 0.06022 | 0.06007 | 0.04936 | 0.19349 | 0.935 | [0.891, 0.961] | 199 |
| 4000 | TMLE | 199 | 1 | 0 | 0.64975 | 0.64953 | -0.00021 | 0.04869 | 0.04857 | 0.04660 | 0.18265 | 0.945 | [0.904, 0.969] | 199 |

### Two-time numerical dose

| n | Estimator | Successful | Failed | Pending | Truth | Mean | Bias | SD | RMSE | Mean SE | Interval length | Coverage | Coverage uncertainty | Warnings |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  500 | SDR | 192 | 8 | 0 | 0.63362 | 0.59906 | -0.03456 | 0.06294 | 0.07166 | 0.05715 | 0.22404 | 0.859 | [0.803, 0.902] | 192 |
|  500 | TMLE | 192 | 8 | 0 | 0.63362 | 0.59962 | -0.03400 | 0.06200 | 0.07057 | 0.05776 | 0.22643 | 0.854 | [0.797, 0.897] | 192 |
| 1000 | SDR | 199 | 1 | 0 | 0.63362 | 0.60629 | -0.02733 | 0.03756 | 0.04638 | 0.03470 | 0.13603 | 0.824 | [0.765, 0.871] | 199 |
| 1000 | TMLE | 199 | 1 | 0 | 0.63362 | 0.60624 | -0.02739 | 0.03700 | 0.04596 | 0.03484 | 0.13656 | 0.839 | [0.782, 0.884] | 199 |
| 4000 | SDR | 199 | 1 | 0 | 0.63362 | 0.62382 | -0.00980 | 0.01974 | 0.02199 | 0.02018 | 0.07910 | 0.889 | [0.838, 0.926] | 199 |
| 4000 | TMLE | 199 | 1 | 0 | 0.63362 | 0.62310 | -0.01052 | 0.01916 | 0.02181 | 0.02011 | 0.07882 | 0.894 | [0.844, 0.930] | 199 |

## Outcome at time 2

### Two-time binary treatment

| n | Estimator | Successful | Failed | Pending | Truth | Mean | Bias | SD | RMSE | Mean SE | Interval length | Coverage | Coverage uncertainty | Warnings |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  500 | SDR | 191 | 9 | 0 | 0.90031 | 0.89733 | -0.00298 | 0.03598 | 0.03601 | 0.03557 | 0.13945 | 0.963 | [0.926, 0.982] | 191 |
|  500 | TMLE | 191 | 9 | 0 | 0.90031 | 0.89791 | -0.00240 | 0.03623 | 0.03621 | 0.03578 | 0.14027 | 0.942 | [0.900, 0.968] | 191 |
| 1000 | SDR | 197 | 3 | 0 | 0.90031 | 0.90199 | 0.00168 | 0.02447 | 0.02447 | 0.02289 | 0.08971 | 0.914 | [0.866, 0.945] | 197 |
| 1000 | TMLE | 197 | 3 | 0 | 0.90031 | 0.90202 | 0.00171 | 0.02552 | 0.02551 | 0.02313 | 0.09067 | 0.914 | [0.866, 0.945] | 197 |
| 4000 | SDR | 199 | 1 | 0 | 0.90031 | 0.90045 | 0.00014 | 0.01214 | 0.01211 | 0.01096 | 0.04296 | 0.915 | [0.867, 0.946] | 199 |
| 4000 | TMLE | 199 | 1 | 0 | 0.90031 | 0.90067 | 0.00036 | 0.01241 | 0.01239 | 0.01101 | 0.04317 | 0.910 | [0.862, 0.942] | 199 |

### Two-time numerical dose

| n | Estimator | Successful | Failed | Pending | Truth | Mean | Bias | SD | RMSE | Mean SE | Interval length | Coverage | Coverage uncertainty | Warnings |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  500 | SDR | 192 | 8 | 0 | 0.85170 | 0.84052 | -0.01118 | 0.04206 | 0.04342 | 0.04278 | 0.16771 | 0.948 | [0.907, 0.971] | 192 |
|  500 | TMLE | 192 | 8 | 0 | 0.85170 | 0.83917 | -0.01253 | 0.04290 | 0.04459 | 0.04256 | 0.16683 | 0.938 | [0.894, 0.964] | 192 |
| 1000 | SDR | 199 | 1 | 0 | 0.85170 | 0.85288 | 0.00118 | 0.02629 | 0.02625 | 0.02707 | 0.10610 | 0.965 | [0.929, 0.983] | 199 |
| 1000 | TMLE | 199 | 1 | 0 | 0.85170 | 0.85231 | 0.00061 | 0.02644 | 0.02638 | 0.02698 | 0.10577 | 0.970 | [0.936, 0.986] | 199 |
| 4000 | SDR | 199 | 1 | 0 | 0.85170 | 0.85141 | -0.00029 | 0.01289 | 0.01286 | 0.01243 | 0.04871 | 0.945 | [0.904, 0.969] | 199 |
| 4000 | TMLE | 199 | 1 | 0 | 0.85170 | 0.85142 | -0.00028 | 0.01285 | 0.01282 | 0.01240 | 0.04860 | 0.940 | [0.898, 0.965] | 199 |

## Counterfactual mean curves

The fraction of simultaneous bands containing both true means is reported separately from pointwise coverage.

| Mechanism | n | Estimator | Successful | Joint coverage |
| --- | --- | --- | --- | --- |
| Two-time binary treatment |  500 | SDR | 191 | 0.937 |
| Two-time binary treatment |  500 | TMLE | 191 | 0.937 |
| Two-time binary treatment | 1000 | SDR | 197 | 0.934 |
| Two-time binary treatment | 1000 | TMLE | 197 | 0.919 |
| Two-time binary treatment | 4000 | SDR | 199 | 0.915 |
| Two-time binary treatment | 4000 | TMLE | 199 | 0.905 |
| Two-time numerical dose |  500 | SDR | 192 | 0.901 |
| Two-time numerical dose |  500 | TMLE | 192 | 0.880 |
| Two-time numerical dose | 1000 | SDR | 199 | 0.859 |
| Two-time numerical dose | 1000 | TMLE | 199 | 0.854 |
| Two-time numerical dose | 4000 | SDR | 199 | 0.925 |
| Two-time numerical dose | 4000 | TMLE | 199 | 0.925 |

![Estimated curves and true means](figures/correctly-specified-curves.png)

## Estimation error and interval performance

![Two-time binary treatment: bias](figures/binary_longitudinal-bias.png)

![Two-time binary treatment: root-n-bias](figures/binary_longitudinal-root-n-bias.png)

![Two-time binary treatment: coverage](figures/binary_longitudinal-coverage.png)

![Two-time binary treatment: standard-errors](figures/binary_longitudinal-standard-errors.png)

![Two-time numerical dose: bias](figures/discrete_dose-bias.png)

![Two-time numerical dose: root-n-bias](figures/discrete_dose-root-n-bias.png)

![Two-time numerical dose: coverage](figures/discrete_dose-coverage.png)

![Two-time numerical dose: standard-errors](figures/discrete_dose-standard-errors.png)

## Results requiring examination

These results require examination. A flag alone does not demonstrate an implementation error. The fitted conditional equations and separate population remainder contributions must be checked.

| mechanism | estimator | n | successful | bias | coverage | coverage_mc_upper |
| --- | --- | --- | --- | --- | --- | --- |
| discrete_dose | sdr | 4000 | 199 | -0.00980126 | 0.8894472 | 0.9258509 |
| discrete_dose | tmle | 4000 | 199 | -0.01052279 | 0.8944724 | 0.9299368 |

## Computation and validation

Recorded dataset processing times sum to 1262.13 hours. This is the sum across workers, not elapsed wall time.

For every successful fit, the direct prediction-based one-step calculation agrees with the public package output. Exact population calculations check the separate remainder contributions. Unknown nuisance functions are fitted from generated data; true functions are used only for diagnostics.

[Numerical summary](summary.csv), [replication estimates](replicates.csv), [population diagnostics](population_diagnostics.csv), [penalties and weights](penalty_and_weight_selections.csv.gz), [errors](errors.csv), and [job log](job_log.csv) retain the numerical records. Checkpoints also store predictor-combination counts, fitted functions on the finite support, seeds, and sample assignments.

[Failed nested candidates](nested-candidate-failures.csv) and [failed penalty trials](nested-penalty-trial-failures.csv.gz) retain recorded bridge fitting failures even when the remaining candidates produce a complete estimator. These events are distinct from a failed final estimator.

The bridge and adjoint may have multiple solutions; conditional-equation errors and the actual remainder determine their accuracy. Difference from one selected exact solution alone is not treated as misspecification.

[All candidate weights](ensemble_weights.csv.gz) and [weight summaries](ensemble_weight_summary.csv) retain the expanded library, including candidates selected with zero weight.


## Conditional equations and estimation error

Evaluate each saved fitted contribution over the complete discrete population, then average the outer training samples using their validation sample sizes. The two contributions add to the fixed-function population error. Outcome times are reported separately.

For SDR this evaluates the expectation of contributions from the fitted nuisance functions. TMLE targeting uses validation outcomes, so holding its final targeted functions fixed is a diagnostic calculation, not a conditional expectation given training data alone.

| Treatment | n | Outcome time | Estimator | Successful | Population error | Sequential contribution | Bridge/adjoint contribution |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Binary treatment | 1000 | 2 | SDR | 197 | 0.000889 | 0.000291 | 0.000598 |
| Binary treatment | 1000 | 3 | SDR | 197 | 0.008346 | 0.009635 | -0.001290 |
| Binary treatment | 1000 | 2 | TMLE | 197 | 0.000544 | -0.000054 | 0.000598 |
| Binary treatment | 1000 | 3 | TMLE | 197 | -0.003394 | -0.002104 | -0.001290 |
| Binary treatment | 4000 | 2 | SDR | 199 | 0.000065 | 0.000076 | -0.000010 |
| Binary treatment | 4000 | 3 | SDR | 199 | 0.002000 | 0.002781 | -0.000781 |
| Binary treatment | 4000 | 2 | TMLE | 199 | 0.000137 | 0.000147 | -0.000010 |
| Binary treatment | 4000 | 3 | TMLE | 199 | 0.001265 | 0.002046 | -0.000781 |
| Binary treatment | 500 | 2 | SDR | 191 | 0.001135 | 0.001406 | -0.000271 |
| Binary treatment | 500 | 3 | SDR | 191 | 0.018439 | 0.023015 | -0.004576 |
| Binary treatment | 500 | 2 | TMLE | 191 | 0.000450 | 0.000722 | -0.000271 |
| Binary treatment | 500 | 3 | TMLE | 191 | 0.017652 | 0.022228 | -0.004576 |
| Numerical dose | 1000 | 2 | SDR | 199 | -0.001126 | -0.000847 | -0.000279 |
| Numerical dose | 1000 | 3 | SDR | 199 | -0.027881 | -0.019206 | -0.008674 |
| Numerical dose | 1000 | 2 | TMLE | 199 | -0.001474 | -0.001195 | -0.000279 |
| Numerical dose | 1000 | 3 | TMLE | 199 | -0.027516 | -0.018842 | -0.008674 |
| Numerical dose | 4000 | 2 | SDR | 199 | -0.000299 | -0.000175 | -0.000124 |
| Numerical dose | 4000 | 3 | SDR | 199 | -0.012281 | -0.005667 | -0.006614 |
| Numerical dose | 4000 | 2 | TMLE | 199 | -0.000289 | -0.000165 | -0.000124 |
| Numerical dose | 4000 | 3 | TMLE | 199 | -0.013104 | -0.006490 | -0.006614 |
| Numerical dose | 500 | 2 | SDR | 192 | -0.001832 | -0.001156 | -0.000676 |
| Numerical dose | 500 | 3 | SDR | 192 | -0.036470 | -0.030815 | -0.005655 |
| Numerical dose | 500 | 2 | TMLE | 192 | -0.003178 | -0.002502 | -0.000676 |
| Numerical dose | 500 | 3 | TMLE | 192 | -0.037453 | -0.031798 | -0.005655 |

The full-support saturated adjoint class contains a valid solution. The implemented sieve dictionary uses measured training combinations and mean continuation for unseen values; its realized finite-sample class need not contain a population solution. The fixed main-effect bridge classes contain a valid solution on the full support. The present study retains the full-population diagnostics for every saved successful fit; other versions and platforms are excluded.

[Population values by outcome time](population-error-by-outcome-time.csv) retain the numerical calculations.

## Coverage including failed fits

The preceding coverage estimates describe successful fits. The additional [table](coverage-including-failures.csv) counts a failed fit as producing no interval and uses all completed datasets as the denominator. Pending datasets are excluded. Its Monte Carlo intervals describe simulation uncertainty.

![Coverage including failed fits](figures/coverage-including-failures.png)
