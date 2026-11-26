"""Exercise history and privileged fan logic against temporary files only."""
from contextlib import redirect_stdout, nullcontext
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import subprocess
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]

def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module

fan = load('fan_fixture', ROOT/'fan-control')
report = load('report_fixture', ROOT/'activity-report')
with tempfile.TemporaryDirectory(prefix='loadlet-controls-') as tmp:
    base = Path(tmp)
    fan.PROFILES = base/'profiles'
    fan.STATE = base
    fan.POWER_STORE = base/'power'
    sensor = base/'cpu_temp'
    sensor.write_text('45000')
    pwm, mode, saved = base/'pwm2', base/'pwm2_enable', base/'pwm2.json'
    pwm.write_text('40'); mode.write_text('2')
    # No access to real sysfs, root helpers, services, or authentication.
    with patch.object(fan, 'channel_files', return_value=(pwm, mode)), \
         patch.object(fan, 'state_path', return_value=saved), \
         patch.object(fan, 'cpu_temperature_paths', return_value=[sensor]), \
         patch.object(fan.signal, 'signal'), patch.object(fan.time, 'sleep'), \
         patch.object(fan.time, 'monotonic', side_effect=[0, 0, 301]):
        fan.worker('pwm2', 60, 5)
    assert pwm.read_text() == '40' and mode.read_text() == '2'
    assert not saved.exists(), 'Timed expiry restores firmware mode and duty'
    pwm.write_text('40'); mode.write_text('0')
    observed = []
    def observe_sleep(_):
        observed.append(pwm.read_text())

    with patch.object(fan, 'channel_files', return_value=(pwm, mode)), \
         patch.object(fan, 'state_path', return_value=saved), \
         patch.object(fan, 'cpu_temperature_paths', return_value=[sensor]), \
         patch.object(fan.signal, 'signal'), patch.object(fan.time, 'sleep', side_effect=observe_sleep), \
         patch.object(fan.time, 'monotonic', side_effect=[0, 0, 301]):
        fan.worker('pwm2', 60, 5)
    assert observed == ['255'], 'Full-speed firmware mode must never be lowered'
    assert pwm.read_text() == '40' and mode.read_text() == '0'
    pwm.write_text('200'); mode.write_text('1')
    with patch.object(fan, 'channel_files', return_value=(pwm, mode)), \
         patch.object(fan, 'state_path', return_value=saved), \
         patch.object(fan, 'cpu_temperature_paths', return_value=[sensor]), \
         patch.object(fan, 'notify_ready', side_effect=OSError('injected worker failure')), \
         patch.object(fan.signal, 'signal'):
        try:
            fan.worker('pwm2', 60, 5)
        except OSError:
            pass
        else:
            raise AssertionError('Expected injected failure')
    assert pwm.read_text() == '200' and mode.read_text() == '1' and not saved.exists()
    with patch.object(fan, 'channel_files', return_value=(pwm, mode)), \
         patch.object(fan, 'restore') as restore, patch.object(fan, 'state_path', return_value=saved), patch.object(fan.os, 'geteuid', return_value=0), \
         patch.object(fan.sys, 'argv', ['fan-control', 'boost', 'pwm2', '80', '5']), \
         patch.object(fan.subprocess, 'run') as run:
        fan.main()
        command = run.call_args_list[-1].args[0]
        assert '--property=RuntimeMaxSec=315' in command
        assert '--property=ExecStopPost=/usr/local/lib/loadlet/fan-control recover pwm2' in command
        assert command[-5:] == ['/usr/local/lib/loadlet/fan-control', 'worker', 'pwm2', '80', '5']
        restore.assert_called_once_with('pwm2')
    # Identification deliberately permits lower duty, unlike the boost path.
    pwm.write_text('200'); mode.write_text('2')
    observed.clear()
    with patch.object(fan, 'STATE', base), \
         patch.object(fan, 'channel_files', return_value=(pwm, mode)), \
         patch.object(fan, 'state_path', return_value=saved), \
         patch.object(fan, 'cpu_temperature_paths', return_value=[sensor]), \
         patch.object(fan.signal, 'signal'), patch.object(fan.time, 'sleep', side_effect=observe_sleep), \
         patch.object(fan.time, 'monotonic', side_effect=[0, 0, 6]):
        fan.worker('pwm2', 0, 5, identify=True)
    assert observed == ['0'], observed
    assert pwm.read_text() == '200' and mode.read_text() == '2' and not saved.exists()
    with patch.object(fan, 'cooling_floor', return_value=255):
        try:
            fan.worker('pwm2', 0, 5, identify=True)
        except ValueError:
            pass
        else:
            raise AssertionError('Hot or missing CPU telemetry must reject identification')
    with patch.object(fan, 'channel_files', return_value=(pwm, mode)), \
         patch.object(fan, 'restore'), patch.object(fan, 'state_path', return_value=saved), patch.object(fan.os, 'geteuid', return_value=0), \
         patch.object(fan.sys, 'argv', ['fan-control', 'identify', 'pwm2', '0', '5']), \
         patch.object(fan.subprocess, 'run') as run:
        fan.main()
        command = run.call_args_list[-1].args[0]
        assert '--property=RuntimeMaxSec=10' in command
        assert command[-5:] == [fan.SELF, 'identify-worker', 'pwm2', '0', '5']
    # A timed boost must not undercut a saved persistent profile.
    fan.PROFILES.mkdir()
    (fan.PROFILES/'pwm2.json').write_text('{"percent":80}')
    pwm.write_text('40');mode.write_text('2')
    observed.clear()
    with patch.object(fan, 'channel_files', return_value=(pwm,mode)), \
         patch.object(fan, 'state_path', return_value=saved), \
         patch.object(fan, 'cpu_temperature_paths', return_value=[sensor]), \
         patch.object(fan.signal,'signal'),patch.object(fan.time,'sleep', side_effect=observe_sleep), \
         patch.object(fan.time,'monotonic',side_effect=[0,0,301]):
        fan.worker('pwm2',60,5)
    assert observed == ['204']
    assert not saved.exists()
    (fan.PROFILES/'pwm2.json').unlink()
    saved_outputs=[]
    def fail_activation(argv, **kwargs):
        if argv[1:3]==['enable','--now']:
            raise subprocess.CalledProcessError(1,argv)
        return subprocess.CompletedProcess(argv,0,stdout='loaded\n')
    with patch.object(fan,'channel_files',return_value=(pwm,mode)), \
         patch.object(fan,'switching',return_value=nullcontext()),patch.object(fan,'install_profile_unit'), \
         patch.object(fan,'read_profile',return_value=80),patch.object(fan,'save_profile',side_effect=lambda c,p:saved_outputs.append(p)), \
         patch.object(fan,'restore'),patch.object(fan.os,'geteuid',return_value=0), \
         patch.object(fan.sys,'argv',['fan-control','save','pwm2','20']), \
         patch.object(fan.subprocess,'run',side_effect=fail_activation) as calls:
        try:
            fan.main()
        except subprocess.CalledProcessError:
            pass
        else:
            raise AssertionError('Failed fan activation accepted')
        assert saved_outputs==[20,80],'Rejected output must not replace the saved choice'
        assert any(c.args[0][1]=='start' for c in calls.call_args_list)
    (fan.PROFILES/'pwm2.json').write_text('{"percent":80}')
    with patch.object(fan,'channel_files',return_value=(pwm,mode)), \
         patch.object(fan,'switching',return_value=nullcontext()) as lock,patch.object(fan,'restore') as restore, \
         patch.object(fan,'stop_unit',side_effect=OSError('stop failed')),patch.object(fan.os,'geteuid',return_value=0), \
         patch.object(fan.sys,'argv',['fan-control','restore','pwm2']):
        try:
            fan.main()
        except OSError:
            pass
        else:
            raise AssertionError('Restore ignored failed stop')
        lock.assert_called_once_with('pwm2');restore.assert_not_called()
        assert (fan.PROFILES/'pwm2.json').exists(),'Failure retains recovery identity'
    (fan.PROFILES/'pwm2.json').unlink()
    print('PASS fan simulation: boost, thermal refusal, unit recovery, failed save rollback and locked restore; no hardware writes')

    folder = base/'omarchy/activity-lite/sensors'
    folder.mkdir(parents=True, mode=0o700)
    stamp = 100000
    frame = 'schema\tactivity-sensors\t1\ntemperature\tcpu\tk10temp\tTctl\t54000\tcpu\tAMD Ryzen\tpackage0\nfan\tfan2\tit8613\tfan2\t700\trpm\tmotherboard\tITE\tisa0a30'
    records = [dict(schema=1, time=stamp-3600+i*15, boot_id='fixture', sensors_tsv=frame) for i in range(240)]
    chunk = folder/'samples-fixture.jsonl'
    chunk.write_text(''.join(json.dumps(row)+'\n' for row in records))
    chunk.chmod(0o600)
    with patch.dict(report.os.environ, {'XDG_STATE_HOME': str(base)}), \
         patch.object(report.time, 'time', return_value=stamp), redirect_stdout(io.StringIO()) as output:
        report.sensor_history()
    data = json.loads(output.getvalue())
    assert len(data['sensors']) == 2
    cpu, rpm = data['sensors']
    assert cpu['history'][-1]['value'] == 54 and rpm['history'][-1]['value'] == 700
    assert rpm['fan'] and rpm['unit'] == 'rpm'
    assert cpu['history'][0]['time'] == stamp-3600
    assert len(output.getvalue()) <= 240000
    # Twenty channels force compaction wider than60s; continuous raw data is not a gap.
    frame_many = 'schema\tactivity-sensors\t1\n' + '\n'.join(
        f'temperature\tcpu{n}\tk10temp\tTctl\t54000\tcpu\tAMD Ryzen\tpackage0' for n in range(20))
    records = [dict(schema=1,time=stamp-6*3600+i*15,boot_id='fixture',sensors_tsv=frame_many) for i in range(1400)]
    records = [r for i,r in enumerate(records) if not 500 <= i < 510]
    chunk.unlink()
    for begin in range(0,len(records),400):
        part=folder/f'samples-fixture-{begin:04}.jsonl'
        part.write_text(''.join(json.dumps(row)+'\n' for row in records[begin:begin+400]));part.chmod(0o600)
    with patch.dict(report.os.environ, {'XDG_STATE_HOME': str(base)}), \
         patch.object(report.time, 'time', return_value=stamp), redirect_stdout(io.StringIO()) as output:
        report.sensor_history()
    data=json.loads(output.getvalue())
    points=data['sensors'][0]['history']
    assert len(points)<150
    assert len({p['time'] for p in points})==len(points), 'Compacted history has unique timestamps'
    assert any(b['time']-a['time']>60 and not b['breakBefore'] for a,b in zip(points,points[1:])), 'Compaction must not invent recording gaps'
    assert sum(bool(p['breakBefore']) for p in points)==1, 'Real omitted recording interval is preserved'
    assert len(output.getvalue())<=240000
    print('PASS persisted sensor history: private JSONL, units, bounded output, compaction continuity and real gaps')


class NvmlFixture:
    """Mock the ABI, including out parameters and driver status codes."""
    def __init__(self):
        self.speed = [55, 88]
        self.targets = self.speed.copy()
        self.temperature = 45
        self.policies = [0, 0]
        self.reset_errors = {}
        self.stuck = set()

        def output(pointer, value):
            pointer._obj.value = value
            return 0

        def set_speed(device, index, target):
            self.speed[index] = target
            self.targets[index] = target
            self.policies[index] = 1
            return 0

        def reset(device, index):
            if index not in self.stuck and index not in self.reset_errors:
                self.policies[index] = 0
            return self.reset_errors.get(index, 0)

        self.nvmlInit_v2 = Mock(return_value=0)
        self.nvmlShutdown = Mock(return_value=0)
        self.nvmlDeviceGetHandleByPciBusId_v2 = Mock(side_effect=lambda bus, ptr: output(ptr, 1))
        self.nvmlDeviceGetNumFans = Mock(side_effect=lambda device, ptr: output(ptr, 2))
        self.nvmlDeviceGetMinMaxFanSpeed = Mock(side_effect=lambda device, low, high: output(low, 30) or output(high, 90))
        self.nvmlDeviceGetTemperature = Mock(side_effect=lambda device, sensor, ptr:
                                             1 if self.temperature is None else output(ptr, self.temperature))
        self.nvmlDeviceGetFanSpeed_v2 = Mock(side_effect=lambda device, index, ptr: output(ptr, self.speed[index]))
        self.nvmlDeviceGetTargetFanSpeed = Mock(side_effect=lambda device, index, ptr: output(ptr, self.targets[index]))
        self.nvmlDeviceSetFanSpeed_v2 = Mock(side_effect=set_speed)
        self.nvmlDeviceSetDefaultFanSpeed_v2 = Mock(side_effect=reset)
        self.nvmlDeviceGetFanControlPolicy_v2 = Mock(side_effect=lambda device, index, ptr: output(ptr, self.policies[index]))


def check_thermal_hold(channel, state, backend, set_temperature, output):
    # Warm samples, the release boundary, and read failures break the cool streak.
    samples = [79, 80, 79, 76, 74, 74, 74, 80, 74, 75, 74, 74, None, 74, 74, 74]
    for persistent in (True, False):
        remaining = iter(samples)
        set_temperature(next(remaining))
        writes = []

        def advance(_):
            writes.append(output())
            if (sample := next(remaining, 'end')) == 'end':
                handlers.call_args.args[1]()
            else:
                set_temperature(sample)

        with patch.object(fan, 'read_profile', return_value=None), patch.object(fan, 'notify_ready'), \
             patch.object(fan.signal, 'signal') as handlers, patch.object(fan.time, 'sleep', side_effect=advance), \
             patch.object(fan.time, 'monotonic', return_value=0):
            fan.run_worker(channel, state, backend, 60, 5, identify=False, persistent=persistent)
        target, maximum = backend.target(60), backend.maximum
        assert writes == [target] + [maximum]*5 + [target] + [maximum]*8 + [target], writes
        assert not state.exists()

    # One unsafe sample aborts a running identification and restores its snapshot.
    snapshot = backend.snapshot()
    for unsafe in (80, None):
        set_temperature(74)
        with patch.object(fan.signal, 'signal'), patch.object(fan, 'notify_ready'), \
             patch.object(fan.time, 'monotonic', return_value=0), \
             patch.object(fan.time, 'sleep', side_effect=lambda _: set_temperature(unsafe)):
            try:
                fan.run_worker(channel, state, backend, 40, 5, identify=True, persistent=False)
            except ValueError as error:
                assert 'telemetry is missing' in str(error)
            else:
                raise AssertionError('Identification continued after an unsafe sample')
        assert backend.snapshot() == snapshot and not state.exists()


with tempfile.TemporaryDirectory(prefix='loadlet-gpu-fan-') as directory:
    base = Path(directory)
    nvml = NvmlFixture()
    gpu = 'nv.0000_01_00_0'
    state = base/(gpu+'.json')
    clock = [0]
    writes = []

    def observe(seconds):
        writes.append((clock[0], tuple(nvml.speed)))
        clock[0] += seconds

    def stop_after_first(seconds):
        observe(seconds)
        handlers.call_args.args[1](None, None)

    with patch.object(fan, 'STATE', base), patch.object(fan, 'PROFILES', base/'saved'), \
         patch.object(fan.os, 'geteuid', return_value=0), patch.object(fan.ctypes, 'CDLL', return_value=nvml), patch.object(fan.signal, 'signal') as handlers, \
         patch.object(fan.time, 'monotonic', side_effect=lambda: clock[0]), patch.object(fan.time, 'sleep', side_effect=observe):
        def checked_state(channel, scope=''):
            fan.check_channel(channel)
            return base/(scope+channel+'.json')
        with patch.object(fan, 'state_path', side_effect=checked_state):
            with patch.object(fan, 'notify_ready', side_effect=lambda: writes.append(('ready', tuple(nvml.speed)))):
                fan.worker(gpu+'.fan0', 40, 5, identify=True)
            assert nvml.nvmlDeviceSetFanSpeed_v2.argtypes == [fan.ctypes.c_void_p, fan.ctypes.c_uint, fan.ctypes.c_uint]
            assert nvml.nvmlDeviceGetHandleByPciBusId_v2.call_args.args[0] == b'0000:01:00.0'
            assert nvml.nvmlDeviceGetFanControlPolicy_v2.call_args.args[1] == 0
            assert clock[0] == 5 and writes[0] == ('ready', (40, 88))
            assert [stamp for stamp, _ in writes[1:]] == [0, 2, 4]
            assert nvml.policies == [0, 0] and not list(base.glob('*.json'))

            writes.clear()
            with patch.object(fan, 'read_profile', return_value=84), patch.object(fan.time, 'sleep', side_effect=stop_after_first):
                fan.worker(gpu, 60, 5)
            assert writes == [(5, (88, 88))], writes
            for temperature in (80, None):
                nvml.temperature = temperature
                writes.clear()
                with patch.object(fan.time, 'sleep', side_effect=stop_after_first):
                    fan.worker(gpu, 60, 5, persistent=True)
                assert writes[0][1] == (90, 90)
                nvml.nvmlDeviceSetFanSpeed_v2.reset_mock()
                try:
                    fan.worker(gpu, 40, 5, identify=True)
                except ValueError as error:
                    assert 'telemetry' in str(error)
                else:
                    raise AssertionError('Unsafe thermal trial accepted')
                nvml.nvmlDeviceSetFanSpeed_v2.assert_not_called()
                assert not state.exists()
            nvml.temperature = 45
            for percent in (29, 91):
                try:
                    fan.worker(gpu, percent, 5)
                except ValueError as error:
                    assert '30-90%' in str(error)
                else:
                    raise AssertionError('Driver range violation accepted')

            calls = []
            def activate(argv, **kwargs):
                calls.append(argv)
                if argv[1:3] == ['enable', '--now']:
                    assert argv[3] == fan.PROFILE_UNIT.format(gpu)
                return subprocess.CompletedProcess(argv, 0, stdout='loaded')
            fan.PROFILES.mkdir()
            saved = fan.PROFILES/(gpu+'.json')
            with patch.object(fan.sys, 'argv', ['fan-control', 'save', gpu, '65']), \
                 patch.object(fan, 'install_profile_unit'), patch.object(fan.subprocess, 'run', side_effect=activate), \
                 patch.object(fan, 'save_profile', side_effect=lambda channel, percent:
                              saved.write_text(json.dumps({'percent': percent}))):
                fan.main()
            assert fan.read_profile(gpu) == 65

            def fail_readiness(argv, **kwargs):
                if argv[0].endswith('systemd-run'):
                    assert '--property=Type=notify' in argv
                    raise subprocess.CalledProcessError(1, argv)
                return activate(argv, **kwargs)
            with patch.object(fan.sys, 'argv', ['fan-control', 'boost', gpu, '80', '5']), \
                 patch.object(fan.subprocess, 'run', side_effect=fail_readiness), redirect_stdout(io.StringIO()) as stdout:
                try:
                    fan.main()
                except subprocess.CalledProcessError:
                    pass
                else:
                    raise AssertionError('Failed notification accepted')
            assert not stdout.getvalue() and ['/usr/bin/systemctl', 'start', fan.PROFILE_UNIT.format(gpu)] in calls
            assert fan.read_profile(gpu) == 65

            # Crash recovery attempts both fans even if driver reset and readback fail.
            nvml.reset_errors[0] = 7
            nvml.stuck.add(1)
            nvml.policies[:] = [1, 1]
            fan.write_snapshot(state, {'fans': [0, 1]})
            nvml.nvmlDeviceSetDefaultFanSpeed_v2.reset_mock()
            try:
                fan.restore(gpu)
            except ValueError as error:
                assert 'fan 0 reset returned 7' in str(error) and 'fan 1 automatic policy unverified' in str(error)
            else:
                raise AssertionError('GPU reset failure ignored')
            assert [call.args[1] for call in nvml.nvmlDeviceSetDefaultFanSpeed_v2.call_args_list] == [0, 1]
            assert state.exists()
            nvml.stuck.clear()
            nvml.reset_errors.clear()
            fan.restore(gpu)
            assert nvml.policies == [0, 0] and not state.exists()

            channel = gpu+'.fan0'
            per_fan = base/(channel+'.json')
            with fan.backend(channel) as backend:
                check_thermal_hold(channel, per_fan, backend, lambda value: setattr(nvml, 'temperature', value),
                                   lambda: nvml.targets[0])
            nvml.temperature = 45

            for identify in (True, False):
                nvml.policies[0], nvml.targets[0], nvml.speed[0] = 1, 62, 55
                nvml.nvmlDeviceGetTargetFanSpeed.reset_mock()
                nvml.nvmlDeviceSetFanSpeed_v2.reset_mock()

                def observe_trial(seconds):
                    assert json.loads(per_fan.read_text()) == {'fans': [0], 'prior': {'0': {'policy': 1, 'target': 62}}}
                    assert nvml.targets[0] == (40 if identify else 80)
                    clock[0] += seconds

                with patch.object(fan.time, 'sleep', side_effect=observe_trial):
                    fan.worker(channel, 40 if identify else 80, 5, identify=identify)
                assert [call.args[1] for call in nvml.nvmlDeviceGetTargetFanSpeed.call_args_list] == [0]
                assert nvml.nvmlDeviceSetFanSpeed_v2.call_args.args[1:] == (0, 62)
                assert nvml.policies == [1, 0] and nvml.targets[0] == 62 and not per_fan.exists()

            legacy_gpu = 'loadlet-gpu-fan@0000:01:00.0.service'
            disable_legacy = ['/usr/bin/systemctl', 'disable', '--now', legacy_gpu]
            for action, extra in [('save', ['65']), ('boost', ['80', '5']), ('identify', ['40', '5']), ('restore', [])]:
                assert not per_fan.exists()
                nvml.nvmlDeviceGetFanControlPolicy_v2.reset_mock()
                nvml.nvmlDeviceSetDefaultFanSpeed_v2.reset_mock()
                with patch.object(fan.sys, 'argv', ['fan-control', action, channel, *extra]), \
                     patch.object(fan, 'install_profile_unit'), redirect_stdout(io.StringIO()), \
                     patch.object(fan, 'save_profile', side_effect=lambda ch, percent:
                                  fan.profile_path(ch).write_text(json.dumps({'percent': percent}))), \
                     patch.object(fan.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, stdout='loaded')) as services:
                    fan.main()
                commands = [call.args[0] for call in services.call_args_list]
                assert commands.count(disable_legacy) == 1, commands
                destination = (['/usr/bin/systemctl', 'enable', '--now', fan.PROFILE_UNIT.format(channel)]
                               if action == 'save' else ['/usr/bin/systemd-run'] if action != 'restore'
                               else ['/usr/bin/systemctl', 'disable', '--now', fan.PROFILE_UNIT.format(channel)])
                assert any(command[:len(destination)] == destination
                           for command in commands[commands.index(disable_legacy)+1:])
                if action == 'restore':
                    assert nvml.nvmlDeviceSetDefaultFanSpeed_v2.call_args.args[1:] == (0,)
                    assert nvml.nvmlDeviceGetFanControlPolicy_v2.call_args.args[1] == 0
                    assert nvml.policies == [0, 0] and not per_fan.exists() and fan.read_profile(channel) is None


with tempfile.TemporaryDirectory(prefix='loadlet-pwm-') as directory:
    base = Path(directory)
    fixture_hwmon = base/'hwmon'
    fixture_pci = base/'pci'
    fixture_thermal = base/'thermal'
    def chip(path, driver, duty, mode, name='pwm1'):
        path.mkdir(parents=True)
        (path/'name').write_text(driver)
        pwm, enable = path/name, path/(name+'_enable')
        pwm.write_text(str(duty))
        enable.write_text(str(mode))
        return pwm, enable
    amd_chip = fixture_pci/'0000:03:00.0/hwmon/hwmon9'
    amd_pwm, amd_mode = chip(amd_chip, 'amdgpu', 55, 2)
    (amd_chip/'pwm1_min').write_text('35')
    (amd_chip/'pwm1_max').write_text('220')
    (amd_chip/'temp1_input').write_text('invalid')
    (amd_chip/'temp2_input').write_text('80000')
    nct_path = fixture_hwmon/'hwmon2'
    it_path = fixture_hwmon/'hwmon3'
    nct_pwm, nct_mode = chip(nct_path, 'NCT6798', 54, 5, 'pwm16')
    it_pwm, it_mode = chip(it_path, 'it8628', 20, 0)
    device = base/'ISA 0290'; device.mkdir()
    (nct_path/'device').symlink_to(device)
    zone = fixture_thermal/'thermal_zone0'; zone.mkdir(parents=True)
    (zone/'type').write_text('TCPU')
    (zone/'temp').write_text('46000')
    with patch.object(fan, 'HWMON', fixture_hwmon), patch.object(fan, 'PCI', fixture_pci), \
         patch.object(fan, 'THERMAL', fixture_thermal):
        assert fan.cooling_floor(50) == 50
        chip(fixture_hwmon/'hwmon4', 'zenpower5', 0, 0)
        (fixture_hwmon/'hwmon4/temp1_input').write_text('broken')
        (fixture_hwmon/'hwmon4/temp2_input').write_text('85000')
        assert fan.cooling_floor(50) == 255
        (fixture_hwmon/'hwmon4/temp2_input').write_text('65000')
        assert fan.cooling_floor(50) == 50
        (fixture_hwmon/'hwmon4/temp1_input').write_text('45000')
        (fixture_hwmon/'hwmon9').symlink_to(amd_chip)
        try:
            fan.channel_files('hw.amdgpu.hwmon9.pwm1')
        except ValueError as error:
            assert 'canonical amd.' in str(error)
        else:
            raise AssertionError('Generic hwmon channel bypassed AMD GPU thermal protection')
        for channel, pwm, mode, manual_target in [
                ('amd.0000_03_00_0.pwm1', amd_pwm, amd_mode, 220),
                ('hw.nct6798.isa_0290.pwm16', nct_pwm, nct_mode, 128),
                ('hw.it8628.hwmon3.pwm1', it_pwm, it_mode, 128)]:
            with fan.backend(channel) as backend:
                previous = backend.snapshot()
                assert backend.full_speed_transition == channel.startswith('hw.it86')
                if channel.startswith('amd.'):
                    assert backend.target(0) == 35 and backend.target(100) == 220
                backend.takeover()
                backend.write(backend.safe_target(backend.target(50), False))
                assert int(pwm.read_text()) == manual_target and mode.read_text() == '1'
                backend.restore(previous)
                assert int(pwm.read_text()) == previous['pwm'] and int(mode.read_text()) == previous['mode']
        (amd_chip/'temp1_input').write_text('45000')
        for channel, sensor, pwm in [
                ('amd.0000_03_00_0.pwm1', amd_chip/'temp2_input', amd_pwm),
                ('hw.nct6798.isa_0290.pwm16', fixture_hwmon/'hwmon4/temp2_input', nct_pwm)]:
            with fan.backend(channel) as backend:
                check_thermal_hold(channel, base/'hold.json', backend,
                                   lambda value: sensor.write_text('unreadable' if value is None else str(value*1000)),
                                   lambda: int(pwm.read_text()))
        duplicate = fixture_hwmon/'hwmon5'
        chip(duplicate, 'nct6798', 54, 5, 'pwm16')
        (duplicate/'device').symlink_to(device)
        for channel in ('hw.nct6798.isa_0290.pwm16', 'hw.asus-ec-sensors.hwmon8.pwm1'):
            try:
                fan.channel_files(channel)
            except ValueError:
                pass
            else:
                raise AssertionError('Ambiguous or read-only channel accepted')

with tempfile.TemporaryDirectory(prefix='loadlet-sudoers-') as directory:
    import re
    import shutil
    rule = fan.sudoers_rule('fixture', '20991231235959Z')
    patterns = re.findall(r'/fan-control (\^.*?\$)', rule)
    assert len(patterns) == 16
    if shutil.which('grep'):
        # Use the actual POSIX ERE regex engine for the bounded hwmon slug.
        hw_restore = patterns[-2]
        for length in range(1, 34):
            result = subprocess.run(['grep', '-Eq', hw_restore], input='restore hw.x.' + 'y'*length + '.pwm16\n',
                                    text=True, check=False)
            assert result.returncode == (0 if length <= 32 else 1)
    for channel in ('pwm2', 'nv.0000_01_00_0', 'nv.0000_01_00_0.fan7',
                    'amd.0000_03_00_0.pwm8', 'hw.nct6798.isa_0290.pwm16'):
        for args in (f'save {channel} 100', f'restore {channel}',
                     f'identify {channel} 0 5', f'boost {channel} 60 30'):
            assert any(re.fullmatch(pattern, args) for pattern in patterns), args
    for args in ('restore pwm1', 'restore pwm2 --extra', 'boost pwm2 60 0', 'save nv.0000_01_00_0.fan8 50',
                 'restore amd.0000_03_00_0.pwm9', 'restore hw.nct6798.pci.pwm17',
                 'restore hw.nct6798.'+'x'*33+'.pwm1', 'save pwm2 101', 'worker pwm2 60 5'):
        assert not any(re.fullmatch(pattern, args) for pattern in patterns), args
    path = Path(directory)/'sudoers'
    path.write_text(rule)
    path.chmod(0o440)
    if shutil.which('visudo'):
        subprocess.run(['visudo', '-cf', str(path)], check=True, capture_output=True, text=True)
    else:
        print('SKIP visudo syntax check: visudo unavailable')

with patch.object(fan.Path, 'is_file', return_value=True), patch.object(
        fan.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, stderr='baseline restore failed')) as run:
    try:
        fan.request(['save', 'pwm2', '50'])
    except ValueError as error:
        assert 'baseline restore failed' in str(error)
    else:
        raise AssertionError('Fan mutation followed failed automation disable')
    run.assert_called_once()
    assert run.call_args.args[0] == ['/usr/local/lib/loadlet/power-profile', 'request', 'auto-off']

with tempfile.TemporaryDirectory(prefix='loadlet-power-lock-') as directory:
    store = Path(directory)
    lock_path = store/'.apply.lock'
    file_lock = fan.file_lock

    def check_lock(action, channel):
        try:
            with file_lock(lock_path, fan.fcntl.LOCK_EX | fan.fcntl.LOCK_NB):
                pass
        except BlockingIOError:
            return
        raise AssertionError(f'{action} mutated {channel} without the profile lock')

    def nonblocking_lock(path, flags):
        return file_lock(path, flags | fan.fcntl.LOCK_NB)

    with patch.object(fan, 'POWER_STORE', store), patch.object(fan.os, 'geteuid', return_value=0), \
         patch.object(fan.os, 'getppid', return_value=123), patch.object(fan.signal, 'signal'), \
         patch.object(Path, 'lstat', return_value=Mock(st_uid=0, st_mode=store.stat().st_mode)), \
         patch.object(fan, 'file_lock', side_effect=nonblocking_lock) as acquire, \
         patch.object(fan, 'operate') as operate:
        with patch.dict(fan.os.environ, LOADLET_PROFILE_LOCK_OWNER='456'):
            operate.side_effect = check_lock
            for action in ('save', 'restore', 'boost', 'identify'):
                with patch.object(fan.sys, 'argv', ['fan-control', action, 'nv.0000_01_00_0.fan0']):
                    fan.main()
            assert acquire.call_count == 4
            with file_lock(lock_path, fan.fcntl.LOCK_EX | fan.fcntl.LOCK_NB):
                pass
        acquire.reset_mock()
        operate.reset_mock()
        operate.side_effect = None
        with file_lock(lock_path, fan.fcntl.LOCK_EX), patch.dict(fan.os.environ, LOADLET_PROFILE_LOCK_OWNER='123'), \
             patch.object(fan.sys, 'argv', ['fan-control', 'restore', 'nv.0000_01_00_0.fan0']):
            fan.main()
        operate.assert_called_once_with('restore', 'nv.0000_01_00_0.fan0')
        acquire.assert_not_called()
        with patch.dict(fan.os.environ, LOADLET_PROFILE_LOCK_OWNER='456'), \
             patch.object(fan.sys, 'argv', ['fan-control', 'profile-worker', 'nv.0000_01_00_0.fan0']):
            fan.main()
        acquire.assert_not_called()

print('PASS NVIDIA/AMD/hwmon fixtures: timed readiness and rollback, limits, thermal fallback, recovery and sudoers')
