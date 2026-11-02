# Comparison with MAR

This study compares bridge SDR and bridge TMLE with multiple imputation
followed by standard lmtp SDR and TMLE. It uses one treatment time and one
partially observed outcome to isolate the missing-data restriction.

The four scenarios are MAR only, shadow only, both, and neither. Each uses
200 replications at n = 1,000 and 4,000, with 50 imputations per dataset.
The intervention sets A1 = 1. The causal target E[Y2(1)] is 0.75 in every
scenario, including when either identifying restriction fails.

## Code and results

- [All four data-generating mechanisms](../studies/imputation/neither/dgp.R).
- [Bridge learners, fitting, and person-level splits](../studies/imputation/neither/original-helpers.R).
- [MI followed by the standard lmtp APIs and Rubin pooling](../studies/imputation/neither/study.R).
- [Fresh all-scenario launcher](../studies/imputation/run_fresh.py) and
  [driver](../studies/imputation/fresh_driver.R).
- [Study plan](../studies/imputation/PLAN.md).
- [Completed results](../results/imputation/REPORT.md),
  [individual estimates](../results/imputation/replicates.csv),
  [summary](../results/imputation/summary.csv), and
  [validation](../results/imputation/VALIDATION.md).
- [Manuscript table code](scripts/build_simulation_section.py).

All 1,600 datasets and 6,400 final method estimates returned. The comparison
uses the same 50 imputations for MI + SDR and MI + TMLE, and shared outer
folds across methods. It retains the internal candidate failures and
Landweber iteration-limit diagnostics documented in the final report.
The original standardization-only MI helper is not the reported comparator;
`study.R` calls the exported standard lmtp estimators on each completed dataset.

## Repeat the statistical fits

From a fresh checkout at the version cited in the manuscript:

```sh
Rscript scripts/install_dependencies.R
python3 studies/imputation/run_fresh.py --output results/new-imputation --workers 8
```

The launcher generates all four scenarios locally, freezes its fitting
sources, and requires a new output directory. It does not require saved
individual fitted objects from the original run. Dependencies are cmbridge
0.3.0.9020, lmtp 1.6.0.9021, and mice 3.19.0, as recorded in the
[package manifest](../dependencies/package-pins.json).

To reproduce the manuscript tables from the public saved estimates without
fitting again, follow the [saved-result reproduction instructions](README.md).
