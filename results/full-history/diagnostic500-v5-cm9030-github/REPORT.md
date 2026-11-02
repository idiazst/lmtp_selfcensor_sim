# Full-history adjustment simulation

Specification: sieve-diagnostic

1000 datasets; 4000 method/horizon estimates returned; 0 failed method/horizon estimates.

All failures remain in estimates.csv and failures.csv. No replacement seeds are generated.

Both methods estimate the bridges, adjoints, sequential regressions and both policy density ratios.
Truth uses independent forward causal enumeration and agrees with the backward bridge functional.
Population adjoint and gradient checks are saved alongside each shard.

 mechanism     n method horizon attempted returned failed  truth      bias
    binary 10000    sdr       1       500      500      0 0.7250 0.0004836
      dose 10000    sdr       1       500      500      0 0.5976 0.0013029
    binary 10000   tmle       1       500      500      0 0.7250 0.0004978
      dose 10000   tmle       1       500      500      0 0.5976 0.0013141
    binary 10000    sdr       2       500      500      0 0.6777 0.0005704
      dose 10000    sdr       2       500      500      0 0.5903 0.0017352
    binary 10000   tmle       2       500      500      0 0.6777 0.0006119
      dose 10000   tmle       2       500      500      0 0.5903 0.0017379
 empirical_sd mean_se    rmse coverage mean_seconds
      0.01363 0.01287 0.01362    0.940       27.418
      0.01364 0.01236 0.01369    0.914       26.229
      0.01362 0.01286 0.01361    0.938        4.204
      0.01364 0.01236 0.01369    0.912        4.106
      0.01756 0.01737 0.01755    0.942       27.418
      0.01756 0.01595 0.01763    0.924       26.229
      0.01752 0.01734 0.01752    0.946        4.204
      0.01755 0.01594 0.01762    0.922        4.106
