# Four-scenario validation

All 1,200 previous corrected dataset checkpoints match their pre-extension SHA256 hashes. The original 24 summary rows reproduce their previous values. The 400 new datasets passed independent validation in [the extension validation](neither/main/VALIDATION.md). The combined report contains 1,600 datasets, 6,400 returned method estimates, and 200 replications in each of the 32 method/scenario/sample-size cells. MSE and all performance metrics use the causal target 0.75.

Independent delivery checks reproduced all means, coverage proportions, and MSE values from the 6,400 replicate rows, verified all 1,600 checkpoint hashes, and confirmed 160,000 completed-data lmtp calls with no failed calls or support assertions.
