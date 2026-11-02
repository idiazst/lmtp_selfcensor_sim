# Full-history adjustment simulation

80 datasets; 316 method/horizon estimates returned; 4 failed method/horizon estimates.

All failures remain in estimates.csv and failures.csv. No replacement seeds are generated.

Both methods estimate the bridges, adjoints, sequential regressions and both policy density ratios.
Truth uses independent forward causal enumeration and agrees with the backward bridge functional.
Population adjoint and gradient checks are saved alongside each shard.

 mechanism    n method horizon attempted returned failed  truth      bias
    binary  500    sdr       1        20       19      1 0.7250  0.025219
      dose  500    sdr       1        20       20      0 0.5976  0.022042
    binary 4000    sdr       1        20       20      0 0.7250  0.007309
      dose 4000    sdr       1        20       20      0 0.5976  0.004445
    binary  500   tmle       1        20       19      1 0.7250  0.024407
      dose  500   tmle       1        20       20      0 0.5976  0.023145
    binary 4000   tmle       1        20       20      0 0.7250  0.007509
      dose 4000   tmle       1        20       20      0 0.5976  0.004373
    binary  500    sdr       2        20       19      1 0.6777  0.038773
      dose  500    sdr       2        20       20      0 0.5903  0.008914
    binary 4000    sdr       2        20       20      0 0.6777  0.007465
      dose 4000    sdr       2        20       20      0 0.5903 -0.003087
    binary  500   tmle       2        20       19      1 0.6777  0.033678
      dose  500   tmle       2        20       20      0 0.5903  0.010898
    binary 4000   tmle       2        20       20      0 0.6777  0.007355
      dose 4000   tmle       2        20       20      0 0.5903 -0.002963
 empirical_sd mean_se    rmse coverage mean_seconds
      0.04766 0.05982 0.05280   1.0000        13.06
      0.07467 0.05469 0.07604   0.8000        19.59
      0.01627 0.01997 0.01746   0.9500        15.18
      0.01870 0.01960 0.01876   0.9500        16.16
      0.04765 0.05936 0.05241   0.9474        12.89
      0.07473 0.05459 0.07643   0.8000        19.35
      0.01615 0.01995 0.01744   0.9500        14.75
      0.01864 0.01959 0.01869   0.9500        15.79
      0.10267 0.09589 0.10719   0.8947        13.06
      0.09993 0.08586 0.09781   0.9000        19.59
      0.01489 0.02748 0.01632   1.0000        15.18
      0.02194 0.02504 0.02161   0.9500        16.16
      0.09464 0.09106 0.09808   0.8947        12.89
      0.09377 0.08471 0.09204   0.9000        19.35
      0.01489 0.02738 0.01627   1.0000        14.75
      0.02175 0.02502 0.02140   0.9500        15.79
