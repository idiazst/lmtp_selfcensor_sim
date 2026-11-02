# Completed binary n=10000 full-ensemble cell

Source: [GitHub run 41460347711](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41460347711),
frozen commit `b609625bb401e4bb6b8c6742eeea98e1ae48e3f5`.
Specification: `ensemble-grid`, lmtp 1.6.0.9025, cmbridge 0.3.0.9030.
All 100 replications and 400 method/horizon estimates returned without failures
or replacement seeds. All four binary-treatment sample-size cells are now
complete; numerical-dose cells in the overall study are still running.

| Method | Horizon | Bias | Bias MCSE | Empirical SD | RMS reported SE | Coverage | Pointwise 95% coverage MC interval |
|---|---:|---:|---:|---:|---:|---:|---:|
| SDR | 1 | -.00120 | .00142 | .01423 | .01308 | .93 | [.863, .966] |
| TMLE | 1 | -.00123 | .00142 | .01422 | .01308 | .92 | [.850, .959] |
| SDR | 2 | -.00190 | .00173 | .01726 | .01757 | .95 | [.888, .978] |
| TMLE | 2 | -.00182 | .00173 | .01728 | .01754 | .95 | [.888, .978] |

Bias is small relative to its Monte Carlo uncertainty. First-horizon reported
SEs are about 8% below empirical SD in this 100-replication sample and coverage
remains below .95. Second-horizon SEs and empirical SD agree closely, with .95
coverage. All pointwise coverage Monte Carlo intervals include .95, which does
not establish nominal coverage. The separately labeled 500-replication
single-sieve diagnostic is still running to assess coverage more precisely;
its results must not be pooled with this ensemble specification.

All nuisances are estimated. The saved sequential variance, bridge variance
and twice their covariance reproduce the reported influence-function variance
to numerical precision. No fitting criteria or confidence intervals changed.

Tables were extracted from completed checkpoints available at 2026-11-02
18:02 UTC and audited with `studies/full-history/report.R` and `diagnose.R`.
Duplicate checkpoints were accepted only with matching file hashes.
`estimates.csv` retains all seeds and estimates; `inference-diagnostics.csv`
adds Monte Carlo uncertainty and SE comparisons; `score-variance.csv` retains
the individual variance identities.
