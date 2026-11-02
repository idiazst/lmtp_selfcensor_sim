# Completed numerical-dose n=1000 full-ensemble cell

Source: [GitHub run 41460347711](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41460347711),
frozen commit `b609625bb401e4bb6b8c6742eeea98e1ae48e3f5`.
Specification: `ensemble-grid`, lmtp 1.6.0.9025, cmbridge 0.3.0.9030.
All 100 replications and 400 method/horizon estimates returned without failures
or replacement seeds. The larger numerical-dose cells are still in progress.

| Method | Horizon | Bias | Bias MCSE | Empirical SD | RMS reported SE | Coverage | Pointwise 95% coverage MC interval |
|---|---:|---:|---:|---:|---:|---:|---:|
| SDR | 1 | -.00165 | .00404 | .04039 | .03988 | .96 | [.902, .984] |
| TMLE | 1 | -.00133 | .00403 | .04029 | .03984 | .96 | [.902, .984] |
| SDR | 2 | -.00085 | .00637 | .06367 | .05334 | .91 | [.838, .952] |
| TMLE | 2 | -.00058 | .00635 | .06350 | .05318 | .90 | [.826, .945] |

Bias is small relative to its Monte Carlo uncertainty. First-horizon coverage
is .96. Second-horizon reported SEs are about 16% below empirical SD and
coverage is .90-.91; the TMLE pointwise MC interval excludes .95. This is a
variance-calibration concern. It does not establish a coding defect or identify
its cause. The larger-sample primary ensemble and the separate diagnostic
regularization sensitivity check are needed for further diagnosis.

All nuisances are estimated. The internal score variance identity passes to
numerical precision; this checks variance assembly and does not by itself
validate calibration against repeated-sample variability. No penalties,
convergence criteria or intervals were changed for this completed cell.

Tables were extracted from completed checkpoints at 2026-11-02 20:02 UTC and
audited with `report.R` and `diagnose.R`. The inference and score variance CSVs
retain per-cell Monte Carlo uncertainty and the individual variance identities.
