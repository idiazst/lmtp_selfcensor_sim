"""Run immutable four-dose simulation shards from the repository root."""
import argparse
import csv
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor


ROOT = Path.cwd()
STUDY = ROOT / "studies/four-dose-pilot"


def numerical_manifest():
    paths = [STUDY / name for name in ("common.R", "run_one.R", "run.py", "check_installed.R")]
    paths.extend(ROOT / "studies" / design / "four_dose_pilot.R"
                 for design in ("longitudinal", "full-history"))
    paths.append(ROOT / "studies/full-history/verify_four_dose_design.py")
    manifest = {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in paths}
    source_root = Path(os.environ.get("FOUR_DOSE_SOURCE_ROOT", ROOT.parent))
    for package in ("cmbridge", "lmtp"):
        source = source_root / package
        package_paths = [source / "DESCRIPTION", source / "NAMESPACE"]
        package_paths.extend(sorted((source / "R").glob("*.R")))
        package_paths.extend(sorted(p for p in (source / "src").glob("*")
                                    if p.suffix not in (".o", ".so", ".dll")))
        for path in package_paths:
            key = f"packages/{package}/{path.relative_to(source).as_posix()}"
            manifest[key] = hashlib.sha256(path.read_bytes()).hexdigest()
    return manifest


def write_json(path, value):
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(value, indent=2) + "\n")
    tmp.replace(path)


def fit_dataset(job, out, fingerprint, env, requested_variants):
    design, n, rep = job
    variants = requested_variants
    if len(variants) == 2 and rep % 2 == 0:
        variants = list(reversed(variants))
    for variant in variants:
        folder = out / "jobs" / f"{design}-n{n}-r{rep}-{variant}"
        folder.mkdir(parents=True, exist_ok=True)
        with (folder / ".lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            usage_path = folder / "usage.json"
            saved = [folder / f"{method}.rds" for method in ("sdr", "tmle")]
            if usage_path.exists() and all(p.exists() for p in saved):
                previous = json.loads(usage_path.read_text())
                if previous["fingerprint"] != fingerprint:
                    raise RuntimeError(f"Numerical inputs changed for {folder}")
                if previous["exit_code"] == 0:
                    continue
            args = ["Rscript", "--vanilla", str(STUDY / "run_one.R"), design, str(n),
                    str(rep), variant, str(folder), fingerprint]
            resumed_methods = [p.stem for p in saved if p.is_file()]
            if usage_path.exists():
                previous_usage = json.loads(usage_path.read_text())
                history = folder / "usage-history.jsonl"
                with history.open("a") as stream:
                    stream.write(json.dumps(previous_usage) + "\n")
            started = time.monotonic()
            with (folder / "worker.log").open("a") as log:
                proc = subprocess.Popen(args, env=env, stdout=log, stderr=subprocess.STDOUT)
                _, status, usage = os.wait4(proc.pid, 0)
                proc.returncode = os.waitstatus_to_exitcode(status)
            elapsed = time.monotonic() - started
            rss = usage.ru_maxrss * (1 if sys.platform == "darwin" else 1024)
            write_json(usage_path, dict(fingerprint=fingerprint, wall_seconds=elapsed,
                max_rss_bytes=rss, exit_code=proc.returncode, resumed_methods=resumed_methods))
            print(folder.name, "exit", proc.returncode, f"{elapsed:.1f}s, {rss/2**20:.1f} MiB",
                  flush=True)
            if proc.returncode != 0 or not all(p.is_file() for p in saved):
                raise RuntimeError(f"Infrastructure failure in {folder}; see worker.log")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("results/four-dose-outer-pilot"))
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--sizes", nargs="+", type=int, default=[1000],
                        choices=(1000, 4000, 10000))
    parser.add_argument("--designs", nargs="+", default=["observed", "full"],
                        choices=("observed", "full"))
    parser.add_argument("--replicates", nargs="+", type=int, default=[1])
    parser.add_argument("--study-replicates", type=int,
                        help="Full planned replication count; shard subsets share one fingerprint")
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--variants", nargs="+", default=["optimized"],
                        choices=("baseline", "optimized"))
    parser.add_argument("--crossfit", default="outer", choices=("outer", "recursive"))
    parser.add_argument("--outer-folds", type=int, default=4, choices=(3, 4))
    args = parser.parse_args()
    if args.workers < 1 or min(args.replicates) < 1 or len(set(args.replicates)) != len(args.replicates):
        parser.error("Workers and distinct replicate IDs must be positive.")
    if args.study_replicates is not None and max(args.replicates) > args.study_replicates:
        parser.error("A shard replicate exceeds the planned study.")
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    manifest = numerical_manifest()
    planned_replicates = (list(range(1, args.study_replicates + 1))
                          if args.study_replicates is not None else args.replicates)
    config = dict(crossfit=args.crossfit, outer_folds=args.outer_folds,
                  sizes=args.sizes, replicates=planned_replicates, designs=args.designs,
                  variants=args.variants, profile=os.environ.get("FOUR_DOSE_PROFILE", "baseline"))
    fingerprint = hashlib.sha256(json.dumps(dict(sources=manifest, config=config),
                                           sort_keys=True).encode()).hexdigest()
    marker = out / "source-fingerprint.txt"
    if marker.exists() and marker.read_text().strip() != fingerprint:
        raise RuntimeError("Different numerical configuration. Use a new output directory.")
    if not marker.exists():
        marker.write_text(fingerprint + "\n")
        write_json(out / "source-manifest.json", manifest)
        write_json(out / "run-config.json", config)
    env = os.environ.copy()
    libs = [ROOT / ".runtime/four-dose-outer-library", ROOT / ".runtime/library"]
    env["R_LIBS_USER"] = os.environ.get("R_LIBS_USER", os.pathsep.join(map(str, libs)))
    env["FOUR_DOSE_CROSSFIT"] = args.crossfit
    env["FOUR_DOSE_OUTER_FOLDS"] = str(args.outer_folds)
    for key in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
                "VECLIB_MAXIMUM_THREADS"):
        env[key] = "1"
    subprocess.run(["Rscript", "--vanilla", str(STUDY / "check_installed.R")],
                   env=env, check=True)
    if not (out / "session.txt").exists():
        session = subprocess.check_output(["Rscript", "--vanilla", "-e",
            "library(cmbridge); library(lmtp); sessionInfo()"], env=env, text=True)
        (out / "session.txt").write_text(session)
    if not (out / "truth-check.txt").exists():
        verified = subprocess.check_output([sys.executable,
            str(ROOT / "studies/full-history/verify_four_dose_design.py")], text=True)
        (out / "truth-check.txt").write_text(verified)
    grid = [(d, n, r, 7200000 + n + r) for r in planned_replicates
            for n in args.sizes for d in args.designs]
    with (out / "design.csv").open("w", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["design", "n", "rep", "seed"])
        writer.writerows(grid)
    if args.prepare_only:
        print(f"Prepared {len(grid)} datasets; fingerprint {fingerprint}")
        return
    jobs = [(design, n, rep) for rep in args.replicates
            for n in args.sizes for design in args.designs]
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        tasks = [pool.submit(fit_dataset, job, out, fingerprint, env, args.variants)
                 for job in jobs]
        for task in tasks:
            task.result()


if __name__ == "__main__":
    main()
