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

`studies/imputation/` contains the latest MI + standard lmtp TMLE/SDR versus
bridge TMLE/SDR comparison. It uses n = 1000, 4000, 200 replications per
scenario, 50 imputations and target 0.75. The first three scenarios are
complete; the extension where neither identification assumption holds is
being computed separately under `studies/imputation/neither/` and
`results/imputation/neither/`. Its results are merged only after validation.
[Current results](results/imputation/REPORT.md).

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
