# PSD versus no PSD: run in progress

Started October 12, 2026 at 16:31 EDT on eight local workers. The plan is
100 paired numerical-dose datasets, each n = 4,000, with seeds 5203001–5203100.
Both SDR and logistic TMLE use the one-step bridge correction. The only
statistical change between versions is the ensemble Gram's PSD projection.
Candidate penalties use the original positive training-only U-statistic CV.

No final coverage or bias results are available at launch. Based on measured
previous dataset times, the estimate is about 7–8 hours from this restart,
subject to slower datasets and failures. The local supervisor writes
REPORT.md, tables and scientific graphs after all 200 checkpoints exist.
Results are published only after verification; this page is a launch record,
not a live count or a completed simulation report.

The prior recording attempt and 16-pair attempt are preserved locally under
ignored .runtime. The latter exposed an error in the raw optimizer when an
unused candidate had enormous residuals. The corrected solver balances each
simplex face separately while evaluating the same raw objective. Every paired
raw fit must score no worse than the PSD weights on its identical raw Gram.
No seeds were selected by their estimates or coverage.

The cmbridge correction is [57b3ee2](https://github.com/idiazst/cmbridge/commit/57b3ee2c2a9ead38d9a8b4c662ec2bc6900df2b1),
which [passed GitHub validation](https://github.com/idiazst/cmbridge/actions/runs/38304759471).
lmtp uses [e463e85](https://github.com/idiazst/lmtp/commit/e463e85bea6b7cdb1c4f5399656a3765f7996eae).
Frozen fitting sources are recorded in [source-manifest.json](source-manifest.json);
the [design](design.csv), [DGP assumption checks](dgp-assumptions.csv), and
[original specification](original-specification.rds) are saved alongside it.
The original completed studies and their frozen dependencies remain intact.
