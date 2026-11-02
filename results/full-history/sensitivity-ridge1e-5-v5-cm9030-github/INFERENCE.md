# Full-history inference diagnostics

Specification: sieve-diagnostic-lambda-1e-05

Bias MCSE is empirical SD divided by the square root of returned replications.
RMS SE is sqrt(mean(reported SE squared)); its ratio to empirical SD compares variances.
Coverage MC limits are pointwise 95% Wilson intervals over returned replications.
They describe simulation uncertainty and do not change any estimator interval.
Cells share datasets across horizons and methods; these are not simultaneous tests.
Failure counts are retained. Coverage describes the returned estimates only.

Largest relative difference between n * SE^2 and Var(sequential + bridge correction): 9.07e-15.

 mechanism     n method horizon attempted returned failed       bias bias_mcse
    binary 10000    sdr       1       100      100      0 -0.0012180  0.001430
      dose 10000    sdr       1       100      100      0  0.0000786  0.001378
    binary 10000   tmle       1       100      100      0 -0.0012425  0.001428
      dose 10000   tmle       1       100      100      0  0.0001094  0.001380
    binary 10000    sdr       2       100      100      0 -0.0017977  0.001717
      dose 10000    sdr       2       100      100      0 -0.0006122  0.001788
    binary 10000   tmle       2       100      100      0 -0.0017205  0.001721
      dose 10000   tmle       2       100      100      0 -0.0006091  0.001778
 empirical_sd  rms_se rms_se_over_sd coverage coverage_mcse coverage_mc_low
      0.01430 0.01324         0.9259     0.93       0.02551          0.8625
      0.01378 0.01312         0.9517     0.92       0.02713          0.8500
      0.01428 0.01324         0.9268     0.93       0.02551          0.8625
      0.01380 0.01312         0.9506     0.92       0.02713          0.8500
      0.01717 0.01759         1.0243     0.95       0.02179          0.8882
      0.01788 0.01692         0.9465     0.94       0.02375          0.8752
      0.01721 0.01756         1.0205     0.95       0.02179          0.8882
      0.01778 0.01691         0.9514     0.94       0.02375          0.8752
 coverage_mc_high interval_below_truth interval_above_truth standardized_mean
           0.9657                 0.02                 0.05          -0.05557
           0.9589                 0.03                 0.05           0.03469
           0.9657                 0.02                 0.05          -0.05749
           0.9589                 0.03                 0.05           0.03707
           0.9785                 0.03                 0.02          -0.10011
           0.9722                 0.04                 0.02          -0.01228
           0.9785                 0.03                 0.02          -0.09559
           0.9722                 0.04                 0.02          -0.01216
 standardized_sd
          1.0769
          1.0554
          1.0758
          1.0569
          0.9742
          1.0576
          0.9784
          1.0520

## Provenance

Fitting run IDs: 41516749627
Estimates MD5: dfbe9f115bfe1622e8513be259a429e6
Audit source MD5: b9f3c44aac2095eb63e54b38f91da502
