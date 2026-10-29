"""Report evidence semantics and bounded agent argv, without invoking a model."""
from pathlib import Path
import importlib.machinery
import importlib.util
import json
import os
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
    path=report.export(s,directory,0,30,'')
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
print('PASS diagnostic report: stable sensors, gaps, PID reuse, missing baseline, PSI deltas, selection, export and inert agent argv')
