# Full longitudinal simulation: completed

All **4,000 planned datasets** have returned: binary treatment and numerical
dose 0–3, n=500, 1,000, 4,000 and 10,000, with **500 replications per setting**.
There are 3,958 successful datasets and 42 datasets with recorded estimator
failures; every failure remains counted, without replacement. No fitting remains
pending. Both SDR and logistic TMLE and both follow-up outcomes are reported.

[Complete tables, scaled bias/MSE, variance diagnosis and graphs](early-summary/REPORT.md)
now use all 500 replications. [The multiplier-bootstrap check](multiplier-bootstrap/REPORT.md)
also uses the full study, with 9,999 +1/-1 and exponential-weight draws per
returned dataset and exact Gaussian intervals. No original simulation, nuisance
fit, penalty choice, estimator or package was rerun or changed for that analysis.

One original GitHub runner lost communication before uploading replication158.
Its failure remains visible in the [first cohort](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/38488063211).
[The second cohort](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/38488067067)
completed successfully. The missing eight datasets were recovered in the
[separate one-worker run](https://github.com/idiazst/lmtp_selfcensor_sim/actions/runs/38903833946),
using identical numerical sources, archives and seeds. All 500 uploaded artifacts,
4,000 checkpoint hashes, seed mappings and frozen fitting fingerprints pass.
Do not rerun the failed original job: its eight datasets have already returned.

The source of the two initial cohorts was commit7035f2a0f74ff1662da521f54d67eb8404546f84;
the recovery used a0fcaebf31403c2a2a35e6aacce31aed473c7fff with only reporting changes.
The original cmbridge0.3.0.9020 and lmtp1.6.0.9021 archives, positive penalty CV,
U-statistic with PSD projection, candidate libraries, one-step bridge correction,
and shared training-only splits are unchanged. No known-function estimator,
zero-penalty simulation or Gaussian mean update was introduced.

[Verification snapshot](PROGRESS-SNAPSHOT.json), [full plan](../../../studies/longitudinal/github-500/PLAN.md),
[design](design.csv), [true parameters](truth.csv), [source hashes](source-manifest.json),
and [launch records](launch.json). No scheduled messages or automations were started.
