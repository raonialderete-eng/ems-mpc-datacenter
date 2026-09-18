"""Read-only verification of evidence hashes and exported fragments."""
from pathlib import Path
import hashlib
import json
import warnings

here = Path(__file__).resolve().parent
root = here.parents[2]
manifest = json.loads((here / 'manifesto_fontes.json').read_text(encoding='utf-8'))
checks = []
for group, base in [('source_files', root), ('outputs', here)]:
    for item in manifest[group]:
        path = base / item['path']
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        assert actual == item['sha256'], f'Hash mismatch: {path}'
        checks.append(str(path.relative_to(root)))
with warnings.catch_warnings():
    warnings.simplefilter('error', SyntaxWarning)
    compile((here / 'gerar_tabelas.py').read_text(encoding='utf-8'), 'gerar_tabelas.py', 'exec')
tables = list((here / 'tabelas').glob('[0-9][0-9]_*.tex'))
assert len(tables) == 5
equations = (here / 'tabelas/equacoes_qp.tex').read_text(encoding='utf-8')
assert equations.count(r'\begin{equation}') == manifest['equation_blocks'] == 13
for path in (here / 'tabelas').glob('*.tex'):
    content = path.read_text(encoding='utf-8')
    assert content.count('{') == content.count('}'), path
print(json.dumps(dict(passed=True, checked_hashes=len(checks), tables=5,
                     equation_blocks=13, generator_syntax='passed',
                     latex_layout='not validated'), indent=2))
