# Completed binary n=1000 full-ensemble cell

Source: [GitHub run 41460347711](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41460347711),
frozen commit `b609625bb401e4bb6b8c6742eeea98e1ae48e3f5`.
Specification: `ensemble-grid`, lmtp 1.6.0.9025, cmbridge 0.3.0.9030.
The overall study is still running. This report contains all 100 binary-treatment
n=1000 replications, 400 method/horizon estimates, and no failures or replacement
seeds. The other sample sizes and mechanism are reported separately.

| Method | Horizon | Bias | Bias MCSE | Empirical SD | RMS reported SE | Coverage | Pointwise 95% coverage MC interval |
|---|---:|---:|---:|---:|---:|---:|---:|
| SDR | 1 | .00194 | .00413 | .04128 | .04152 | .96 | [.902, .984] |
| TMLE | 1 | .00256 | .00412 | .04117 | .04139 | .96 | [.902, .984] |
| SDR | 2 | .00073 | .00610 | .06105 | .05793 | .95 | [.888, .978] |
| TMLE | 2 | .00147 | .00602 | .06017 | .05683 | .95 | [.888, .978] |

Coverage is close to nominal in this cell, and estimated bias is small relative
to its Monte Carlo uncertainty. This is consistent with a finite-sample component
to the lower first-horizon coverage at n=500, but does not establish nominal
coverage across all designs. Horizons and methods share datasets. The remaining
larger-sample and numerical-dose cells are needed for the overall assessment.

All nuisances are estimated. The influence-function variance agrees with the
saved sequential variance, bridge variance and twice their covariance to
numerical precision. No fitting criteria or confidence intervals were changed.

`estimates.csv` includes every estimate and seed. `summary.csv` contains the
original reporting fields; `inference-diagnostics.csv` adds bias MCSE, Wilson
coverage limits and standard-error comparisons; `score-variance.csv` contains
the per-dataset variance identities. Tables were extracted from the cumulative
completed checkpoints available at 2026-11-02 16:32 UTC and audited with
`studies/full-history/report.R` and `diagnose.R`. Identical redownloaded
checkpoints were deduplicated only after their file hashes matched.
