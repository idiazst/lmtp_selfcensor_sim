# Equal-bias scenario implementation check

The calibrated four-dataset pilot finished all fits on October 10, 2026.
All 400 completed-data standard lmtp calls returned successfully, as did all
eight bridge estimates. Independent validation found zero imputation stream
reconstruction error, maximum EIF reconstruction error 4.44e-16, and minimum
saturated support cell count 10. Mean MI Monte Carlo SE / total SE was 8.6%,
with maximum 9.3%. The pilot is an implementation check, not an assessment of
empirical bias or coverage.

An overlapping repository reorganization moved the private library after fitting
and before validation. The first validation invocation therefore could not load
digest. Restoring the library compatibility symlink fixed this path issue. No
datasets or fitted estimates were replaced or refitted. The independent data
regeneration check also passed for all four datasets.

Before main, this source moved to lmtp_selfcensor_sim/studies/imputation/neither,
and outputs moved to results/imputation/neither in the same repository. Main
will run entirely from canonical paths and the unchanged .runtime/library.
The coordination chat owns package/repository work and is leaving these sources,
results, and the private library untouched while main runs.

The only changes after the successful pilot are path defaults, frozen-archive
checks from scripts/setup.R, additional data-regeneration validation, and combined
report publication. Statistical function bodies, DGP coefficients, tuning,
imputation, and pooling are unchanged. The final combined report includes the
original 1,200 unchanged checkpoints and 400 new checkpoints.
