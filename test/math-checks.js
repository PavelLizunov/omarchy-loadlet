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
let sensorHistory=M.nextSensorHistory({}, {sample:100,temperatures:[{id:'cpu',value:50}],fans:[]},240,15);
assert.equal(sensorHistory.cpu[0].breakBefore,undefined,'The first live sample must not declare saved-to-live continuity');
sensorHistory=M.nextSensorHistory(sensorHistory,{sample:103,temperatures:[{id:'cpu',value:55}],fans:[]},240,15);
assert.equal(sensorHistory.cpu[1].breakBefore,false);
sensorHistory=M.nextSensorHistory(sensorHistory,{sample:160,temperatures:[{id:'cpu',value:60}],fans:[]},240,15);
assert.equal(sensorHistory.cpu.length,3,'A gap does not erase earlier observations');
assert.equal(sensorHistory.cpu[2].breakBefore,true);
assert.equal(M.nextSensorHistory(sensorHistory,{sample:10,temperatures:[{id:'cpu',value:45}],fans:[]},240,15).cpu.length,1,'Counter reset starts a new history');
console.log('PASS model mathematics: CPU/RAM/swap ratios, rates, identity, bounded history and explicit sensor gaps');
