"""Exercise power admission and mapping/session lifetimes with inert NVML."""
from pathlib import Path
import os
import selectors
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SAMPLER = Path(os.environ.get('ACTIVITY_TEST_SAMPLER', ROOT / 'activity-sampler'))


def frame(process):
    data = b''
    deadline = time.monotonic() + 3
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        while not data.endswith(b'snapshot-end\tgpus\n'):
            remaining = deadline - time.monotonic()
            assert remaining > 0 and selector.select(remaining), 'GPU frame timed out'
            chunk = os.read(process.stdout.fileno(), 16384)
            assert chunk, 'Reader exited before frame completed'
            data += chunk
            assert len(data) <= 262144
    assert b'schema\tactivity-gpus\t1\n' in data
    return data


with tempfile.TemporaryDirectory() as directory:
    base = Path(directory)
    device = base / 'sys/devices/0000:01:00.0'
    (device / 'power').mkdir(parents=True)
    pci = base / 'sys/bus/pci/devices'
    pci.mkdir(parents=True)
    (pci / device.name).symlink_to(device)
    proc_gpus = base / 'proc/driver/nvidia/gpus'
    (proc_gpus / device.name).mkdir(parents=True)
    nvidia_driver = base / 'sys/bus/pci/drivers/nvidia'
    nouveau_driver = nvidia_driver.with_name('nouveau')
    nvidia_driver.mkdir(parents=True)
    nouveau_driver.mkdir()
    driver = device / 'driver'
    driver.symlink_to(nouveau_driver)
    (base / 'proc/uptime').write_text('100.0 0.0\n')
    (device / 'vendor').write_text('0x10de\n')
    (device / 'product_name').write_text('Fixture\n')
    power = device / 'power/runtime_status'
    source = base / 'nvml.cpp'
    source.write_text('''
#include <cstdio>
#include <cstdlib>
#include <sys/eventfd.h>
extern "C" {
void logcall(const char *s) { auto f=fopen(getenv("NVML_LOG"),"a"); if(f){fputs(s,f);fclose(f);} }
// Model a driver resource lost on unloading: the provider must not reload it per sample.
__attribute__((constructor)) void mapped() { eventfd(0,EFD_CLOEXEC);logcall("map\\n"); }
__attribute__((destructor)) void unmapped() { logcall("unmap\\n"); }
int nvmlInitWithFlags(unsigned f) { logcall(f==0?"init0\\n":"bad\\n"); return 0; }
int nvmlShutdown() { logcall("stop\\n"); return 0; }
int nvmlDeviceGetHandleByPciBusId_v2(const char*,void** d) { *d=(void*)1; return 0; }
int nvmlDeviceGetName(void*,char* s,unsigned n) { snprintf(s,n,"Fixture"); return 0; }
int nvmlDeviceGetUtilizationRates(void*,void* p) { ((unsigned*)p)[0]=12; ((unsigned*)p)[1]=0; return 0; }
int nvmlDeviceGetMemoryInfo(void*,void* p) { auto v=(unsigned long long*)p; v[0]=100;v[1]=80;v[2]=20; return 0; }
int nvmlDeviceGetClockInfo(void*,unsigned,unsigned* p) { *p=300; return 0; }
int nvmlDeviceGetNumFans(void*, unsigned* n) { *n=3; return 0; }
int nvmlDeviceGetFanSpeed_v2(void*, unsigned fan, unsigned* v) {
    if (fan != 0) return 3;
    *v=120; return 0;
}
int nvmlDeviceGetFanControlPolicy_v2(void*, unsigned fan, unsigned* v) {
    if (fan >= 2) return 3;
    *v=fan; return 0;
}
int nvmlDeviceGetTargetFanSpeed(void*, unsigned, unsigned* v) { *v=65; return 0; }
int nvmlDeviceGetMinMaxFanSpeed(void*, unsigned* low, unsigned* high) { *low=25; *high=95; return 0; }
struct FanSpeed { unsigned version, fan, speed; };
int nvmlDeviceGetFanSpeedRPM(void*, FanSpeed* info) {
    if (info->version != ((1U << 24) | sizeof(FanSpeed)) || info->fan != 1) return 3;
    info->speed=1700; return 0;
}
}
''')
    subprocess.run(['g++', '-shared', '-fPIC', str(source), '-o', str(base/'libnvidia-ml.so.1')], check=True)
    log = base/'calls'
    env = dict(os.environ, LD_LIBRARY_PATH=str(base), NVML_LOG=str(log),
               OMARCHY_SYSTEM_STATS_SYS_PATH=str(base/'sys'),
               OMARCHY_SYSTEM_STATS_PROC_PATH=str(base/'proc'))
    power.write_text('active\n')
    subprocess.run([str(SAMPLER), '--activity-gpus'], env=env, capture_output=True, timeout=3, check=True)
    assert not log.exists(), 'A bound Nouveau device must never map NVML'
    driver.unlink()
    driver.symlink_to(nvidia_driver)
    for status in ['suspended', 'active', 'suspended']:
        power.write_text(status+'\n')
        subprocess.run([str(SAMPLER), '--activity-gpus'], env=env,
                       capture_output=True, timeout=3, check=True)
        if log.exists():
            assert log.read_text() == 'map\ninit0\nstop\nunmap\n'
        else:
            assert status == 'suspended'
    log.unlink()
    process = subprocess.Popen([str(SAMPLER), '--activity-reader'], env=env,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        def request(status):
            power.write_text(status+'\n')
            process.stdin.write(b'gpus\n')
            process.stdin.flush()
            return frame(process)

        for status in ['suspended', 'unknown', 'unsupported']:
            request(status)
            assert not log.exists(), 'Inactive/unknown NVIDIA must not initialize NVML'
        assert b'Fixture\t12\t20\t100' in request('active')
        steady_fds = len(list(Path(f'/proc/{process.pid}/fd').iterdir()))
        for _ in range(24):
            assert b'Fixture\t12\t20\t100' in request('active')
            assert len(list(Path(f'/proc/{process.pid}/fd').iterdir())) == steady_fds, 'FD growth across samples'
        calls = log.read_text()
        assert calls == 'map\n' + 'init0\nstop\n' * 25, 'One mapping, balanced per-sample sessions'
        request('suspended')
        request('unknown')
        assert log.read_text() == calls, 'No calls during inactivity'
        request('active')
        assert log.read_text() == calls + 'init0\nstop\n', 'Resume without remapping'
        calls = log.read_text()
        driver.unlink()
        driver.symlink_to(nouveau_driver)
        assert b'\t12\t20\t100\t' not in request('active')
        assert b'\t12\t20\t100\t' not in request('active')
        assert log.read_text() == calls, 'A cached device must be revalidated before NVML admission'
        process.stdin.close()
        assert process.wait(timeout=3) == 0
        assert log.read_text() == calls + 'unmap\n', 'Unload only on reader destruction'
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=3)
        process.stdin.close()
        process.stdout.close()
        process.stderr.close()
    driver.unlink()
    driver.symlink_to(nvidia_driver)
    (proc_gpus / device.name).rmdir()
    data = subprocess.run([str(SAMPLER), '--activity-sensors'], env=env, capture_output=True,
                          text=True, timeout=3, check=True).stdout.splitlines()
    rows = [line.split('\t') for line in data if line.startswith('fan-channel\t')]
    assert len(rows) == 3 and all(len(row) == 15 for row in rows), rows
    assert rows[0] == ['fan-channel', 'nv.0000_01_00_0.fan0', 'nvidia', 'nvidia', 'Fixture',
                       'fan1', '0000:01:00.0', '120', 'auto', '', '25', '95', '1', '',
                       'nvidia/0000:01:00.0/fan0']
    assert rows[1][7:15] == ['', 'manual', '1700', '25', '95', '1', '', 'nvidia/0000:01:00.0/fan1']
    assert rows[2][7:15] == ['', 'unknown', '', '25', '95', '1', '', '']
    assert 'fan\tnvidia/0000:01:00.0/fan0\tFixture\tfan1\t120\tpercent\tgpu\tFixture\t0000:01:00.0' in data
    assert 'fan\tnvidia/0000:01:00.0/fan1\tFixture\tfan2\t1700\trpm\tgpu\tFixture\t0000:01:00.0' in data
    print('PASS NVIDIA: headless discovery, driver/power admission, per-fan telemetry, balanced sessions and stable FDs')
