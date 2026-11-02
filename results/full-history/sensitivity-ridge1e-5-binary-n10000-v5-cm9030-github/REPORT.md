# Completed binary matched-ridge diagnostic

Sensitivity: [GitHub run 41516749627](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41516749627),
source `a24fd2d5fe40171cfd15c4fb9b52dc89b7606912`.
Reference: [GitHub run 41488034067](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41488034067),
source `bb8a0079f3339f4f73b5656e9ffd9c9cfec40a55`, replications 1:100 only.
Both use lmtp 1.6.0.9025 and cmbridge 0.3.0.9030.

All 100 binary sensitivity datasets at n=10000 returned all 400 estimates
without failures. Numerical-dose sensitivity results remain pending. The
single-sieve bridge and adjoint ridge is .001 in the reference and 1e-5 in
the sensitivity. All other library settings, folds, SuperLearners, links,
criteria and intervals match. Package archives and the DGP are unchanged;
the study source exposes the explicitly recorded ridge input. These are
matched comparisons of the same seeds, not 200 independent datasets.

| Method | Horizon | Reference RMS SE | Sensitivity RMS SE | Mean SE change (paired MCSE) | Mean estimate change (paired MCSE) | Reference / sensitivity coverage |
|---|---:|---:|---:|---:|---:|---:|
| SDR | 1 | .012900 | .013238 | .000337 (.0000054) | -.000153 (.0000140) | .92 / .93 |
| TMLE | 1 | .012898 | .013236 | .000337 (.0000053) | -.000152 (.0000140) | .92 / .93 |
| SDR | 2 | .017440 | .017588 | .000147 (.0000067) | -.000113 (.0000299) | .95 / .95 |
| TMLE | 2 | .017411 | .017560 | .000148 (.0000067) | -.000114 (.0000299) | .95 / .95 |

First-horizon reported SE rises by about 2.6%, with a paired effect well beyond
its Monte Carlo uncertainty. The gradient variance increases about .088:
bridge variance increases about .079 and twice the covariance increases about
.039, partly offset by a .030 decrease in sequential variance. This locates
the change in the saved score components; changing both ridge penalties does
not isolate the bridge fit from the adjoint fit.

The first-horizon coverage change is .01 with paired MCSE .01: one previously
uncovered replication becomes covered, and none becomes uncovered. No second-
horizon interval changes coverage. This is not evidence of restored nominal
coverage or equivalence. Sensitivity coverage is .93 at horizon 1 (pointwise
95% MC interval [.863, .966]) and .95 at horizon 2 ([.888, .978]). Bias is
between -.00180 and -.00122, comparable to its MCSE. The numerical-dose
comparison is needed before attributing its larger precision-study shortfall
to regularization.

Tables were produced with `report.R`, `diagnose.R` and `compare-ridge.R` from
completed checkpoints at 2026-11-02 21:02 UTC. Separate fitting specifications
are retained, no known nuisances were fitted, no seeds were replaced, and no
estimator confidence intervals were altered.
