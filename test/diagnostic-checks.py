"""Safe journal/export checks using temporary procfs and private storage only."""
from pathlib import Path
import importlib.machinery
import importlib.util
import json
import os
import stat
import subprocess
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
loader=importlib.machinery.SourceFileLoader('activity_report',str(ROOT/'activity-report'))
spec=importlib.util.spec_from_loader(loader.name,loader)
report=importlib.util.module_from_spec(spec);loader.exec_module(report)

with tempfile.TemporaryDirectory(prefix='activity-diagnostic-') as tmp:
    base=Path(tmp);proc=base/'proc';proc.mkdir()
    (proc/'sys/kernel/random').mkdir(parents=True)
    (proc/'sys/kernel/random/boot_id').write_text('fixture-boot\n')
    (proc/'uptime').write_text('100 0\n')
    (proc/'stat').write_text('cpu 100 0 100 800 0 0 0 0\n')
    (proc/'meminfo').write_text('MemTotal: 1000 kB\nMemAvailable: 600 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\nCached: 100 kB\n')
    (proc/'pressure').mkdir();(proc/'pressure/cpu').write_text('some avg10=2 avg60=1 avg300=0 total=200\n')
    policies=base/'sys/devices/system/cpu/cpufreq'
    for n in range(64):
        policy=policies/f'policy{n}';policy.mkdir(parents=True)
        (policy/'scaling_driver').write_text('fixture-pstate')
        (policy/'related_cpus').write_text(str(n))
    state=base/'state';state.mkdir(mode=0o700)
    env=dict(os.environ,HOME=str(base),XDG_STATE_HOME=str(state),OMARCHY_SYSTEM_STATS_PROC_PATH=str(proc),OMARCHY_SYSTEM_STATS_SYS_PATH=str(base/'sys'))
    run=lambda commands: subprocess.run([str(ROOT/'activity-sampler'),'--activity-reader'],input=commands,text=True,capture_output=True,env=env,timeout=5,check=True)
    run('glance\nthermals\n');assert not (state/'omarchy').exists(),'Disabled journal must do no writes'
    # Actual reader and journal writer. Flush on disable; baseline is unavailable.
    run('journal-on\nglance\nthermals\nprocesses\ndiagnostics\njournal\njournal\njournal-off\n')
    directory=state/'omarchy/activity-lite/journal';files=list(directory.glob('samples-*.jsonl'))
    assert len(files)==1
    old_record=directory/'samples-outside-window.jsonl'
    old_record.write_text(json.dumps({'schema':99,'time':1})+'\n');old_record.chmod(0o600)
    assert list(report.records(directory,10,20))==[], 'Out-of-window malformed schema must not pollute export'
    old_record.unlink()
    rows=[json.loads(x) for x in files[0].read_text().splitlines()]
    assert len(rows)==1 and rows[0]['cpu_pct'] is None and rows[0]['boot_id']=='fixture-boot'
    assert stat.S_IMODE(files[0].stat().st_mode)==0o600
    assert report.valid_record(rows[0])
    context=rows[0]['context']
    assert context and context['policies_truncated']
    assert 0<len(context['policies'])<64
    assert context['policies'][0]['id']=='policy0'
    assert context['psi']['cpu'] and context['power_supplies']==[]
    result=report.export(directory,2,base/'export')
    assert (result/'AGENT-PROMPT.md').exists()
    assert json.loads((result/'summary.json').read_text())['samples']==1
    cli=subprocess.run(['/usr/bin/python3','-I',str(ROOT/'activity-report'),'--state-dir',str(directory),'--output',str(base/'cli-export')],capture_output=True,text=True,timeout=5,check=True)
    assert Path(json.loads(cli.stdout)['prompt']).is_file()
    # Exports never overwrite user reports; malformed file input is bounded.
    try:
        report.export(directory,2,base/'export')
        raise AssertionError('export overwrite admitted')
    except FileExistsError:
        pass
    unsafe=directory/'samples-test-link.jsonl';unsafe.symlink_to(files[0])
    try:
        list(report.records(directory,0,time.time()))
        raise AssertionError('journal symlink admitted')
    except OSError:
        pass
    unsafe.unlink()
    # Writer refuses symlink ancestors and permits metrics to continue.
    alias=base/'alias';alias.symlink_to(state,target_is_directory=True)
    bad=subprocess.run([str(ROOT/'activity-sampler'),'--activity-reader'],input='journal-on\nglance\n',text=True,capture_output=True,env=dict(env,XDG_STATE_HOME=str(alias)),timeout=5,check=True)
    assert 'error\tunsafe_or_unavailable_state_directory' in bad.stdout
    assert 'snapshot-end\tglance' in bad.stdout
    # Writer lock covers competing readers, not just file append.
    writer=subprocess.Popen([str(ROOT/'activity-sampler'),'--activity-reader'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,env=env)
    try:
        writer.stdin.write('journal-on\n');writer.stdin.flush()
        while writer.stdout.readline().strip()!='snapshot-end\tjournal-on': pass
        assert 'journal_writer_busy_or_unsafe' in run('journal-on\n').stdout
    finally:
        writer.stdin.close();writer.wait(timeout=3)
    # SIGTERM while blocked waiting for a request flushes an owned batch.
    writer=subprocess.Popen([str(ROOT/'activity-sampler'),'--activity-reader'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,env=env)
    try:
        for command in ['journal-on','glance','journal']:
            writer.stdin.write(command+'\n');writer.stdin.flush()
            while writer.stdout.readline().strip()!='snapshot-end\t'+command: pass
        count_before=len(list(directory.glob('samples-*.jsonl')))
        writer.terminate();assert writer.wait(timeout=3)==0
        assert len(list(directory.glob('samples-*.jsonl')))>count_before
    finally:
        if writer.poll() is None: writer.kill();writer.wait(timeout=2)
        writer.stdin.close();writer.stdout.close()
    binary=base/'journal-check'
    subprocess.run(['c++','-std=c++17','-O0','-Wall','-Wextra','-Werror',str(ROOT/'test/diagnostic-checks.cpp'),'-ldl','-o',str(binary)],check=True,timeout=90)
    subprocess.run([str(binary),str(base)],env=env,check=True,timeout=5)
    total=sum(p.stat().st_size for p in directory.glob('samples-*.jsonl'));assert total<=20*1024*1024

def row(stamp,boot='b',sample=100,state='R',cpu=50):
    return dict(schema=1,time=stamp,boot_id=boot,cpu_pct=cpu,temperature_c=85,process_sample_uptime=sample,
                process_age_ms=0,processes=[dict(pid=42,start_ticks=123,name_bytes='worker',state=state,
                   cpu_pct_one_core=200,rss_kib=1024,rss_delta_kib=128,state_observed_seconds=30)],context=None)
a=row(100);b=row(115);c=row(200,boot='other',sample=200)
summary=report.summarize([a,b,c]);assert len(summary['gaps'])==1
assert summary['top_cpu_candidates'][0]['observations']==1,'Cached process list must not duplicate evidence'
assert len(summary['thermal_intervals'])==2,'Reboot/gap must split thermal episode'
assert not report.valid_record(row(100,cpu=101))
assert not report.valid_record(dict(a,processes='bad'))
assert not report.valid_record(dict(a,time=float('nan')))
x=row(100);y=row(160,sample=160)
x['context']={'sample_uptime':100,'vmstat':{'pswpin':10,'pswpout':20},'psi':{'cpu':'some avg10=12.5 avg60=2 avg300=0 total=5\nfull avg10=0\n'}}
y['context']={'sample_uptime':160,'vmstat':{'pswpin':130,'pswpout':80},'psi':{'cpu':'some avg10=20 avg60=2 avg300=0 total=5\n'}}
z=report.summarize([x,y]);assert z['swap_vm_rates'][0]['pswpin_per_second']==2
assert z['swap_vm_rates'][0]['pswpout_per_second']==1
assert z['psi_peak_avg10_pct']['cpu_some_avg10_pct']==20
assert 'cpu_full_avg10_pct' not in z['psi_peak_avg10_pct']
print('PASS diagnostic reader/export: disabled writes, identity, freshness, local permissions, lock, symlinks, bounded retention, malformed data and gaps')
