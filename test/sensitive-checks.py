"""Bounded source-secret heuristic with an explicit, nonzero coverage receipt."""
from collections import Counter
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MAX_FILES = 1000
MAX_FILE_BYTES = 3_000_000
MAX_TOTAL_BYTES = 16_000_000
PATTERNS = [
    ('private-key', re.compile(r'-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY')),
    ('aws-key', re.compile(r'\bAKIA[0-9A-Z]{16}\b')),
    ('github-token', re.compile(r'\bgh[pousr]_[A-Za-z0-9]{30,}\b|\bgithub_pat_[A-Za-z0-9_]{30,}\b')),
    ('slack-token', re.compile(r'\bxox[abprs]-[A-Za-z0-9-]{10,}\b')),
    ('jwt', re.compile(r'\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b')),
    ('url-credentials', re.compile(r'://[^/\s:@\'"]{2,}:[^/\s@\'"]{4,}@[\w.-]+')),
    ('key-value', re.compile(r'(?i)\b(?:api[_-]?key|secret|passwd|password|token|auth)\w*\s*[:=]\s*[\'"]([A-Za-z0-9+/_=.-]{16,})[\'"]')),
]
REQUIRED = {'Panel.qml', 'ActivityController.qml', 'ActivityIconSvg.js', 'process-signal',
            'activity-report', 'README.md', 'docs/guide.md', '.github/workflows/check.yml'}
TEXT_TYPES = {'.qml', '.js', '.mjs', '.py', '.cpp', '.h', '.sh', '.md', '.json', '.yml', '.html'}


def findings(text):
    return [(kind, number) for number, line in enumerate(text.splitlines(), 1)
            for kind, pattern in PATTERNS if pattern.search(line)]


def scan(root, paths):
    assert 0 < len(paths) <= MAX_FILES, 'Empty or over-budget scan selection'
    examined, excluded, matches = [], [], []
    total = 0
    for name in sorted(set(paths)):
        path = root / name
        assert not Path(name).is_absolute() and '..' not in Path(name).parts
        assert path.is_file() and not path.is_symlink(), 'Invalid scan input: ' + name
        if path.stat().st_size > MAX_FILE_BYTES:
            assert path.suffix not in TEXT_TYPES, 'Text source exceeds scan bound: ' + name
            excluded.append({'path': name, 'reason': 'size limit'})
            continue
        data = path.read_bytes()
        if b'\0' in data[:8192]:
            assert path.suffix not in TEXT_TYPES, 'Text source contains binary data: ' + name
            excluded.append({'path': name, 'reason': 'binary'})
            continue
        total += len(data)
        assert total <= MAX_TOTAL_BYTES, 'Total scan-byte budget exceeded'
        text = data.decode('utf-8')
        examined.append({'path': name, 'bytes': len(data), 'lines': len(text.splitlines()),
                         'sha256': hashlib.sha256(data).hexdigest()})
        matches.extend({'kind': kind, 'path': name, 'line': line} for kind, line in findings(text))
    assert examined and REQUIRED <= {item['path'] for item in examined}, 'Required consumer inputs not scanned'
    return {'examinedFiles': len(examined), 'examinedBytes': total,
            'examinedLines': sum(item['lines'] for item in examined),
            'fileTypes': dict(sorted(Counter(Path(item['path']).suffix or '(no extension)'
                                           for item in examined).items())),
            'excludedFiles': excluded, 'files': examined, 'findings': matches}


def main():
    assert findings('const value="ghp_' + 'A' * 36 + '";'), 'Synthetic token was not detected'
    assert not findings('const value="fixture";'), 'Benign control was rejected'
    try:
        scan(ROOT, [])
    except AssertionError:
        pass
    else:
        raise AssertionError('Empty scan was accepted')
    listed = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '-c', '-o',
                                      '--exclude-standard', '-z'], timeout=5)
    paths = [name for name in listed.decode('utf-8').split('\0') if name]
    result = scan(ROOT, paths)
    if len(sys.argv) == 3 and sys.argv[1] == '--report':
        destination = Path(sys.argv[2]).resolve()
        assert destination.is_absolute() and not destination.is_relative_to(ROOT)
        with destination.open('x', encoding='utf-8') as output:
            json.dump(result, output, indent=2)
            output.write('\n')
    else:
        assert len(sys.argv) == 1, 'Usage: sensitive-checks.py [--report NEW_EXTERNAL_PATH]'
    for match in result['findings']:
        print(f'SENSITIVE {match["kind"]} at {match["path"]}:{match["line"]}; value withheld')
    print(f'{"FAIL" if result["findings"] else "PASS"} sensitive source heuristic: '
          f'{result["examinedFiles"]} text files, {result["examinedBytes"]} bytes, '
          f'{result["examinedLines"]} lines examined; '
          f'{len(result["excludedFiles"])} binary/size exclusions; '
          f'{len(result["findings"])} findings; positive/negative/empty controls passed')
    raise SystemExit(bool(result['findings']))


if __name__ == '__main__':
    main()
