# Exact influence-function tangent validation

This analytical audit calls no fitted estimator and changes no study fits.
It compares forward causal derivatives with E[D * observed-law score].
The observed-law score marginalizes every unrecorded health value.
Separate logit tilts cover baseline health, each treatment/state cell,
each health transition cell and each visit-transition cell.
Visit tilts preserve the treatment shadow exclusions. Policies stay fixed.
Both horizons are checked at finite-difference steps 1e-5 and 5e-6.

232 comparisons across 58 generative-law directions; maximum error 3.14e-11.
Maximum observed-data measurability error: 0.
The population variances also agree with the separate existing reference calculation.
These checks validate formulas on this finite-support family; they do not prove
finite-sample nuisance fits or confidence interval calibration.

Validator MD5: 1d350bebf4d5a276fe56f98ed44d4d32
DGP source MD5: 80b62d7f9ba6a3e0dd889cbe0bb8bf8d
