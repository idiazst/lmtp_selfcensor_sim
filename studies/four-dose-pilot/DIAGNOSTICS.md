# Coverage investigation

The first 165 returned baseline replications per setting triggered the prespecified severe-undercoverage flag for full-history final-outcome inference at n = 10,000. Both SDR and TMLE had 89.7% coverage, with a Wilson Monte Carlo interval of 84.1–93.5%. The baseline 500-replication study continues unchanged so completion-time selection does not determine the final comparison.

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
