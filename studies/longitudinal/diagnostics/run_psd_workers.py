"""Run independent paired datasets, checkpointing each projection version."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("--workers", type=int, default=8)
parser.add_argument("--first", type=int, default=1)
parser.add_argument("--last", type=int, default=100)
args = parser.parse_args()
assert 1 <= args.workers <= 10 and 1 <= args.first <= args.last <= 100
out = Path(os.environ.get("PSD_OUTPUT", "results/longitudinal/psd-numerical-n4000-v2"))
out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1", VECLIB_MAXIMUM_THREADS="1")
started = dt.datetime.now().astimezone()
queue = list(range(args.first, args.last + 1))
active = {}
finished = []
failed = []
logs = []

def stop(signum, frame):
    raise KeyboardInterrupt

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
(out / "run.pid").write_text(str(os.getpid()) + "\n")
(out / "run-started-at.txt").write_text(started.isoformat() + "\n")
try:
    while queue or active:
        while queue and len(active) < args.workers:
            i = queue.pop(0)
            log = (out / f"dataset-{i:03d}.log").open("a")
            logs.append(log)
            proc = subprocess.Popen(["Rscript", "studies/longitudinal/diagnostics/run_psd_comparison.R"],
                env=dict(env, PSD_TASKS=str(i)), stdout=log, stderr=subprocess.STDOUT)
            active[i] = proc
        for i, proc in list(active.items()):
            code = proc.poll()
            if code is None:
                continue
            (finished if code == 0 else failed).append(i)
            del active[i]
            print(f"Dataset {i}: process exit {code}; {len(finished)} completed, {len(failed)} process failures", flush=True)
        paths = list((out / "jobs").glob("*.rds"))
        paired = sum((out / "jobs" / f"r{i:03d}-psd.rds").exists() and
                     (out / "jobs" / f"r{i:03d}-raw.rds").exists() for i in range(1, 101))
        progress = {"updated": dt.datetime.now().astimezone().isoformat(), "paired_datasets": paired,
            "dataset_version_checkpoints": len(paths), "planned_datasets": 100,
            "workers": args.workers, "active_datasets": list(active),
            "remaining_in_queue": len(queue), "process_failures": failed}
        (out / "PROGRESS.json").write_text(json.dumps(progress, indent=2) + "\n")
        if queue or active:
            time.sleep(15)
    if failed:
        raise RuntimeError(f"R processes failed for datasets {failed}; checkpoints retained")
    manifest = json.loads((out / "source-manifest.json").read_text())
    for name, expected in manifest.items():
        assert hashlib.sha256(Path(name).read_bytes()).hexdigest() == expected, name
    checkpoints = list((out / "jobs").glob("*.rds"))
    if len(checkpoints) == 200:
        log = (out / "postprocessing.log").open("a")
        logs.append(log)
        subprocess.run(["Rscript", "studies/longitudinal/diagnostics/report_psd_comparison.R"],
            env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
        finished_at = dt.datetime.now().astimezone()
        (out / "runtime.json").write_text(json.dumps({"start": started.isoformat(), "end": finished_at.isoformat(),
            "supervisor_wall_seconds": (finished_at - started).total_seconds(), "workers": args.workers,
            "datasets_assigned": args.last - args.first + 1, "all_100_paired_datasets": True,
            "report_sha256": hashlib.sha256((out / "REPORT.md").read_bytes()).hexdigest()}, indent=2) + "\n")
        (out / "FITTING-COMPLETED.txt").write_text(finished_at.isoformat() + "\n")
        print("All 100 paired datasets processed; report, tables and plots saved.", flush=True)
    else:
        print(f"Assigned jobs finished; {len(checkpoints)}/200 checkpoints saved. Other workers may still be running.", flush=True)
finally:
    for proc in active.values():
        if proc.poll() is None:
            proc.terminate()
    for log in logs:
        log.close()
