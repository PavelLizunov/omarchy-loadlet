// Production numerical helpers, checked against independent arithmetic.
const assert=require('node:assert/strict');
const M=require('../Model.js');
for(let total=100;total<=10000;total*=10) {
  for(let idle=0;idle<=total;idle+=total/20) {
    assert.ok(Math.abs(M.counterPercent({total:20000,idle:5000},{total:20000+total,idle:5000+idle})-100*(total-idle)/total)<1e-9);
  }
}
for(let available=0;available<=1000;available+=25) {
  assert.ok(Math.abs(M.memoryPercent({total:1000,available})-(1000-available)/10)<1e-9);
  assert.ok(Math.abs(M.swapPercent({swapTotal:1000,swapFree:available})-(1000-available)/10)<1e-9);
}
assert.equal(M.memoryPercent({total:1000,available:2000}),0);
assert.equal(M.swapPercent({swapTotal:0,swapFree:0}),0);
assert.equal(M.counterRate(100,500,4),100);
assert.equal(M.counterRate(500,100,4),0);
assert.equal(M.counterRate(100,500,0),0);
const p=(start,ticks,rss)=>({pid:42,startTicks:start,cpuTicks:ticks,rss,name:'worker'});
const before={sample:100,clockTicks:100,processes:[p(123,1000,1024)]};
const next={sample:130,clockTicks:100,processes:[p(123,7000,2048)]};
const value=M.nextProcesses(before,next,8192)[0];
assert.equal(value.cpu,200);assert.equal(value.memory,25);assert.equal(value.rss,2048);
next.processes=[p(124,8000,2048)];assert.equal(M.nextProcesses(before,next,8192)[0].cpu,0);
next.sample=100;assert.equal(M.nextProcesses(before,next,8192)[0].cpu,0);
assert.deepEqual(M.appendHistory([1,2,3],4,3),[2,3,4]);
console.log('PASS model mathematics: CPU ratios 63 cases, RAM/swap ratios 82 cases, rates, one-core process CPU, identity and bounded history');
const gpuFrame=(extra)=>'schema\tactivity-gpus\t1\nsample\t10\ngpu\t0000:04:00.0\tNVIDIA\tnvidia\tTest\t40\t1\t2\tvram\t1500\n'+extra;
assert.equal(M.nextGpus(M.emptyGpuSnapshot(),M.parseGpuSnapshot(gpuFrame('gpu-temperature\t0000:04:00.0\t61.5\n')))[0].temperature,61.5);
assert.equal(M.nextGpus(M.emptyGpuSnapshot(),M.parseGpuSnapshot(gpuFrame('')))[0].temperature,-1);
assert.equal(M.parseGpuSnapshot(gpuFrame('gpu-temperature\t0000:04:00.0\t900\n')).gpus[0].temperature,-1);
assert.equal(M.parseGpuSnapshot(gpuFrame('gpu-temperature\t0000:04:00.0\t61\n')).gpus.length,1);
console.log('PASS GPU temperature parsing: present, absent from an older sampler, and implausible values');
const thermal=M.parseThermalSnapshot('schema\tactivity-thermals\t1\nsample\t10\ntemperature\thwmon5/temp1\tcoretemp\tPackage id 0\t38000\ngpu-temperature\tcard0\t45\ngpu-temperature\tcard1\t61.5\ngpu-temperature\tcard2\t900\n');
assert.equal(thermal.temperatures.length,1);assert.equal(thermal.gpuTemperatures.length,2);
assert.equal(M.gpuTemperature(thermal.gpuTemperatures),61.5);
assert.equal(M.gpuTemperature(M.parseThermalSnapshot('schema\tactivity-thermals\t1\nsample\t10\n').gpuTemperatures),-1);
console.log('PASS thermal GPU temperature: hottest adapter, implausible rows dropped, absent stays unknown');
