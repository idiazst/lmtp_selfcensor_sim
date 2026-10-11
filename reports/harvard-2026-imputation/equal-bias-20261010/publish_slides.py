"""Publish the verified, final Beamer update to the user-authorized talk folder.

Run only after final rendering and review. The caller must obtain the filesystem
tool's ordinary escalation for the explicitly requested external folder write.
"""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import os
import shutil
from pypdf import PdfReader

here = Path(__file__).resolve().parent
target = Path('/Users/ivan/Library/CloudStorage/GoogleDrive-diazi07@nyu.edu/My Drive/presentations/2026 Harvard')
meta = json.loads((here / 'provenance.json').read_text())
assert meta['final'] is True and meta['replications'] == [200]
assert meta['updated_frames'] == 3
tex = here / 'slides-with-simulation.tex'
pdf = here / 'slides-with-simulation.pdf'
assert pdf.stat().st_mtime >= tex.stat().st_mtime, 'Recompile after the last source edit'
reader = PdfReader(pdf)
assert len(reader.pages) == meta['integrated_frames']
text = '\n'.join(p.extract_text() for p in reader.pages)
# Other simulations retain their existing preliminary labels.
for page in meta['updated_slides']:
    assert 'preliminary' not in reader.pages[page-1].extract_text().lower()
for phrase in ['Simulation results', 'data-generating process', '200 replications']:
    assert phrase in text
source_hash = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert source_hash(target / 'slides.tex') == meta['original_sha256'], 'The user edited the talk: rebuild from its current source'
assert source_hash(target / 'slides.pdf') == meta['original_pdf_sha256'], 'The talk PDF changed: inspect before publishing'
stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
backup = here / 'backups' / stamp
backup.mkdir(parents=True)
for name in ['slides.tex', 'slides.pdf']:
    shutil.copy2(target / name, backup / name)
temps = []
for source, name in [(tex, 'slides.tex'), (pdf, 'slides.pdf')]:
    temporary = target / ('.' + name + '.simulation-update.tmp')
    shutil.copy2(source, temporary)
    assert source_hash(temporary) == source_hash(source)
    temps.append((temporary, target / name))
assert source_hash(target / 'slides.tex') == meta['original_sha256'], 'Talk changed during staging'
assert source_hash(target / 'slides.pdf') == meta['original_pdf_sha256'], 'Talk PDF changed during staging'
for temporary, destination in temps:
    os.replace(temporary, destination)
assert source_hash(target / 'slides.tex') == source_hash(tex)
assert source_hash(target / 'slides.pdf') == source_hash(pdf)
receipt = dict(delivered_at=datetime.now().astimezone().isoformat(),
               tex=str(target / 'slides.tex'), pdf=str(target / 'slides.pdf'),
               tex_sha256=source_hash(target / 'slides.tex'), pdf_sha256=source_hash(target / 'slides.pdf'),
               backup=str(backup), updated_slides=meta['updated_slides'], frames=meta['integrated_frames'])
(here / 'DELIVERED.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
