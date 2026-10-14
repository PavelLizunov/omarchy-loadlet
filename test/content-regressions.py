"""Exercise byte, ignored-file, dangling-history and shallow coverage admission."""
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ['Panel.qml', 'ActivityController.qml', 'ActivityIconSvg.js', 'process-signal',
            'activity-report', 'README.md', 'docs/guide.md', '.github/workflows/check.yml']


def main():
    with tempfile.TemporaryDirectory(prefix='activity-content-control-') as temporary:
        base = Path(temporary)
        repo = base / 'repository'
        repo.mkdir()
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1', GIT_CONFIG_NOSYSTEM='1',
                   GIT_CONFIG_GLOBAL=os.devnull)
        def git(*args):
            return subprocess.check_output(['git', '-C', str(repo), *args], env=env, timeout=10)
        git('init', '-q', '--template=')
        for name in REQUIRED + ['.gitignore']:
            path = repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('benign\n' if name != '.gitignore' else 'ignored.bin\n')
        git('add', '--', *REQUIRED, '.gitignore')
        git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
            '-c', 'commit.gpgsign=false', 'commit', '-qm', 'Benign control')
        def check(name, expected):
            receipt = base / (name + '.json')
            result = subprocess.run([sys.executable, str(ROOT / 'test/content-checks.py'),
                                     '--root', str(repo), '--report', str(receipt)], env=env,
                                    capture_output=True, text=True, timeout=15)
            assert result.returncode == expected, 'Coverage control failed: ' + name
            if receipt.exists():
                return json.loads(receipt.read_text())
            return None
        benign = check('benign', 0)
        assert benign['currentFiles'] == len(REQUIRED) + 1 and benign['gitObjects']['commit'] == 1
        assert benign['excludedFiles'] == 0
        token = ('ghp_' + 'A' * 36).encode()
        ignored = repo / 'ignored.bin'
        ignored.write_bytes(b'\0' * 9000 + token)
        detected = check('ignored-binary', 1)
        assert detected['ignoredFiles'] == 1 and any(item['location'] == 'ignored.bin' for item in detected['findings'])
        ignored.write_bytes(b'X' + token.decode().encode('utf-16-le'))
        assert check('ignored-unaligned-utf16', 1)['findings']
        ignored.unlink()
        # This object is deliberately unreachable from every ref, but exists locally.
        oid = subprocess.check_output(['git', '-C', str(repo), 'hash-object', '-w', '--stdin'],
                                      input=token, env=env, timeout=10).decode().strip()
        historical = check('dangling-blob', 1)
        assert any(item['location'] == 'git:' + oid for item in historical['findings'])
        head = git('rev-parse', 'HEAD').decode().strip()
        (repo / '.git/shallow').write_text(head + '\n')
        assert check('shallow-denied', 1) is None
        (repo / '.git/shallow').unlink()
        (repo / 'Panel.qml').unlink()
        assert check('missing-tracked-input', 1) is None
    print('PASS actual Git content controls: benign count, ignored binary, unalignedUTF16, dangling blob, shallow/missing denial')


if __name__ == '__main__':
    main()
