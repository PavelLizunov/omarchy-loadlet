"""Exercise actual native recording against inert proc/sys fixtures."""
from pathlib import Path
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import signal
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='loadlet-fast-') as tmp:
    home = Path(tmp)
    proc = home/'proc'; proc.mkdir()
    (proc/'sys/kernel/random').mkdir(parents=True)
    (proc/'sys/kernel/random/boot_id').write_text('fixture-boot\n')
    (proc/'uptime').write_text('100.0 0\n')
    (proc/'stat').write_text('cpu 100 0 100 800 0 0 0 0\n')
    (proc/'meminfo').write_text('MemTotal: 1000 kB\nMemAvailable: 600 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n')
    sensor=home/'sys/class/hwmon/hwmon0';sensor.mkdir(parents=True)
    (sensor/'name').write_text('k10temp\n');(sensor/'temp1_label').write_text('Tctl\n')
    (sensor/'temp1_input').write_text('70000\n')
    state=home/'state';state.mkdir(mode=0o700)
    env=dict(os.environ,HOME=str(home),XDG_STATE_HOME=str(state),OMARCHY_SYSTEM_STATS_PROC_PATH=str(proc),
             OMARCHY_SYSTEM_STATS_SYS_PATH=str(home/'sys'),OMARCHY_SYSTEM_STATS_PASSWD_PATH=str(home/'passwd'))
    process=subprocess.Popen([str(ROOT/'activity-sampler'),'--activity-reader'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,env=env)
    def command(cmd):
        process.stdin.write(cmd+'\n');process.stdin.flush()
        lines=[]
        while True:
            line=process.stdout.readline().rstrip('\n')
            assert line or process.poll() is None, 'Reader exited unexpectedly'
            if line=='snapshot-end\t'+cmd:return lines
            lines.append(line)
    try:
        assert 'enabled\t1' in command('capture-250')
        time.sleep(.7)
        (proc/'uptime').write_text('100.75 0\n')
        (proc/'stat').write_text('cpu 125 0 125 850 0 0 0 0\n')
        (sensor/'temp1_input').write_text('86000\n')
        time.sleep(.65)
        command('capture-marker');command('capture-flush')
        rows=[json.loads(line) for p in (state/'omarchy/activity-lite/diagnostics').glob('samples-*.jsonl') for line in p.read_text().splitlines()]
        ticks=[r for r in rows if r['type']=='tick']
        assert len(ticks)>=5, ticks
        assert ticks[0]['cpu_pct'] is None
        assert any(r['temperature_c']==86 for r in ticks)
        assert any(r['type']=='processes' for r in rows)
        assert any(r['type']=='marker' for r in rows)
        assert all(r['schema']==2 and r['boot_id']=='fixture-boot' for r in rows)
        assert all(150<=b['mono_ms']-a['mono_ms']<=500 for a,b in zip(ticks,ticks[1:])), ticks
        assert not (state/'omarchy/activity-lite/journal').exists()
        assert not (state/'omarchy/activity-lite/sensors').exists()
        assert 'enabled\t0' in command('capture-off')
        count=sum(p.stat().st_size for p in (state/'omarchy/activity-lite/diagnostics').glob('*.jsonl'))
        time.sleep(.3)
        assert count==sum(p.stat().st_size for p in (state/'omarchy/activity-lite/diagnostics').glob('*.jsonl'))
        capture_status=command('capture-500')
        latest=next(line.split('\t',1)[1] for line in capture_status if line.startswith('session\t'))
        time.sleep(.6)
        os.kill(process.pid,signal.SIGSTOP);time.sleep(2.1);os.kill(process.pid,signal.SIGCONT)
        command('capture-status');time.sleep(.55)
        process.terminate();assert process.wait(timeout=3)==0
        rows=[json.loads(line) for p in (state/'omarchy/activity-lite/diagnostics').glob('samples-*.jsonl') for line in p.read_text().splitlines()]
        assert len({r['session'] for r in rows})==2
        assert len([r for r in rows if r['type']=='stop'])==2
        resumed=sorted((r for r in rows if r['session']==latest and r['type']=='tick'),key=lambda r:r['sequence'])
        assert any(r['lateness_ms']>=1500 for r in resumed), resumed
        assert all(b['mono_ms']-a['mono_ms']>100 for a,b in zip(resumed,resumed[1:])), 'Catch-up burst'
        assert any(r['type']=='rollup' for p in (state/'omarchy/activity-lite/diagnostics-rollup').glob('*.jsonl') for r in map(json.loads,p.read_text().splitlines()))
        for p in (state/'omarchy/activity-lite/diagnostics').glob('*.jsonl'):
            assert p.stat().st_mode&0o777==0o600
    finally:
        if process.poll() is None:process.kill();process.wait(timeout=3)
        process.stdin.close();process.stdout.close()
print('PASS native fast diagnostics: autonomous subsecond schedule, baseline, marker, stop, private bounded storage, legacy isolation, SIGTERM flush')
