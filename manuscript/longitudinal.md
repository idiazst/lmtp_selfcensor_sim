# Longitudinal treatment effects under informative missingness

This is the two-time, observed-history simulation reported in the manuscript:
binary treatment and numerical dose 0-3; n = 500, 1,000, 4,000, and 10,000;
500 replications per setting. Both follow-up outcomes are reported. All 4,000
datasets are complete, with 3,958 successful datasets and 42 failed datasets.

## Code and results

- [Data-generating mechanisms and exact truths](../studies/longitudinal/dgp.R).
- [Nuisance libraries, fitting, gradients, and interval calculations](../studies/longitudinal/study.R).
- [The 500-replication grid and seed mapping](../studies/longitudinal/github-500/config.R).
- [Individual dataset runner](../studies/longitudinal/github-500/run_one.R) and
  [parallel worker](../studies/longitudinal/github-500/worker.py).
- [Full study plan](../studies/longitudinal/github-500/PLAN.md) and
  [GitHub Actions workflow](../.github/workflows/full-longitudinal-500.yml).
- [Completed report](../results/longitudinal/full500-github-20261013/early-summary/REPORT.md),
  [individual estimates](../results/longitudinal/full500-github-20261013/early-summary/replicates.csv),
  [summary](../results/longitudinal/full500-github-20261013/early-summary/summary.csv), and
  [failed fits](../results/longitudinal/full500-github-20261013/early-summary/errors.csv).
- [Manuscript table and figure code](scripts/build_simulation_section.py).

Treatment at a missed visit is the deterministic zero prescription. The
policy sets the first treatment component to one for the binary mechanism
or increases it by one, capped at three, for numerical dose; the second
component is unchanged. Measurement depends on the subsequent health vector.
The final outcome after a missed intermediate visit equals the baseline
outcome, which makes the target-specific adjoint equation solvable at that
history. The code checks the bridge and adjoint equations on the finite support.

## Repeat the statistical fits

The study used cmbridge 0.3.0.9020 and lmtp 1.6.0.9021 from the archived
packages in `dependencies/`. From a fresh checkout at the version cited in
the manuscript, run:

```sh
Rscript studies/longitudinal/github-500/install.R
FULL_OUTPUT=work/metadata Rscript studies/longitudinal/github-500/prepare.R
```

For example, this runs the eight datasets for replication 1 into a new directory:

```sh
FULL_REPLICATE=1 FULL_OUTPUT=results/new-longitudinal FULL_WORKERS=2 \
  python3 studies/longitudinal/github-500/worker.py
```

The full grid uses `FULL_REPLICATE` values 1 through 500. The supplied workflow
distributes those replications across GitHub runners. A replication always
uses its fixed eight dataset/seed combinations; saved checkpoints are retained
when an interrupted run resumes. Fitting retains the original positive
penalty selection, U-statistic ensemble loss, and PSD projection. Failed
statistical fits are recorded rather than replaced.

To reproduce the manuscript tables and figure without fitting again, follow
the [saved-result reproduction instructions](README.md).
