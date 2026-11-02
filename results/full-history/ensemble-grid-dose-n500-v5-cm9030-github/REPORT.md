# Completed numerical-dose n=500 full-ensemble cell

Source: [GitHub run 41460347711](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41460347711),
frozen commit `b609625bb401e4bb6b8c6742eeea98e1ae48e3f5`.
Specification: `ensemble-grid`, lmtp 1.6.0.9025, cmbridge 0.3.0.9030.
All 100 replications and 400 method/horizon estimates returned without failures
or replacement seeds. The larger numerical-dose cells remain in progress.

| Method | Horizon | Bias | Bias MCSE | Empirical SD | RMS reported SE | Coverage | Pointwise 95% coverage MC interval |
|---|---:|---:|---:|---:|---:|---:|---:|
| SDR | 1 | .01576 | .00565 | .05648 | .05416 | .94 | [.875, .972] |
| TMLE | 1 | .01590 | .00560 | .05604 | .05405 | .94 | [.875, .972] |
| SDR | 2 | .00339 | .00799 | .07990 | .07968 | .92 | [.850, .959] |
| TMLE | 2 | .00535 | .00795 | .07950 | .07928 | .92 | [.850, .959] |

There is positive first-horizon bias at this sample size. Its magnitude is
about 2.8 Monte Carlo standard errors; larger-sample results are needed to
assess the bias pattern. First-horizon RMS SEs are about 4% below empirical SD.
Second-horizon SEs and empirical SD agree closely, although coverage is .92
in these 100 replications. Pointwise coverage MC intervals include .95, which
does not establish nominal coverage. Both methods use the same datasets.

All nuisances are estimated. The saved score decomposition reproduces the
reported variance to numerical precision. Fitting criteria and intervals are
unchanged. Tables were extracted from completed checkpoints at 2026-11-02
19:02 UTC and audited with `report.R` and `diagnose.R`. `estimates.csv` includes
every seed and estimate; the inference and variance tables retain the audit.
