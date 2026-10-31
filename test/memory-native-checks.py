"""Bounded native memory snapshots against synthetic procfs, with capture coexistence."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='loadlet-memory-native-') as directory:
    base = Path(directory)
    proc = base/'proc'
    (proc/'sys/kernel/random').mkdir(parents=True)
    (proc/'sys/kernel/random/boot_id').write_text('fixture-boot\n')
    (proc/'uptime').write_text('100 0\n')
    (proc/'stat').write_text('cpu 100 0 100 800 0 0 0 0\n')
    (proc/'meminfo').write_text('MemTotal: 1000000 kB\nMemAvailable: 700000 kB\nCached: 100000 kB\nSReclaimable: 5000 kB\n')
    (proc/'pressure').mkdir()
    (proc/'pressure/memory').write_text('some avg10=1.25 avg60=0.0 avg300=0.0 total=2\nfull avg10=0.50 avg60=0.0 avg300=0.0 total=1\n')
    def add(pid, rss, state='S', kernel=False):
        folder=proc/str(pid);folder.mkdir()
        fields=[state,'1','0','0','0','0',str(0x200000 if kernel else 0)]+['0']*12+[str(pid*10)]
        (folder/'stat').write_text(f'{pid} (fixture ) name) '+ ' '.join(fields)+'\n')
        if state!='Z':
            (folder/'status').write_text(f'VmRSS: {rss} kB\nRssAnon: {rss//2} kB\nVmSwap: 0 kB\n')
        (folder/'smaps_rollup').write_text('Pss: 80 kB\nPrivate_Clean: 10 kB\nPrivate_Dirty: 20 kB\n')
    for pid in range(1,271):add(pid,1000+pid)
    add(300,500000,'Z');add(301,500000,kernel=True)
    (proc/'270/smaps_rollup').unlink()
    (proc/'269/status').write_text('VmRSS: 1269 kB\nRssAnon: -1 kB\nVmSwap: invalid kB\n')
    env=dict(os.environ, HOME=str(base), XDG_STATE_HOME=str(base/'state'),
             OMARCHY_SYSTEM_STATS_PROC_PATH=str(proc), OMARCHY_SYSTEM_STATS_SYS_PATH=str(base/'sys'))
    def request(commands):
        return subprocess.run([str(ROOT/'activity-sampler'),'--activity-reader'],input=commands,text=True,
                              capture_output=True,timeout=8,check=True,env=env).stdout
    output=request('memory-watch\n')
    rows=[line.split('\t') for line in output.splitlines() if line.startswith('process\t')]
    assert len(rows)==256 and rows[0][1]=='270'
    assert rows[0][8:10]==['-1','-1']
    assert rows[1][6:10]==['-1','-1','80','30']
    assert all(row[1] not in ('300','301') for row in rows)
    assert 'coverage\t270\t256\t31\t0\t1\t1\t' in output
    assert 'pressure\tsome\t1.250' in output
    assert 'memory\tSwapFree\t-1' in output
    assert output.endswith('snapshot-end\tmemory-watch\n') and len(output)<262144
    assert not (base/'state').exists(), 'Observation must not create a journal'
    combined=request('capture-500\nmemory-watch\ncapture-status\ncapture-off\n')
    assert combined.count('snapshot-end\t')==4
    assert 'enabled\t1' in combined and 'enabled\t0' in combined
print('PASS native memory: RSS ordering/256 retention, 32 PSS admissions, unknown counters, zombie/kernel exclusion, framing, no watch persistence, capture coexistence')
