# Full-history adjustment simulation

Specification: saved nuisance specification

80 datasets; 320 method/horizon estimates returned; 0 failed method/horizon estimates.

All failures remain in estimates.csv and failures.csv. No replacement seeds are generated.

Both methods estimate the bridges, adjoints, sequential regressions and both policy density ratios.
Truth uses independent forward causal enumeration and agrees with the backward bridge functional.
Population adjoint and gradient checks are saved alongside each shard.

 mechanism    n method horizon attempted returned failed  truth      bias
    binary  500    sdr       1        20       20      0 0.7250  0.022336
      dose  500    sdr       1        20       20      0 0.5976  0.022042
    binary 4000    sdr       1        20       20      0 0.7250  0.007309
      dose 4000    sdr       1        20       20      0 0.5976  0.004445
    binary  500   tmle       1        20       20      0 0.7250  0.021696
      dose  500   tmle       1        20       20      0 0.5976  0.023145
    binary 4000   tmle       1        20       20      0 0.7250  0.007509
      dose 4000   tmle       1        20       20      0 0.5976  0.004373
    binary  500    sdr       2        20       20      0 0.6777  0.035448
      dose  500    sdr       2        20       20      0 0.5903  0.008914
    binary 4000    sdr       2        20       20      0 0.6777  0.007465
      dose 4000    sdr       2        20       20      0 0.5903 -0.003087
    binary  500   tmle       2        20       20      0 0.6777  0.029244
      dose  500   tmle       2        20       20      0 0.5903  0.010407
    binary 4000   tmle       2        20       20      0 0.6777  0.007330
      dose 4000   tmle       2        20       20      0 0.5903 -0.002962
 empirical_sd mean_se    rmse coverage mean_seconds
      0.04814 0.06028 0.05197     1.00      18.1209
      0.07467 0.05469 0.07604     0.80      17.2654
      0.01627 0.01997 0.01746     0.95      19.0043
      0.01870 0.01960 0.01876     0.95      17.5156
      0.04794 0.05981 0.05152     0.95       0.7379
      0.07473 0.05459 0.07643     0.80       0.6985
      0.01615 0.01995 0.01744     0.95       2.2428
      0.01864 0.01959 0.01869     0.95       2.0814
      0.10103 0.09730 0.10466     0.90      18.1209
      0.09993 0.08586 0.09781     0.90      17.2654
      0.01489 0.02748 0.01632     1.00      19.0043
      0.02194 0.02504 0.02161     0.95      17.5156
      0.09369 0.09284 0.09589     0.90       0.7379
      0.09369 0.08476 0.09191     0.90       0.6985
      0.01489 0.02738 0.01626     1.00       2.2428
      0.02169 0.02502 0.02135     0.95       2.0814
