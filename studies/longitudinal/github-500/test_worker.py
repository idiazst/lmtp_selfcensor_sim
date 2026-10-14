"""Exercise checkpoint orchestration without running a statistical simulation."""
import csv
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class WorkerChecks(unittest.TestCase):
    def exercise(self, failed_job=None):
        runner = Path(__file__).resolve().with_name("worker.py")
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            metadata = root / "work/metadata"
            metadata.mkdir(parents=True)
            rows = [{"replicate": "1", "n": str(n), "mechanism": m,
                     "job": f"{m}-n{n}-r001"}
                    for n in (500, 1000, 4000, 10000)
                    for m in ("binary_longitudinal", "discrete_dose")]
            with (metadata / "design.csv").open("w") as stream:
                writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
                writer.writeheader(); writer.writerows(rows)
            (metadata / "source-fingerprint.txt").write_text("fixture-only\n")
            fake = root / "fake-rscript"
            fake.write_text("#!/usr/bin/env python3\n"
                "import os, pathlib, time\n"
                "job=os.environ['FULL_JOB']; out=pathlib.Path(os.environ['FULL_OUTPUT'])\n"
                "time.sleep(.02)\n"
                "if job==os.environ.get('TEST_FAILED_JOB'): raise SystemExit(7)\n"
                "(out/'jobs').mkdir(exist_ok=True)\n"
                "(out/'jobs'/(job+'.rds')).write_bytes(b'fixture checkpoint; no R fit')\n")
            fake.chmod(0o700)
            env = dict(os.environ, FULL_REPLICATE="1", FULL_RSCRIPT=str(fake),
                       FULL_WORKERS="2", TEST_FAILED_JOB=failed_job or "")
            run = subprocess.run(["python3", str(runner)], cwd=root, env=env,
                                 capture_output=True, text=True, timeout=90)
            saved = list((root / "work/shard/jobs").glob("*.rds"))
            manifest = json.loads((root / "work/shard/checkpoint-manifest.json").read_text())
            failures = json.loads((root / "work/shard/infrastructure-failures.json").read_text())
            self.assertEqual(len(saved), len(manifest))
            return run.returncode, len(saved), failures

    def test_all_eight_datasets_checkpoint(self):
        code, saved, failures = self.exercise()
        self.assertEqual((code, saved, failures), (0, 8, []))

    def test_process_failure_preserves_other_checkpoints(self):
        job = "discrete_dose-n10000-r001"
        code, saved, failures = self.exercise(job)
        self.assertNotEqual(code, 0)
        self.assertEqual(saved, 7)
        self.assertEqual(failures[0]["job"], job)
        self.assertEqual(failures[0]["exit_code"], 7)


if __name__ == "__main__":
    unittest.main()
