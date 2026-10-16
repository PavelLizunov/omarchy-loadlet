"""Verify and exercise the distributed sampler before any local source rebuild."""
from pathlib import Path
import hashlib
import json
import os
import platform
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def verify_hashes(root, expected):
    for name, digest in expected.items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, name

with tempfile.TemporaryDirectory(prefix='loadlet-hash-control-') as directory:
    fixture = Path(directory)
    (fixture / 'file').write_bytes(b'original')
    expected = {'file': hashlib.sha256(b'original').hexdigest()}
    verify_hashes(fixture, expected)
    (fixture / 'file').write_bytes(b'changed')
    try:
        verify_hashes(fixture, expected)
    except AssertionError:
        pass
    else:
        raise AssertionError('Changed package passed its hash check')

provenance = json.loads((ROOT / 'docs/binary-provenance.json').read_text())
assert provenance['platform'] == 'linux-x86_64'
assert platform.system() == 'Linux' and platform.machine() == 'x86_64'
verify_hashes(ROOT, provenance['sha256'])
helper = ROOT / 'activity-sampler'
elf = helper.read_bytes()
assert elf[:6] == b'\x7fELF\x02\x01' and struct.unpack_from('<H', elf, 18)[0] == 62
assert helper.stat().st_mode & 0o111
with tempfile.TemporaryDirectory(prefix='loadlet-package-') as directory:
    home = Path(directory)
    proc = home / 'proc'
    proc.mkdir()
    (proc / 'uptime').write_text('100.0 0.0\n')
    (proc / 'stat').write_text('cpu 100 0 100 800 0 0 0 0\n')
    (proc / 'meminfo').write_text('MemTotal: 1000 kB\nMemAvailable: 600 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\nCached: 100 kB\n')
    env = dict(os.environ, HOME=str(home), XDG_STATE_HOME=str(home / 'state'),
               OMARCHY_SYSTEM_STATS_PROC_PATH=str(proc),
               OMARCHY_SYSTEM_STATS_SYS_PATH=str(home / 'sys'))
    result = subprocess.run([str(helper), '--activity-reader'], input='glance\n',
                            text=True, capture_output=True, timeout=4, env=env, check=True)
    assert result.stdout.splitlines() == [
        'schema\tactivity-resources\t1', 'sample\t100.0', 'cpu\tcpu\t1000\t800',
        'memory\t1000\t600\t0\t0\t100', 'snapshot-end\tglance']
    assert not (home / 'state').exists(), 'Normal sampling must not create history'
print('PASS distributed Linux x86_64 sampler: source/package hashes, changed-byte control, real framed sample; no build or journal write')
