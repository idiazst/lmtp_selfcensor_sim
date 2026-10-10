"""Record the current implementation without including generated study outputs."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
files=[]
for name in ['studies','scripts','dependencies']:
    files.extend(p for p in (root/name).rglob('*') if p.is_file() and p.name!='SOURCE-SHA256.json')
manifest={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}
(root/'SOURCE-SHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Recorded',len(manifest),'current source and dependency checksums.')
