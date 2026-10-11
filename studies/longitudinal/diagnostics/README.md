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
