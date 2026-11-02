# Completed 500-replication binary coverage diagnostic

Source: [GitHub run 41488034067](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41488034067),
frozen commit `bb8a0079f3339f4f73b5656e9ffd9c9cfec40a55`.
Specification: `sieve-diagnostic`, lmtp 1.6.0.9025, cmbridge 0.3.0.9030.
All 500 binary-treatment n=10000 replications and 2,000 method/horizon estimates
returned without failures or replacement seeds. The numerical-dose half of
this diagnostic is still in progress.

| Method | Horizon | Bias | Bias MCSE | Empirical SD | RMS reported SE | Coverage | Pointwise 95% coverage MC interval |
|---|---:|---:|---:|---:|---:|---:|---:|
| SDR | 1 | .000484 | .000609 | .013626 | .012874 | .940 | [.916, .958] |
| TMLE | 1 | .000498 | .000609 | .013617 | .012871 | .938 | [.913, .956] |
| SDR | 2 | .000570 | .000785 | .017560 | .017380 | .942 | [.918, .959] |
| TMLE | 2 | .000612 | .000784 | .017522 | .017349 | .946 | [.923, .963] |

Coverage is mildly below .95, with pointwise coverage MCSEs near one percentage
point. All pointwise Monte Carlo intervals include .95. The larger diagnostic
does not support claiming uniformly nominal coverage, nor does it isolate a
coding error. Bias is smaller than its MCSE in every cell. Horizons and methods
share the same datasets.

For this binary mechanism, the independently enumerated population gradient
variances give reference SEs .013182 and .017413 at n=10000. First-horizon RMS
reported SE is about 2.3% below that reference in this single-sieve diagnostic;
the main full-ensemble RMS SE is about 0.8% below it. Second-horizon diagnostic
SE is close to the population reference. The reference is used only to audit
the fitted results; no known nuisance function enters any fitted estimator.
`gradient-reference-comparison.csv` records both specifications separately.
Their overlapping seeds are not counted as independent extra replications.

This fixed-positive-ridge diagnostic is a separate nuisance specification
from the primary cross-validated ensemble. Its results are not pooled with
that study or older package versions. All score variance identities pass to
numerical precision; no criteria, penalties or confidence intervals were
altered in response to these results.

Tables were extracted from completed checkpoints available at 2026-11-02
19:02 UTC and audited with `studies/full-history/report.R` and `diagnose.R`.
`estimates.csv` retains all seeds; `inference-diagnostics.csv` records Monte
Carlo uncertainty and SE calibration; `score-variance.csv` retains the per-fit
variance identities.
