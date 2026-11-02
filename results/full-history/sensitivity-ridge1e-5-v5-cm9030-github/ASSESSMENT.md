# Completed matched positive-ridge diagnosis

[GitHub run 41516749627](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/41516749627)
completed all 200 datasets and 800 method/horizon estimates without failures.
There are 100 replications per binary/dose mechanism at n=10000. Source commit:
`a24fd2d5fe40171cfd15c4fb9b52dc89b7606912`; lmtp 1.6.0.9025 and cmbridge
0.3.0.9030. All nuisances are estimated.

The single-sieve bridge and adjoint penalties are both positive ridge 1e-5,
compared with .001 in the reference. Other libraries, folds, losses, convergence
criteria and intervals match. Package archives are unchanged. The reference is
only the matching first 100 seeds per mechanism from run 41488034067. The full
500-replication reference is reported separately; overlapping seeds are never
counted as independent additional datasets.

## Results

| Mechanism | Method | Horizon | Bias | Bias MCSE | Empirical SD | RMS SE | Coverage | Pointwise 95% coverage MC interval |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Binary | SDR | 1 | -.001218 | .001430 | .01430 | .01324 | .93 | [.863, .966] |
| Binary | TMLE | 1 | -.001242 | .001428 | .01428 | .01324 | .93 | [.863, .966] |
| Binary | SDR | 2 | -.001798 | .001717 | .01717 | .01759 | .95 | [.888, .978] |
| Binary | TMLE | 2 | -.001721 | .001721 | .01721 | .01756 | .95 | [.888, .978] |
| Dose | SDR | 1 | .000079 | .001378 | .01378 | .01312 | .92 | [.850, .959] |
| Dose | TMLE | 1 | .000109 | .001380 | .01380 | .01312 | .92 | [.850, .959] |
| Dose | SDR | 2 | -.000612 | .001788 | .01788 | .01692 | .94 | [.875, .972] |
| Dose | TMLE | 2 | -.000609 | .001778 | .01778 | .01691 | .94 | [.875, .972] |

The lower ridge increases dose first-horizon RMS SE by about 6.2% and second-
horizon RMS SE by about 5.4%. Mean paired SE changes are .000758 (MCSE .000010)
and .000858 (MCSE .000016). Mean paired point-estimate changes are about
-.000644 and -.000783, respectively. These changes exceed their Monte Carlo
uncertainty, demonstrating a regularization contribution to reported precision.

Dose first-horizon coverage stays .92 on the same seeds: none changes coverage.
Second-horizon coverage rises from .91 to .94 for both methods: three intervals
gain coverage and none loses it. The paired .03 change has MCSE .0171 and does
not establish restored nominal coverage. No discordance in the first-horizon
comparison is evidence about the observed pairs, not proof of equivalence.

Dose RMS SEs remain about 5% below empirical SD. With only 100 replications,
SE-calibration bootstrap intervals and coverage MC intervals include their
nominal values. This is insufficient to declare calibration resolved. The
binary first-horizon coverage changes only .92 to .93; its second horizon
stays .95. The main ensemble uses a separately recorded cross-validated library
and remains under assessment.

## Score diagnosis and limits

For dose, the mean reported gradient variance increases about .194 at horizon 1
and .285 at horizon 2. Bridge-correction variance increases about .197 and .292,
and twice its covariance with the sequential score increases about .019 and
.058, partly offset by sequential-variance decreases about .023 and .066.
Changing both ridge penalties does not isolate the bridge fit from the adjoint
fit. These component comparisons are paired by dataset.

The internal score variance identity passes with maximum relative error
9.1e-15. It verifies variance assembly, not repeated-sampling calibration.
The independent exact tangent audit in the completed precision diagnostic
passes 232 derivative comparisons with error below 3.2e-11; no estimator
formula defect has been isolated in the tested family.

No bridges were clipped, known nuisance functions supplied to fitted estimators,
failed seeds replaced, convergence criteria loosened, or confidence intervals
rescaled. This sensitivity is a diagnosis of the fixed-ridge specification,
not a package-code fix or evidence of uniformly nominal coverage. Its remaining
coverage uncertainty must be kept explicit in the final validation assessment.

## Reproduction

The original `full-history-report` artifact was downloaded into this new result
directory. `diagnose.R`, `compare-ridge.R` and `plot-inference.R` were run after
download. Their CSVs retain individual estimates, failures, Monte Carlo
uncertainty, paired comparisons and score components. The PNG/PDF figures show
coverage, bias and SE calibration without changing estimator intervals.
