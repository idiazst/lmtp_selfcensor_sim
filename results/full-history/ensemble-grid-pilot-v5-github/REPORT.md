# Full-history adjustment simulation

Specification: ensemble-grid

4 datasets; 16 method/horizon estimates returned; 0 failed method/horizon estimates.

All failures remain in estimates.csv and failures.csv. No replacement seeds are generated.

Both methods estimate the bridges, adjoints, sequential regressions and both policy density ratios.
Truth uses independent forward causal enumeration and agrees with the backward bridge functional.
Population adjoint and gradient checks are saved alongside each shard.

 mechanism    n method horizon attempted returned failed  truth      bias
    binary 1000    sdr       1         1        1      0 0.7250  0.052521
      dose 1000    sdr       1         1        1      0 0.5976 -0.033449
    binary 4000    sdr       1         1        1      0 0.7250  0.011841
      dose 4000    sdr       1         1        1      0 0.5976  0.015590
    binary 1000   tmle       1         1        1      0 0.7250  0.058182
      dose 1000   tmle       1         1        1      0 0.5976 -0.033466
    binary 4000   tmle       1         1        1      0 0.7250  0.011166
      dose 4000   tmle       1         1        1      0 0.5976  0.015496
    binary 1000    sdr       2         1        1      0 0.6777 -0.062603
      dose 1000    sdr       2         1        1      0 0.5903  0.007214
    binary 4000    sdr       2         1        1      0 0.6777  0.027506
      dose 4000    sdr       2         1        1      0 0.5903 -0.046412
    binary 1000   tmle       2         1        1      0 0.6777 -0.049335
      dose 1000   tmle       2         1        1      0 0.5903  0.007260
    binary 4000   tmle       2         1        1      0 0.6777  0.029346
      dose 4000   tmle       2         1        1      0 0.5903 -0.045669
 empirical_sd mean_se     rmse coverage mean_seconds
           NA 0.03665 0.052521        1     2933.689
           NA 0.04068 0.033449        1     3981.983
           NA 0.01989 0.011841        1     1636.305
           NA 0.01855 0.015590        1     1995.424
           NA 0.03649 0.058182        1        2.201
           NA 0.04067 0.033466        1        3.683
           NA 0.01985 0.011166        1        5.381
           NA 0.01854 0.015496        1        8.387
           NA 0.05582 0.062603        1     2933.689
           NA 0.04549 0.007214        1     3981.983
           NA 0.02590 0.027506        1     1636.305
           NA 0.02516 0.046412        1     1995.424
           NA 0.05379 0.049335        1        2.201
           NA 0.04550 0.007260        1        3.683
           NA 0.02592 0.029346        1        5.381
           NA 0.02514 0.045669        1        8.387
