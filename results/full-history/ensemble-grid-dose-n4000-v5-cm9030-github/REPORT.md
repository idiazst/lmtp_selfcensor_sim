# Completed numerical-dose n=4000 full-ensemble cell

Source: [GitHub run 41460347711](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41460347711),
frozen commit `b609625bb401e4bb6b8c6742eeea98e1ae48e3f5`.
Specification: `ensemble-grid`, lmtp 1.6.0.9025, cmbridge 0.3.0.9030.
All 100 replications and 400 method/horizon estimates returned without failures
or replacement seeds. The numerical-dose n=10000 cell is still in progress.

| Method | Horizon | Bias | Bias MCSE | Empirical SD | RMS reported SE | Coverage | Pointwise 95% coverage MC interval |
|---|---:|---:|---:|---:|---:|---:|---:|
| SDR | 1 | .00038 | .00207 | .02068 | .01958 | .93 | [.863, .966] |
| TMLE | 1 | .00032 | .00206 | .02064 | .01957 | .93 | [.863, .966] |
| SDR | 2 | -.00296 | .00278 | .02782 | .02592 | .95 | [.888, .978] |
| TMLE | 2 | -.00286 | .00276 | .02758 | .02590 | .95 | [.888, .978] |

Bias is small relative to its Monte Carlo uncertainty. Reported SEs are about
5-7% below empirical SD. All pointwise coverage MC intervals include .95;
100 replications cannot establish uniformly nominal coverage. The n=1000
second-horizon shortfall is less pronounced at this larger sample size, but
these are separate cells and the n=10000 ensemble results remain pending.

All nuisances are estimated. The internal score variance identity passes to
numerical precision. No penalties, fitting criteria or intervals were changed
for this cell. Tables were extracted from complete checkpoints collected by
2026-11-02 20:52 UTC, audited with `report.R` and `diagnose.R`.
