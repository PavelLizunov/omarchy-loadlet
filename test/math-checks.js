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
const fanChannel = (...fields) => ['fan-channel', ...fields].join('\t');
const nvFan = fanChannel('nv.0000_01_00_0.fan0', 'nvidia', 'nvidia', 'RTX 5060 Ti',
  'fan1', '0000:01:00.0', '125', 'auto', '', '30', '100', '1', '', 'gpu-fan');
const amdFan = fanChannel('amd.0000_03_00_0.pwm1', 'amdgpu', 'amdgpu', 'Radeon', 'fan1',
  '0000:03:00.0', '', 'manual', '1700', '20', '90', '1', '', 'amd-fan');
const boardFan = fanChannel('hw.nct6799.isa_0290.pwm16', 'hwmon', 'nct6799', 'Motherboard',
  'Case fan', 'isa-0290', '55', 'full', '0', '0', '100', '0', '', '');
const itFan = fanChannel('pwm2', 'it8613', 'it8613', 'ITE IT8613E', 'fan2', 'isa0a30',
  '16', 'auto', '', '0', '100', '1', 'pwm2', 'it-fan');
const snapshot = M.parseSensorSnapshot([
  'schema\tactivity-sensors\t1', 'sample\t100',
  'control\tpwm2\t40\t2\t', 'control\tpwm3\t41\t2', 'control\tpwm3\t70\t2\t880',
  'control\tpwm4\t256\t1\t0', 'control\tpwm4\t\t1\t0', 'control\tpwm4\t10\t\t0',
  'control\tpwm5\t50\t3\t0', 'control\tpwm5\t50\t1\t-20', 'control\tpwm5\t50',
  nvFan, nvFan, amdFan, boardFan, itFan,
  nvFan.replace('.fan0', '.fan8'), nvFan.replace('.fan0', '.fan2').replace('\t125\t', '\t151\t'),
  nvFan.replace('.fan0', '.fan2').replace('\t30\t100\t', '\t101\t100\t'),
  nvFan.replace('.fan0', '.fan2').replace('\tauto\t', '\tother\t'),
  'fan\tgpu-fan\tnvidia\tfan1\t150\tpercent\tgpu',
  'fan\tx\tnvidia\tfan2\t151\tpercent\tgpu',
  'temperature\tpsu\tpmbus\tIntake probe\t-8000\tpsu',
  'temperature\tbattery\tbattery\tCell probe\t22000\tbattery',
  'temperature\taio\tliquidctl\tCoolant\t15000\taio',
].join('\n'));
assert.equal(snapshot.controls.length, 5);
const [nvidia, amd, hwmon, it, oldIt] = snapshot.controls;
assert.deepEqual(nvidia, {id:'nv.0000_01_00_0.fan0', legacyId:'', backend:'nvidia', driver:'nvidia',
  owner:'RTX 5060 Ti', label:'fan1', location:'0000:01:00.0', duty:255, percent:125, mode:2,
  modeName:'auto', rpm:-1, minPercent:30, maxPercent:100, controllable:true, sensorId:'gpu-fan'});
assert.equal(amd.percent, -1);
assert.equal(amd.duty, -1);
assert.equal(amd.rpm, 1700);
assert.equal(amd.modeName, 'manual');
assert.equal(hwmon.rpm, 0);
assert.equal(hwmon.controllable, false);
assert.equal(it.duty, 40);
assert.equal(it.sensorId, 'it-fan');
assert.equal(oldIt.duty, 41);
assert.equal(oldIt.rpm, -1);
assert.deepEqual(snapshot.fans.map(fan => fan.value), [150]);
assert.deepEqual(snapshot.temperatures.map(sensor => sensor.category), ['battery', 'psu', 'aio']);
assert.equal(snapshot.temperatures[1].label, 'Intake probe');
const processSamples = [{pid:1,cpu:0,cpuMeasured:false}, {pid:2,cpu:0}, {pid:3,cpu:25,cpuMeasured:true}];
assert.deepEqual(M.filterAndSortProcesses(processSamples, '', 'cpu', true).map(p => p.pid), [2,3,1]);
assert.deepEqual(M.filterAndSortProcesses(processSamples, '', 'cpu', false).map(p => p.pid), [3,2,1]);
let sensorHistory=M.nextSensorHistory({}, {sample:100,temperatures:[{id:'cpu',value:50}],fans:[]},240,15);
assert.equal(sensorHistory.cpu[0].breakBefore,undefined,'The first live sample must not declare saved-to-live continuity');
sensorHistory=M.nextSensorHistory(sensorHistory,{sample:103,temperatures:[{id:'cpu',value:55}],fans:[]},240,15);
assert.equal(sensorHistory.cpu[1].breakBefore,false);
sensorHistory=M.nextSensorHistory(sensorHistory,{sample:160,temperatures:[{id:'cpu',value:60}],fans:[]},240,15);
assert.equal(sensorHistory.cpu.length,3,'A gap does not erase earlier observations');
assert.equal(sensorHistory.cpu[2].breakBefore,true);
assert.equal(M.nextSensorHistory(sensorHistory,{sample:10,temperatures:[{id:'cpu',value:45}],fans:[]},240,15).cpu.length,1,'Counter reset starts a new history');
const missing=M.nextSensorHistory(sensorHistory,{sample:163,temperatures:[],fans:[]},240,15);
assert.equal(missing.cpu.length,3,'Temporary absence retains observations');
assert.equal(missing.cpu.at(-1).unavailableAfter,true);
assert.equal(sensorHistory.cpu.at(-1).unavailableAfter,undefined,'Previous snapshot is immutable');
const returned=M.nextSensorHistory(missing,{sample:166,temperatures:[{id:'cpu',value:61}],fans:[]},240,15);
assert.equal(returned.cpu.at(-1).breakBefore,true,'Even a brief disappearance breaks continuity');
assert.equal(Object.keys(M.nextSensorHistory(missing,{sample:221,temperatures:[],fans:[]},240,15)).length,0);
const many=Object.fromEntries(Array.from({length:300},(_,i)=>['sensor'+i,[{time:100,value:i}]]));
assert.equal(Object.keys(M.nextSensorHistory(many,{sample:103,temperatures:[],fans:[]},240,15)).length,288);
const mixed=M.parseGpuSnapshot('schema\tactivity-gpus\t1\nsample\t100\n'
  +'process-gpu\tgpu0\t42\t123\t40\nprocess-engine\tgpu0\tclient\trender\t100\t-1\t1\ttime\t42\t123\n'
  +'process-gpu\tgpu0\t42\t123\t20\nprocess-gpu\tgpu1\t42\t123\t60\n');
assert.equal(mixed.processGpus.length,2,'One PID/start/GPU identity for direct and engine rows');
assert.equal(mixed.processGpus[0].engines.length,1);
assert.equal(mixed.processGpus[0].directUtilization,40);
assert.deepEqual(M.nextProcessGpus(null,mixed)['42:123'],{usage:60,byGpu:{gpu0:40,gpu1:60}});
console.log('PASS model mathematics: ratios, identity, mixed GPU records, bounded missing history and explicit gaps');
