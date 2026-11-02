# Matched positive-ridge comparison

Reference ridge: 0.001; sensitivity ridge: 1e-05.
Reference run: 41488034067 ; sensitivity run: 41516749627
Package versions, DGP hash, folds/control, SL learners, randomizer and k match.
The declared libraries differ only in their strictly positive ridge penalty.
The run.R source changed to expose this explicit study input; fitting archives are unchanged.
Rows are paired by mechanism, n, replication, estimator, horizon and seed.
No different specifications or overlapping seeds are pooled as independent data.
Only currently available sensitivity checkpoints are compared. A full cell has 100 pairs.
Use paired SE changes to assess regularization; partial-cell coverage is descriptive only.

Coverage-change MCSE uses paired indicator differences; gained/lost counts retain discordant pairs.
It does not treat the two specifications as independent simulations.

A zero empirical coverage-change MCSE with no discordant pairs does not establish equivalence.

 mechanism     n method horizon attempted_pairs valid_pairs failed_pairs
    binary 10000    sdr       1             100         100            0
      dose 10000    sdr       1             100         100            0
    binary 10000   tmle       1             100         100            0
      dose 10000   tmle       1             100         100            0
    binary 10000    sdr       2             100         100            0
      dose 10000    sdr       2             100         100            0
    binary 10000   tmle       2             100         100            0
      dose 10000   tmle       2             100         100            0
 mean_estimate_change estimate_change_mcse mean_se_change se_change_mcse
          -0.00015264           1.4000e-05     0.00033657     5.3507e-06
          -0.00064336           3.8900e-05     0.00075822     9.9529e-06
          -0.00015217           1.4023e-05     0.00033652     5.3488e-06
          -0.00064402           3.8879e-05     0.00075826     9.9534e-06
          -0.00011328           2.9905e-05     0.00014662     6.7163e-06
          -0.00078192           5.1953e-05     0.00085782     1.5564e-05
          -0.00011385           2.9867e-05     0.00014760     6.7469e-06
          -0.00078320           5.2123e-05     0.00085837     1.5565e-05
 reference_rms_se sensitivity_rms_se reference_empirical_sd
         0.012900           0.013238               0.014246
         0.012357           0.013118               0.013600
         0.012898           0.013236               0.014229
         0.012356           0.013116               0.013615
         0.017440           0.017588               0.017131
         0.016058           0.016921               0.017689
         0.017411           0.017560               0.017170
         0.016049           0.016913               0.017588
 sensitivity_empirical_sd reference_bias sensitivity_bias reference_coverage
                 0.014297    -0.00106534      -1.2180e-03               0.92
                 0.013783     0.00072196       7.8596e-05               0.92
                 0.014281    -0.00109031      -1.2425e-03               0.92
                 0.013797     0.00075341       1.0938e-04               0.92
                 0.017170    -0.00168443      -1.7977e-03               0.95
                 0.017878     0.00016972      -6.1220e-04               0.91
                 0.017207    -0.00160668      -1.7205e-03               0.95
                 0.017776     0.00017407      -6.0913e-04               0.91
 sensitivity_coverage coverage_change coverage_change_mcse gained_coverage
                 0.93            0.01             0.010000               1
                 0.92            0.00             0.000000               0
                 0.93            0.01             0.010000               1
                 0.92            0.00             0.000000               0
                 0.95            0.00             0.000000               0
                 0.94            0.03             0.017145               3
                 0.95            0.00             0.000000               0
                 0.94            0.03             0.017145               3
 lost_coverage
             0
             0
             0
             0
             0
             0
             0
             0

## Changes in reported gradient variance

Components are sequential variance, bridge variance and twice their covariance.
Each mean change and MCSE uses the same paired datasets; components can offset each other.

 mechanism     n method horizon sequential_pairs sequential_change
    binary 10000    sdr       1              100         -0.029545
      dose 10000    sdr       1              100         -0.023189
    binary 10000   tmle       1              100         -0.029501
      dose 10000   tmle       1              100         -0.023181
    binary 10000    sdr       2              100         -0.094070
      dose 10000    sdr       2              100         -0.065817
    binary 10000   tmle       2              100         -0.093763
      dose 10000   tmle       2              100         -0.065719
 sequential_change_mcse bridge_pairs bridge_change bridge_change_mcse
             0.00031676          100      0.078864          0.0013727
             0.00029294          100      0.197464          0.0028789
             0.00031687          100      0.078864          0.0013727
             0.00029276          100      0.197464          0.0028789
             0.00115243          100      0.081992          0.0022718
             0.00102222          100      0.292394          0.0059376
             0.00114506          100      0.081992          0.0022718
             0.00101943          100      0.292394          0.0059376
 covariance_twice_pairs covariance_twice_change covariance_twice_change_mcse
                    100                0.038975                   0.00066303
                    100                0.019454                   0.00067378
                    100                0.038905                   0.00066287
                    100                0.019436                   0.00067351
                    100                0.063924                   0.00115484
                    100                0.058051                   0.00168300
                    100                0.063879                   0.00115444
                    100                0.057988                   0.00167929
 total_pairs total_change total_change_mcse
         100     0.088294         0.0016793
         100     0.193729         0.0031120
         100     0.088268         0.0016791
         100     0.193719         0.0031118
         100     0.051847         0.0025081
         100     0.284629         0.0063593
         100     0.052108         0.0025148
         100     0.284664         0.0063579

Comparison source MD5: 76f1179281d06f044693bc8c085fdd17
