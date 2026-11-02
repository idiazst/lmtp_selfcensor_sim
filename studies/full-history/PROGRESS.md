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

At the 2026-11-02 18:02 UTC audit, all 400 binary-treatment datasets are complete.
The n=10000 cell has bias between -.00190 and -.00120, first-horizon coverage
.93 (SDR) and .92 (TMLE), and second-horizon coverage .95 for both methods.
First-horizon RMS SEs are about 8% below empirical SD in these 100 replications;
second-horizon SEs and empirical SD agree closely. All pointwise coverage MC
intervals include .95. Its tables are in
`results/full-history/ensemble-grid-binary-n10000-v5-cm9030-github/`.
Including the partial numerical-dose cells, 424 datasets and 1,696 estimates
have returned without failures; the variance identity passes within 8.2e-15.

At the 2026-11-02 19:02 UTC audit, 516 main-study datasets and 2,064 estimates
have returned without failures. Numerical-dose n=500 is complete: first-horizon
bias is .01576/.01590 (SDR/TMLE), with .94 coverage for both; second-horizon
bias is .00339/.00535 with .92 coverage. The positive first-horizon bias is
about 2.8 MCSEs, so its larger-sample pattern remains to be assessed. All
coverage MC intervals include .95. Tables are in
`results/full-history/ensemble-grid-dose-n500-v5-cm9030-github/`.
The other numerical-dose sample sizes are still partial or pending.

At the 2026-11-02 20:02 UTC audit, 640 main-study datasets and 2,560 estimates
have returned without failures. Numerical-dose n=1000 is complete: bias is
below .0017, first-horizon coverage is .96 for both methods, and second-horizon
coverage is .91 (SDR) and .90 (TMLE). Second-horizon RMS SEs are about 16% below
empirical SD; the TMLE pointwise coverage MC interval excludes .95. This is an
actual finite-sample calibration concern, without an identified coding defect.
Its tables are in `results/full-history/ensemble-grid-dose-n1000-v5-cm9030-github/`.
The n=4000 dose cell is still partial with 40 completed replications.

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
one percentage point. At the 2026-11-02 18:02 UTC audit, 270 binary-treatment
datasets and 1,080 estimates have returned without failures. Its variance
identity passes within 9.3e-15. This is still a partial cell; its coverage
assessment is pending all 500 replications and the numerical-dose mechanism.

At the 2026-11-02 19:02 UTC audit, all 500 binary-treatment diagnostic
replications are complete, with 2,000 returned estimates and no failures.
Coverage is .940/.938 for the first horizon (SDR/TMLE) and .942/.946 for the
second. All pointwise 95% coverage MC intervals include .95; bias is below
.00062 and below its MCSE. This remains mild observed undercoverage, not
evidence of uniformly nominal calibration. First-horizon diagnostic RMS SE
is about 2.3% below the independently enumerated population gradient reference;
the primary ensemble RMS SE is about 0.8% below that reference. Its tables and
the separate-specification reference comparison are in
`results/full-history/diagnostic500-binary-n10000-v5-cm9030-github/`.
The diagnostic's numerical-dose half is still pending. Forty dose datasets
have returned at this audit; all 540 datasets and 2,160 estimates across the
separate diagnostic have returned without failures, with variance identity
error below 9.3e-15.

At the 2026-11-02 20:02 UTC audit, 350 dose diagnostic replications are available,
with second-horizon coverage about .926 and reported SEs below empirical SD.
The diagnostic has 850 returned datasets and 3,400 estimates, no failures and
variance identity error below 1.1e-14. Final dose coverage is still pending.

## Regularization sensitivity protocol

To investigate the observed SE shortfall, a matched single-sieve sensitivity
check uses positive ridge 1e-5 in place of .001 at n=10000, for 100 replications
of both mechanisms. All other splits, learners, objectives, links, convergence
checks and intervals are held fixed. This is a separately labeled diagnostic
specification, not a change to the primary ensemble or an asserted estimator
fix. Package source archives remain unchanged. The exact ridge is included in
the specification label and manifest; the study source hash changes with the
new explicit configuration input. This check will compare the same seeds with
the original diagnostic, without pooling or treating them as independent data.

The local n=10000 binary seed-1 smoke check returned all four estimates with
the requested 1e-5 ridge and the pinned package versions. Frozen earlier runs
are unaffected. The matched sensitivity protocol was dispatched as
[GitHub run 41516749627](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41516749627)
from frozen commit `a24fd2d5fe40171cfd15c4fb9b52dc89b7606912`, with 100
replications per mechanism at n=10000, `sieve_lambda=0.00001`, and four parallel
runners. It targets 200 datasets and 800 estimates. Monitor this run alongside
the main ensemble and 500-replication diagnostic, then compare its first 100
seeds with the matching original diagnostic seeds. No results are available yet.

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
