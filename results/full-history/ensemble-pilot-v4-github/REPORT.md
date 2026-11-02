# Full-history adjustment simulation

Specification: saved nuisance specification

4 datasets; 16 method/horizon estimates returned; 0 failed method/horizon estimates.

All failures remain in estimates.csv and failures.csv. No replacement seeds are generated.

Both methods estimate the bridges, adjoints, sequential regressions and both policy density ratios.
Truth uses independent forward causal enumeration and agrees with the backward bridge functional.
Population adjoint and gradient checks are saved alongside each shard.

 mechanism    n method horizon attempted returned failed  truth      bias
    binary 1000    sdr       1         1        1      0 0.7250  0.052673
      dose 1000    sdr       1         1        1      0 0.5976 -0.032887
    binary 4000    sdr       1         1        1      0 0.7250  0.011830
      dose 4000    sdr       1         1        1      0 0.5976  0.014696
    binary 1000   tmle       1         1        1      0 0.7250  0.058193
      dose 1000   tmle       1         1        1      0 0.5976 -0.032879
    binary 4000   tmle       1         1        1      0 0.7250  0.011160
      dose 4000   tmle       1         1        1      0 0.5976  0.014597
    binary 1000    sdr       2         1        1      0 0.6777 -0.061206
      dose 1000    sdr       2         1        1      0 0.5903  0.007362
    binary 4000    sdr       2         1        1      0 0.6777  0.027188
      dose 4000    sdr       2         1        1      0 0.5903 -0.046972
    binary 1000   tmle       2         1        1      0 0.6777 -0.049660
      dose 1000   tmle       2         1        1      0 0.5903  0.006527
    binary 4000   tmle       2         1        1      0 0.6777  0.029492
      dose 4000   tmle       2         1        1      0 0.5903 -0.046440
 empirical_sd mean_se     rmse coverage mean_seconds
           NA 0.03667 0.052673        1     8418.958
           NA 0.04056 0.032887        1    11433.560
           NA 0.01989 0.011830        1     3711.015
           NA 0.01860 0.014696        1     4261.764
           NA 0.03649 0.058193        1        2.505
           NA 0.04055 0.032879        1        2.887
           NA 0.01985 0.011160        1        5.221
           NA 0.01859 0.014597        1        5.652
           NA 0.05569 0.061206        1     8418.958
           NA 0.04527 0.007362        1    11433.560
           NA 0.02592 0.027188        1     3711.015
           NA 0.02523 0.046972        1     4261.764
           NA 0.05369 0.049660        1        2.505
           NA 0.04530 0.006527        1        2.887
           NA 0.02592 0.029492        1        5.221
           NA 0.02521 0.046440        1        5.652
