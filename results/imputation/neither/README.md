# Four-scenario MI + standard lmtp comparison

STATUS: Main started October 10, 2026 at 17:02 EDT after the four-dataset pilot
and canonical-path validation passed. Eight workers are running. Final combined
results will publish to the parent results/imputation directory. The active
completion follow-up is finish-equal-bias-mi-scenario.

October 10, 2026 extension of the completed study in ../mi-lmtp-comparison-v2.
The new scenario violates both MAR and the shadow restriction. At the user's
request, its coefficients give the two population functionals exactly the same
bias. No simulated results were used to choose these coefficients.

    P(R2=1 | W,A1,Y2) = 0.675 + 0.1 W + 0.15 A1 - 0.3 Y2.

Everything else is as in the original study. The causal target remains 0.75,
missingness remains 35%, and both population functionals equal
0.663743991454513 (bias -0.086256008545487). Finite-sample biases can differ.

- `pilot/`: four implementation-check datasets, excluded from final results.
- `main/`: 400 new datasets, 200 at each of n=1,000 and 4,000.
- `combined/`: final four-scenario report, created only after main validation.
- `original-results-sha256.json`: pre-extension hashes of all 1,200 old jobs.
- `unused-first-design/`: an earlier frozen design superseded before any run.

Each phase generates bridge/input checkpoints in `inputs/jobs`, then runs
50 imputations through both standard lmtp TMLE and SDR, storing final four-arm
checkpoints in `jobs`. The reported MI estimators are the standard lmtp APIs
followed by Rubin pooling. The retained original standardized MI calculation is
only a reproducibility check and is excluded from all reported comparisons.

The pinned private library remains ../mi-comparison-v1/library. Every installed
file is verified against the original manifest. Package versions are cmbridge
0.3.0.9020, lmtp 1.6.0.9021, and mice 3.19.0. Frozen helper and estimator code
matches the successful prior study, except for the new DGP and output paths.

`COMPLETED.txt` means all expected datasets, independent saved-result validation,
and reporting succeeded. `FITTING-COMPLETED.txt` alone is insufficient. Reports
retain mean estimates, coverage, and MSE, along with uncertainty and diagnostics.
Original results are preserved and hash-checked before aggregation.

The design and implementation live in ../../simulations/mi_lmtp_neither.
