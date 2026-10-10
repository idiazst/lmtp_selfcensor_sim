"""Run all current MI scenarios from scratch with the validated fitting functions."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--workers', type=int, default=8)
parser.add_argument('--replications', type=int, default=200)
parser.add_argument('--sizes', default='1000,4000')
parser.add_argument('--scenarios', default='mar_only,shadow_only,both,neither')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
out = args.output.resolve()
sizes = [int(n) for n in args.sizes.split(',')]
scenarios = args.scenarios.split(',')
assert args.workers > 0 and args.replications > 0
assert sizes and len(sizes) == len(set(sizes))
assert scenarios and len(scenarios) == len(set(scenarios))
assert set(sizes) <= {1000, 4000}
assert set(scenarios) <= {'mar_only', 'shadow_only', 'both', 'neither'}
if out.exists():
    raise SystemExit('Use a new output directory; existing checkpoints are never overwritten.')
source = out / 'source'
source.mkdir(parents=True)
validated = repo / 'studies/imputation/neither'
for name in ['dgp.R', 'study.R', 'original-helpers.R', 'bridge_run.R']:
    shutil.copy2(validated / name, source / name)
for name in ['validate.R', 'summarize.R']:
    shutil.copy2(Path(__file__).with_name(name), source / name)
shutil.copy2(repo / 'scripts/setup.R', source / 'runtime-setup.R')
shutil.copy2(Path(__file__).with_name('fresh_driver.R'), source / 'fresh_driver.R')
settings = {'sizes': sizes, 'scenarios': scenarios, 'replications': args.replications,
            'workers': args.workers}
(source / 'design.json').write_text(json.dumps(settings, indent=2) + '\n')
manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in source.iterdir()}
fingerprint = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
(source / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(out / 'fingerprint.txt').write_text(fingerprint + '\n')
env = os.environ.copy()
env.update(SIM_REPO=str(repo), MI_STUDY_ROOT=str(repo / '.runtime'),
           MI_STUDY_SOURCE=str(source), MI_LMTP_SOURCE=str(source),
           MI_LMTP_ROOT=str(out), MI_LMTP_PHASE='main',
           MI_SOURCE_FINGERPRINT=fingerprint, MI_LMTP_FINGERPRINT=fingerprint,
           MI_LMTP_WORKERS=str(args.workers), OMP_NUM_THREADS='1',
           OPENBLAS_NUM_THREADS='1', VECLIB_MAXIMUM_THREADS='1')
print('Frozen fresh design:', settings, flush=True)
print('Output:', out, 'fingerprint:', fingerprint, flush=True)
with (out / 'run.log').open('w') as log:
    subprocess.run(['Rscript', str(source / 'fresh_driver.R')], cwd=repo,
                   env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
print('Completed; results:', out / 'main/REPORT.md')
