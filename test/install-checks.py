"""Exercise native add/enable/update with a packaged sampler and no compiler calls."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HOST = Path(os.environ.get('ACTIVITY_OMARCHY_BIN', '/usr/share/omarchy/bin'))
assert (HOST / 'omarchy-plugin-add').is_file(), 'Native Omarchy installation tools unavailable'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()

with tempfile.TemporaryDirectory(prefix='loadlet-install-') as directory:
    base = Path(directory)
    source, home, tools = base / 'source', base / 'home', base / 'tools'
    source.mkdir(); home.mkdir(); tools.mkdir()
    paths = set(subprocess.check_output(
        ['git', '-C', str(ROOT), 'ls-files', '-c', '-o', '--exclude-standard', '-z'],
        text=True, timeout=15).strip('\0').split('\0'))
    for name in sorted(paths):
        original, copied = ROOT / name, source / name
        assert original.is_file() and not original.is_symlink()
        copied.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, copied)
    git = lambda *args: subprocess.check_output(['git', '-C', str(source), *args], timeout=20)
    git('init', '-q', '--template=', '-b', 'main')
    git('add', '--', *sorted(paths))
    git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
        'commit', '-qm', 'Package fixture')
    shell = tools / 'omarchy-shell'
    shell.write_text('''#!/usr/bin/python3
from pathlib import Path
import json, os, subprocess, sys
args = sys.argv[1:]
with (Path(os.environ['HOME'])/'ipc.jsonl').open('a') as stream:
    stream.write(json.dumps(args)+'\\n')
assert args[0] == 'shell'
if args[1] == 'listPlugins':
    subprocess.run([os.environ['ACTIVITY_CATALOG']], check=True)
elif args[1] == 'rescanPlugins':
    print('ok')
elif args[1] == 'enablePlugin':
    assert args[2] == 'slovn.activity-lite'
    print('ok')
else:
    raise AssertionError(args)
''')
    shell.chmod(0o755)
    denied = '#!/bin/sh\nprintf "%s\\n" "$0" >> "$HOME/compiler-calls"\nexit 97\n'
    for name in ['make', 'c++', 'g++', 'gcc', 'cc', 'clang', 'clang++', 'cmake']:
        (tools / name).write_text(denied)
        (tools / name).chmod(0o755)
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'),
               XDG_STATE_HOME=str(home / 'state'), XDG_RUNTIME_DIR=str(home / 'runtime'),
               OMARCHY_PATH=str(base / 'host'), ACTIVITY_CATALOG=str(HOST / 'omarchy-plugin-catalog'),
               PATH=str(tools) + ':' + str(HOST) + ':' + os.environ.get('PATH', '/usr/bin:/bin'))
    (base / 'host/shell/plugins').mkdir(parents=True)
    (home / 'runtime').mkdir(mode=0o700)
    url = os.environ.get('LOADLET_INSTALL_URL', str(source))
    command = [str(HOST / 'omarchy'), 'plugin', 'add', url, '--yes', '--enable']
    added = subprocess.run(command, env=env, text=True, capture_output=True, timeout=60)
    assert added.returncode == 0, added.stdout + added.stderr
    installed = home / '.config/omarchy/plugins/slovn.activity-lite'
    assert sha(installed / 'activity-sampler') == sha(ROOT / 'activity-sampler')
    assert (installed / 'activity-sampler').stat().st_mode & 0o111
    subprocess.run(['/usr/bin/python3', '-B', str(installed / 'test/package-checks.py')],
                   env=env, check=True, timeout=8)
    proc = home / 'proc'
    proc.mkdir()
    (proc / 'uptime').write_text('100.0 0.0\n')
    (proc / 'stat').write_text('cpu 100 0 100 800 0 0 0 0\n')
    (proc / 'meminfo').write_text('MemTotal: 1000 kB\nMemAvailable: 600 kB\nCached: 100 kB\n')
    sample = subprocess.run([str(installed / 'activity-sampler'), '--activity-reader'],
                            input='glance\n', text=True, capture_output=True, check=True, timeout=4,
                            env=dict(env, OMARCHY_SYSTEM_STATS_PROC_PATH=str(proc)))
    model = '''const fs=require('node:fs'),m=require(process.argv[1]);
const s=m.parseSnapshot(fs.readFileSync(0,'utf8'));
if(s.schema!==1||s.cpu.total!==1000||s.memory.total!==1024000)process.exit(1);'''
    subprocess.run(['node', '-e', model, str(installed / 'Model.js')], input=sample.stdout,
                   text=True, check=True, timeout=5, env=env)
    before = sha(installed / 'activity-sampler')
    refused = subprocess.run(command, env=env, text=True, capture_output=True, timeout=60)
    assert refused.returncode != 0 and sha(installed / 'activity-sampler') == before
    calls = [json.loads(line) for line in (home / 'ipc.jsonl').read_text().splitlines()]
    assert sum(row[1] == 'enablePlugin' for row in calls) == 1
    if 'LOADLET_INSTALL_URL' not in os.environ:
        (source / 'install-fixture.txt').write_text('updated package\n')
        git('add', 'install-fixture.txt')
        git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
            'commit', '-qm', 'Package update fixture')
        updated = subprocess.run([str(HOST / 'omarchy'), 'plugin', 'update',
                                  'slovn.activity-lite', '--yes'], env=env,
                                 text=True, capture_output=True, timeout=30)
        assert updated.returncode == 0, updated.stdout + updated.stderr
        assert (installed / 'install-fixture.txt').read_text() == 'updated package\n'
        assert sha(installed / 'activity-sampler') == before
    assert not (home / 'compiler-calls').exists(), 'User install called a build tool'
    assert not (home / 'state').exists(), 'Install must not create diagnostic history'
print('PASS native packaged add/enable/update: no compiler, exact executable, real Model parser, existing-ID refusal; only shell IPC stubbed')
