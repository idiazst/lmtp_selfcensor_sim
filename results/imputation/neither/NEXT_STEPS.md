# Finish the fourth scenario with equal population bias

Main started October 10, 2026 at 17:02 EDT with eight workers in canonical paths.
Supervisor PID 2279. Frozen main fingerprint:
163b4b859c5a1afb16071755677197237882581a99ddbd811964763ff31d41c4.
Completion heartbeat: finish-equal-bias-mi-scenario.
All 5452 library files and frozen package archives passed startup verification.
The pilot and canonical-path validation passed without refitting any pilot data.

User requests on October 10, 2026: add a scenario where neither MAR nor shadow
holds, then adjust coefficients so both approaches have approximately equal bias.
The calibrated law below gives EXACT equality of population bias. This is the
authorized current design. Do not use the earlier unrun design.

    P(R2=1 | W,A1,Y2) = 0.675 + 0.1 W + 0.15 A1 - 0.3 Y2.

Everything else is unchanged: truth E[Y2(1)]=0.75, 35% missingness, n=1000/4000,
200 replications at each n, M=50, three outer folds, MI followed by exported
standard lmtp TMLE/SDR, bridge TMLE/SDR, and the verified private package builds.
Both population functionals equal 0.663743991454513 and both biases equal
-0.086256008545487. Finite-sample biases need not agree exactly.

## Run and completion checks

- Result root: /Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/results/imputation/neither
- Source: /Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/studies/imputation/neither
- Original corrected jobs (preserve): lmtp_selfcensor_sim/results/imputation/jobs.
- Canonical combined final report: lmtp_selfcensor_sim/results/imputation/REPORT.md.
- Baseline compact tables: results/imputation/neither/baseline, with 24 original rows.
- Private library (preserve): lmtp_selfcensor_sim/.runtime/library.
- `pilot` contains four independent implementation-check datasets and is excluded
  from the main report. The calibrated pilot source fingerprint is
  87566784e03dfd457b33d6b1770855f70b42d5e56fa1d8d21ac449391e3eee43.
- `main/run-study.sh` fits 400 new datasets then automatically runs combine.py.
  Never start a duplicate run. Check run.pid, processes, running.lock, and logs.
  Each stage skips saved checkpoints on resume.
- Bridge stage progress: main/inputs/jobs and main/bridge.log.
- Corrected MI stage progress: main/jobs and main/run.log.
- `main/COMPLETED.txt` requires 400 datasets, independent validation, and reports.
- `combined/COMPLETED.txt` additionally means old checkpoint hashes were verified
  and all 1,600 datasets were combined, preserving the 1,200 original jobs.
- Check main/validate-errors.log, main/summarize-errors.log, combine.log,
  main/VALIDATION.md, combined/VALIDATION.md, and combined/REPORT.md.
- Require 32 summary rows, 200 replications per row, 6,400 final method estimates,
  and 160,000 standard MI lmtp calls across all scenarios. Retain candidate
  failures and iteration-limit diagnostics, distinct from failed final fits.
- If fitting finishes but combining fails, fix only the reporting problem and
  rerun the frozen combine.py with the result root argument. Do not refit.

## Results and slides after completion

Notify only on completion, meaningful failure, or required input. Keep quiet
while the job is making ordinary progress. The final table must retain mean,
coverage, and MSE, all evaluated against 0.75. Explicitly distinguish exact
population bias equality from finite-sample empirical bias differences.

The user's earlier request also placed three simulation slides in the Harvard
2026 talk. Update those existing frames to include this fourth scenario after
the new results pass validation. Keep exactly three simulation frames.
Read the CURRENT source and preserve newer user edits, including edits inside
those frames. Never republish an old whole-deck copy blindly.

Actual talk:
/Users/ivan/Library/CloudStorage/GoogleDrive-diazi07@nyu.edu/My Drive/presentations/2026 Harvard/slides.tex
and slides.pdf in the same folder.

Previous preparation and safe publishing tools:
/Users/ivan/Projects/cmbridge-work/lmtp_selfcensor_sim/reports/harvard-2026-imputation
Its README.md describes the migrated helpers. The prior builder
hardcodes 3 scenarios, 24 method/setting rows, and 1200 datasets. For this update,
work in a NEW private directory, adapt it to combined results, 4 scenarios,
32 rows, 1600 datasets, the calibrated neither law above, and combined provenance.
The original publisher backs up the actual talk and checks its source hash before
writing. Adapt it to the current deck structure if needed and retain these guards.

Match the user's current Beamer design. Read the presentation/PDF skills when
performing the edits. Native compile_latex_document provides diagnostics; use the
existing /Library/TeX/texbin/pdflatex to export a filesystem PDF without installing
anything. Render the three updated frames with the bundled Poppler and inspect
them before replacing the actual TeX/PDF. Open the actual TeX in Codex afterward.
Do not publish preliminary results. Use ordinary filesystem escalation for the
user-authorized CloudStorage writes. Never discard concurrent edits.

Delete the completion heartbeat after successful delivery. Do not modify any
other chat's automation or packages. The user explicitly authorized coordination
with chat 01a10e8d-a943-78e1-9887-a198ab1ed2d0 (Push cmbridge ensemble updates)
on October 10. Read MI-SIMULATION-COORDINATION.md in the workspace root. That chat
owns repository reorganization and has deferred all imputation source/results to
this chat. The dependency audit is complete and the organization chat has removed obsolete
cmbridge-tests files and old-path compatibility links. All active dependencies
are canonical. It owns the fresh all-scenarios launcher (fresh.R/fresh_driver.R
or replacements), repository README, and publication. Do not edit that separate
launcher concurrently. This chat owns the active neither run and slide delivery.
Coordinate after results are ready for any final manifest/commit update.
