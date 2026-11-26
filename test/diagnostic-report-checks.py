"""Report evidence semantics and bounded agent argv, without invoking a model."""
from pathlib import Path
import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
loader=importlib.machinery.SourceFileLoader('diagnostic_report',str(ROOT/'diagnostic-report'))
spec=importlib.util.spec_from_loader(loader.name,loader);report=importlib.util.module_from_spec(spec);loader.exec_module(report)
def row(t,kind,**values):return dict(schema=2,time=t,mono_ms=t*1000,boot_id='boot',session='session',type=kind,**values)
rows=[row(10,'tick',cpu_pct=None,interval_ms=250,sensors_tsv='schema\tactivity-sensors\t1\ntemperature\thwmon0/temp1\tk10temp\tTctl\t80000\tcpu\tAMD\tdevice\n'),
      row(10.25,'tick',cpu_pct=50,interval_ms=250,sensors_tsv='schema\tactivity-sensors\t1\ntemperature\thwmon8/temp1\tk10temp\tTctl\t87000\tcpu\tAMD\tdevice\n'),
      row(20,'tick',cpu_pct=10,interval_ms=250),
      row(10,'processes',processes=[dict(pid=42,start_ticks=1,name_bytes='worker',cpu_pct_one_core=200,rss_kib=1024)]),
      row(11,'processes',processes=[dict(pid=42,start_ticks=2,name_bytes='replacement',cpu_pct_one_core=None,rss_kib=512)]),
      row(10.5,'marker',label='user_incident'),
      row(10,'pressure',psi={'cpu':'some avg10=1 total=10000\nfull avg10=0 total=0\n'}),
      row(11,'pressure',psi={'cpu':'some avg10=1 total=110000\nfull avg10=0 total=0\n'})]
s=report.summarize(rows,0,30)
assert len(s['gaps'])==1
thermal=next(x for x in s['series'] if x['unit']=='°C')
assert thermal['count']==2 and thermal['max']==87 and thermal['peak_time']==10.25
assert len(s['top_processes'])==2
assert s['top_processes'][1]['peak_cpu'] is None
assert next(x for x in s['series'] if x['id']=='psi|cpu|some')['max']==10
assert not any(x['id']=='psi|cpu|full' for x in s['series'])
assert s['events'][0]['type']=='marker'
with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,{'XDG_STATE_HOME':tmp}):
    directory=report.state_path()/'diagnostics';directory.mkdir(parents=True,mode=0o700)
    f=directory/'samples-test.jsonl';f.write_text(''.join(json.dumps(r)+'\n' for r in rows));f.chmod(0o600)
    assert len(list(report.records(directory,0,30)))==len(rows)
    assert not list(report.records(directory,0,30,'other'))
    path=report.export(directory,0,30,'')
    assert Path(path,'summary.json').is_file()
    assert len(Path(path,'samples.jsonl').read_text().splitlines())==len(rows)
    with patch.object(report.shutil,'which',return_value='/usr/bin/fixture'),patch.object(report.subprocess,'run') as run:
        report.launch('omarchy',path)
        assert run.call_args.args[0][0]=='omarchy-agent-prompt'
        assert run.call_args.kwargs['cwd']==Path(path)
        assert 'shell' not in run.call_args.kwargs
    link=directory/'samples-link.jsonl';link.symlink_to(f)
    try:list(report.records(directory,0,30));raise AssertionError('Symlink admitted')
    except OSError:pass
with tempfile.TemporaryDirectory(prefix='loadlet-cold-runtime-') as tmp:
    runtime=Path(tmp)/'runtime';runtime.mkdir()
    config=Path(tmp)/'agent';config.mkdir();(config/'settings.json').write_text('{}');(config/'models.json').write_text('{}')
    for name in ('diagnostic-report','activity-report'):shutil.copy2(ROOT/name,runtime/name)
    env=dict(os.environ,PI_CODING_AGENT_DIR=str(config),XDG_STATE_HOME=str(Path(tmp)/'state'))
    env.pop('PYTHONDONTWRITEBYTECODE',None)
    before={p.name:p.read_bytes() for p in runtime.iterdir()}
    for args in (['--agent-info'],['--seconds','60'],['--seconds','60','--export']):
        result=subprocess.run(['/usr/bin/python3','-I',str(runtime/'diagnostic-report'),*args],
                              env=env,capture_output=True,text=True,timeout=5)
        assert result.returncode==(1 if '--export' in args else 0),result.stderr
        assert {p.name for p in runtime.iterdir()}==set(before),'Helper wrote into watched runtime'
        assert all((runtime/name).read_bytes()==data for name,data in before.items())
print('PASS diagnostic report: stable sensors, gaps, PID reuse, missing baseline, PSI deltas, selection, export, inert argv and cold-runtime immutability')

bad = [[], row(11, ['tick']), row(11, 'tick', interval_ms='250'), row(11, 'pressure', psi='wrong'),
       row(11, 'tick', cpu_pct=10**400)]
rollup = row(15, 'rollup', temperature_min=24, temperature_min_time=9, temperature_max=91, temperature_max_time=14)
bounded = report.summarize(bad + [rollup], 10, 15)
assert bounded['invalid_records'] == len(bad)
extrema = next(s for s in bounded['series'] if s['id'] == 'rollup-temperature')
assert extrema['count'] == 1 and extrema['min'] == extrema['max'] == 91 and extrema['peak_time'] == 14
assert report.summarize([row(11, 'context', context=None), row(11, 'processes', processes=None)], 10, 15)['records'] == 2

with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'XDG_STATE_HOME': tmp}):
    directory = report.state_path()/'diagnostics'
    with patch.object(report, 'records', return_value=iter(rows)) as source:
        published = Path(report.export(directory, 0, 30, ''))
        source.assert_called_once()
    assert json.loads((published/'summary.json').read_text())['records'] == len(rows)
    assert [json.loads(line) for line in (published/'samples.jsonl').read_text().splitlines()] == rows

    def broken_rows():
        yield rows[0]
        raise OSError('injected read failure')

    with patch.object(report, 'records', side_effect=lambda *args: broken_rows()):
        try:
            report.export(directory, 0, 30, '')
        except OSError:
            pass
        else:
            raise AssertionError('Partial export published')
    assert list(published.parent.iterdir()) == [published]
    legacy = report.legacy
    clean = dict(schema=1, time=10, boot_id='test')
    malformed = [[], dict(clean, schema=True), dict(clean, time=10**400), dict(clean, event=['collection_error'])]
    assert legacy.summarize([clean, *malformed])['invalid_records'] == len(malformed)
    path = published.parent/'legacy-export'
    with patch.object(legacy, 'records', return_value=iter([clean])) as source:
        legacy.export(directory, 1, path)
        source.assert_called_once()
    assert json.loads((path/'summary.json').read_text())['samples'] == 1
    assert json.loads((path/'samples.jsonl').read_text()) == clean
    existing = published.parent/'existing'
    existing.mkdir()
    with patch.object(legacy, 'records', return_value=iter([clean])):
        try:
            legacy.export(directory, 1, existing)
        except FileExistsError:
            pass
        else:
            raise AssertionError('Existing empty export overwritten')
    assert not list(existing.iterdir()) and not list(existing.parent.glob('.loadlet-export-*'))
print('PASS report validation: malformed records, selected extrema, single-read exports, failed staging and existing destinations')
