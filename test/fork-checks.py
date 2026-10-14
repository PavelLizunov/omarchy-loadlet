"""Preserve upstream-owned bytes and the explicit existing fork boundary."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
boundary = json.loads((root / 'docs/fork-boundary.json').read_text())

def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()

def unchanged(expected, actual):
    assert set(expected) <= set(actual), 'An upstream-owned file is missing'
    assert all(actual[name] == oid for name, oid in expected.items()), 'Upstream-owned bytes changed'

unchanged({'fixture': 'old'}, {'fixture': 'old'})
for actual in [{}, {'fixture': 'changed'}]:
    try:
        unchanged({'fixture': 'old'}, actual)
    except AssertionError:
        pass
    else:
        raise AssertionError('Upstream boundary negative control failed')

assert boundary['upstream'] == 'b25a98c7ff2a688ab74d86d2be42249e2db2f9cf'
assert len(boundary['unchanged']) == 12 and len(boundary['modified']) == 14 and len(boundary['deleted']) == 4
assert not (set(boundary['unchanged']) & set(boundary['modified']))
assert not (set(boundary['deleted']) & (set(boundary['unchanged']) | set(boundary['modified'])))
actual = {name: blob((root / name).read_bytes()) for name in boundary['unchanged'] if (root / name).is_file()}
unchanged(boundary['unchanged'], actual)
assert all((root / name).is_file() for name in boundary['modified'])
assert all(not (root / name).exists() for name in boundary['deleted'])
print(f'PASS fork boundary: {len(actual)} upstream files exact; {len(boundary["modified"])} existing modified owners; '
      f'{len(boundary["deleted"])} historical deletions unchanged; missing/changed controls PASS')
