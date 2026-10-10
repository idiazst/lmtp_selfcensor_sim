#!/bin/sh
set -eu
mkdir /Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/results/imputation/neither/main/running.lock
trap 'rmdir /Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/results/imputation/neither/main/running.lock' EXIT
export MI_LMTP_SOURCE=/Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/results/imputation/neither/main/source
export MI_LMTP_ROOT=/Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/results/imputation/neither
export MI_STUDY_ROOT=/Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/.runtime
export SIM_REPO=/Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim
export MI_LMTP_PHASE=main
export MI_LMTP_FINGERPRINT=163b4b859c5a1afb16071755677197237882581a99ddbd811964763ff31d41c4
export MI_SOURCE_FINGERPRINT=163b4b859c5a1afb16071755677197237882581a99ddbd811964763ff31d41c4
export MI_LMTP_WORKERS=8
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
Rscript /Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/results/imputation/neither/main/source/run.R >> /Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/results/imputation/neither/main/run.log 2>&1
python3 /Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/results/imputation/neither/main/source/combine.py /Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/results/imputation/neither >> /Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/results/imputation/neither/combine.log 2>&1
