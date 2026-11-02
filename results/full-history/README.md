# Full-history simulation results

`pilot-v1-github/` is the initial 80-dataset single-sieve diagnostic, run
41378099245 with lmtp 1.6.0.9023. One binary n=500 dataset failed for both methods
because a deep 17-observation bridge fit did not pass its inverse-link
convergence check. Its original errors remain in the saved results.

`pilot-v2-github/` repeats the identical 80 dataset seeds with lmtp 1.6.0.9024.
Retaining three descendant groups when measured transitions are scarce recovers
that seed without changing convergence criteria. All 80 datasets return both
methods and both horizons (320 estimates; zero failures). At n=4000, absolute
bias is below .008 in every mechanism/method/horizon cell. The 20-replication
coverage estimates are preliminary; the 100-replication expansion assesses them
more reliably.

`three-time-v4-github/` is the separate three-treatment-time MNAR stress check
(run 41380534156). It permits return after missed earlier health, exercises the
nonterminal adjoint loading on a depth-one regression, passes the Linux package
tests, and solves every TMLE score equation. This single-dataset stress check is
not a coverage study.

Full-ensemble benchmarks, the 100-replication diagnostic expansion and the
latest callback-context checks run separately on GitHub. Do not combine
checkpoints from different source or nuisance specifications. Each compact
report includes attempted, returned and failed counts. Individual checkpoint
jobs remain in GitHub artifacts and ignored local jobs directories.
