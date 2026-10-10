# Fourth scenario: neither MAR nor the shadow restriction holds

Requested October 10, 2026. Preserve the completed three-scenario study and its
verified package builds. Add one scenario to complete the assumptions comparison.

## Data-generating process and target

Keep W ~ Bernoulli(0.5), A1 | W ~ Bernoulli(0.4 + 0.2 W), and
Y2 | W,A1 ~ Bernoulli(0.2 + 0.1 W + 0.5 A1), with independent generating uniforms.
For the new scenario, use

    P(R2 = 1 | W,A1,Y2) = 0.675 + 0.1 W + 0.15 A1 - 0.3 Y2.

Observe W and A1 for everyone and Y2 only if R2=1. Outcome dependence violates
MAR, and treatment dependence violates the shadow exclusion. Response
probabilities range from 0.375 to 0.925, and marginal missingness remains exactly 35%.
Treatment exchangeability, positivity, and the full-data law are unchanged.
The intervention sets A1=1 for everyone. The estimand E[Y2(1)] remains 0.75.

Before fitting, enumerate the binary support to verify positivity, both
assumption violations, full-rank bridge operators, bridge solutions greater
than one, and saturated-basis representation of bridge and adjoint solutions.
Both population functionals equal 0.663743991454513, so both biases equal
-0.086256008545487. The user requested this calibration before any new simulation
was run. The treatment coefficient 0.15 equals 0.3 times the treatment effect
0.5 on the outcome probability. Consequently P(R2=1|W,A1) = 0.615 + 0.07 W
does not depend on A1. The unique observed-data bridge is therefore constant
over Y2 within W, beta(W,Y2) = 1/(0.615 + 0.07 W), and the bridge and MAR
functionals coincide within each W stratum. Both conditional independence
assumptions still fail. Finite-sample biases may differ slightly.
No population truth or latent outcome enters estimation.

## Estimation and simulation design

Use n=1,000 and 4,000, with 200 main replications each (400 additional datasets).
Use the original main data seeds and folds so W, A1, latent Y2, and underlying
random uniforms are paired across scenarios. Append neither as scenario four
without changing the existing scenario order. The new imputation seed uses this
scenario index. Use four separate pilot datasets (two per sample size), excluded
from main results. Do not select DGP parameters based on simulated performance.

Use the original private library: cmbridge 0.3.0.9020, lmtp 1.6.0.9021, and
mice 3.19.0. Verify every library file against the original SHA256 manifest.
The numerical bodies of the bridge helpers and all completed-data fitting,
imputation, and pooling functions are retained. Path defaults now use the
canonical lmtp_selfcensor_sim repository. Only paths, the DGP, orchestration, and reporting
change. No package code changes or tuning changes are permitted.

For each dataset, fit bridge SDR and TMLE with the same conditional-moment
ensemble, saturated nuisance classes, and three shared outer folds. Generate
50 logistic imputations with W,A1,W*A1, run exported standard lmtp_tmle and
lmtp_sdr on every completed dataset, and pool each method with Rubin's rules.
Exclude R2 from completed-data analyses. The old saturated-standardization MI
calculation is retained only as an imputation-stream verification check and is
not a reported estimator. Both MI arms receive exactly the same imputations.

Saturated observed-data regressions and finite binary support avoid additional
functional-form misspecification. Invalid missing-data identification assumptions
are intentional. Finite-sample regularization remains as in the original study.

## Validation, checkpoints, and reporting

Freeze sources for each phase; use atomic dataset checkpoints and resumable
launchers. Audit the DGP before the pilot. Require successful independent pilot
checks before launching main. Validate the imputation stream, saved data, folds,
complete-data estimator classes, individual EIF reconstruction, and Rubin pooling.
Retain all failed fits and internal candidate diagnostics. Never replace a dataset
or silently pool a subset of imputations.

New results live in lmtp_selfcensor_sim/results/imputation/neither.
The final combined report lives in lmtp_selfcensor_sim/results/imputation. Hash the 1,200 existing corrected
jobs before the run and verify those hashes before combining results. Combine
only references to the old jobs and the 400 new jobs, preserving all original
files. Report all four scenarios, mean estimates, bias, coverage, MSE, RMSE,
empirical SD, mean SE, Monte Carlo uncertainty, failures, and diagnostics.
All performance measures use truth 0.75 even when both assumptions fail.
