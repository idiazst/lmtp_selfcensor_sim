"""Verify old results and create the four-scenario report without changing them."""
from pathlib import Path
import csv
from datetime import datetime
import hashlib
import json
import shutil
import subprocess
from zoneinfo import ZoneInfo

source = Path(__file__).resolve().parent
# Called with the result root explicitly, whether this script is frozen or not.
import sys
root = Path(sys.argv[1]).resolve()
old = root.parent
baseline = root / "baseline"
new = root / "main"
assert (baseline / "COMPLETED.txt").exists() and (new / "COMPLETED.txt").exists()
manifest = json.loads((root / "original-results-sha256.json").read_text())
assert len(manifest) == 1200
for name, expected in manifest.items():
    canonical = old / "jobs" / Path(name).name
    assert hashlib.sha256(canonical.read_bytes()).hexdigest() == expected, name
old_jobs = sorted(old / "jobs" / Path(name).name for name in manifest)
new_jobs = sorted((new / "jobs").glob("*.rds"))
assert len(old_jobs) == 1200 and len(new_jobs) == 400
summary = list(csv.DictReader((new / "summary.csv").open()))
assert len(summary) == 8 and all(int(r["completed"]) == 200 and int(r["failures"]) == 0 for r in summary)
target = root / "combined"
(target / "jobs").mkdir(parents=True, exist_ok=True)
for job in old_jobs + new_jobs:
    link = target / "jobs" / job.name
    if link.is_symlink():
        assert link.resolve() == job.resolve()
    else:
        assert not link.exists()
        link.symlink_to(job)
assert len(list((target / "jobs").glob("*.rds"))) == 1600
with (target / "design.csv").open("w") as handle:
    writer = csv.DictWriter(handle, fieldnames=["scenario", "n", "replicate"])
    writer.writeheader()
    for phase in [baseline, new]:
        writer.writerows(csv.DictReader((phase / "design.csv").open()))
with (target / "summary.log").open("w") as log:
    subprocess.run(["Rscript", str(source / "summarize.R"), str(target)], stdout=log, stderr=subprocess.STDOUT, check=True)
summary = list(csv.DictReader((target / "summary.csv").open()))
assert len(summary) == 32 and all(int(r["completed"]) == 200 and int(r["failures"]) == 0 for r in summary)
old_summary = list(csv.DictReader((baseline / "summary.csv").open()))
lookup = {(r["scenario"], r["n"], r["method"]): r for r in summary}
for original in old_summary:
    combined = lookup[original["scenario"], original["n"], original["method"]]
    for metric in ["mean_estimate", "bias", "rmse", "coverage", "mean_se", "empirical_sd"]:
        assert abs(float(original[metric]) - float(combined[metric])) < 1e-13
(target / "VALIDATION.md").write_text(
    "# Four-scenario validation\n\n"
    "All 1,200 previous corrected dataset checkpoints match their pre-extension SHA256 hashes. "
    "The original 24 summary rows reproduce their previous values. "
    "The 400 new datasets passed independent validation in ../main/VALIDATION.md. "
    "The combined report contains 1,600 datasets, 6,400 returned method estimates, "
    "and 200 replications in each of the 32 method/scenario/sample-size cells. "
    "MSE and all performance metrics use the causal target 0.75.\n")
provenance = {
    "original_result_manifest": str(root / "original-results-sha256.json"),
    "original_fingerprint": (baseline / "fingerprint.txt").read_text().strip(),
    "extension_fingerprint": (new / "fingerprint.txt").read_text().strip(),
    "old_datasets": 1200, "new_datasets": 400,
    "original_estimates_unchanged": True,
}
(target / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
(target / "fingerprint.txt").write_text(hashlib.sha256(json.dumps(provenance, sort_keys=True).encode()).hexdigest() + "\n")
(target / "COMPLETED.txt").write_text(datetime.now(ZoneInfo("America/New_York")).isoformat() + "\n")
# Publish the newest four-scenario results to the agreed canonical location.
# The 1,200 original checkpoint files remain byte-for-byte unchanged.
for job in new_jobs:
    link = old / "jobs" / job.name
    if link.is_symlink():
        assert link.resolve() == job.resolve()
    else:
        assert not link.exists()
        link.symlink_to(job)
assert len(list((old / "jobs").glob("*.rds"))) == 1600
all_hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in old_jobs + new_jobs}
(target / "checkpoint-manifest.json").write_text(json.dumps(all_hashes, indent=2) + "\n")
for artifact in target.iterdir():
    if artifact.is_file() and artifact.name != "COMPLETED.txt":
        tmp = old / ("." + artifact.name + ".neither-update.tmp")
        shutil.copy2(artifact, tmp)
        tmp.replace(old / artifact.name)
shutil.copy2(target / "COMPLETED.txt", old / "COMPLETED.txt")
print(old / "REPORT.md")
