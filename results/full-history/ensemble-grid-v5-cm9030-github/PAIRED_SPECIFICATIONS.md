# Matched large-sample specification comparisons

Main specification: ensemble-grid ; run: 41460347711
All differences are main ensemble minus the named comparison, at n=10000.
Only the same mechanism/replication/method/horizon/seed is paired; all truths agree.
The fitting libraries are distinct. Package versions, DGP hash, folds/control and randomizer match.
The run.R source hash differs for the explicit ridge-input diagnostic; package archives are unchanged.
Each comparison uses the matching first 100 reference seeds, not all 500 precision-study seeds.
Specifications are never pooled and overlapping seeds do not increase independent replication counts.
Coverage-change MCSE uses within-seed indicator differences. No discordance does not establish equivalence.

      comparison_specification comparison_run mechanism     n method horizon
              sieve-diagnostic    41488034067    binary 10000    sdr       1
 sieve-diagnostic-lambda-1e-05    41516749627    binary 10000    sdr       1
              sieve-diagnostic    41488034067      dose 10000    sdr       1
 sieve-diagnostic-lambda-1e-05    41516749627      dose 10000    sdr       1
              sieve-diagnostic    41488034067    binary 10000   tmle       1
 sieve-diagnostic-lambda-1e-05    41516749627    binary 10000   tmle       1
              sieve-diagnostic    41488034067      dose 10000   tmle       1
 sieve-diagnostic-lambda-1e-05    41516749627      dose 10000   tmle       1
              sieve-diagnostic    41488034067    binary 10000    sdr       2
 sieve-diagnostic-lambda-1e-05    41516749627    binary 10000    sdr       2
              sieve-diagnostic    41488034067      dose 10000    sdr       2
 sieve-diagnostic-lambda-1e-05    41516749627      dose 10000    sdr       2
              sieve-diagnostic    41488034067    binary 10000   tmle       2
 sieve-diagnostic-lambda-1e-05    41516749627    binary 10000   tmle       2
              sieve-diagnostic    41488034067      dose 10000   tmle       2
 sieve-diagnostic-lambda-1e-05    41516749627      dose 10000   tmle       2
 attempted_pairs valid_pairs failed_pairs   main_bias comparison_bias
             100         100            0 -1.2023e-03     -1.0653e-03
             100         100            0 -1.2023e-03     -1.2180e-03
             100         100            0  4.0143e-04      7.2196e-04
             100         100            0  4.0143e-04      7.8596e-05
             100         100            0 -1.2300e-03     -1.0903e-03
             100         100            0 -1.2300e-03     -1.2425e-03
             100         100            0  4.3214e-04      7.5341e-04
             100         100            0  4.3214e-04      1.0938e-04
             100         100            0 -1.8999e-03     -1.6844e-03
             100         100            0 -1.8999e-03     -1.7977e-03
             100         100            0 -1.0530e-04      1.6972e-04
             100         100            0 -1.0530e-04     -6.1220e-04
             100         100            0 -1.8188e-03     -1.6067e-03
             100         100            0 -1.8188e-03     -1.7205e-03
             100         100            0 -8.3005e-05      1.7407e-04
             100         100            0 -8.3005e-05     -6.0913e-04
 mean_estimate_change estimate_change_mcse main_rms_se comparison_rms_se
          -1.3695e-04           2.9945e-05    0.013082          0.012900
           1.5687e-05           2.8547e-05    0.013082          0.013238
          -3.2053e-04           2.1114e-04    0.012422          0.012357
           3.2283e-04           2.2753e-04    0.012422          0.013118
          -1.3967e-04           2.9708e-05    0.013080          0.012898
           1.2498e-05           2.8389e-05    0.013080          0.013236
          -3.2126e-04           2.1085e-04    0.012421          0.012356
           3.2276e-04           2.2716e-04    0.012421          0.013116
          -2.1551e-04           9.3847e-05    0.017575          0.017440
          -1.0223e-04           1.0871e-04    0.017575          0.017588
          -2.7502e-04           5.0203e-04    0.016205          0.016058
           5.0690e-04           5.2019e-04    0.016205          0.016921
          -2.1216e-04           9.2286e-05    0.017545          0.017411
          -9.8309e-05           1.0748e-04    0.017545          0.017560
          -2.5708e-04           5.0138e-04    0.016197          0.016049
           5.2613e-04           5.1965e-04    0.016197          0.016913
 mean_se_change se_change_mcse main_coverage comparison_coverage
     1.8111e-04     6.9546e-06          0.93                0.92
    -1.5546e-04     6.0698e-06          0.93                0.93
     6.4414e-05     1.9780e-05          0.92                0.92
    -6.9381e-04     2.2431e-05          0.92                0.92
     1.8094e-04     6.9311e-06          0.92                0.92
    -1.5558e-04     6.0408e-06          0.92                0.93
     6.4102e-05     1.9778e-05          0.92                0.92
    -6.9415e-04     2.2428e-05          0.92                0.92
     1.3460e-04     2.1473e-05          0.95                0.95
    -1.2017e-05     2.4807e-05          0.95                0.95
     1.4129e-04     2.8512e-05          0.95                0.91
    -7.1653e-04     2.7591e-05          0.95                0.94
     1.3353e-04     2.1448e-05          0.95                0.95
    -1.4071e-05     2.4777e-05          0.95                0.95
     1.4237e-04     2.8534e-05          0.94                0.91
    -7.1601e-04     2.7634e-05          0.94                0.94
 coverage_change coverage_change_mcse gained_coverage lost_coverage
            0.01             0.010000               1             0
            0.00             0.000000               0             0
            0.00             0.000000               0             0
            0.00             0.000000               0             0
            0.00             0.000000               0             0
           -0.01             0.010000               0             1
            0.00             0.000000               0             0
            0.00             0.000000               0             0
            0.00             0.000000               0             0
            0.00             0.000000               0             0
            0.04             0.019695               4             0
            0.01             0.010000               1             0
            0.00             0.000000               0             0
            0.00             0.000000               0             0
            0.03             0.017145               3             0
            0.00             0.014213               1             1

Main estimates MD5: 95ed7d670eb9c32d2bc82ae31f1bad7d
Comparison source MD5: 63f33cf497d612d8345454a1b4f9e1e5
