# Latest MI and self-censoring comparison

Four estimators: MI + standard lmtp TMLE, MI + standard lmtp SDR, bridge TMLE,
and bridge SDR. Four scenarios: MAR only, shadow only, both, and neither.
The intervention sets A1=1 and E[Y2(1)]=0.75 throughout. Use n=1000/4000,
200 replications per setting, and 50 imputations per dataset. The neither law
P(R2=1|W,A1,Y2)=0.675+0.1W+0.15A1-0.3Y2 gives both approaches the exact population
bias -0.086256008545487. See neither/PLAN.md for the complete design and audit.

All numerical fitting code lives in neither/. The redundant unvalidated
three-scenario refactor has been removed. run.R is a thin entry point with
protection against duplicate processes. From the repository root:

    Rscript studies/imputation/run.R status
    Rscript studies/imputation/run.R main

The main command resumes the frozen 400-dataset extension when needed and
reports completion when it has finished. It refuses to duplicate an active run.
The original 1200 corrected checkpoints are retained unchanged and combined
with the new 400 checkpoints. This resume workflow requires the retained local
baseline checkpoints/tables and the pinned private runtime, which are ignored
by Git. A fresh all-scenarios launcher is not provided by this thin entry point.

Prepare a phase using python3 studies/imputation/neither/freeze.py pilot or main
only when it has not already been frozen. Main requires a validated pilot.
Never edit frozen source while a phase is active. Checkpoints are atomic and
saved results are independently validated. All bias, coverage, and MSE use .75.

Canonical outputs: results/imputation/. Extension provenance and frozen source:
results/imputation/neither/. Runtime: .runtime/library. Startup verifies all
5452 runtime file hashes and the original package archive hashes. No code or
data in cmbridge-tests is required. Cleanup coordination is recorded in the
workspace-level MI-SIMULATION-COORDINATION.md.

## Fresh reproduction from a clone

After `Rscript scripts/install_dependencies.R`, use
`python3 studies/imputation/run_fresh.py --output results/new-imputation --workers 8`.
This creates a new source freeze and runs all four scenarios (n=1000,4000,
200 replications). Its unchanged validated bridge and corrected-MI function
bodies are copied into that freeze. It generates all inputs locally and does
not require retained baseline checkpoints. Existing output directories are
rejected. `run.R status/main` remains the guarded entry point for the current
extension, separate from this fresh reproduction.
