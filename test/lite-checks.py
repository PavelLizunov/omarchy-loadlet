"""Bounded local regressions. Run in an isolated PID namespace."""
import importlib.machinery
import importlib.util
from dataclasses import replace
from argparse import Namespace
from unittest.mock import patch
from contextlib import redirect_stderr
import io
import os
from pathlib import Path
import signal
import stat as file_mode
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('process_signal', str(ROOT / 'process-signal'))
spec = importlib.util.spec_from_loader(loader.name, loader)
helper = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = helper
loader.exec_module(helper)

def refused(call, status=77):
    with redirect_stderr(io.StringIO()):
        try:
            call()
        except SystemExit as error:
            assert error.code == status, error.code
        else:
            raise AssertionError('Unsafe process action was accepted')

stat = helper.ProcessStat(42, b'windows', 'S', 2, 0, 1234)
owner = helper.ProcessStatus(42, 'S', (0, 0, 0, 0))
with patch.object(helper.os, 'getuid', return_value=1000):
    refused(lambda: helper.reject_unsafe_target(stat, owner, 1234))
    helper.reject_unsafe_target(stat, owner, 1234, owner.user_ids)
    refused(lambda: helper.reject_unsafe_target(stat, replace(owner, user_ids=(1, 0, 0, 0)),
                                                1234, owner.user_ids))
    refused(lambda: helper.check_authorization(time.monotonic()+120))
for unsafe in [replace(stat, name=b'quickshell'), replace(stat, flags=helper.PF_KTHREAD),
               replace(stat, state='Z')]:
    refused(lambda: helper.reject_unsafe_target(unsafe, owner, 1234, owner.user_ids))
refused(lambda: helper.reject_unsafe_target(replace(stat, start_ticks=1235), owner, 1234,
                                            owner.user_ids), 1)
with patch.object(helper.os, 'getuid', return_value=0), \
     patch.object(helper.os, 'geteuid', return_value=0), \
     patch.dict(os.environ, {'PKEXEC_UID': '1000'}):
    helper.check_authorization(time.monotonic()+120)
    for deadline in [None, time.monotonic()-1, time.monotonic()+121, float('nan'), float('inf')]:
        refused(lambda: helper.check_authorization(deadline))

system_path = Path('/usr/local/lib/loadlet/process-signal')
trusted_directory = SimpleNamespace(st_uid=0, st_mode=file_mode.S_IFDIR | 0o755)
trusted_program = SimpleNamespace(st_uid=0, st_mode=file_mode.S_IFREG | 0o755)
path_metadata = dict.fromkeys(system_path.parents, trusted_directory)
path_metadata[system_path] = trusted_program
request = Namespace(signal_name='TERM', pid=42, start_ticks=1234)

def read_metadata(path):
    if path not in path_metadata:
        raise FileNotFoundError(path)
    return path_metadata[path]

with patch.object(Path, 'lstat', read_metadata), \
     patch.object(Path, 'read_text', side_effect=AssertionError('Plugin source reread')), \
     patch.object(helper.os, 'execv') as execute:
    helper.request_authorization(request, owner)
    executable, command = execute.call_args.args
    assert executable == '/usr/bin/pkexec'
    assert command[:-1] == [
        'pkexec', '--disable-internal-agent', str(system_path),
        'TERM', '42', '1234', '--authorized-owner', '0', '0', '0', '0',
        '--authorization-deadline',
    ]
    assert 0 < float(command[-1]) - time.monotonic() <= 120
    with patch.object(sys, 'argv', command[2:]):
        assert helper.parse_args() == Namespace(
            signal_name=request.signal_name, pid=request.pid, start_ticks=request.start_ticks,
            authorize=False, authorized_owner=list(owner.user_ids),
            authorization_deadline=float(command[-1]),
        )
    execute.reset_mock()

    del path_metadata[system_path]
    refused(lambda: helper.request_authorization(request, owner), 78)
    execute.assert_not_called()
    path_metadata[system_path] = trusted_program
    for path, metadata in [
        (system_path, SimpleNamespace(st_uid=1000, st_mode=file_mode.S_IFREG | 0o755)),
        (system_path, SimpleNamespace(st_uid=0, st_mode=file_mode.S_IFREG | 0o775)),
        (system_path, SimpleNamespace(st_uid=0, st_mode=file_mode.S_IFREG | 0o644)),
        (system_path, SimpleNamespace(st_uid=0, st_mode=file_mode.S_IFLNK | 0o777)),
        (system_path.parent, SimpleNamespace(st_uid=1000, st_mode=file_mode.S_IFDIR | 0o755)),
        (Path('/usr/local'), SimpleNamespace(st_uid=0, st_mode=file_mode.S_IFDIR | 0o757)),
        (Path('/usr/local'), SimpleNamespace(st_uid=0, st_mode=file_mode.S_IFLNK | 0o777)),
    ]:
        original = path_metadata[path]
        path_metadata[path] = metadata
        refused(lambda: helper.request_authorization(request, owner), 78)
        execute.assert_not_called()
        path_metadata[path] = original

argv = ['process-signal', 'TERM', '42', '1234', '--authorized-owner', '0', '0', '0', '0',
        '--authorization-deadline', str(time.monotonic()+120)]
with patch.object(sys, 'argv', argv), \
     patch.object(helper, 'protected_processes', return_value=set()), \
     patch.object(helper.os, 'getuid', return_value=0), \
     patch.object(helper.os, 'geteuid', return_value=0), \
     patch.dict(os.environ, {'PKEXEC_UID': '1000'}), \
     patch.object(helper.os, 'pidfd_open', return_value=9), \
     patch.object(helper.os, 'close'), \
     patch.object(helper.signal, 'alarm') as alarm, \
     patch.object(helper, 'read_process_stat', return_value=stat) as read_stat, \
     patch.object(helper, 'read_process_status', return_value=owner) as read_status, \
     patch.object(helper.signal, 'pidfd_send_signal') as send:
    helper.main()
    send.assert_called_once_with(9, signal.SIGTERM)
    alarm.assert_called_once_with(5)
    send.reset_mock()
    read_stat.return_value = replace(stat, start_ticks=1235)
    refused(helper.main, 1); send.assert_not_called()
    read_stat.return_value = stat
    read_status.return_value = replace(owner, user_ids=(0, 0, 0, 1))
    refused(helper.main); send.assert_not_called()
    read_status.return_value = owner
    with patch.object(helper.time, 'monotonic', return_value=float(argv[-1])+1):
        refused(helper.main); send.assert_not_called()
print('PASS process authentication: fixed privileged entry point, trusted path, deadlines and target guards')

def invoke(child, name='TERM', delta=0):
    start = helper.read_process_stat(Path('/proc'), child.pid).start_ticks
    return subprocess.run([str(ROOT / 'process-signal'), name,
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
        # Internal privileged mode cannot be enabled by argv/environment as a user.
        start = helper.read_process_stat(Path('/proc'), child.pid).start_ticks
        forged = subprocess.run([sys.executable, '-I', str(ROOT / 'process-signal'),
                                 'TERM', str(child.pid), str(start),
                                 '--authorized-owner', *[str(os.getuid())]*4,
                                 '--authorization-deadline', str(time.monotonic()+120)],
                                env=dict(os.environ, PKEXEC_UID='1000' if os.getuid() else ''),
                                capture_output=True, text=True, timeout=4)
        assert forged.returncode != 0 and child.poll() is None
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

with tempfile.TemporaryDirectory() as directory:
    base = Path(directory)
    proc = base / 'proc'
    proc.mkdir()
    (proc / 'uptime').write_text('100.0 0.0\n')
    hwmon = base / 'sys' / 'class' / 'hwmon'
    # An idle iwlwifi sensor fails its read (ENODATA); a directory fails the same way.
    (hwmon / 'hwmon0' / 'temp1_input').mkdir(parents=True)
    (hwmon / 'hwmon0' / 'name').write_text('iwlwifi_1\n')
    (hwmon / 'hwmon1').mkdir()
    (hwmon / 'hwmon1' / 'name').write_text('coretemp\n')
    (hwmon / 'hwmon1' / 'temp1_input').write_text('45000\n')
    (hwmon / 'hwmon1' / 'temp1_label').write_text('Package id 0\n')
    env = dict(os.environ, OMARCHY_SYSTEM_STATS_PROC_PATH=str(proc),
               OMARCHY_SYSTEM_STATS_SYS_PATH=str(base / 'sys'))
    def thermals():
        return subprocess.run([str(ROOT / 'activity-sampler'), '--activity-reader'],
                              input='thermals\n', env=env, capture_output=True,
                              text=True, timeout=3, check=True).stdout.splitlines()
    assert thermals() == ['schema\tactivity-thermals\t1', 'sample\t100.0',
                          'temperature\thwmon1/temp1\tcoretemp\tPackage id 0\t45000',
                          'snapshot-end\tthermals'], thermals()
    print('PASS thermals: an unreadable sensor is skipped, not a capacity error')
    (hwmon / 'hwmon0' / 'name').write_text('x' * 9000)
    assert thermals() == ['error\tcapacity', 'snapshot-end\tthermals'], thermals()
    print('PASS thermals: an overlong sysfs line is still a capacity error')
