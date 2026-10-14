"""Exercise the real native sampler against an inert NVML fixture."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as directory:
    base = Path(directory)
    device = base / 'sys/class/drm/card0/device'
    (device / 'power').mkdir(parents=True)
    (base / 'proc').mkdir()
    (base / 'proc/uptime').write_text('100.0 0.0\n')
    (device / 'vendor').write_text('0x10de\n')
    (device / 'product_name').write_text('Fixture\n')
    power = device / 'power/runtime_status'
    power.write_text('suspended\n')
    source = base / 'nvml.cpp'
    source.write_text('''
#include <cstdio>
#include <cstdlib>
extern "C" {
void logcall(const char *s) { auto f=fopen(getenv("NVML_LOG"),"a"); if(f){fputs(s,f);fclose(f);} }
int nvmlInitWithFlags(unsigned f) { logcall(f==2?"init2\\n":"bad\\n"); return 0; }
int nvmlShutdown() { logcall("stop\\n"); return 0; }
int nvmlDeviceGetHandleByPciBusId_v2(const char*,void** d) { *d=(void*)1; return 0; }
int nvmlDeviceGetName(void*,char* s,unsigned n) { snprintf(s,n,"Fixture"); return 0; }
int nvmlDeviceGetUtilizationRates(void*,void* p) { ((unsigned*)p)[0]=12; ((unsigned*)p)[1]=0; return 0; }
int nvmlDeviceGetMemoryInfo(void*,void* p) { auto v=(unsigned long long*)p; v[0]=100;v[1]=80;v[2]=20; return 0; }
int nvmlDeviceGetClockInfo(void*,unsigned,unsigned* p) { *p=300; return 0; }
}
''')
    subprocess.run(['g++', '-shared', '-fPIC', str(source), '-o', str(base/'libnvidia-ml.so.1')], check=True)
    log = base/'calls'
    env = dict(os.environ, LD_LIBRARY_PATH=str(base), NVML_LOG=str(log),
               OMARCHY_SYSTEM_STATS_SYS_PATH=str(base/'sys'),
               OMARCHY_SYSTEM_STATS_PROC_PATH=str(base/'proc'))
    for status in ['suspended', 'active', 'suspended']:
        power.write_text(status+'\n')
        result = subprocess.run([str(ROOT/'activity-sampler'), '--activity-gpus'],
                                env=env, capture_output=True, text=True, timeout=3, check=True)
        if status == 'active': assert log.read_text() == 'init2\nstop\n'
        elif log.exists(): assert log.read_text() == 'init2\nstop\n'
        else: assert not log.exists()
    print('PASS NVIDIA: suspended skips NVML; active uses NO_ATTACH and shutdown')
