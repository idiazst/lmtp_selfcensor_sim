"""Update only the three existing MI frames from validated four-scenario results."""
from pathlib import Path
import csv
import hashlib
import json
import re
import shutil

HERE = Path(__file__).resolve().parent
STUDY = HERE.parents[2] / 'results' / 'imputation'
TALK = Path('/Users/ivan/Library/CloudStorage/GoogleDrive-diazi07@nyu.edu/My Drive/presentations/2026 Harvard/slides.tex')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
for p in [STUDY/'COMPLETED.txt', STUDY/'neither/combined/COMPLETED.txt',
          STUDY/'neither/main/VALIDATION.md', STUDY/'VALIDATION.md']:
    assert p.exists(), f'Final validation is not complete: {p}'
summary = list(csv.DictReader((STUDY/'summary.csv').open()))
replicates = list(csv.DictReader((STUDY/'replicates.csv').open()))
audits = list(csv.DictReader((STUDY/'audit-summary.csv').open()))
methods = ['mi_tmle', 'mi_sdr', 'bridge_tmle', 'bridge_sdr']
scenarios = ['mar_only', 'shadow_only', 'both', 'neither']
labels = dict(zip(scenarios, ['MAR only', 'Shadow only', 'Both hold', 'Neither holds']))
assert len(list((STUDY/'jobs').glob('*.rds'))) == 1600
assert len(summary) == 32 and len(replicates) == len(audits) == 6400
assert sum(int(a['completed_data_calls']) for a in audits) == 160000
assert all(int(a['failed_calls']) == int(a['support_failures']) == 0 for a in audits)
lookup = {(r['scenario'], int(r['n']), r['method']): r for r in summary}
assert len(lookup) == 32
rows = []
for scenario in scenarios:
    for n in [1000, 4000]:
        cells = []
        for method in methods:
            r = lookup[scenario, n, method]
            assert int(r['completed']) == int(r['successful']) == 200 and int(r['failures']) == 0
            values = [v for v in replicates if (v['scenario'], int(v['n']), v['method']) == (scenario, n, method)]
            assert len(values) == 200 and len({v['replicate'] for v in values}) == 200
            assert all(float(v['truth']) == .75 and not v['error'] for v in values)
            mean = sum(float(v['estimate']) for v in values)/200
            mse = sum((float(v['estimate'])-.75)**2 for v in values)/200
            coverage = sum(float(v['lower']) <= .75 <= float(v['upper']) for v in values)/200
            for actual, expected in [(mean, r['mean_estimate']), (mse, r['mse']),
                                     (coverage, r['coverage']), (mse, float(r['rmse'])**2)]:
                assert abs(actual-float(expected)) < 1e-12
            cells.append(r'\shortstack{$' + f'{mean:.3f}' + r'$ ($' + f'{100*coverage:.1f}' +
                         r'$)\\[-1pt]$' + f'{1000*mse:.2f}' + '$}')
        rows.append(f"{labels[scenario] if n == 1000 else ''} & {n:,} & " + ' & '.join(cells) + r' \\')
        if n == 4000 and scenario != 'neither':
            rows.append(r'\addlinespace[3pt]')

original = TALK.read_text()
integrated = original
blocks = {}
for section in ['main slides', 'appendix']:
    pattern = r'% BEGIN CMBridge MI comparison: ' + section + r'.*?% END CMBridge MI comparison: ' + section
    matches = list(re.finditer(pattern, original, re.S))
    assert len(matches) == 1
    blocks[section] = matches[0].group()

main = blocks['main slides']
old_bullet = r'''    \item Estimands under no identification are $\approx 0.61$ in both
      settings.'''
new_bullet = r'''    \item With one assumption violated, that method's population limit is $\approx 0.61$.
    \item With neither assumption, both limits are $0.664$: bias $-0.086$ for each.'''
assert main.count(old_bullet) == 1, 'Inspect newer user edits before rebuilding'
main = main.replace(old_bullet, new_bullet)
main = main.replace('Intervention is $A=1$.', 'Intervention assigns $A_1=1$ to everyone.')
assert main.count(r'Both hold & Holds & Holds\\') == 1
main = main.replace(r'Both hold & Holds & Holds\\', r'Both hold & Holds & Holds\\' + '\n' + r'Neither holds & Fails & Fails\\')
# Replace only the data rows of the existing results table, retaining user layout edits.
results_start = main.index(r'\begin{frame}{Simulation results}')
left = main.index('MAR only & 1,000', results_start)
right = main.index(r'\bottomrule', left)
main = main[:left] + '\n'.join(rows) + '\n' + main[right:]
main = main.replace(r'\renewcommand{\arraystretch}{1.05}', r'\renewcommand{\arraystretch}{1.0}')

appendix = blocks['appendix']
old_law = r'Both hold & $0.6+0.1W$\\ \bottomrule'
new_law = r'''Both hold & $0.6+0.1W$\\
Neither holds & $0.675+0.1W+0.15A_1-0.3Y_2$\\ \bottomrule'''
assert appendix.count(old_law) == 1
appendix = appendix.replace(old_law, new_law)
for section, updated in [('main slides', main), ('appendix', appendix)]:
    integrated = integrated.replace(blocks[section], updated)

# Everything outside our marked frames must remain byte-for-byte equivalent.
def remove_ours(s):
    for section in blocks:
        s = re.sub(r'% BEGIN CMBridge MI comparison: ' + section +
                   r'.*?% END CMBridge MI comparison: ' + section, '', s, flags=re.S)
    return s
assert remove_ours(original) == remove_ours(integrated)
active_frames = lambda s: len(re.findall(r'^\s*\\begin\{frame\}', s, re.M))
assert active_frames(original) == active_frames(integrated)
assert active_frames(main + appendix) == 3
slide_numbers = [active_frames(original[:original.index(blocks['main slides'])])+1]
slide_numbers += [slide_numbers[0]+1, active_frames(original[:original.index(blocks['appendix'])])+1]
preview = original.split(r'\begin{document}')[0] + '\\begin{document}\n' + main + '\n' + appendix + '\n\\end{document}\n'
(HERE/'slides-with-simulation.tex').write_text(integrated)
(HERE/'simulation-slides.tex').write_text(preview)
(HERE/'simulation-frames.tex').write_text(main+'\n'+appendix+'\n')
shutil.copy2(TALK, HERE/'before.tex')
shutil.copy2(TALK.with_suffix('.pdf'), HERE/'before.pdf')
meta = dict(final=True, original_source=str(TALK), original_sha256=sha(TALK),
            original_pdf_sha256=sha(TALK.with_suffix('.pdf')),
            summary_sha256=sha(STUDY/'summary.csv'), source_fingerprint=(STUDY/'fingerprint.txt').read_text().strip(),
            replications=[200], datasets=1600, returned_estimates=6400, standard_lmtp_calls=160000,
            integrated_frames=active_frames(integrated), updated_frames=3, updated_slides=slide_numbers,
            outside_mi_frames_unchanged=True,
            packages={'cmbridge':'0.3.0.9020', 'lmtp':'1.6.0.9021', 'mice':'3.19.0'})
(HERE/'provenance.json').write_text(json.dumps(meta, indent=2)+'\n')
print(json.dumps(meta, indent=2))
