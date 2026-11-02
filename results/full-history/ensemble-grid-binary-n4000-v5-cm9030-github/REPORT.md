# Completed binary n=4000 full-ensemble cell

Source: [GitHub run 41460347711](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41460347711),
frozen commit `b609625bb401e4bb6b8c6742eeea98e1ae48e3f5`.
Specification: `ensemble-grid`, lmtp 1.6.0.9025, cmbridge 0.3.0.9030.
All 100 binary-treatment n=4000 replications and 400 method/horizon estimates
returned without failures or replacement seeds. The overall study is ongoing.

| Method | Horizon | Bias | Bias MCSE | Empirical SD | RMS reported SE | Coverage | Pointwise 95% coverage MC interval |
|---|---:|---:|---:|---:|---:|---:|---:|
| SDR | 1 | .00288 | .00216 | .02163 | .02038 | .92 | [.850, .959] |
| TMLE | 1 | .00302 | .00217 | .02171 | .02037 | .93 | [.863, .966] |
| SDR | 2 | .00123 | .00231 | .02307 | .02794 | .98 | [.930, .994] |
| TMLE | 2 | .00082 | .00232 | .02316 | .02782 | .98 | [.930, .994] |

Bias is small relative to its Monte Carlo uncertainty. First-horizon coverage
remains below .95 in this completed cell; reported SEs are about 6% below the
empirical SD. Second-horizon SEs exceed the empirical SD and coverage is .98.
All pointwise Monte Carlo coverage intervals include .95; this alone does not
establish nominal coverage. The shared pattern of first-horizon undercoverage
in the diagnostic and some ensemble cells warrants a more precise large-sample
diagnostic, not an automatic change to the confidence intervals.

Estimated nuisances are used throughout. The reported influence-function
variance equals the saved sequential variance, bridge variance and twice their
covariance to numerical precision. No fitting criteria were changed.

Tables were extracted from the cumulative completed checkpoints available at
2026-11-02 17:02 UTC and audited with `studies/full-history/report.R` and
`diagnose.R`. Duplicate checkpoints were accepted only when hashes matched.
`estimates.csv` retains all seeds and estimates; `inference-diagnostics.csv`
records coverage uncertainty and SE comparisons; `score-variance.csv` contains
the individual variance identities.
