# Frozen full-history package sources

The current manifest installs cmbridge 0.3.0.9030 from idiazst/cmbridge commit
e772812c68a05e5072bae9fb323b1f4d4cc249c7, and lmtp 1.6.0.9025 from
idiazst/lmtp commit d6bd64d (full-history-adjustment).

Historical archives are preserved:

- 1.6.0.9023: original pilot and original full-ensemble benchmark.
- 1.6.0.9024: corrected measured-history retention, equivalent-nuisance reuse,
  the 80-dataset corrected pilot and the 100-replication diagnostic expansion.
- 1.6.0.9025: additionally evaluates alpha and t with current health hidden and
  current measurement set to zero. The constant-alpha, treatment-only
  continuation rules in these DGPs give the same policy values under this
  safeguard. The cache signature includes the implementation version.

Each run checks archive hashes and records the exact package versions and study
source fingerprints. Different nuisance specifications and source versions are
reported separately. The original ensemble uses SL.saturated_l1_cv; the
ensemble-grid specification uses three existing positive-L1 wrappers plus the
mean with ordinary SuperLearner CV. Conditional-moment ensemble loss and tuning
are unchanged in ensemble-grid.


The preserved cmbridge 0.3.0.9029 archive is the source of the historical pilots
and diagnostic100 run. Version 0.3.0.9030 adds finite coordinate starting values
and a short initial unrestricted BFGS pass before a full-budget fallback.
Original objectives, penalties, links and gradient acceptance checks are kept.
The full cmbridge suite and the observed-history and full-history lmtp checks
pass; R CMD check reports only the existing closure-binding NOTE in cmbridge.
