"""Bounded local regressions. Run in an isolated PID namespace."""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('process_signal', str(ROOT / 'process-signal'))
spec = importlib.util.spec_from_loader(loader.name, loader)
helper = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = helper
loader.exec_module(helper)

def invoke(child, name='TERM', delta=0):
    start = helper.read_process_stat(Path('/proc'), child.pid).start_ticks
    return subprocess.run([sys.executable, '-I', str(ROOT / 'process-signal'), name,
                           str(child.pid), str(start + delta)], capture_output=True,
                          text=True, timeout=4)

for name, ignored in [('тест', False), ('quickshell', False), ('worker', True)]:
    code = ("import pathlib,signal,time; "
            f"pathlib.Path('/proc/self/comm').write_text({name!r}); "
            + ("signal.signal(signal.SIGTERM,signal.SIG_IGN); " if ignored else '')
            + "print('ready',flush=True); time.sleep(20)")
    child = subprocess.Popen([sys.executable, '-c', code], stdout=subprocess.PIPE, text=True)
    try:
        assert child.stdout.readline().strip() == 'ready'
        assert invoke(child, delta=1).returncode != 0
        assert child.poll() is None
        assert invoke(child, 'APP_TERM').returncode != 0
        result = invoke(child)
        if name == 'quickshell':
            assert result.returncode != 0 and child.poll() is None
        elif ignored:
            assert result.returncode == 0
            time.sleep(3.2)
            assert child.poll() is None, 'TERM must never escalate'
            assert invoke(child, 'KILL').returncode == 0
            assert child.wait(timeout=2) == -signal.SIGKILL
        else:
            assert result.returncode == 0, result.stderr
            assert child.wait(timeout=2) == -signal.SIGTERM
        print('PASS process:', name, 'ignored-term:', ignored)
    finally:
        if child.poll() is None: child.kill()
        child.wait(timeout=2)

with tempfile.TemporaryDirectory() as directory:
    base = Path(directory)
    proc = base / 'proc'
    proc.mkdir()
    (proc / 'uptime').write_text('1000.00 0.00\n')
    (proc / 'stat').write_text('cpu 1 2 3 4 5 6 7 8\n')
    env = dict(os.environ, OMARCHY_SYSTEM_STATS_PROC_PATH=str(proc),
               OMARCHY_SYSTEM_STATS_SYS_PATH=str(base / 'sys'),
               OMARCHY_SYSTEM_STATS_PASSWD_PATH=str(base / 'passwd'))
    # Valid frame followed by an overflowing one must never emit partial records.
    for pid in range(100, 600):
        folder = proc / str(pid)
        folder.mkdir()
        fields = ['0'] * 22
        fields[0] = 'S'; fields[19] = '100'; fields[21] = '20'
        (folder / 'stat').write_text(f'{pid} (' + 'x' * 800 + ') ' + ' '.join(fields))
        (folder / 'status').write_text('Uid:\t1000\t1000\t1000\t1000\n')
    result = subprocess.run([str(ROOT / 'activity-sampler'), '--activity-reader'],
                            input='processes\nresources\n', env=env,
                            capture_output=True, text=True, timeout=5, check=True)
    first, second = result.stdout.split('snapshot-end\tprocesses\n')
    assert first == 'error\tcapacity\n', first[:100]
    assert second.endswith('snapshot-end\tresources\n')
    assert len(result.stdout.encode()) < 262144
    print('PASS bounded producer: no partial overflow frame; next request survives')
    assert subprocess.run([str(ROOT / 'activity-sampler'), '--activity-process-power'],
                          capture_output=True, timeout=2).returncode != 0
    print('PASS removed power-reader entry point')

print('Activity Lite regressions passed')

with tempfile.TemporaryDirectory() as directory:
    proc = Path(directory) / 'proc'
    proc.mkdir()
    (proc / 'uptime').write_text('100.0 0.0\n')
    (proc / 'stat').write_text('cpu 100 0 100 800 0 0 0 0\ncpu0 100 0 100 800 0 0 0 0\n')
    (proc / 'meminfo').write_text('MemTotal: 1000 kB\nMemAvailable: 600 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\nCached: 100 kB\n')
    result = subprocess.run([str(ROOT / 'activity-sampler'), '--activity-reader'],
                            input='glance\n', env=dict(os.environ, OMARCHY_SYSTEM_STATS_PROC_PATH=str(proc)),
                            capture_output=True, text=True, timeout=3, check=True)
    assert result.stdout.splitlines() == ['schema\tactivity-resources\t1', 'sample\t100.0',
                                         'cpu\tcpu\t1000\t800', 'memory\t1000\t600\t0\t0\t100',
                                         'snapshot-end\tglance'], result.stdout
    print('PASS glance reader: aggregate CPU/RAM only, framed response')
