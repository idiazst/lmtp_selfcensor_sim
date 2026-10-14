# Full longitudinal rerun: 500 replications

Binary treatment and numerical dose 0–3, with missingness at both follow-ups,
use n = 500, 1,000, 4,000 and 10,000. Each of the eight settings has 500
replications: **4,000 datasets** in total. Every dataset is analyzed by SDR
and logistic TMLE, with the one-step bridge/adjoint correction. Both outcome
times are reported. The parameter, conditional distributions and assumptions
are unchanged from the [original plan](../PLAN.md).

The original frozen full-study archives are cmbridge 0.3.0.9020 and lmtp
1.6.0.9021. Their SHA256 checksums are verified. This rerun retains the original
positive penalty CV, the U-statistic with PSD projection, all candidate learners,
and shared outer, learner and nested training-only splits. No misspecified-model,
known-function, zero-penalty or Gaussian mean-update simulations are added.
No adaptation of the penalty-selection rule is included.

The fixed seed mapping extends the original mapping to n = 10,000 and replication
500. Every fit is recomputed on GitHub, including the first 200 original seeds;
none is copied from an earlier study. Failed statistical fits are retained,
recorded and counted, rather than replaced. Interrupted infrastructure attempts
may resume only missing checkpoints with the same frozen source fingerprint.

Two GitHub workflow runs cover replications 1–250 and 251–500, with ten concurrent
standard Linux runners per cohort and two independent R processes per runner.
Each runner handles eight datasets for one replication, saving an immutable
compressed checkpoint after every dataset. The long sample sizes run first,
and unfinished attempts are logged before the runner's time limit. Fitting and
reporting jobs have read-only repository permissions. Checkpoint artifacts
persist for 90 days, allowing recovery after infrastructure interruptions.

The report job reads artifacts from both cohorts and verifies checkpoint hashes,
seeds, source fingerprints and returned estimator results. The last cohort to
finish produces the combined report. It explicitly reports completed, failed
and pending counts, with conditional coverage and coverage counting failures as
producing no interval. Incomplete results are labeled preliminary.

Tables and scientific graphs show bias, square root n times bias, RMSE, empirical
SD, mean estimated SE, pointwise and simultaneous coverage, simulation uncertainty,
and the mean of each EIF component. Full-support conditional-equation diagnostics,
penalties, ensemble weights, warnings and numerical failures are retained.
No package implementation is altered to obtain a desired coverage result.

## Launch

Use the same immutable source revision and study label for both dispatches:

```sh
gh workflow run full-longitudinal-500.yml --ref full-study-500-github \
  -f study_id=full500-20261013 -f first=1 -f last=250 -f parallel=10
gh workflow run full-longitudinal-500.yml --ref full-study-500-github \
  -f study_id=full500-20261013 -f first=251 -f last=500 -f parallel=10
```

There is no local fitting run or scheduled chat message. Completion time will be
estimated from actual GitHub fitting times, including n = 10,000, rather than
extrapolated solely from the previous laptop run.
