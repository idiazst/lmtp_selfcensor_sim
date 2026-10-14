# Full longitudinal simulation: 500 replications

Launched on GitHub on October 13, 2026, at approximately 20:05 EDT.

**October 14 morning update:** 760 of 4,000 datasets (19%) are checkpointed,
covering 95 replications in each mechanism/sample-size setting. Twenty GitHub
runners are active. No completed runner job has failed. Five datasets had
recorded estimator failures, all at n=500 or n=1,000; they are retained and
counted. Checkpoint hashes, seed mappings and frozen-source fingerprints pass.

[Preliminary report, tables and scientific graphs](early-summary/REPORT.md)
use exactly these 760 datasets. At n=10,000, final-outcome coverage among
returned estimators is 94.7% (SDR) and 95.8% (TMLE) for binary treatment,
and 88.4% for both numerical-dose estimators. These are 95-replication
preliminary results, not the planned 500-replication conclusions.

Measured mean completed-batch time is 2.66 hours. Approximately 50–60 hours
remain at the current 20-runner pace, subject to longer fits and runner availability.
The [progress snapshot](PROGRESS-SNAPSHOT.json) records its denominator and timing.


| Setting | Sample sizes | Replications per sample size |
| --- | --- | --- |
| Binary treatment | 500; 1,000; 4,000; 10,000 | 500 |
| Numerical dose 0–3 | 500; 1,000; 4,000; 10,000 | 500 |

There are **4,000 planned datasets**, with SDR and logistic TMLE on each
dataset and both follow-up outcomes reported. This launch record contains
no new estimates or coverage results.

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
