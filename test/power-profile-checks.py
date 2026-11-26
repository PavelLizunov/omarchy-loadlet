"""Power profiles use temporary sysfs and mocked services only."""
from contextlib import nullcontext
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

with tempfile.TemporaryDirectory() as directory:
    base = Path(directory)
    channel = 'nv.0000_01_00_0.fan0'
    saved = {channel: 62}
    updates = []
    target = {'cpu': {'platformProfile': 'quiet'}, 'gpuFans': {channel: 80}}
    payload = base64.urlsafe_b64encode(json.dumps({'game': target, 'base': target}).encode()).decode()
    acpi = base/'acpi'
    acpi.mkdir()
    (acpi/'platform_profile').write_text('balanced')
    (acpi/'platform_profile_choices').write_text('balanced quiet')
    adapter = Mock(read_profile=saved.get, backend=Mock(return_value=nullcontext(Mock())))

    def fail_auto_start(argv, **kwargs):
        if argv[0] == power.FANS:
            assert kwargs['env']['LOADLET_PROFILE_LOCK_OWNER'] == str(power.os.getpid())
            action, key, *args = argv[1:]
            assert key == channel
            if action == 'save':
                saved[key] = int(args[0])
                updates.append(saved[key])
            else:
                assert action == 'restore'
                saved.pop(key)
        if argv[1:] == ['enable', '--now', 'loadlet-auto-game.service']:
            assert saved[channel] == 80
            raise subprocess.CalledProcessError(1, argv)

    with patch.dict(power.os.environ, {'SUDO_UID': '1000'}), patch.object(power, 'install_units'), \
         patch.object(power, 'STORE', base/'store'), patch.object(power, 'AUTO_STATUS', base/'run/status.json'), \
         patch.object(power, 'CPU', base/'cpu'), patch.object(power, 'ACPI', acpi), \
         patch.object(power, 'detector', return_value=Mock(running_games=lambda uid: [])), \
         patch.object(power, 'fan_adapter', return_value=adapter), \
         patch.object(power.subprocess, 'run', side_effect=fail_auto_start):
        try:
            power.configure_auto(payload)
        except subprocess.CalledProcessError as error:
            assert error.cmd[-1] == 'loadlet-auto-game.service'
        else:
            raise AssertionError('Failed automatic startup reported success')
        assert saved == {channel: 62} and updates == [80, 62]
        assert (acpi/'platform_profile').read_text() == 'balanced'
        assert not list(power.STORE.glob('*.json')) and not power.AUTO_STATUS.exists()

with tempfile.TemporaryDirectory() as temp:
    base=Path(temp)
    prior=power.validate({'fans':{'pwm2':40},'gpuFans':{'0000:01:00.0':30}})
    with patch.object(power,'STORE',base),patch.object(power,'cpu_snapshot',return_value={}), \
         patch.object(power,'fan_adapter',return_value=Mock(read_profile=Mock(return_value=40))), \
         patch.object(power,'restore_cpu',side_effect=OSError('CPU rollback failure')) as cpu_restore, \
         patch.object(power,'stop_gpu',side_effect=OSError('GPU stop failure')) as gpu_stop, \
         patch.object(power.subprocess,'run') as services:
        power.atomic(base/'active.json',prior)
        try:
            power.apply({})
        except ValueError as error:
            assert 'recovery incomplete' in str(error)
        else:
            raise AssertionError('Failed recovery accepted')
        cpu_restore.assert_called_once()
        assert gpu_stop.call_count==2
        rollback, = (c for c in services.call_args_list if c.args[0] == [power.FANS, 'save', 'pwm2', '40'])
        assert rollback.kwargs['env']['LOADLET_PROFILE_LOCK_OWNER'] == str(power.os.getpid())
        assert not any('enable' in c.args[0] for c in services.call_args_list),'Failed GPU stop must not start a replacement'
        recovery=json.loads((base/'recovery.json').read_text())
        assert recovery['previous']==prior and recovery['target']==power.validate({})
        assert len(recovery['errors'])==2
        try:
            power.apply({})
        except ValueError as error:
            assert 'Previous profile recovery' in str(error)
        else:
            raise AssertionError('Unresolved recovery overwritten')
with patch.object(power.subprocess,'run',return_value=subprocess.CompletedProcess([],0,stdout='not-found\n')) as services:
    power.stop_gpu('0000:01:00.0');assert services.call_count==1
with patch.object(power.subprocess,'run',side_effect=[subprocess.CompletedProcess([],0,stdout='loaded\n'),subprocess.CalledProcessError(1,[]) ]):
    try:
        power.stop_gpu('0000:01:00.0')
    except subprocess.CalledProcessError:
        pass
    else:
        raise AssertionError('Failed GPU stop ignored')
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

with tempfile.TemporaryDirectory() as directory:
    base = Path(directory)
    cpu, acpi, store = base/'cpu', base/'acpi', base/'store'
    acpi.mkdir()
    platform_file = acpi/'platform_profile'
    platform_file.write_text('balanced')
    (acpi/'platform_profile_choices').write_text('quiet balanced performance')
    rows = [cpu/'cpufreq'/f'policy{n}' for n in range(2)]
    for row in rows:
        row.mkdir(parents=True)
        (row/'boost').write_text('1')
        (row/'scaling_available_governors').write_text('powersave ondemand conservative')
        (row/'scaling_governor').write_text('powersave')
    with patch.object(power, 'CPU', cpu), patch.object(power, 'ACPI', acpi), patch.object(power, 'STORE', store), \
         patch.object(power.subprocess, 'run'), patch.object(power, 'fan_adapter', return_value=Mock(read_profile=lambda _: None)):
        original = power.cpu_snapshot()
        caps = power.capabilities()
        assert caps['boost'] == '1' and caps['platformProfile'] == 'balanced'
        assert caps['platformProfileChoices'] == ['quiet', 'balanced', 'performance']
        real_apply = power.apply_cpu

        def check_intent(cpu):
            intent = json.loads((store/'recovery.json').read_text())
            assert intent['cpu'] == original and intent['target']['cpu'] == cpu
            real_apply(cpu)

        with patch.object(power, 'apply_cpu', side_effect=check_intent):
            power.apply({'cpu': {'boost': False, 'governor': 'conservative', 'platformProfile': 'quiet'}})
        assert platform_file.read_text() == 'quiet'
        assert all((row/'boost').read_text() == '0' and (row/'scaling_governor').read_text() == 'conservative'
                   for row in rows)
        assert json.loads((store/'original-cpu.json').read_text())[str(platform_file)] == 'balanced'
        assert not (store/'recovery.json').exists()
        power.apply({'fans': {'hw.nct6798.isa0290.pwm16': 60}})
        assert power.cpu_snapshot() == original, 'Fan-only profile restores prior CPU baseline'
        try:
            power.apply({'cpu': {'platformProfile': 'unsupported'}})
        except ValueError as error:
            assert 'unavailable' in str(error)
        else:
            raise AssertionError('Unavailable ACPI mode accepted')
        assert not (store/'recovery.json').exists()
        power.apply_cpu({'boost': False, 'governor': 'ondemand', 'platformProfile': 'performance'})
        write = Path.write_text

        def fail_first_policy(path, value):
            if path == rows[0]/'boost':
                raise OSError('injected policy failure')
            return write(path, value)

        with patch.object(Path, 'write_text', autospec=True, side_effect=fail_first_policy):
            try:
                power.restore_cpu(original)
            except ValueError as error:
                assert str(rows[0]/'boost') in str(error)
            else:
                raise AssertionError('Failed CPU restore reported success')
        assert (rows[1]/'boost').read_text() == '1'
        assert (rows[1]/'scaling_governor').read_text() == 'powersave'
        assert platform_file.read_text() == 'balanced'
    with patch.object(power, 'CPU', base/'no-cpufreq'), patch.object(power, 'ACPI', acpi):
        power.apply_cpu({'platformProfile': 'quiet', 'maxMHz': 0})
        assert platform_file.read_text() == 'quiet'

    handlers = base/'sys/class/platform-profile'
    profiles = {}
    for index, mode in enumerate(('balanced', 'performance')):
        path = handlers/f'platform-profile-{index}'/'profile'
        path.parent.mkdir(parents=True)
        path.write_text(mode)
        profiles[str(path)] = mode
    platform_file.write_text('custom')
    with patch.object(power, 'CPU', base/'no-cpufreq'), patch.object(power, 'ACPI', acpi), \
         patch.object(power, 'ACPI_HANDLERS', handlers):
        original = power.cpu_snapshot()
        assert original == profiles
        power.apply_cpu({'platformProfile': 'quiet'})
        for path in profiles:
            Path(path).write_text('quiet')
        # A legacy snapshot containing the synthetic aggregate must also be safe.
        with patch.object(Path, 'write_text', autospec=True, side_effect=Path.write_text) as writes:
            power.restore_cpu(original | {str(platform_file): 'custom'})
        assert {(str(call.args[0]), call.args[1]) for call in writes.call_args_list} == set(profiles.items())
        assert all(Path(path).read_text() == mode for path, mode in profiles.items())
        assert platform_file.read_text() == 'quiet'

assert len(power.validate({'fans': {f'hw.nct6798.isa0290.pwm{i}': 50 for i in range(1, 17)}})['fans']) == 16
assert power.validate({'gpuFans': {'nv.0000_01_00_0.fan0': 60, 'amd.0000_03_00_0.pwm1': 70}})['gpuFans'] == {
    'nv.0000_01_00_0.fan0': 60, 'amd.0000_03_00_0.pwm1': 70}
for gpus in ({'0000:01:00.0': 40, 'nv.0000_01_00_0.fan0': 42},
             {'nv.0000_01_00_0': 40, 'nv.0000_01_00_0.fan0': 42}):
    try:
        power.validate({'gpuFans': gpus})
    except ValueError:
        pass
    else:
        raise AssertionError('Overlapping GPU owners accepted')
with tempfile.TemporaryDirectory() as directory:
    base = Path(directory)
    pwm_dir = base/'hwmon'
    pwm_dir.mkdir()
    (pwm_dir/'pwm1').touch()
    (pwm_dir/'pwm1_enable').touch()
    adapter = Mock(amd_hwmon=Mock(side_effect=lambda bus: [pwm_dir] if bus == '0000:03:00.0' else []))
    with patch.object(power, 'fan_adapter', return_value=adapter):
        power.gpu_worker('0000:03:00.0', 75)
        adapter.worker.assert_called_once_with('amd.0000_03_00_0.pwm1', 75, 0, persistent=True, scope='profile-')
        power.gpu_reset('0000:01:00.0')
        adapter.restore.assert_called_once_with('nv.0000_01_00_0', reset=True, scope='profile-')
with patch.object(power.sys, 'argv', ['power-profile', 'request', 'restore']), \
     patch.object(power, 'request_run', return_value=subprocess.CompletedProcess([], 1, stderr='  GPU reset incomplete\n')):
    try:
        power.main()
    except ValueError as error:
        assert str(error) == 'GPU reset incomplete'
    else:
        raise AssertionError('Request wrapper suppressed backend failure')
print('PASS platform and GPU profiles: ACPI choices, per-policy boost, fan-only baseline, recovery intent, both GPU backends')
