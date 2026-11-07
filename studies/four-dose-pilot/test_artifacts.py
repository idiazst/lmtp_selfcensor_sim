"""Offline artifact safety, deduplication and partial-resume regression checks."""
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import artifacts


FINGERPRINT = "a" * 64
JOB = "jobs/observed-n1000-r1-optimized/"


def payloads(**extra):
    values = {
        "source-fingerprint.txt": FINGERPRINT + "\n",
        "source-manifest.json": '{"test.R":"123"}\n',
        "run-config.json": '{"crossfit":"outer","outer_folds":4,"replicates":[1,2]}\n',
        "design.csv": "design,n,rep,seed\nobserved,1000,1,7201001\n",
        JOB + "usage.json": json.dumps({"fingerprint": FINGERPRINT, "exit_code": 0}),
    }
    values.update(extra)
    return values


def archive_bytes(values):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w") as archive:
        for name, value in values.items():
            archive.writestr(name, value)
    return stream.getvalue()


def item(identity=10, replicate=1, kind="shard"):
    return {"id": identity, "name": f"test-r{replicate}-attempt1", "replicate": replicate,
            "kind": kind, "expired": False, "workflow_run": {"id": 100}}


class ArtifactTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.target = Path(self.directory.name)
        self.versions = {}

    def tearDown(self):
        self.directory.cleanup()

    def ingest(self, values, identity=10, **kwargs):
        with zipfile.ZipFile(io.BytesIO(archive_bytes(values))) as archive:
            artifacts.ingest_archive(archive, self.target, item(identity, **kwargs), self.versions)

    def test_partial_attempts_union_and_all_usage_retained(self):
        self.ingest(payloads(**{JOB + "sdr.rds": b"SDR", JOB + "worker.log": "first"}))
        # Later attempt lacks SDR but must preserve its original checkpoint.
        usage = json.dumps({"fingerprint": FINGERPRINT, "exit_code": 1})
        self.ingest(payloads(**{JOB + "tmle.rds": b"TMLE", JOB + "usage.json": usage,
                               JOB + "worker.log": "second"}), identity=11)
        self.assertEqual((self.target / JOB / "sdr.rds").read_bytes(), b"SDR")
        self.assertEqual((self.target / JOB / "tmle.rds").read_bytes(), b"TMLE")
        self.assertEqual((self.target / JOB / "worker.log").read_text(), "second")
        self.assertEqual((self.target / "artifact-history/10" / JOB / "worker.log").read_text(), "first")
        self.assertEqual(json.loads((self.target / "artifact-history/11" / JOB / "usage.json").read_text())["exit_code"], 1)

    def test_older_attempt_does_not_replace_latest_usage(self):
        self.ingest(payloads(**{JOB + "worker.log": "new"}), identity=20)
        self.ingest(payloads(**{JOB + "worker.log": "old"}), identity=10)
        self.assertEqual((self.target / JOB / "worker.log").read_text(), "new")

    def test_conflicting_checkpoint_rejects_whole_archive(self):
        self.ingest(payloads(**{JOB + "sdr.rds": b"original"}))
        with self.assertRaisesRegex(ValueError, "Conflicting immutable"):
            self.ingest(payloads(**{JOB + "sdr.rds": b"changed", JOB + "tmle.rds": b"new"}), identity=11)
        self.assertFalse((self.target / JOB / "tmle.rds").exists())
        self.assertEqual((self.target / JOB / "sdr.rds").read_bytes(), b"original")

    def test_fingerprint_and_config_conflicts_rejected(self):
        self.ingest(payloads())
        for name, value in [("source-fingerprint.txt", "b" * 64),
                            ("run-config.json", '{"outer_folds":3}'),
                            ("source-manifest.json", '{"test.R":"456"}'),
                            ("design.csv", "design,n,rep,seed\nfull,1000,1,7201001\n")]:
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "Conflicting"):
                self.ingest(payloads(**{name: value}), identity=11)

    def test_equivalent_json_formatting_accepted(self):
        self.ingest(payloads())
        self.ingest(payloads(**{"source-manifest.json": '{\n "test.R" : "123"\n}'}), identity=11)

    def test_missing_fingerprint_is_rejected(self):
        values = payloads()
        del values["source-fingerprint.txt"]
        with self.assertRaisesRegex(ValueError, "fingerprint"):
            self.ingest(values)
        self.assertFalse((self.target / "design.csv").exists())

    def test_wrong_replicate_and_usage_identity_rejected(self):
        for values in [payloads(**{"jobs/full-n4000-r2-optimized/sdr.rds": b"wrong"}),
                       payloads(**{JOB + "usage.json": '{"fingerprint":"wrong"}'})]:
            with self.assertRaises(ValueError):
                self.ingest(values)

    def test_zip_traversal_absolute_and_windows_names_rejected(self):
        for name in ("../outside", "/tmp/outside", "jobs/../../outside", "C:\\outside", "jobs\\outside"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.ingest(payloads(**{name: "bad"}))

    def test_target_symlink_escape_rejected(self):
        with tempfile.TemporaryDirectory() as outside:
            (self.target / "jobs").symlink_to(outside)
            with self.assertRaisesRegex(ValueError, "escapes"):
                self.ingest(payloads(**{JOB + "sdr.rds": b"bad"}))

    def test_all_attempts_kept_and_unrelated_expired_skipped(self):
        values = [dict(item(10), name="test-r1-attempt1"),
                  dict(item(11), name="test-r1-attempt2"),
                  dict(item(12), name="test-r2-attempt1"),
                  dict(item(13), name="test-design-1-250"),
                  dict(item(14), name="test-r3-attempt1", expired=True),
                  dict(item(15), name="other-r1-attempt1")]
        selected = artifacts.select_artifacts([{"artifacts": values[:2]}, {"artifacts": values[2:]}], "test", 1)
        self.assertEqual([x["id"] for x in selected], [10, 11, 13])

    def test_collect_downloads_only_new_ids_and_preserves_provenance(self):
        listing = [{"artifacts": [dict(item(), name="test-r1-attempt1")]}]
        archive = archive_bytes(payloads(**{JOB + "sdr.rds": b"SDR"}))
        downloads = []

        def fake_run(command, **kwargs):
            if command[-1].endswith("/zip"):
                downloads.append(command[-1])
                kwargs["stdout"].write(archive)
                return subprocess.CompletedProcess(command, 0)
            self.assertIn("--paginate", command)
            self.assertIn("--slurp", command)
            return subprocess.CompletedProcess(command, 0, stdout=json.dumps(listing).encode())

        with patch.object(artifacts.subprocess, "run", side_effect=fake_run):
            artifacts.collect("test", self.target)
            artifacts.collect("test", self.target)
        self.assertEqual(len(downloads), 1)
        provenance = json.loads((self.target / "artifact-provenance.json").read_text())
        self.assertEqual(len(provenance), 1)
        manifest = json.loads((self.target / "checkpoint-manifest.json").read_text())
        self.assertIn(JOB + "sdr.rds", manifest)


if __name__ == "__main__":
    unittest.main()
