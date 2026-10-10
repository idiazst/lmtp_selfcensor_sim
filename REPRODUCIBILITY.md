# Reorganization verification

October 10, 2026. Repository organization preserves the statistical functions.

- cmbridge unit tests and all four numerical recovery checks pass. Its package
  check has no errors or warnings (one existing note). GitHub validation passed.
- lmtp unit/integration tests pass, including supplied/shared splits and nuisance
  fitting inside training samples. Its Rd usage was repaired after package
  checking identified a missing documented argument.
- All current study R sources parse. Discrete support, missingness, required DGP
  assumptions, and independently enumerated truths pass the study setup checks.
- The complete longitudinal report was rebuilt from all 1,200 checkpoints,
  including the 23 failed datasets. Its numerical-dose undercoverage is retained.

A fresh reproduction of `both-n1000-r001` generated all bridge and 50-imputation
standard-lmtp fits. Its four estimates, standard errors, and both confidence
limits match the original checkpoint exactly (maximum absolute difference 0).
Input and imputation hashes, shared folds, support assertions, interior penalty
choices, EIF reconstruction, and independent Rubin pooling checks pass.
The maximum reconstructed EIF difference is 4.44e-16 and the maximum estimate
reconstruction difference is 1.90e-9, within the existing 1e-8/1e-7 tolerances.
This is a reproducibility check of one dataset, not an additional coverage study.

That fresh attempt initially reached a validator restricted to the fourth
scenario. The saved fits and failure log were retained. Generic validation and
report generation were repaired and rerun without changing or refitting the
numerical objects; Mac and Linux graphics devices are selected appropriately.
The fresh launcher now freezes these generic postprocessing entry points.

Current code and results contain only the latest longitudinal and imputation
studies. Older implementations/results were removed from the active repository
trees. Git histories are retained. The active fourth-scenario MI extension uses
unchanged frozen sources and remains owned by its separate simulation chat.
