"""Exercise history and privileged fan logic against temporary files only."""
from contextlib import redirect_stdout
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import tempfile
from unittest.mock import patch

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
    pwm, mode, saved = base/'pwm2', base/'pwm2_enable', base/'pwm2.json'
    pwm.write_text('40'); mode.write_text('2')
    # No access to real sysfs, root helpers, services, or authentication.
    with patch.object(fan, 'channel_files', return_value=(pwm, mode)), \
         patch.object(fan, 'state_path', return_value=saved), \
         patch.object(fan, 'cooling_floor', side_effect=lambda target: target), \
         patch.object(fan.signal, 'signal'), patch.object(fan.time, 'sleep'), \
         patch.object(fan.time, 'monotonic', side_effect=[0, 0, 301]):
        fan.worker('pwm2', 60, 5)
    assert pwm.read_text() == '40' and mode.read_text() == '2'
    assert not saved.exists(), 'Timed expiry restores firmware mode and duty'
    pwm.write_text('40'); mode.write_text('0')
    with patch.object(fan, 'channel_files', return_value=(pwm, mode)), \
         patch.object(fan, 'state_path', return_value=saved), \
         patch.object(fan, 'cooling_floor', side_effect=lambda target: target) as floor, \
         patch.object(fan.signal, 'signal'), patch.object(fan.time, 'sleep'), \
         patch.object(fan.time, 'monotonic', side_effect=[0, 0, 301]):
        fan.worker('pwm2', 60, 5)
    assert all(call.args == (255,) for call in floor.call_args_list), 'Full-speed firmware mode must never be lowered'
    assert pwm.read_text() == '40' and mode.read_text() == '0'
    pwm.write_text('200'); mode.write_text('1')
    with patch.object(fan, 'channel_files', return_value=(pwm, mode)), \
         patch.object(fan, 'state_path', return_value=saved), \
         patch.object(fan, 'cooling_floor', side_effect=OSError('injected write failure')), \
         patch.object(fan.signal, 'signal'):
        try:
            fan.worker('pwm2', 60, 5)
        except OSError:
            pass
        else:
            raise AssertionError('Expected injected failure')
    assert pwm.read_text() == '200' and mode.read_text() == '1' and not saved.exists()
    with patch.object(fan, 'channel_files', return_value=(pwm, mode)), \
         patch.object(fan, 'restore') as restore, patch.object(fan.os, 'geteuid', return_value=0), \
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
    observed = []
    def observe_sleep(_):
        observed.append(pwm.read_text())
    with patch.object(fan, 'STATE', base), \
         patch.object(fan, 'channel_files', return_value=(pwm, mode)), \
         patch.object(fan, 'state_path', return_value=saved), \
         patch.object(fan, 'cooling_floor', side_effect=lambda target: target), \
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
         patch.object(fan, 'restore'), patch.object(fan.os, 'geteuid', return_value=0), \
         patch.object(fan.sys, 'argv', ['fan-control', 'identify', 'pwm2', '0', '5']), \
         patch.object(fan.subprocess, 'run') as run:
        fan.main()
        command = run.call_args_list[-1].args[0]
        assert '--property=RuntimeMaxSec=10' in command
        assert command[-5:] == [fan.SELF, 'identify-worker', 'pwm2', '0', '5']
    print('PASS fan simulation: boost floor, exact zero duty, 5s restoration, thermal refusal and unit recovery; no hardware writes')

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
