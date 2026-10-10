#!/bin/sh
set -eu
mkdir /Users/ivan/Projects/cmbridge-work/cmbridge-tests/results/mi-lmtp-comparison-v3/pilot/running.lock
trap 'rmdir /Users/ivan/Projects/cmbridge-work/cmbridge-tests/results/mi-lmtp-comparison-v3/pilot/running.lock' EXIT
export MI_LMTP_SOURCE=/Users/ivan/Projects/cmbridge-work/cmbridge-tests/results/mi-lmtp-comparison-v3/pilot/source
export MI_LMTP_ROOT=/Users/ivan/Projects/cmbridge-work/cmbridge-tests/results/mi-lmtp-comparison-v3
export MI_LMTP_PHASE=pilot
export MI_LMTP_FINGERPRINT=456f8b95389148e308e757ea44b0f34db0731539d50094e7ddac056e263ff836
export MI_SOURCE_FINGERPRINT=456f8b95389148e308e757ea44b0f34db0731539d50094e7ddac056e263ff836
export MI_LMTP_WORKERS=4
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
Rscript /Users/ivan/Projects/cmbridge-work/cmbridge-tests/results/mi-lmtp-comparison-v3/pilot/source/run.R >> /Users/ivan/Projects/cmbridge-work/cmbridge-tests/results/mi-lmtp-comparison-v3/pilot/run.log 2>&1
