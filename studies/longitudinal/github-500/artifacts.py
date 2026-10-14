"""Read-only artifact recovery and aggregation across both 250-replication runs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile


def collect(study, target, replicate=None):
    assert re.fullmatch(r"[a-zA-Z0-9_-]{1,50}", study)
    repository = os.environ.get("GITHUB_REPOSITORY", "idiazst/lmtp_selfcensor_sim")
    response = subprocess.run(["gh", "api", "--paginate", "--slurp",
        f"repos/{repository}/actions/artifacts?per_page=100"], capture_output=True, check=True)
    pages = json.loads(response.stdout)
    prefix = f"{study}-r"
    candidates = [a for page in pages for a in page["artifacts"]
                  if a["name"].startswith(prefix) and not a["expired"]]
    pattern = re.compile(re.escape(study) + r"-r(\d+)-attempt(\d+)$")
    selected = {}
    for item in candidates:
        match = pattern.fullmatch(item["name"])
        if not match:
            continue
        r = int(match[1])
        if replicate is not None and r != replicate:
            continue
        assert 1 <= r <= 500
        if r not in selected or item["id"] > selected[r]["id"]:
            selected[r] = item
    target = Path(target)
    target.mkdir(parents=True, exist_ok=True)
    provenance = []
    for r, item in sorted(selected.items()):
        with tempfile.TemporaryFile() as downloaded:
            subprocess.run(["gh", "api", f"repos/{repository}/actions/artifacts/{item['id']}/zip"],
                stdout=downloaded, check=True)
            downloaded.seek(0)
            with zipfile.ZipFile(downloaded) as archive:
                for name in archive.namelist():
                    path = (target / name).resolve()
                    if target.resolve() not in path.parents:
                        raise ValueError("Artifact path escapes the output directory")
                    if name.endswith("/"):
                        continue
                    payload = archive.read(name)
                    # Checkpoints are immutable. Different attempts may have different logs.
                    if name.endswith(".rds") and path.exists() and path.read_bytes() != payload:
                        raise ValueError(f"Conflicting checkpoint: {name}")
                    path.parent.mkdir(parents=True, exist_ok=True)
                    if name.endswith(".rds") or replicate is not None:
                        path.write_bytes(payload)
        provenance.append({"replicate": r, "artifact_id": item["id"], "name": item["name"],
                           "run_id": item["workflow_run"]["id"]})
    (target / "artifact-provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    paths = sorted((target / "jobs").glob("*.rds"))
    manifest = {p.name: {"sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths}
    (target / "checkpoint-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Read {len(selected)} shard artifacts; {len(paths)} checkpoints available.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--study", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--replicate", type=int)
    args = parser.parse_args()
    collect(args.study, args.target, args.replicate)
