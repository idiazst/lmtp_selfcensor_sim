# Coverage investigation

The first 165 returned baseline replications per setting triggered the prespecified severe-undercoverage flag for full-history final-outcome inference at n = 10,000. Both SDR and TMLE had 89.7% coverage, with a Wilson Monte Carlo interval of 84.1–93.5%. The baseline 500-replication study was completed unchanged so completion-time selection does not determine the final comparison.

Audits found the stated EIF terms, signs, centering, person-level folds and classifier class-proportion adjustment intact. Saved standard errors agree with direct empirical EIF standard deviations divided by sqrt(n). Four continuation nodes enumerate all four dose atoms exactly.

Two isolated diagnostics use the same full-history datasets and folds, n = 10,000 and replications 1–100:

| Profile | Change from baseline |
|---|---|
| `support` | Set attended-policy ratios to zero at dose 0 and continuation-policy ratios to zero at auxiliary treatment 1, using the known policy support. Apply the same masks to held-out and internal out-of-fold predictions. |
| `rich_adjoint` | Replace additive marginal polynomial bases by the existing quadratic basis with pairwise interactions in the sieve and Landweber adjoints. Preserve their tuning grids and the PMMR candidate. |

The `support_rich` profile combines these changes if a follow-up comparison is warranted. Support diagnostics are currently implemented for the full-history adapter only. The quadratic basis adds interactions but still does not span arbitrary four-dose contrasts or all higher-order interactions; it is a controlled approximation diagnostic, not a claim of exact specification.

A subsequent population projection verified that the pairwise quadratic space remains restrictive. The `tensor_adjoint` comparison therefore uses tensor products of marginal cubic polynomials, with binary columns limited to degree one and constant columns omitted. It represents all four dose levels and all interactions among the dose, auxiliary treatment, binary state and continuous state. The full-history target and instrument designs each have 64 basis columns. Marginal polynomials are orthogonalized using the training sample for numerical stability, and the fitted transformations are retained for prediction. Only the sieve and Landweber adjoint bases change. The original PMMR candidate, tuning grids and other nuisances remain fixed. `support_tensor` combines this basis with policy-support zeros if warranted. Both tensor profiles are restricted to the full-history diagnostic. The pairwise diagnostic remains a separate comparison.

The generator, policy, target means, bridge library, outcome learners, ratio learners, randomizer draws, folds and 95% Wald interval formula remain fixed. Each profile has its own study label, numerical fingerprint and output directory. All failures are retained. Compare bias, sampling SD, RMS reported SE, tail behavior, coverage and conditional-moment diagnostics; a coverage increase alone is insufficient to justify a change. Any selected revision needs a separate confirmation run rather than pooling diagnostic and baseline outputs.

The early full-history n = 1,000 instability is a separate issue. Replication 31 has an extreme final-outcome estimate and a nearly unregularized adjoint fit; this explains most of the inflated sampling variance in that early cell. It remains in all reported results.

At the two-hour check, baseline n = 1,000 replication 145 and tensor n = 10,000 replication 1 showed much larger errors. In each case, one outer fold's terminal adjoint selected a nearly unregularized sieve with a negative U-statistic validation score and produced almost all the EIF variance. The `tensor_v` follow-up keeps the tensor basis but uses V-statistic validation for adjoint penalty selection and stacking. Including the diagonal residual products supplies a finite-sample variance penalty; it changes neither the EIF formula nor the bridge fits. Compare this profile on the same 100 replications at n = 1,000 and 10,000. The n = 10,000 comparison isolates U versus V from the tensor profile; the n = 1,000 comparison assesses the combined basis/tuning change against baseline. Wide intervals alone are not evidence of a successful repair.

## Completed results, 7 November 2026

All baseline and diagnostic GitHub runs completed. The baseline contains 3,000 datasets: 500 replications at each combination of observed/full history and n = 1,000, 4,000, 10,000. Of 6,000 method attempts, 5,977 returned valid results and 23 had statistical failures. There were no infrastructure failures. All statistical failures occurred at full-history n = 1,000: 15 SDR and eight TMLE. No failed seed was replaced, no extreme estimate was removed, and no numerical profiles were pooled.

Final-outcome coverage of nominal 95% intervals, conditional on a returned fit:

| History | n | SDR | TMLE |
|---|---:|---:|---:|
| Observed | 1,000 | 93.0% | 91.8% |
| Observed | 4,000 | 93.2% | 92.8% |
| Observed | 10,000 | 93.0% | 92.2% |
| Full | 1,000 | 90.9% | 89.4% |
| Full | 4,000 | 92.2% | 91.6% |
| Full | 10,000 | 91.4% | 90.4% |

Counting a failed fit as unsuccessful interval production, full-history n = 1,000 coverage is 88.2% for SDR and 88.0% for TMLE. Rare extreme estimates also dominate that cell's mean bias and sampling SD; these summaries should be read alongside individual-estimate and tail diagnostics. The observed-history undercoverage remains outside the scope of the full-history fitting revisions below.

The controlled full-history comparisons at n = 10,000 use the same 100 seeds and person folds. Their final-outcome results are:

| Profile | SDR coverage | TMLE coverage | SDR empirical SD | SDR RMS SE |
|---|---:|---:|---:|---:|
| Baseline, matched seeds 1–100 | 90% | 90% | 0.01724 | 0.01578 |
| Policy-support zeros | 90% | 88% | 0.01719 | 0.01563 |
| Pairwise quadratic adjoints | 92% | 91% | 0.01800 | 0.01664 |
| Tensor adjoints, U selection | 96% | 96% | 1.07842 | 1.01272 |
| Tensor adjoints, V selection | 94% | 93% | 0.01759 | 0.01589 |

All 100 fits returned for each method in these n = 10,000 comparisons. Tensor U's apparent coverage increase accompanies severe instability and is not an improvement. V selection substantially reduces that instability. Its three- to four-point coverage gain over the matched original baseline remains uncertain with 100 replications; the paired descriptive McNemar p-values are 0.375 and 0.219 for TMLE and SDR. These are development comparisons, not independent confirmation.

The V profile does not resolve inference across sample sizes and outcomes. At n = 1,000, 97 SDR and 99 TMLE fits returned. Earlier-outcome coverage is only 87.6% and 88.9%, respectively, or 85% and 88% counting failures. Final-outcome coverage is 97.9% and 93.9% among returned fits, or 95% and 93% counting failures. At n = 10,000, the final-outcome RMS SE remains about 90% of the empirical SD for SDR and 88% for TMLE. Do not promote this diagnostic profile to a validated replacement on these results.

Two separately labelled V stress replays at full-history n = 1,000 use replications 145 and 432, outside the planned 100-seed comparison. They are excluded from its coverage calculations:

| Replication | Baseline SDR estimate (SE) | Tensor V estimate (SE) |
|---|---:|---:|
| 145 | 86.838 (78.895) | 0.479 (0.046) |
| 432 | 0.967 (0.371) | 0.736 (0.159) |

The true final-outcome mean is 0.536243. Replication 145's dominant fold falls from 99.91% to 35.28% of EIF squared mass. Replication 432 still places about 91% of that mass in one fold, and its unchanged bridge retains an extreme negative U selection score. The saved bridge summaries are identical across these stress comparisons; adjoint selection uses V as intended. These selected examples establish neither a population failure rate nor coverage.

The remaining issues concern nuisance approximation, regularization and fit stability. The completed audits have not identified an EIF sign, SE scaling, person-fold or randomizer class-proportion implementation error. Negative U scores are mathematically possible; the evidence here is that unstable fitted candidates can win that criterion. Further work should assess bridge stability and uncertainty calibration using fixed numerical specifications and separate confirmation seeds. Repeatedly selecting profiles solely for favorable coverage would not validate inference.

## Run provenance and saved reports

| Run | GitHub Actions |
|---|---|
| Baseline replications 1–250 | [42330495803](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/42330495803) |
| Baseline replications 251–500 | [42330536762](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/42330536762) |
| Policy support, 100 | [42335033687](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/42335033687) |
| Pairwise adjoints, 100 | [42335035323](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/42335035323) |
| Tensor U, 100 | [42335652591](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/42335652591) |
| Tensor V, 100 at each of two sizes | [42340315097](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/42340315097) |
| Tensor V stress replication 145 | [42345060292](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/42345060292) |
| Tensor V stress replication 432 | [42345065099](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/42345065099) |

The baseline uses frozen commit `b0c4d5ae80cf6fdfa769caf5105bcb3691f407b9`; Tensor V and its stress replays use `8f164b4eff326ef39288ccb3edf71dcebcef2c75`. Each artifact retains its source fingerprint, complete study manifest, seed, data hash and fold hash. All paired GitHub datasets and folds agree exactly.

Collected local reports live under `results/four-dose-full-v1` and `results/four-dose-diagnostic-{support100,rich100,tensor100,tensorv100}`. Each completed cohort has `COVERAGE.md`, CSV summaries, individual estimates and failure records. Paired reports live in each diagnostic's `comparisons` directory. The Tensor V `comparisons/tensor-u` report uses V as its first/reference profile and U as its second profile so the comparison cohort is exactly the shared n = 10,000 seeds. The separate stress report is `results/four-dose-diagnostic-tensorv-stress/STRESS_RESULTS.md`. The two-hour baseline snapshot remains under `results/four-dose-full-v1/checks/two-hour`.
