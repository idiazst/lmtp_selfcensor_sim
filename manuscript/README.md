# Reproduce the manuscript simulations

This directory connects each simulation subsection to its generating code,
fitting code, saved results, and reproduction commands.

| Manuscript subsection | Guide |
| --- | --- |
| Longitudinal treatment effects under informative missingness | [Longitudinal study](longitudinal.md) |
| Treatment effects under full-history adjustment | [Full-history study and MC variance diagnostics](full-history.md) |
| Comparison with MAR | [Four-scenario comparison](mar.md) |

## Rebuild the tables and figure from saved results

From the repository root, with Python 3 and Rscript available:

```sh
python3 manuscript/scripts/build_simulation_section.py
python3 manuscript/scripts/build_full_history_section.py
```

This command needs only the Python standard library and base R. Ghostscript,
if installed, is used for optional PDF font processing. It does not fit any
statistical models or modify any simulation result file.

The second command uses only the Python standard library. It separately
verifies all 8,000 full-history estimate rows across 48 cells, then writes the
primary results and Monte Carlo sampling-variance tables, the numerical CSV,
and an input-hash audit. See the [full-history guide](full-history.md) for the
frozen estimator sources, distinct specifications, and output filenames.

Before writing output it checks all 64 reported simulation cells against the
saved individual estimates: means, bias, MSE, and interval coverage. For the
longitudinal study it also checks empirical SD, mean SE, variance ratios,
simultaneous coverage, coverage using Monte Carlo sampling variance before
and after subtracting mean bias, unique replication IDs, and the reconciliation of
3,958 successful datasets and 42 failures with the 4,000-dataset design.

Outputs are written to:

- `manuscript/simulation_tables/longitudinal.tex`: both longitudinal outcome times.
- `manuscript/simulation_tables/mar.tex`: all four MAR/shadow scenarios.
- `manuscript/simulation_tables/variance.tex`: variance and curve-coverage results.
- `manuscript/simulation_tables/sampling_variance.tex`: coverage using Monte Carlo sampling variance, with and without mean-bias subtraction.
- `manuscript/simulation_tables/verification.json`: checks and input SHA256 hashes.
- `manuscript/figures/simulation-longitudinal.pdf` and `.png`: final-outcome plots.

The `early-summary` directory name is historical: its saved longitudinal
results now contain all 500 replications per setting. Earlier simulation
runs and selected-dataset diagnostics are not pooled into the manuscript
tables. Failed fits and estimates with large errors remain included in the
reported counts and calculations.

To repeat the statistical fits rather than rebuild their summaries, follow
the study-specific guides above. Both use the package archives and hashes in
the [dependency manifest](../dependencies/package-pins.json).
