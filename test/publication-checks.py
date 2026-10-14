"""Keep public-visibility acceptance separate from credential-pattern checks."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]

def private_metadata(text):
    return bool(re.search(r'\b(?:ses|msg)_[A-Za-z0-9]{12,}\b', text)
                or re.search(r'/\.local/share/opencode/(?:log/|opencode\.db)', text))

assert private_metadata('Historical session ' + 'ses_' + 'X' * 24)
assert private_metadata('/home/example/' + '.local/share/' + 'opencode/' + 'opencode.db')
assert not private_metadata('Native QML demonstration data; no private session reference.')

if sys.argv[1:] != ['--public']:
    assert not sys.argv[1:], 'Usage: publication-checks.py [--public]'
    print('PASS publication controls; public-visibility gate not requested')
else:
    rows = subprocess.check_output(
        ['git', '-C', str(root), 'rev-list', '--objects', '--all'], timeout=15).splitlines()
    assert 0 < len(rows) <= 2000, 'Publication object budget exceeded'
    matches, inspected, total = 0, 0, 0
    for row in rows:
        oid = row.split(b' ', 1)[0].decode()
        kind = subprocess.check_output(['git', '-C', str(root), 'cat-file', '-t', oid], timeout=5).strip()
        if kind != b'blob':
            continue
        size = int(subprocess.check_output(['git', '-C', str(root), 'cat-file', '-s', oid], timeout=5))
        total += size
        assert size <= 64 * 1024 * 1024 and total <= 256 * 1024 * 1024, 'Publication blob budget exceeded'
        data = subprocess.check_output(['git', '-C', str(root), 'cat-file', 'blob', oid], timeout=5)
        inspected += 1
        if private_metadata(data.decode('utf-8', errors='replace')):
            matches += 1
    assert inspected, 'Empty publication corpus'
    if matches:
        print(f'BLOCKED public visibility: {matches} reachable blobs contain private diagnostic identifiers or store paths; values withheld')
        sys.exit(1)
    print(f'PASS public metadata heuristic: {inspected} reachable blobs; not universal privacy certification')
