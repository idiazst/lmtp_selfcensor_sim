# Full-history inference diagnostics

Specification: sieve-diagnostic

Bias MCSE is empirical SD divided by the square root of returned replications.
RMS SE is sqrt(mean(reported SE squared)); its ratio to empirical SD compares variances.
Coverage MC limits are pointwise 95% Wilson intervals over returned replications.
They describe simulation uncertainty and do not change any estimator interval.
Cells share datasets across horizons and methods; these are not simultaneous tests.
Failure counts are retained. Coverage describes the returned estimates only.

Largest relative difference between n * SE^2 and Var(sequential + bridge correction): 5.58e-15.

 mechanism    n method horizon attempted returned failed      bias bias_mcse
    binary  500    sdr       1        20       20      0  0.022335  0.010765
      dose  500    sdr       1        20       20      0  0.022042  0.016696
    binary 4000    sdr       1        20       20      0  0.007309  0.003638
      dose 4000    sdr       1        20       20      0  0.004445  0.004181
    binary  500   tmle       1        20       20      0  0.021695  0.010720
      dose  500   tmle       1        20       20      0  0.023145  0.016711
    binary 4000   tmle       1        20       20      0  0.007509  0.003612
      dose 4000   tmle       1        20       20      0  0.004373  0.004168
    binary  500    sdr       2        20       20      0  0.035448  0.022591
      dose  500    sdr       2        20       20      0  0.008914  0.022346
    binary 4000    sdr       2        20       20      0  0.007465  0.003328
      dose 4000    sdr       2        20       20      0 -0.003087  0.004906
    binary  500   tmle       2        20       20      0  0.029244  0.020950
      dose  500   tmle       2        20       20      0  0.010408  0.020950
    binary 4000   tmle       2        20       20      0  0.007330  0.003329
      dose 4000   tmle       2        20       20      0 -0.002962  0.004851
 empirical_sd  rms_se rms_se_over_sd coverage coverage_mcse coverage_mc_low
      0.04814 0.06098         1.2665     1.00       0.00000          0.8389
      0.07467 0.05518         0.7390     0.80       0.08944          0.5840
      0.01627 0.01999         1.2286     0.95       0.04873          0.7639
      0.01870 0.01963         1.0500     0.95       0.04873          0.7639
      0.04794 0.06052         1.2624     0.95       0.04873          0.7639
      0.07473 0.05508         0.7370     0.80       0.08944          0.5840
      0.01615 0.01997         1.2365     0.95       0.04873          0.7639
      0.01864 0.01963         1.0531     0.95       0.04873          0.7639
      0.10103 0.09939         0.9838     0.90       0.06708          0.6990
      0.09993 0.08661         0.8667     0.90       0.06708          0.6990
      0.01489 0.02754         1.8503     1.00       0.00000          0.8389
      0.02194 0.02506         1.1420     0.95       0.04873          0.7639
      0.09369 0.09497         1.0137     0.90       0.06708          0.6990
      0.09369 0.08553         0.9128     0.90       0.06708          0.6990
      0.01489 0.02743         1.8427     1.00       0.00000          0.8389
      0.02169 0.02504         1.1541     0.95       0.04873          0.7639
 coverage_mc_high interval_below_truth interval_above_truth standardized_mean
           1.0000                 0.00                 0.00            0.4466
           0.9193                 0.05                 0.15            0.5309
           0.9911                 0.00                 0.05            0.3962
           0.9911                 0.00                 0.05            0.2767
           0.9911                 0.00                 0.05            0.4448
           0.9193                 0.05                 0.15            0.5563
           0.9911                 0.00                 0.05            0.4066
           0.9911                 0.00                 0.05            0.2729
           0.9721                 0.00                 0.10            0.4257
           0.9721                 0.00                 0.10            0.2026
           1.0000                 0.00                 0.00            0.2709
           0.9911                 0.05                 0.00           -0.1244
           0.9721                 0.00                 0.10            0.3828
           0.9721                 0.00                 0.10            0.2192
           1.0000                 0.00                 0.00            0.2675
           0.9911                 0.05                 0.00           -0.1193
 standardized_sd
          0.7854
          1.3568
          0.8449
          0.9754
          0.8127
          1.3654
          0.8374
          0.9719
          1.1679
          1.2202
          0.5444
          0.8754
          1.1524
          1.1648
          0.5472
          0.8665

## Provenance

Fitting run IDs: 41459459543
Estimates MD5: 1d42788c3d52596ec0d7ff16ee2cb0af
Audit source MD5: b9f3c44aac2095eb63e54b38f91da502
