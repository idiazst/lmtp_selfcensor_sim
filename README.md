# lmtp_selfcensor_sim

The latest longitudinal self-censoring study and multiple-imputation comparison.
Earlier simulation implementations and results are excluded.

The repositories have separate responsibilities:

| Repository | Responsibility |
| --- | --- |
| [cmbridge](https://github.com/idiazst/cmbridge) | Conditional-moment estimators and ensembles; unit tests and recovery checks |
| [lmtp, self-censoring branch](https://github.com/idiazst/lmtp/tree/self-censoring) | lmtp package with pooled SDR/logistic TMLE, shared splits and the observed-history one-step correction |
| This repository | DGPs, study configurations, launchers, verification, tables, graphs and latest results |

The package is named **lmtp**, rather than a separate wrapper package.

## Studies

The manuscript's completed longitudinal study uses **500 replications** at
n = 500, 1,000, 4,000 and 10,000 for binary treatment and numerical dose:
4,000 datasets, 3,958 returned fits per method, and 42 failed datasets.
Both follow-up outcomes, SDR and logistic TMLE, the original PSD projection,
and positive penalty CV are retained. [Code and reproduction instructions](manuscript/longitudinal.md),
[completed results](results/longitudinal/full500-github-20261013/early-summary/REPORT.md).

The earlier 200-replication study at n = 500, 1,000 and 4,000 is preserved
separately as a historical comparison. Its results are not pooled with the
500-replication study. [Historical plan](studies/longitudinal/PLAN.md),
[historical results](results/longitudinal/REPORT.md).

The [selected-seed bridge/adjoint diagnostic](studies/longitudinal/diagnostics/README.md)
uses the numerical-dose datasets with the largest and smallest absolute
n=4,000 SDR errors, then refits only those ensembles at n=4,000, 10,000 and
50,000. [Plots and equation checks](results/longitudinal/bridge-adjoint-seed-check/REPORT.md)
use held-out predictions. Its adjoint loading uses exact DGP treatment ratios,
so it is an isolated nuisance diagnostic rather than another full-estimator
coverage study.

The [RKHS loss check](results/longitudinal/rkhs-loss-check/REPORT.md) evaluates
the true DGP functions and saved fits on the exact population support, then
replays the actual validation scores. It verifies that truth minimizes the
population loss and documents finite-sample selection after PSD projection.

`studies/imputation/` contains the latest MI + standard lmtp TMLE/SDR versus
bridge TMLE/SDR comparison. It uses n = 1000, 4000, 200 replications per
scenario, 50 imputations and target 0.75. All four scenarios are complete:
MAR only, shadow only, both assumptions, and neither assumption. The validated
aggregate contains 1,600 datasets and 6,400 returned method estimates, with
160,000 completed-data lmtp calls. Original results are unchanged.
[Completed results](results/imputation/REPORT.md),
[validation](results/imputation/VALIDATION.md).

## Code for the manuscript

| Simulation subsection | Code and reproduction guide |
| --- | --- |
| Longitudinal treatment effects under informative missingness | [Longitudinal study](manuscript/longitudinal.md) |
| Comparison with MAR | [Four-scenario MAR comparison](manuscript/mar.md) |
| Manuscript tables and figure | [Saved-result verification and reporting](manuscript/README.md) |

## Reproduce

Use R >= 4.1. The [dependency manifest](dependencies/package-pins.json)
pins the exact cmbridge and lmtp archives used for the saved studies, together
with their SHA256 hashes. Study code does not substitute the newest package
version for those builds. Install the frozen dependencies into an isolated
library:

```sh
Rscript scripts/install_dependencies.R
Rscript scripts/check_setup.R
```

From this repository's root:

```sh
# Recompute the four-scenario MAR comparison into a new directory.
python3 studies/imputation/run_fresh.py --output results/new-imputation --workers 8

# Rebuild reports from the saved local checkpoints without fitting again.
Rscript studies/longitudinal/collect.R
Rscript studies/imputation/validate.R results/imputation
Rscript studies/imputation/summarize.R results/imputation
```

For the 500-replication longitudinal study, use the commands in
[its reproduction guide](manuscript/longitudinal.md). To regenerate the manuscript
tables and figure from the public saved results without fitting models, run
`python3 manuscript/scripts/build_simulation_section.py`.

The extension's validated launcher is documented in
`studies/imputation/neither/PLAN.md`; its frozen fitting sources are kept
unchanged during execution. Running studies is separate from package CI.
Set `SIM_WORKERS=1` for sequential execution. Positive penalties, training-only
CV and shared person splits retain their approved definitions. Truth is used
only for verification and reporting. No known-function, zero-penalty or Gaussian
mean-update simulations are included.

Compact tables, reports, figures and checkpoint hashes are versioned. Large
individual fitted objects remain in ignored `results/**/jobs/` directories;
installed packages remain in `.runtime/`. The numerical-dose study still shows
final-outcome undercoverage. All 42 failed datasets across both treatment
mechanisms in the 500-replication study are retained.

See [result provenance](results/PROVENANCE.md). Published historical fingerprints
refer to the original runs; new runs receive their own source fingerprints.
