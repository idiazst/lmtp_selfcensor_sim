"""Keep full numerical records in GitHub-sized, reproducible gzip files."""
from pathlib import Path
import gzip
import shutil
import sys

root = Path(sys.argv[1])
replacements = {}
for path in root.glob('*.csv'):
    if path.stat().st_size <= 10_000_000:
        continue
    output = path.with_suffix('.csv.gz')
    with path.open('rb') as source, output.open('wb') as raw:
        with gzip.GzipFile(filename='', fileobj=raw, mode='wb', mtime=0) as target:
            shutil.copyfileobj(source, target)
    replacements[path.name] = output.name
report = root / 'REPORT.md'
text = report.read_text()
for before, after in replacements.items():
    text = text.replace('(' + before + ')', '(' + after + ')')
report.write_text(text)
print('Compressed complete diagnostic tables:', replacements)
