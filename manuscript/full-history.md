# Reproduce the full-history adjustment simulation

This guide accompanies the manuscript subsections **Treatment effects under
full-history adjustment** and **Full-history coverage using Monte Carlo sampling
variance**. The primary study uses estimated nuisances, SDR and logistic TMLE,
two outcome times, binary treatment and numerical dose, and 100 replications
at each of n = 500, 1,000, 4,000 and 10,000. All 800 datasets returned both
methods at both outcomes (3,200 estimates), with no failed or replaced seeds.

## Public estimator and frozen versions

The estimator is `lmtp::lmtp_full_history()`. The implementation used in these
results is published in [lmtp commit d6bd64d](https://github.com/idiazst/lmtp/tree/d6bd64dba183c4aa3e2cc94d9b9446edf09e2d70),
version 1.6.0.9025. Its conditional-moment learners are published in
[cmbridge commit e772812](https://github.com/idiazst/cmbridge/tree/e772812c68a05e5072bae9fb323b1f4d4cc249c7),
version 0.3.0.9030. Install the frozen archives in this repository rather than
substituting the current default branches. The package PRs retain the
documented interval-calibration limitations; public availability of the
research code does not imply that these limitations have been resolved.

- [Frozen package archives and checksums](../dependencies/full-history/manifest.csv)
- [Source-version record](../dependencies/full-history/SOURCES.md)
- [Data-generating laws, intervention, and exact truth](../studies/full-history/dgp.R)
- [Estimator configuration and replication runner](../studies/full-history/run.R)
- [GitHub Actions workflow](../.github/workflows/full-history.yml)
- [Study design and mathematical checks](../studies/full-history/README.md)

The main fitted results were generated from simulation commit
[`b609625`](https://github.com/idiazst/lmtp_selfcensor_sim/tree/b609625bb401e4bb6b8c6742eeea98e1ae48e3f5),
in [run 41460347711](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41460347711).
Each checkpoint records the seed, source hashes, package versions, fitting
specification, and any errors. The frozen runner uses `ensemble-grid`: three
positive-L1 saturated learners plus the mean for regression/classification,
and sieve, Landweber and kernel conditional-moment ensembles for bridges and
adjoints. Truth is used only for validation and reporting.

## Rebuild the manuscript tables without fitting models

From a checkout of the `full-history-adjustment` branch:

```sh
python3 manuscript/scripts/build_full_history_section.py
```

Only Python 3's standard library is required. The script verifies 8,000
saved estimate rows in 48 cells across three separate specifications, checking
the intended seeds, unique replication IDs, counts, finite estimates and SEs,
error fields, original Wald interval endpoints, and the saved summary values.
It computes the sampling variance with denominator M-1 from the individual
estimates, and verifies coverage both with the MC SD and after subtracting
the across-replication mean bias. It never refits an estimator or changes a
saved result file.

Outputs in `manuscript/simulation_tables/`:

- `full_history.tex`: primary results for both outcomes, with scaled bias,
  scaled MSE, and coverage.
- `full_history_sampling_variance_1.tex` and `_2.tex`: main-study MC variance
  diagnostics for outcomes at times 2 and 3.
- `full_history_diagnostic_variance.tex`: separately labeled single-sieve
  precision and ridge-sensitivity diagnostics.
- `full_history_diagnostics.csv`: all 48 cells, including MC variance, RMS SE,
  variance ratios, bias and its MCSE, and all three coverage calculations.
- `full_history_verification.json`: input SHA256 hashes and verification counts.

Use `--output /path/to/manuscript` to select another output directory. The
tables require the LaTeX `booktabs` package. These are simulation diagnostics:
the MC SD is the sampling SD of an individual estimate, not its Monte Carlo
standard error; the same replications estimate variance/bias and assess
coverage. They are not feasible alternative confidence intervals for real data.

## Saved results and distinct diagnostic specifications

| Study | Replications per mechanism/sample size | Saved results |
| --- | --- | --- |
| Primary ensemble, n = 500, 1,000, 4,000, 10,000 | 100 | [Assessment and estimates](../results/full-history/ensemble-grid-v5-cm9030-github/ASSESSMENT.md) |
| Single sieve, ridge 0.001, n = 10,000 | 500 | [Precision diagnostic](../results/full-history/diagnostic500-v5-cm9030-github/ASSESSMENT.md) |
| Single sieve, ridge 0.00001, n = 10,000 | 100 | [Matched ridge sensitivity](../results/full-history/sensitivity-ridge1e-5-v5-cm9030-github/ASSESSMENT.md) |

Each directory contains `estimates.csv`, `summary.csv`, `failures.csv`, and
the recorded specification. Seeds overlap across specifications; these studies
must not be pooled or counted as independent additional replications.
[Matched comparisons](../results/full-history/ensemble-grid-v5-cm9030-github/PAIRED_SPECIFICATIONS.md)
use the same first 100 seeds. The single-sieve diagnostic and sensitivity
were frozen at commits `bb8a0079f3339f4f73b5656e9ffd9c9cfec40a55` and
`a24fd2d5fe40171cfd15c4fb9b52dc89b7606912`, respectively.

At n >= 4,000, main-study absolute bias is below 0.0031. Coverage varies across
cells; the 500-replication single-sieve diagnostic confirms numerical-dose
undercoverage. Lower ridge increases reported SEs without establishing restored
95% coverage. The appendix reports the MC variance diagnostics without changing
the primary intervals or combining these distinct nuisance specifications.

## Repeat the statistical fits

For the original main fitting sources, check out commit
`b609625bb401e4bb6b8c6742eeea98e1ae48e3f5` in a separate checkout. R 4.5.2 was
used by the saved GitHub workflow. From that checkout's repository root:

```sh
export R_LIBS_USER="$PWD/.runtime/full-history-library"
Rscript studies/full-history/install.R
FH_LIBRARY=ensemble-grid FH_FIRST=1 FH_LAST=100 FH_N=1000 \
  FH_MECHANISM=binary FH_OUTPUT=work/reproduce-full-history-binary-n1000 \
  Rscript studies/full-history/run.R
Rscript studies/full-history/report.R work/reproduce-full-history-binary-n1000
```

Repeat for both mechanisms and all four sample sizes, using distinct output
directories. The workflow provides a sharded alternative; use the matching
frozen source commit for an exact protocol reproduction. Estimator fitting can
be expensive. The install script checks the archived package MD5 values and
versions before fitting. No new simulation fits are needed to reproduce the
manuscript tables.
