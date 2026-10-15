# Full longitudinal simulation: 500 replications

Launched on GitHub on October 13, 2026, at approximately 20:05 EDT.

**October 14, 20:57 EDT update:** 1,408 of 4,000 datasets (35.2%) are
checkpointed, covering 176 replications in each mechanism/sample-size setting.
Twenty GitHub runners are active; no completed runner job has failed. Fifteen
datasets have recorded estimator failures: binary n=500 (6), binary n=1,000 (1),
numerical n=500 (4), numerical n=1,000 (3), and numerical n=4,000 (1). These
failures remain counted and are not replaced. Checkpoint hashes, seed mappings,
frozen-source fingerprints and independently recomputed table statistics pass.
All previously reported estimates and confidence intervals are unchanged.

[Preliminary report, tables and scientific graphs](early-summary/REPORT.md)
now use all 1,408 checkpoints, with 170–176 returned estimators per setting.
At n=10,000, final-outcome coverage is 95.5% (SDR) and 96.0% (TMLE) for
binary treatment, and 90.3% (SDR) and 90.9% (TMLE) for numerical dose.
Tables include square root n times bias, n times MSE, simulation uncertainty,
EIF component means, estimated/empirical variance ratios, and diagnostic
coverage calculations. These are preliminary results, not the planned
500-replication conclusions.

Measured mean completed-batch time is 2.64 hours. Approximately 40–45 hours
remain at the current 20-runner pace, subject to longer fits and runner availability.
The [progress snapshot](PROGRESS-SNAPSHOT.json) records its denominator and timing.

| Setting | Sample sizes | Replications per sample size |
| --- | --- | --- |
| Binary treatment | 500; 1,000; 4,000; 10,000 | 500 |
| Numerical dose 0–3 | 500; 1,000; 4,000; 10,000 | 500 |

There are **4,000 planned datasets**, with SDR and logistic TMLE on each
dataset and both follow-up outcomes reported. The linked preliminary tables use only completed, verified checkpoints;
pending datasets do not contribute estimates or coverage.

The original positive penalty CV, U-statistic with PSD projection, candidate
libraries, one-step bridge/adjoint correction and shared training-only splits
are retained. The exact original full-study archives are verified and used:
cmbridge 0.3.0.9020 and lmtp 1.6.0.9021. Every dataset is freshly fitted on
GitHub, rather than reusing previous estimates.

- [Replications 1–250](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/38488063211)
- [Replications 251–500](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/38488067067)

Both runs use source commit 7035f2a0f74ff1662da521f54d67eb8404546f84, with ten
standard Linux runners per cohort and two independent R fits per runner.
Each dataset is checkpointed. Statistical failures are retained; an
infrastructure retry verifies and resumes only missing checkpoints.

The report job combines returned checkpoints from both cohorts and saves
tables, scientific graphs and verification records as a run artifact. The last
cohort to finish generates the combined report. Incomplete counts are clearly
labeled preliminary. Artifacts persist for 90 days. Runtime estimates will use
actual GitHub fitting times, including n=10,000. There are no local fitting
workers or scheduled chat messages for this study.

[Full plan](../../../studies/longitudinal/github-500/PLAN.md),
[design](design.csv), [true parameters](truth.csv),
[source hashes](source-manifest.json), [launch records](launch.json).
