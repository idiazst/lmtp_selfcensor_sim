# Full-history inference diagnostics

Specification: sieve-diagnostic

Bias MCSE is empirical SD divided by the square root of returned replications.
RMS SE is sqrt(mean(reported SE squared)); its ratio to empirical SD compares variances.
Coverage MC limits are pointwise 95% Wilson intervals over returned replications.
They describe simulation uncertainty and do not change any estimator interval.
Cells share datasets across horizons and methods; these are not simultaneous tests.
Failure counts are retained. Coverage describes the returned estimates only.

Largest relative difference between n * SE^2 and Var(sequential + bridge correction): 1.1e-14.

 mechanism     n method horizon attempted returned failed      bias bias_mcse
    binary 10000    sdr       1       500      500      0 0.0004836 0.0006094
      dose 10000    sdr       1       500      500      0 0.0013029 0.0006101
    binary 10000   tmle       1       500      500      0 0.0004978 0.0006090
      dose 10000   tmle       1       500      500      0 0.0013141 0.0006102
    binary 10000    sdr       2       500      500      0 0.0005704 0.0007853
      dose 10000    sdr       2       500      500      0 0.0017352 0.0007854
    binary 10000   tmle       2       500      500      0 0.0006119 0.0007836
      dose 10000   tmle       2       500      500      0 0.0017379 0.0007848
 empirical_sd  rms_se rms_se_over_sd coverage coverage_mcse coverage_mc_low
      0.01363 0.01287         0.9448    0.940       0.01062          0.9156
      0.01364 0.01237         0.9068    0.914       0.01254          0.8862
      0.01362 0.01287         0.9452    0.938       0.01078          0.9133
      0.01364 0.01237         0.9066    0.912       0.01267          0.8839
      0.01756 0.01738         0.9898    0.942       0.01045          0.9179
      0.01756 0.01596         0.9089    0.924       0.01185          0.8974
      0.01752 0.01735         0.9901    0.946       0.01011          0.9226
      0.01755 0.01595         0.9091    0.922       0.01199          0.8951
 coverage_mc_high interval_below_truth interval_above_truth standardized_mean
           0.9577                0.018                0.042           0.07083
           0.9355                0.024                0.062           0.13609
           0.9560                0.018                0.044           0.07192
           0.9338                0.024                0.064           0.13702
           0.9593                0.022                0.036           0.03636
           0.9441                0.028                0.048           0.12647
           0.9626                0.022                0.032           0.03893
           0.9424                0.030                0.048           0.12682
 standardized_sd
           1.062
           1.111
           1.062
           1.111
           1.014
           1.102
           1.014
           1.102

## Provenance

Fitting run IDs: 41488034067
Estimates MD5: e1238f43864d49b7950d62bc18884786
Audit source MD5: b9f3c44aac2095eb63e54b38f91da502
