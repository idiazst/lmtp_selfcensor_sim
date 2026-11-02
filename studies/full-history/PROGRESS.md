# Full-history validation progress

Updated 2026-11-02. Implementation is available in draft
[lmtp PR #1](https://github.com/idiazst/lmtp/pull/1), branch
`full-history-adjustment`. The numerical solver improvement is in draft
[cmbridge PR #1](https://github.com/idiazst/cmbridge/pull/1), branch
`full-history-performance`. Neither PR has been merged.

The new API accepts separate alpha, visit d and stochastic continuation t
callbacks. It builds the pseudo-outcome at every time, estimates both ratios
by classification, and fits target-specific bridge adjoints. Both SDR and
logistic TMLE are implemented. The paper sources have not been edited.

## Completed validation

- 62 new lmtp full-history checks, 182 existing bridge checks, and 181 other
  relevant existing checks pass. lmtp source R CMD check is OK with tests run
  separately. Existing spline boundary warnings remain in some bridge tests.
- All 416 cmbridge checks pass. Full R CMD check, including tests, has no errors
  or warnings and retains its existing prediction-closure binding NOTE.
  [GitHub package validation](https://github.com/idiazst/cmbridge/actions/runs/41459537168)
  also passed.
- Finite-support calculations verify causal truth, the bridge and adjoint
  equations, the mean-zero gradient, and the mixed second-order remainder.
  Truth and population nuisances are never supplied to the fitted estimators.
- The three-treatment-time stress check passed on Linux, including histories
  that return after a missed measurement. This is one dataset, not a coverage
  study.
- The original inverse-link failure at binary n=500, replicate 5 remains
  recorded. Retaining sufficient descendant training groups fixed this seed;
  it is covered by a package regression fixture. Failed seeds were not replaced.

The [100-replication single-sieve diagnostic](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41380165948)
returned all 3,200 method/horizon estimates from 800 datasets without failures.
These results use lmtp 1.6.0.9024 and cmbridge 0.3.0.9029. Every cell at n=4,000
or 10,000 has absolute bias below .003. Coverage at these sizes ranges from .91
to .98 across cells. Some small-sample cells under-cover, including the
numerical-dose first outcome at n=500. The inference audit records pointwise
Monte Carlo uncertainty; these results do not establish uniformly nominal
coverage. The reported variance identity agrees within 1e-14 over all saved
score decompositions.

The original full-ensemble and the grid SuperLearner benchmarks each returned
all 16 estimates from four datasets. All use the three bridge/adjoint candidate
methods. Four datasets are insufficient to assess coverage. The grid variant
uses separately cross-validated existing positive-L1 wrappers plus the mean;
it is recorded separately from the original `SL.saturated_l1_cv` variant.

An additional [80-dataset diagnostic](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41459459543)
using lmtp 1.6.0.9025 and cmbridge 0.3.0.9030 returned all 320 estimates with
no failures. Its sample sizes are 500 and 4,000 and it has 20 replications per
cell. Its results are kept separate from the older 100-replication diagnostic.
Across matched seeds, the largest absolute point-estimate change from the
older source versions is below .000009. The variance identity also passes.

## Current study

[Full-ensemble GitHub run 41460347711](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41460347711)
was launched from commit `b609625bb401e4bb6b8c6742eeea98e1ae48e3f5` with:

- `library=ensemble-grid`, `replications=100`, `first=1`;
- sample sizes 500, 1,000, 4,000 and 10,000;
- binary and numerical-dose mechanisms, both methods and both horizons;
- lmtp 1.6.0.9025 and cmbridge 0.3.0.9030;
- 200 fitting jobs, four datasets per job, at most 20 concurrent runners.

Its target is 800 datasets and 3,200 method/horizon estimates. As of this update,
the study is running and no full-ensemble coverage conclusion has been made.
At the 2026-11-02 16:02 UTC checkpoint audit, 192 datasets and 768 estimates
had returned without failures, and the variance identity passed within 4e-15.
The binary n=500 cell is complete: 100 replications, with first-horizon coverage
.91 (SDR) and .92 (TMLE), and second-horizon coverage .96 and .94. All four
pointwise 95% Monte Carlo coverage intervals include .95; this does not establish
nominal coverage. Its complete tables are saved separately in
`results/full-history/ensemble-grid-binary-n500-v5-cm9030-github/`.
The n=1000 and n=4000 cells were still partial at this audit, and no partial-cell
coverage conclusion is drawn.

At the 2026-11-02 16:32 UTC audit, 268 datasets and 1,072 estimates had returned
without failures. The binary n=1000 cell is now complete: coverage is .96 for
the first horizon and .95 for the second, for both SDR and TMLE; absolute bias
is below .0026 in all four cells. The reported and empirical standard errors
are close. Its tables are in
`results/full-history/ensemble-grid-binary-n1000-v5-cm9030-github/`.
The n=4000 cell has 68 of 100 replications returned and is still partial.
The variance identity across all 268 datasets passes within 5e-15. Monitoring
snapshots are under `work/full-history-monitor/41460347711/`; the `cumulative`
subdirectory contains deduplicated, hash-matched completed checkpoints and is
explicitly a partial audit, not the final 800-dataset report.

At the 2026-11-02 17:02 UTC audit, 316 datasets and 1,264 estimates returned
without failures; the variance identity passed within 7.5e-15. The binary
n=4000 cell is complete. First-horizon coverage is .92 (SDR) and .93 (TMLE),
second-horizon coverage is .98 for both, and absolute bias is below .0031.
First-horizon RMS SEs are about 6% below empirical SD, while second-horizon
SEs exceed empirical SD. All pointwise coverage MC intervals include .95.
Tables are in `results/full-history/ensemble-grid-binary-n4000-v5-cm9030-github/`.
The n=10000 ensemble cell has only 16 returned replications at this audit.

## Additional coverage precision diagnostic

The shared first-horizon coverage shortfall across several diagnostic and
ensemble cells needs a more precise large-sample assessment. A separately
labeled [500-replication diagnostic](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41488034067)
was dispatched at n=10000 for both mechanisms, with `library=sieve-diagnostic`,
`first=1`, `replications=500`, and at most eight parallel runners. It targets
1,000 datasets and 4,000 method/horizon estimates. It uses frozen source commit
`bb8a0079f3339f4f73b5656e9ffd9c9cfec40a55`, lmtp 1.6.0.9025 and cmbridge
0.3.0.9030. Its fitting source hashes match the main study, with the explicitly
different single-sieve diagnostic library. All nuisances remain estimated,
with positive penalties and the same intervals and convergence criteria.
Near 95% coverage, 500 replications reduce its per-cell coverage MCSE to about
one percentage point. This run is ongoing and has no results yet.

The first 100 seeds overlap with the main ensemble and older diagnostic runs;
this permits matched comparisons. Do not pool them or count overlapping
datasets as independent replications across specifications. Keep the new
diagnostic separate from both the main ensemble and the older source versions.
Monitor and assess both runs before finishing this task.

After it completes, download its `full-history-report` artifact into a new
directory, run `diagnose.R`, inspect every failure and all coverage/variance
diagnostics, and preserve the frozen sources and original failed attempts.
Do not pool fitting source versions or nuisance specifications. Any adjustment
to the estimator requires a new source archive and a separately labeled run.
