"""Collect immutable four-dose checkpoints, including partial earlier attempts.

Run from the simulation repository. Only newly available artifact IDs are
downloaded. Non-checkpoint files from each attempt are retained separately, and
the most recent copy is exposed beside each checkpoint for reporting/resume.
"""
import argparse
import csv
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import tempfile
import zipfile


IDENTITY_FILES = {"source-fingerprint.txt", "source-manifest.json",
                  "run-config.json", "design.csv"}
JOB_PATH = re.compile(
    r"jobs/(observed|full)-n(1000|4000|10000)-r([1-9][0-9]*)-optimized/([^/]+)$")


def write_bytes(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".artifact-part")
    temporary.write_bytes(value)
    temporary.replace(path)


def write_json(path, value):
    write_bytes(path, (json.dumps(value, indent=2, sort_keys=True) + "\n").encode())


def identity_value(name, payload):
    if name.endswith(".json"):
        return json.loads(payload)
    if name == "design.csv":
        return list(csv.DictReader(io.StringIO(payload.decode())))
    return payload.strip()


def select_artifacts(pages, study, replicate=None):
    """Keep every attempt: the newest can contain fewer completed methods."""
    if not re.fullmatch(r"[a-zA-Z0-9_-]{1,80}", study):
        raise ValueError("Invalid study label")
    if replicate is not None and not 1 <= replicate <= 500:
        raise ValueError("Replication must be between 1 and 500")
    shard = re.compile(re.escape(study) + r"-r([1-9][0-9]*)-attempt([1-9][0-9]*)$")
    metadata = re.compile(re.escape(study) + r"-design-([1-9][0-9]*)-([1-9][0-9]*)$")
    selected = []
    for page in pages:
        for item in page["artifacts"]:
            match = shard.fullmatch(item["name"])
            design_match = metadata.fullmatch(item["name"])
            if item["expired"] or not (match or design_match):
                continue
            if match:
                rep = int(match[1])
                if not 1 <= rep <= 500:
                    raise ValueError("Artifact replication is outside the frozen study")
                if replicate is not None and rep != replicate:
                    continue
                selected.append(dict(item, replicate=rep, kind="shard"))
            else:
                first, last = map(int, design_match.groups())
                if not 1 <= first <= last <= 500:
                    raise ValueError("Artifact cohort is outside the frozen study")
                selected.append(dict(item, replicate=None, kind="design"))
    return sorted(selected, key=lambda item: int(item["id"]))


def ingest_archive(archive, target, item, file_versions):
    """Validate a whole ZIP before exposing any of its files to the collector."""
    target = Path(target).resolve()
    payloads = {}
    seen = set()
    for entry in archive.infolist():
        name = entry.filename
        posix = PurePosixPath(name)
        if (not name or name in seen or "\\" in name or posix.is_absolute()
                or ".." in posix.parts or re.match(r"^[a-zA-Z]:", name)
                or stat.S_ISLNK(entry.external_attr >> 16)):
            raise ValueError(f"Unsafe or duplicate artifact member: {name}")
        seen.add(name)
        destination = (target / name).resolve()
        if target not in destination.parents:
            raise ValueError(f"Artifact path escapes the output directory: {name}")
        if entry.is_dir():
            continue
        if name.startswith(("artifact-history/", "artifact-provenance.json",
                            "checkpoint-manifest.json", "collection-state.json")):
            # A rerun may upload its downloaded collection history. Re-ingesting
            # that history is unnecessary and would grow the archive each time.
            continue
        if name.endswith((".part", ".artifact-part")) or Path(name).name == ".lock":
            continue
        if name.startswith("jobs/"):
            job = JOB_PATH.fullmatch(name)
            if not job or item["kind"] != "shard" or int(job[3]) != item["replicate"]:
                raise ValueError(f"Checkpoint belongs to another shard: {name}")
        elif "/" in name:
            raise ValueError(f"Unexpected artifact directory: {name}")
        if name.endswith(".rds") and not JOB_PATH.fullmatch(name):
            raise ValueError(f"Unexpected checkpoint path: {name}")
        payloads[name] = archive.read(entry)

    fingerprint = payloads.get("source-fingerprint.txt", b"").strip()
    if not re.fullmatch(rb"[0-9a-f]{64}", fingerprint):
        raise ValueError(f"Artifact {item['id']} lacks a valid numerical fingerprint")
    if not IDENTITY_FILES.issubset(payloads):
        raise ValueError(f"Artifact {item['id']} lacks the full frozen study metadata")
    for name, value in payloads.items():
        existing = target / name
        if name in IDENTITY_FILES and existing.exists():
            if identity_value(name, existing.read_bytes()) != identity_value(name, value):
                raise ValueError(f"Conflicting {name}; use a separate revision directory")
        if name.endswith(".rds") and existing.exists() and existing.read_bytes() != value:
            raise ValueError(f"Conflicting immutable checkpoint: {name}")
        if name.endswith("/usage.json"):
            usage = json.loads(value)
            if usage.get("fingerprint") != fingerprint.decode():
                raise ValueError(f"Usage record has a different fingerprint: {name}")

    artifact_id = int(item["id"])
    for name, value in payloads.items():
        destination = target / name
        if name.endswith(".rds") or name in IDENTITY_FILES:
            if not destination.exists():
                write_bytes(destination, value)
        else:
            # Keep every attempt's runtime, exit code, warnings and worker log.
            history = target / "artifact-history" / str(artifact_id) / name
            write_bytes(history, value)
            if artifact_id >= file_versions.get(name, 0):
                write_bytes(destination, value)
                file_versions[name] = artifact_id
    return file_versions


def collect(study, target, replicate=None, repository=None):
    repository = repository or os.environ.get("GITHUB_REPOSITORY", "idiazst/lmtp_selfcensor_sim")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Invalid repository name")
    response = subprocess.run(["gh", "api", "--paginate", "--slurp",
        f"repos/{repository}/actions/artifacts?per_page=100"],
        capture_output=True, check=True)
    selected = select_artifacts(json.loads(response.stdout), study, replicate)
    target = Path(target).resolve()
    target.mkdir(parents=True, exist_ok=True)
    state_path = target / "collection-state.json"
    state = json.loads(state_path.read_text()) if state_path.exists() else {
        "study": study, "repository": repository, "artifacts": {}, "file_versions": {}}
    if state["study"] != study or state["repository"] != repository:
        raise ValueError("This output directory belongs to another study/repository")
    downloaded = 0
    for item in selected:
        identity = str(item["id"])
        if identity in state["artifacts"]:
            continue
        with tempfile.TemporaryFile() as archive_file:
            subprocess.run(["gh", "api",
                f"repos/{repository}/actions/artifacts/{identity}/zip"],
                stdout=archive_file, check=True)
            archive_file.seek(0)
            with zipfile.ZipFile(archive_file) as archive:
                ingest_archive(archive, target, item, state["file_versions"])
        state["artifacts"][identity] = {
            "artifact_id": item["id"], "name": item["name"],
            "replicate": item["replicate"], "kind": item["kind"],
            "run_id": item.get("workflow_run", {}).get("id"),
            "created_at": item.get("created_at"), "digest": item.get("digest")}
        write_json(state_path, state)
        downloaded += 1
    provenance = sorted(state["artifacts"].values(), key=lambda item: int(item["artifact_id"]))
    write_json(target / "artifact-provenance.json", provenance)
    paths = sorted((target / "jobs").glob("*/*.rds"))
    manifest = {p.relative_to(target).as_posix(): {
        "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths}
    write_json(target / "checkpoint-manifest.json", manifest)
    print(f"Downloaded {downloaded} new artifacts; {len(provenance)} collected; "
          f"{len(paths)} immutable method checkpoints available.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--study", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--replicate", type=int)
    parser.add_argument("--repository")
    arguments = parser.parse_args()
    collect(arguments.study, arguments.target, arguments.replicate, arguments.repository)
