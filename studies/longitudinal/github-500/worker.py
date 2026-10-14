"""Two independent R fits; immutable checkpoints survive infrastructure reruns."""
import csv
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time


def run():
    replicate = int(os.environ["FULL_REPLICATE"])
    assert 1 <= replicate <= 500
    out = Path(os.environ.get("FULL_OUTPUT", "work/shard"))
    out.mkdir(parents=True, exist_ok=True)
    jobs = [r for r in csv.DictReader(Path("work/metadata/design.csv").open())
            if int(r["replicate"]) == replicate]
    assert len(jobs) == 8 and len({r["job"] for r in jobs}) == 8
    jobs.sort(key=lambda r: (-int(r["n"]), r["mechanism"]))
    started = time.monotonic()
    deadline = int(os.environ.get("FULL_MAX_SECONDS", "17100"))
    slots = int(os.environ.get("FULL_WORKERS", "2"))
    assert 1 <= slots <= 4
    active, failures, logs = {}, [], []

    def stop(signum, frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        while jobs or active:
            while jobs and len(active) < slots and time.monotonic() - started < deadline:
                row = jobs.pop(0)
                log = (out / (row["job"] + ".log")).open("a")
                logs.append(log)
                env = dict(os.environ, FULL_JOB=row["job"], FULL_OUTPUT=str(out),
                           OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1",
                           MKL_NUM_THREADS="1", VECLIB_MAXIMUM_THREADS="1")
                process = subprocess.Popen([os.environ.get("FULL_RSCRIPT", "Rscript"),
                    "studies/longitudinal/github-500/run_one.R"], env=env,
                    stdout=log, stderr=subprocess.STDOUT)
                active[row["job"]] = process
            for job, process in list(active.items()):
                code = process.poll()
                if code is None:
                    continue
                checkpoint = out / "jobs" / (job + ".rds")
                if code != 0 or not checkpoint.exists():
                    failures.append({"job": job, "exit_code": code,
                                     "reason": "Infrastructure process did not save a checkpoint"})
                del active[job]
            if time.monotonic() - started >= deadline:
                failures.extend({"job": j, "reason": "Runner time budget; no statistical result"}
                                for j in list(active) + [r["job"] for r in jobs])
                break
            progress = {"updated": dt.datetime.now(dt.timezone.utc).isoformat(),
                "replicate": replicate, "completed": len(list((out / "jobs").glob("*.rds"))),
                "planned": 8, "active": list(active), "queued": len(jobs),
                "infrastructure_failures": failures}
            (out / "PROGRESS.json").write_text(json.dumps(progress, indent=2) + "\n")
            if jobs or active:
                time.sleep(5)
    finally:
        for process in active.values():
            if process.poll() is None:
                process.terminate()
        for process in active.values():
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
        for log in logs:
            log.close()
        paths = sorted((out / "jobs").glob("*.rds"))
        manifest = {p.name: {"sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths}
        (out / "checkpoint-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        (out / "source-fingerprint.txt").write_text(Path("work/metadata/source-fingerprint.txt").read_text())
        (out / "infrastructure-failures.json").write_text(json.dumps(failures, indent=2) + "\n")
    if failures:
        raise SystemExit("Incomplete infrastructure attempts are preserved; rerun only unfinished jobs.")
    print(f"Replication {replicate}: all 8 datasets checkpointed; numerical failures retained.", flush=True)


if __name__ == "__main__":
    run()
