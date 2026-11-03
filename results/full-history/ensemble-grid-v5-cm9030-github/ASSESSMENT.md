# Completed full-history ensemble validation

[Main GitHub run 41460347711](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41460347711)
completed successfully from frozen commit
`b609625bb401e4bb6b8c6742eeea98e1ae48e3f5`. All 800 datasets and 3,200
method/horizon estimates returned, with no failures or replacement seeds.
Every mechanism/sample-size/method/horizon cell has all 100 planned replications.
The fitting specification is `ensemble-grid`, with lmtp 1.6.0.9025 and cmbridge
0.3.0.9030. Both policy ratios, the bridges, adjoints and regressions are estimated.

The new `lmtp_full_history()` API implements the manuscript's full-history
adjustment alongside the observed-history estimator, with separate alpha,
visit d and stochastic continuation t callbacks, pseudo-outcomes at every time,
and both SDR and logistic TMLE. The original observed-history work is preserved.

## Bias and large-sample inference

At n>=4000, the largest absolute bias over all cells is .003016. At n=10000,
absolute bias is below .00190 for binary treatment and .000433 for numerical
dose. In the n=500 dose first-horizon cell, bias is .01576/.01590 (SDR/TMLE),
about 2.8 bias MCSEs. The small-sample bias is therefore not uniformly negligible.

| Mechanism | Method | Horizon | Bias | Bias MCSE | Empirical SD | RMS reported SE | Coverage | Pointwise 95% coverage MC interval |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Binary | SDR | 1 | -.001202 | .001423 | .014234 | .013082 | .93 | [.863, .966] |
| Binary | TMLE | 1 | -.001230 | .001422 | .014219 | .013080 | .92 | [.850, .959] |
| Binary | SDR | 2 | -.001900 | .001726 | .017257 | .017575 | .95 | [.888, .978] |
| Binary | TMLE | 2 | -.001819 | .001728 | .017278 | .017545 | .95 | [.888, .978] |
| Dose | SDR | 1 | .000401 | .001322 | .013222 | .012422 | .92 | [.850, .959] |
| Dose | TMLE | 1 | .000432 | .001323 | .013231 | .012421 | .92 | [.850, .959] |
| Dose | SDR | 2 | -.000105 | .001749 | .017492 | .016205 | .95 | [.888, .978] |
| Dose | TMLE | 2 | -.000083 | .001741 | .017412 | .016197 | .94 | [.875, .972] |

All rows in this table use n=10000 and 100 replications. Monte Carlo intervals
measure simulation uncertainty; they do not change estimator intervals. Their
inclusion of .95 does not establish nominal calibration. At n=10000, dose RMS
SE is about 6% below empirical SD at horizon 1 and 7% below at horizon 2.
Binary first-horizon RMS SE is about 8% low; second-horizon SE agrees closely
with empirical SD. The precision of these comparisons is limited by 100 draws.

Across all 32 cells, coverage ranges .90-.98. Dose n=1000 second-horizon
coverage is .91/.90, with RMS SE about 16% below empirical SD. The TMLE Wilson
interval [.826,.945] excludes .95. Both methods' SE-calibration MC bootstrap
intervals have upper limits below 1 in that cell. Conversely, binary n=4000
second-horizon SE is about 20% above empirical SD, with MC calibration limits
above 1 and .98 coverage. A common empirical interval multiplier would not
address this varying pattern and was not used.

## Matched diagnosis across nuisance specifications

The completed precision diagnostic has 500 replications per mechanism at
n=10000 and fixed single-sieve ridge .001. Its dose coverage .912-.924 has
upper pointwise 95% MC limits below .95; RMS SE is about 9% below empirical SD.
That provides evidence of undercoverage for that specification beyond MC noise.
It is not pooled with this ensemble.

The positive-ridge sensitivity changes the single-sieve bridge and adjoint
ridge to 1e-5 and retains other settings. On its matching 100 dose seeds, RMS
SE rises about 6.2%/5.4% across horizons. Coverage stays .92 at horizon 1 and
rises .91 to .94 at horizon 2 (three gained intervals, none lost; paired change
MCSE .0171). This identifies a regularization contribution, without resolving
nominal coverage or isolating bridge from adjoint regularization.

The final ensemble comparisons in `PAIRED_SPECIFICATIONS.md` use the matching
first 100 seeds of each diagnostic, not all 500 as independent comparators.
Compared with the .001 diagnostic, ensemble dose RMS SE is about .5%/.9%
higher across horizons; first-horizon coverage is the same .92. At horizon 2,
four SDR intervals and three TMLE intervals gain coverage, with none lost.
These small discordant counts limit inference about coverage differences.
Compared with the 1e-5 diagnostic, ensemble dose SEs are about 5%/4% lower.
The same specifications can have materially different SEs on the same datasets;
this cannot be diagnosed by counting them as additional independent samples.

## Numerical and mathematical checks

The reported score variance equals sequential variance plus bridge-correction
variance plus twice their covariance, with maximum relative error 8.2e-15
over all 3,200 estimates. This validates variance assembly, not finite-sample
calibration. The independent exact tangent audit passes 232 comparisons across
58 generative-law directions and both horizons, with maximum derivative error
below 3.2e-11. The tested gradient is observable and mean-zero. No new estimator
formula or optimizer defect was isolated by these completed studies.

The retained earlier small-sample optimizer failure was fixed and covered by a
regression fixture. Current package checks pass: 62 new full-history checks,
182 existing bridge checks, 181 other relevant lmtp checks, and 416 cmbridge
checks. The three-treatment-time Linux stress check also passed. Historical
failures and frozen archives remain available; no failed seed was replaced.

## Assessment and limits

Implementation and the three specified GitHub study protocols are complete.
The implementation passes the mathematical, numerical, leakage and regression
checks that were run, with no current study fitting failures and small
large-sample bias. Uniformly nominal confidence-interval coverage has not been
established. The diagnosed regularization sensitivity does not fully resolve
that limitation. Both package PRs remain drafts, with this limitation explicit.
No additional estimator change is claimed or justified solely by a nominal
coverage line falling inside a 100-replication MC interval.

No known nuisance function was supplied to a fitted estimator, bridge clipped,
convergence criterion relaxed, failure replaced, or interval empirically
rescaled. Paper LaTeX, unrelated observed-history work, and user manuscript
edits were preserved. Further changes to nuisance fitting or inference require
a separately specified statistical intervention and fresh validation.

## Reproduction

The complete original `full-history-report` artifact is downloaded into this
new directory. `diagnose.R`, `plot-inference.R` and `compare-specifications.R`
were run locally after download; no estimator was refitted. Figures were
visually inspected. CSVs retain all estimates, failure counts, MC uncertainty,
paired seed comparisons and score components. `SPECIFICATION.txt` and the
original manifest record the frozen fitting sources and settings.
