"""Freeze the local package source used by the four-dose study, without Git metadata."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "dependencies/four-dose"


def freeze(replace=False):
    manifest = {"packages": {}}
    for package in ("cmbridge", "lmtp"):
        source = ROOT.parent / package
        files = []
        for name in ("DESCRIPTION", "NAMESPACE", "LICENSE", "LICENSE.md", "configure", "configure.win"):
            if (source / name).is_file():
                files.append(source / name)
        for name in ("R", "src", "man", "inst", "data"):
            if (source / name).is_dir():
                files.extend(p for p in (source / name).rglob("*") if p.is_file()
                             and p.suffix not in (".o", ".so", ".dll", ".dylib")
                             and p.name != ".DS_Store")
        expected = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in sorted(files)}
        destination = DEST / package
        existing = {str(p.relative_to(destination)): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in sorted(destination.rglob("*")) if p.is_file()}
        if existing and existing != expected and not replace:
            raise RuntimeError(f"Frozen {package} differs. Inspect the changes before using --replace.")
        if existing != expected:
            if destination.exists():
                shutil.rmtree(destination)
            for p in files:
                target = destination / p.relative_to(source)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(p, target)
        fingerprint = hashlib.sha256(json.dumps(expected, sort_keys=True).encode()).hexdigest()
        manifest["packages"][package] = {"files": expected, "sha256": fingerprint}
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("Frozen package source:", ", ".join(
        f"{name} {item['sha256']}" for name, item in manifest["packages"].items()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--replace", action="store_true")
    freeze(parser.parse_args().replace)
