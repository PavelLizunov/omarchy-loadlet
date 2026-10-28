"""Power profiles use temporary sysfs and mocked services only."""
from pathlib import Path
import importlib.machinery
import importlib.util
import tempfile
import base64
import json
import subprocess
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('power_profile', str(ROOT/'power-profile'))
spec = importlib.util.spec_from_loader(loader.name, loader)
power = importlib.util.module_from_spec(spec)
loader.exec_module(power)

for bad in [{'cpu': {'boost': 1}}, {'fans': {'pwm1': 50}}, {'fans': {'pwm2': True}},
            {'cpu': {'maxMHz': -1}}, {'gpuFans': {'bad': 30}}, {'cpu': {'epp': 'shell'}}]:
    try:
        power.validate(bad)
    except ValueError:
        pass
    else:
        raise AssertionError(bad)
assert power.validate({'cpu': {'boost': False, 'maxMHz': 1800}, 'fans': {'pwm2': 42}})['fans']['pwm2'] == 42

with tempfile.TemporaryDirectory() as temp:
    base=Path(temp);cpu=base/'cpu';row=cpu/'cpufreq/policy0';row.mkdir(parents=True)
    values={'scaling_driver':'amd-pstate-epp','scaling_governor':'performance',
        'scaling_available_governors':'performance powersave','scaling_min_freq':'1400000',
        'scaling_max_freq':'5400000','cpuinfo_min_freq':'400000','cpuinfo_max_freq':'5400000',
        'energy_performance_preference':'performance',
        'energy_performance_available_preferences':'performance power balance_power'}
    for key,value in values.items():(row/key).write_text(value)
    (cpu/'cpufreq/boost').write_text('1')
    with patch.object(power,'CPU',cpu),patch.object(power,'STORE',base/'store'):
        original=power.cpu_snapshot()
        power.apply_cpu({'boost':False,'governor':'powersave','epp':'power','maxMHz':1200})
        assert (cpu/'cpufreq/boost').read_text()=='0'
        assert (row/'scaling_governor').read_text()=='powersave'
        assert (row/'scaling_min_freq').read_text()=='1200000'
        assert (row/'scaling_max_freq').read_text()=='1200000'
        power.restore_cpu(original)
        assert power.cpu_snapshot()==original
        with patch.object(power.subprocess,'run'):
            power.apply({'cpu':{'boost':False,'governor':'powersave','epp':'power'}})
            assert (base/'store/active.json').is_file()
            assert (base/'store/original-cpu.json').is_file()
            assert (cpu/'cpufreq/boost').read_text()=='0'
        before=power.cpu_snapshot()
        with patch.object(power.subprocess,'run'):
            try:power.apply({'cpu':{'governor':'schedutil'}})
            except ValueError:pass
            else:raise AssertionError('Unavailable governor accepted')
        assert power.cpu_snapshot()==before,'Failure restores prior CPU state'
        # Boot replay must not restart already-enabled motherboard fan workers.
        with patch.object(power.subprocess,'run') as calls,patch.object(power,'fan_adapter') as adapter:
            power.apply({'fans':{'pwm2':42},'cpu':{'boost':False}},boot=True)
            adapter.assert_not_called()
            assert not any(c.args[0][0]==power.FANS for c in calls.call_args_list)
with tempfile.TemporaryDirectory() as temp:
    base = Path(temp)
    with patch.object(power, 'STORE', base/'store'), patch.object(power, 'AUTO_STATUS', base/'run/status.json'), patch.object(power.time, 'monotonic', return_value=100):
        assert power.auto_status()['enabled'] is False
        power.publish_auto(True)
        assert power.auto_status()['gaming'] is True
        with patch.object(power.time, 'monotonic', return_value=131):
            assert power.auto_status()['gaming'] is None
            assert power.auto_status()['error'] == 'status_unavailable'
        power.publish_auto(error='injected')
        assert power.auto_status()['gaming'] is None
        prior = power.validate({'cpu':{'boost':False}})
        power.atomic(power.STORE/'active.json', prior)
        payload = base64.urlsafe_b64encode(json.dumps({'game':{'cpu':{'boost':True}},'base':prior}).encode()).decode()
        calls = []
        def fail_start(argv, **kwargs):
            calls.append(argv)
            if argv[1:3] == ['enable','--now']:
                raise subprocess.CalledProcessError(1, argv)
        with patch.dict(power.os.environ, {'SUDO_UID':'1000'}), patch.object(power, 'install_units'), \
             patch.object(power, 'detector', return_value=Mock(running_games=lambda uid: [123])), \
             patch.object(power, 'apply') as apply, patch.object(power.subprocess, 'run', side_effect=fail_start):
            try:
                power.configure_auto(payload)
            except subprocess.CalledProcessError:
                pass
            else:
                raise AssertionError('Failed startup accepted')
            assert not (power.STORE/'auto.json').exists()
            assert not power.AUTO_STATUS.exists()
            assert apply.call_args.args[0] == prior
        (power.STORE/'active.json').unlink()
        before = {'cpu-state': 'original'}
        with patch.dict(power.os.environ, {'SUDO_UID':'1000'}), patch.object(power, 'install_units'), \
             patch.object(power, 'detector', return_value=Mock(running_games=lambda uid: [123])), \
             patch.object(power, 'cpu_snapshot', return_value=before), patch.object(power, 'restore_cpu') as restore, \
             patch.object(power, 'apply') as apply, patch.object(power.subprocess, 'run', side_effect=fail_start):
            try:
                power.configure_auto(payload)
            except subprocess.CalledProcessError:
                pass
            else:
                raise AssertionError('First activation failure accepted')
            restore.assert_called_once_with(before)
            assert apply.call_args.args[0] == {'cpu': {}, 'fans': {}, 'gpuFans': {}}
            assert not (power.STORE/'active.json').exists()
            assert not (power.STORE/'original-cpu.json').exists()
        power.atomic(power.STORE/'auto.json', {'base':prior})
        with patch.object(power.subprocess, 'run'), patch.object(power, 'apply') as apply:
            power.disable_auto(restore_base=False)
            apply.assert_not_called()
        assert not (power.STORE/'auto.json').exists()
with tempfile.TemporaryDirectory() as temp:
    base = Path(temp)
    clock = [100]
    game = power.validate({'cpu': {'boost': True}})
    idle = power.validate({'cpu': {'boost': False}})
    applied = []
    def apply_fixture(value):
        applied.append((clock[0], value))
        power.atomic(base/'active.json', value)
    def sleep_fixture(seconds):
        clock[0] += seconds
        if clock[0] >= 125:
            (base/'auto.json').unlink(missing_ok=True)
    detection = Mock(running_games=Mock(side_effect=[[123], [456], [], [], []]))
    with patch.object(power, 'STORE', base), patch.object(power, 'AUTO_STATUS', base/'run/status.json'), \
         patch.object(power, 'detector', return_value=detection), patch.object(power, 'apply', side_effect=apply_fixture), \
         patch.object(power.time, 'monotonic', side_effect=lambda: clock[0]), \
         patch.object(power.time, 'sleep', side_effect=sleep_fixture), patch.object(power.signal, 'signal'):
        power.atomic(base/'auto.json', {'uid': 1000, 'game': game, 'base': idle})
        power.auto_worker()
        assert applied == [(100, game), (120, idle)], applied
        assert power.auto_status()['gaming'] is False
        assert detection.running_games.call_count == 5
print('PASS power profiles: validation, CPU rollback, boot replay, stale/failed automation, startup rollback, manual override, worker/game grace; no real writes')
