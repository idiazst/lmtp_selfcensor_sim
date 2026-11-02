# Frozen full-history package sources

The current manifest installs cmbridge 0.3.0.9029 from idiazst/cmbridge commit
57b3ee2c2a9ead38d9a8b4c662ec2bc6900df2b1, and lmtp 1.6.0.9025 from
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
