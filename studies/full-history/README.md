# Full-history adjustment study

This extension implements the full-history method in the current manuscript's
`latex/v2/full_main.tex`, using `lmtp_full_history()` in the same lmtp package
as the observed-history `lmtp_bridge()` estimator. It uses the conditional-moment
bridge and adjoint implementations from idiazst/cmbridge. Earlier observed-history
studies and their package pins remain unchanged.

The primary design has two follow-up outcomes, binary treatment and four-level
numerical dose, and n = 500, 1000, 4000 and 10000. The main study uses estimated
nuisances: the sieve/Landweber/PMMR ensembles, inverse-logit bridges, unrestricted
adjoints, positive-penalty training CV, saturated L1 and mean SuperLearners,
three outer person folds and shared inner person folds, and logistic TMLE and
SDR. Both policy ratios are fitted by classification. The continuation law is
Bernoulli(.35) for binary treatment and Uniform{0,1,2,3} for dose. Alpha is zero.
The visit policy sets binary treatment to one or increases dose by one, capped
at three. Retained states are first-order Markov (k=1).

The current latent health affects treatment decisions at visits, making the
full-history adjustment relevant. Visits depend on the current latent health
and previous health. They have no direct effect on later health or later visits;
treatment is known at no-visit times. The independent errors satisfy sequential
randomization and the treatment shadow exclusions. Treatment and visit laws have
strictly positive support. The finite-support gradient check explicitly solves
each target-specific adjoint equation; it checks the nonzero mixed second-order
bridge remainder. Exact causal truth is calculated by forward enumeration and
verified against the independent backward bridge functional. Truth is never
passed into an estimator.

A separate `sieve-diagnostic` pilot fits the same estimator with a single
positive-ridge sieve and a positive-L1 regression/classification learner. It
checks coding and inference at much lower computational cost. This diagnostic
is labeled separately and is not pooled with the ensemble study. The initial
GitHub push runs 20 replications at n=500 and 4000 for both mechanisms, retaining
both outcomes and methods (80 datasets; 320 method/horizon estimates).

The `Full-history adjustment simulation` GitHub Actions workflow installs the
frozen source archives in `dependencies/full-history/`, checks their hashes,
runs the exact population validations, fits the study, and uploads checkpoints
and reports. It runs independently of the local computer. All errors and missing
checkpoints are counted; failed seeds are never replaced. Individual checkpoints
record package versions, source fingerprints, seeds, run ID, warnings, score
components, maximum weights and targeting diagnostics.

For an ensemble run, dispatch `.github/workflows/full-history.yml` on branch
`full-history-adjustment` with `library=ensemble`, the desired replication count,
and comma-separated sizes. Each ensemble runner fits one replication. Set `first` to create consecutive
cohorts without repeating seeds. Split large
studies into cohorts to stay within GitHub's 256-job matrix limit. Use new output
directories and immutable source archives after any implementation change.

For a local check using the pinned library:

```sh
Rscript studies/full-history/install.R
FH_LIBRARY=sieve-diagnostic FH_FIRST=1 FH_LAST=2 FH_N=1000 \
  FH_OUTPUT=work/full-history Rscript studies/full-history/run.R
Rscript studies/full-history/report.R work/full-history
```

The ensemble library can be expensive because each bridge, response ancestor,
SuperLearner weight and adjoint loading is rebuilt inside its training split.
Identical training fits are reused between SDR and TMLE through a validated
training-data signature. Descendant CV retains three groups when at most 32
complete measured transitions remain, preventing the original 17-observation
bridge failure without weakening its convergence checks.

All randomizer classification samples are fresh independent draws; regression
integration uses the known-law midpoint nodes. For a continuous continuation
law use a matching continuous `randomizer` and check quadrature accuracy.
