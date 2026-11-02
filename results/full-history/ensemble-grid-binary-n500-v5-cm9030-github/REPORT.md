# Completed binary n=500 full-ensemble cell

Source: [GitHub run 41460347711](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41460347711),
frozen commit `b609625bb401e4bb6b8c6742eeea98e1ae48e3f5`.
Specification: `ensemble-grid`, lmtp 1.6.0.9025, cmbridge 0.3.0.9030.
This report covers only the completed binary-treatment n=500 cell; the overall
800-dataset study is still running. Replications 1 through 100 are all included,
with 400 method/horizon estimates and no failures or replacement seeds.

| Method | Horizon | Bias | Bias MCSE | Empirical SD | RMS reported SE | Coverage | Pointwise 95% coverage MC interval |
|---|---:|---:|---:|---:|---:|---:|---:|
| SDR | 1 | .00756 | .00594 | .05936 | .06177 | .91 | [.838, .952] |
| TMLE | 1 | .00822 | .00590 | .05905 | .06139 | .92 | [.850, .959] |
| SDR | 2 | .00484 | .00860 | .08601 | .09252 | .96 | [.902, .984] |
| TMLE | 2 | .00116 | .00852 | .08516 | .08893 | .94 | [.875, .972] |

First-horizon coverage is below nominal in this finite-sample cell, although
the pointwise Monte Carlo intervals include .95. These intervals quantify
simulation uncertainty; they neither modify the estimator intervals nor
establish nominal coverage. Horizons and methods use the same datasets.
The second-horizon coverage is closer to .95. Larger sample sizes and the
numerical-dose mechanism remain necessary to assess the full ensemble.

The reported influence-function variance agrees with the sum of the saved
sequential variance, bridge-correction variance and twice their covariance
to numerical precision. Estimated nuisance fits are used throughout.

`estimates.csv` retains every estimate and seed. `summary.csv` retains the
original reporting fields; `inference-diagnostics.csv` adds bias MCSE, Wilson
coverage limits and standard-error comparisons; `score-variance.csv` retains
the per-dataset variance identity. These tables are filtered from the complete
available checkpoint snapshot downloaded at 2026-11-02 16:02 UTC, then audited
with `studies/full-history/report.R` and `diagnose.R`. No fitting code or source
archives were changed for this report.
