# Full-history adjustment simulation

Specification: sieve-diagnostic-lambda-1e-05

200 datasets; 800 method/horizon estimates returned; 0 failed method/horizon estimates.

All failures remain in estimates.csv and failures.csv. No replacement seeds are generated.

Both methods estimate the bridges, adjoints, sequential regressions and both policy density ratios.
Truth uses independent forward causal enumeration and agrees with the backward bridge functional.
Population adjoint and gradient checks are saved alongside each shard.

 mechanism     n method horizon attempted returned failed  truth       bias
    binary 10000    sdr       1       100      100      0 0.7250 -0.0012180
      dose 10000    sdr       1       100      100      0 0.5976  0.0000786
    binary 10000   tmle       1       100      100      0 0.7250 -0.0012425
      dose 10000   tmle       1       100      100      0 0.5976  0.0001094
    binary 10000    sdr       2       100      100      0 0.6777 -0.0017977
      dose 10000    sdr       2       100      100      0 0.5903 -0.0006122
    binary 10000   tmle       2       100      100      0 0.6777 -0.0017205
      dose 10000   tmle       2       100      100      0 0.5903 -0.0006091
 empirical_sd mean_se    rmse coverage mean_seconds
      0.01430 0.01323 0.01428     0.93       25.977
      0.01378 0.01311 0.01371     0.92       28.168
      0.01428 0.01323 0.01426     0.93        3.996
      0.01380 0.01311 0.01373     0.92        4.398
      0.01717 0.01757 0.01718     0.95       25.977
      0.01788 0.01690 0.01780     0.94       28.168
      0.01721 0.01755 0.01721     0.95        3.996
      0.01778 0.01690 0.01770     0.94        4.398
