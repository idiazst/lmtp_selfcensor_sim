"""Freeze the fourth-scenario code; never alter the previous study."""
from pathlib import Path
import hashlib
import json
import shlex
import shutil
import sys

source = Path(__file__).resolve().parent
repo = source.parents[2]
root = repo / "results" / "imputation" / "neither"
old = root.parent
phase = sys.argv[1]
assert phase in {"pilot", "main"}
if phase == "main":
    assert (root / "pilot" / "COMPLETED.txt").exists(), "Pilot must pass first"
target = root / phase
frozen = target / "source"
assert not frozen.exists(), "Frozen phase exists; resume via its launcher"
frozen.mkdir(parents=True)
for p in list(source.glob("*.R")) + list(source.glob("*.md")) + list(source.glob("*.csv")) + list(source.glob("*.py")):
    shutil.copy2(p, frozen / p.name)
shutil.copy2(repo / "scripts" / "setup.R", frozen / "runtime-setup.R")
manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in frozen.iterdir()}
fingerprint = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
(frozen / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
(target / "fingerprint.txt").write_text(fingerprint + "\n")
old_manifest = root / "original-results-sha256.json"
if not old_manifest.exists():
    jobs = sorted((old / "jobs").glob("*.rds"))
    assert len(jobs) == 1200 and (old / "COMPLETED.txt").exists()
    hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in jobs}
    old_manifest.write_text(json.dumps(hashes, indent=2) + "\n")
q = shlex.quote
launcher = ["#!/bin/sh", "set -eu", f"mkdir {q(str(target / 'running.lock'))}",
    f"trap 'rmdir {q(str(target / 'running.lock'))}' EXIT",
    f"export MI_LMTP_SOURCE={q(str(frozen))}", f"export MI_LMTP_ROOT={q(str(root))}",
    f"export MI_STUDY_ROOT={q(str(repo / '.runtime'))}",
    f"export SIM_REPO={q(str(repo))}",
    f"export MI_LMTP_PHASE={phase}", f"export MI_LMTP_FINGERPRINT={fingerprint}",
    f"export MI_SOURCE_FINGERPRINT={fingerprint}",
    f"export MI_LMTP_WORKERS={'4' if phase == 'pilot' else '8'}",
    "export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1",
    f"Rscript {q(str(frozen / 'run.R'))} >> {q(str(target / 'run.log'))} 2>&1"]
if phase == "main":
    launcher.append(f"python3 {q(str(frozen / 'combine.py'))} {q(str(root))} >> {q(str(root / 'combine.log'))} 2>&1")
(target / "run-study.sh").write_text("\n".join(launcher) + "\n")
print(target / "run-study.sh")
print(fingerprint)
