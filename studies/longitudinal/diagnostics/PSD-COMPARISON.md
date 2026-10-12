# Numerical-dose PSD comparison

100 prespecified datasets, each n = 4,000, seeds 5203001–5203100. The original
numerical-dose mechanism has missingness at both follow-ups. All four nuisance
function libraries use their original specifications. Both SDR and logistic
TMLE receive the one-step bridge/adjoint correction.

The two versions differ only in projecting the U-statistic ensemble Gram to PSD.
Without projection, the three-candidate weights globally minimize the raw
quadratic over the simplex by enumerating all faces. Every bridge and adjoint
ensemble, including descendant response fits, uses the assigned version.
Candidate penalty CV remains the original raw U-statistic RKHS criterion with
positive extendable grids. No experimental Robins, discrepancy, GCV, L-curve or
quasi-optimality rules are used. Landweber and PMMR retain their original controls.

Data, original outer/learner splits, nested training-only splits and random seeds
are shared. Candidate fits are fresh for each dataset. Descendant bridge candidates
are shared across projection versions only after verifying data/library signatures
and all recorded split assignments; their raw ensemble weights are recomputed
globally. Outer nuisances and sequential regressions are refitted. Candidate predictions,
penalty histories, fold labels and raw ensemble Grams are compared across versions.
Sequential outcome regressions must be refitted because their bridge responses
change when the ensemble weights change.

Report pointwise and joint coverage, bias, Monte Carlo uncertainty, empirical SD,
estimated SE, interval length, paired changes and failures for both follow-ups.
Evaluate bridge/adjoint defining equations on the exact finite DGP population.
Reference-function plots use held-out predictions; the adjoint reference can be
nonunique, so defining-equation errors are the primary adjoint recovery criterion.
Truth is used only for evaluation, not fitting or penalty selection. No known-function
estimator simulation, zero-penalty simulation or Gaussian mean update is included.

Run from the simulation repository using the isolated `.runtime/psd-balanced-library`:

```sh
PSD_PREPARE_ONLY=true Rscript studies/longitudinal/diagnostics/run_psd_comparison.R
PSD_TASKS=1 Rscript studies/longitudinal/diagnostics/run_psd_comparison.R
python3 studies/longitudinal/diagnostics/run_psd_workers.py --workers 8
```

Each dataset/version checkpoint is atomic and resumable. Preserve all failed fits
and use their actual denominators; do not replace or selectively retry them.
The canonical output is `results/longitudinal/psd-numerical-n4000-v2`.
The final report includes both follow-ups, paired changes, recovery equations,
EIF means, weights and scientific graphs. Fitting versions are cmbridge
0.3.0.9029 and lmtp 1.6.0.9022 in the separate comparison library; the original
completed-study dependencies remain unchanged. The fresh/reweighted bridge
check and exact response-cache signature check are in `verify_psd_reweight.R`.
Reused fits save computation; raw versus PSD worker times are not a direct
benchmark of the weight optimizer alone.

The raw optimizer balances each simplex face separately so an enormous unused
candidate cannot erase meaningful curvature among other candidates. This is a
numerical correction to the same raw objective; the PSD optimizer is unchanged.
Each raw ensemble must score no worse than PSD weights on its identical raw Gram.
Prior recorder and unbalanced-optimizer attempts remain under ignored .runtime.
