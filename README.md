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

`studies/longitudinal/` contains binary treatment and numerical dose 0–3,
with missingness at both follow-ups. The approved study uses n = 500, 1000,
4000, with 200 replications per setting, and SDR and logistic TMLE with the
one-step bridge correction. [Plan](studies/longitudinal/PLAN.md),
[completed results](results/longitudinal/REPORT.md).

The [selected-seed bridge/adjoint diagnostic](studies/longitudinal/diagnostics/README.md)
uses the numerical-dose datasets with the largest and smallest absolute
n=4,000 SDR errors, then refits only those ensembles at n=4,000, 10,000 and
50,000. [Plots and equation checks](results/longitudinal/bridge-adjoint-seed-check/REPORT.md)
use held-out predictions. Its adjoint loading uses exact DGP treatment ratios,
so it is an isolated nuisance diagnostic rather than another full-estimator
coverage study.

`studies/imputation/` contains the latest MI + standard lmtp TMLE/SDR versus
bridge TMLE/SDR comparison. It uses n = 1000, 4000, 200 replications per
scenario, 50 imputations and target 0.75. All four scenarios are complete:
MAR only, shadow only, both assumptions, and neither assumption. The validated
aggregate contains 1,600 datasets and 6,400 returned method estimates, with
160,000 completed-data lmtp calls. Original results are unchanged.
[Completed results](results/imputation/REPORT.md),
[validation](results/imputation/VALIDATION.md).

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
# Recompute a study into a new directory; defaults are the approved full design.
SIM_OUTPUT=results/new-longitudinal SIM_WORKERS=8 Rscript studies/longitudinal/run.R
python3 studies/imputation/run_fresh.py --output results/new-imputation --workers 8

# Rebuild reports from the saved local checkpoints without fitting again.
Rscript studies/longitudinal/collect.R
Rscript studies/imputation/validate.R results/imputation
Rscript studies/imputation/summarize.R results/imputation
```

The extension's validated launcher is documented in
`studies/imputation/neither/PLAN.md`; its frozen fitting sources are kept
unchanged during execution. Running studies is separate from package CI.
Set `SIM_WORKERS=1` for sequential execution. Positive penalties, training-only
CV and shared person splits retain their approved definitions. Truth is used
only for verification and reporting. No known-function, zero-penalty or Gaussian
mean-update simulations are included.

Compact tables, reports, figures and checkpoint hashes are versioned. Large
individual fitted objects remain in ignored `results/**/jobs/` directories;
installed packages remain in `.runtime/`. The numerical-dose longitudinal
study still shows final-outcome undercoverage, and its 23 failed datasets are
retained. Organization does not resolve that statistical finding.

See [result provenance](results/PROVENANCE.md). Published historical fingerprints
refer to the original runs; new runs receive their own source fingerprints.
