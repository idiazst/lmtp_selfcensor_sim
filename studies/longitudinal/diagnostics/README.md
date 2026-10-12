# Bridge and adjoint fits at two selected data seeds

This diagnostic was requested October 11, 2026. It uses the numerical-dose
longitudinal DGP with both follow-ups missing and the frozen study libraries.
The lowest pointwise coverage was 82.4% for the final-outcome SDR at n=1,000.
Among the 199 successful n=4,000 SDR datasets, select the largest absolute final
error (replication 41, seed 5203041) and smallest (replication 167, seed 5203167).
Generate a single dataset from each seed at n=4,000, 10,000 and 50,000.

Run from the simulation repository root:

```sh
DIAGNOSTIC_WORKERS=6 Rscript studies/longitudinal/diagnostics/run_bridge_adjoint.R
Rscript studies/longitudinal/diagnostics/audit_support.R
Rscript studies/longitudinal/diagnostics/verify_bridge_adjoint.R
```

The three original outer folds and balanced three-group learner assignments
are reused at n=4,000, and generated identically at the larger sizes. Bridge and
adjoint fits share assignments. Penalty selection is confined to each training
sample; every plotted individual prediction excludes its outer validation row.
No package is edited. No treatment/outcome regression or final SDR/TMLE estimate
is fitted: exact DGP treatment ratios supply the required adjoint loading in
this isolated diagnostic. This differs from the full study's estimated loading.

The bridge reference is the inverse measurement probability, which belongs to
the prespecified main-effect inverse-expit class and solves its population
moment equation, including histories with a missed previous visit. The adjoint
reference is the previous minimum-Euclidean-norm solution. Exact equations are
checked before any fits. Solutions need not be unique, so population conditional
moment errors accompany distances from the selected reference functions.

Fits are saved per seed/size/follow-up/outer fold and retain warnings, failed
candidates, penalty extensions, ensemble weights and elapsed time. Existing
checkpoints may resume only with the same source/configuration fingerprint.
The plots use all held-out rows; identical coordinates overlap, with no jitter
or truncation. Identical seeds do not imply nested samples because the approved
DGP generates variables in blocks. These six selected datasets do not constitute
a new coverage or convergence-rate study.

Default output: `results/longitudinal/bridge-adjoint-seed-check/`.
Both follow-ups have y=x figures; the report also shows the final-outcome adjoint
conditional equation. Model objects are ignored by Git; tables and compressed
prediction rows are retained for reproducibility.

The last two commands inspect saved fits without refitting. They record
training support, penalty-CV tables, warnings and checkpoint checksums, verify
the complete out-of-sample prediction rows, and add the interpretation to the
report. Their source hashes are separate from the frozen fitting fingerprint.

To check the RKHS loss at the true functions without refitting:

```sh
Rscript studies/longitudinal/diagnostics/check_rkhs_loss.R
Rscript studies/longitudinal/diagnostics/report_rkhs_loss.R
```

This computes exact population losses, replays the original CV criterion,
and evaluates the diagnostic candidate set augmented with the true function.
The [loss report](../../../results/longitudinal/rkhs-loss-check/REPORT.md)
distinguishes the population minimum from the empirical U-statistic and PSD
criteria. No changes to packages or original fitted objects are made.

## U/V ensemble comparison

The opt-in scorer is implemented in cmbridge 0.3.0.9022, published commit
`8d8203061fcb421a070b9ec50874e51d7409ea0b`. Keep the completed
study's `.runtime/library` intact; install that cmbridge version into the
separate `.runtime/statistic-library` before running this diagnostic.

For example, after the repository's usual pinned dependency installation:

```r
dir.create(".runtime/statistic-library", recursive = TRUE, showWarnings = FALSE)
remotes::install_github(
  "idiazst/cmbridge@8d8203061fcb421a070b9ec50874e51d7409ea0b",
  lib = ".runtime/statistic-library", upgrade = "never")
```

```sh
DIAGNOSTIC_WORKERS=6 Rscript studies/longitudinal/diagnostics/run_statistic_comparison.R
Rscript studies/longitudinal/diagnostics/compare_statistic_fits.R
Rscript studies/longitudinal/diagnostics/report_statistic_comparison.R
```

This extends the selected-seed test to the binary and numerical-dose DGPs,
using the largest and smallest absolute realized n=4,000 final-SDR errors for
each DGP, and n=4,000, 10,000 and 50,000 at both follow-ups. At n=4,000 the
original outer and learner assignments are reused. Fresh U/V fits use their
statistic for candidate penalty CV as well as stacking. The saved numerical
U fits are reused with explicit provenance and checkpoint hashes.

A separate comparison keeps the U-tuned candidate predictions and penalties
fixed, changing only the weighting criterion: projected U, globally minimized
raw U, and V. Exact population losses, defining-equation errors, held-out y=x
plots, weights, penalty histories and failures distinguish selection changes
from changes in the candidate fits. The same isolated adjoint loading as the
preceding diagnostic is used; no full causal-estimator or coverage simulation
is run. True functions are used for evaluation, never penalty selection.

Default output: `results/longitudinal/ensemble-statistic-check/`. Override
`STATISTIC_MECHANISMS`, `STATISTIC_TIMES`, or `STATISTIC_OUTPUT` only in a new
output directory so an existing fitting fingerprint is not overwritten.

The completed [comparison report](../../../results/longitudinal/ensemble-statistic-check/REPORT.md)
contains the held-out plots, exact population equation errors and all ensemble
weights. This diagnostic leaves the original completed studies and pins intact.

## Inverse-problem penalty selection, n=4,000

The replacement experimental branch reverts the Robins/Syrgkanis adapters and
compares GCV, L-curve curvature and interior quasi-optimality in the three native
bridge/adjoint candidates. It retains the original RKHS U + PSD ensemble selector,
saved numerical-dose seeds 5203041/5203167, both follow-ups and three original
outer/learner folds. Failed parameter paths and failed candidates are retained.

Install cmbridge commit `4d2c35668e6d09068f9242bef740ddbda1324c5f` (version
0.3.0.9027) into `.runtime/inverse-penalty-library`, after installing the frozen
study dependencies. The full study's library stays separate. From the repository
root run `run_penalty_selection.R` with a disjoint `PENALTY_TASKS` list for each
independent worker, then `report_penalty_selection.R`. `PENALTY_PREPARE_ONLY=true`
freezes the design/manifest, and `PENALTY_PREPARED=true` lets workers reuse it.
All scripts are in this directory; default outputs are
`results/longitudinal/inverse-penalty-n4000`. The shared source fingerprint must
match all checkpoints. Do not combine previous preflight attempts with final
results. This diagnostic computes no new SDR/TMLE estimates or coverage.

`check_penalty_classes.R` verifies bridge class membership and whether any
member of the frozen adjoint classes can satisfy the exact population equation.
It is an evaluation-only range check; it does not select penalties or provide
known-function fits to the simulation. The reporting script runs this audit.
