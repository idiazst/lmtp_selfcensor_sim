# Completed four-scenario MI + standard lmtp comparison

All 400 fourth-scenario datasets finished October 10, 2026 and passed independent
validation. The final aggregate in [the parent report](../REPORT.md) contains
1,600 datasets and 6,400 returned method estimates, with 200 replications per
setting. Original estimates and checkpoints are unchanged.

The fourth scenario violates both MAR and the shadow restriction. Its response
probability is 0.675 + 0.1 W + 0.15 A1 - 0.3 Y2. The causal target remains 0.75;
both population functionals equal 0.663743991454513, giving the same population
bias -0.086256008545487. Coefficients were chosen analytically, before fitting.

- `pilot/`: four implementation-check datasets, excluded from final results.
- `main/`: 400 datasets, 200 at each of n=1,000 and 4,000; validation and diagnostics.
- `combined/`: final aggregation audit, copied to canonical `results/imputation/`.
- `baseline/`: unchanged original summaries and validation provenance.
- `original-results-sha256.json`: pre-extension hashes of the original 1,200 jobs.

The simulation source is in `studies/imputation/neither/` at the repository root.
The pinned runtime is `.runtime/library/`. Frozen sources and fitted objects
remain local and ignored by Git. Each MI arm uses the standard lmtp API on 50
completed datasets and then Rubin pooling. Its original standardized calculation
is used only to check imputation reconstruction and is excluded from results.

`COMPLETED.txt` records completion of fitting, independent saved-result validation
and reporting. All means, coverage and MSE are relative to 0.75. Full diagnostics,
including internal candidate failures and iteration-limit stops, are retained.
