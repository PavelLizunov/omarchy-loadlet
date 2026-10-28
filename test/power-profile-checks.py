"""Power profiles use temporary sysfs and mocked services only."""
from pathlib import Path
import importlib.machinery
import importlib.util
import tempfile
from unittest.mock import patch

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
print('PASS power profiles: validation, boost/governor/EPP, frequency range order, persistence and CPU rollback; no real writes')
