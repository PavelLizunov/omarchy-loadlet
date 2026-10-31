const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const watch = {};
vm.createContext(watch);
vm.runInContext(fs.readFileSync(`${__dirname}/../MemoryWatch.js`, 'utf8'), watch);
function raw(i, {pid = 42, start = 7, boot = 'fixture', anon = 100000 + i * 4096, pss = -1} = {}) {
  return ['schema\tactivity-memory-watch\t1', `sample\t${1000+i*30}\t${100+i*30}\t${100+i*30}\t${boot}`,
    'memory\tMemTotal\t1000000', 'memory\tMemAvailable\t700000', 'memory\tCached\t100000',
    'memory\tSReclaimable\t5000', 'memory\tSwapTotal\t200000', 'memory\tSwapFree\t200000',
    `process\t${pid}\t${start}\t1\tS\t300000\t${anon}\t0\t${pss}\t-1\tfixture`,
    'coverage\t1\t1\t0\t0\t0\t0\t2'].join('\n');
}
let frames = [];
for (let i = 0; i <= 20; ++i) frames = watch.append(frames, watch.parse(raw(i)), false);
let row = watch.summaries(frames)[0];
assert.equal(row.candidate, true);
assert.equal(row.span, 600); assert.equal(row.growth, 81920); assert.equal(row.pss, null);
assert.equal(frames[0].system.cache, 105000); assert.equal(frames[0].system.swap, 0);
assert.equal(frames[0].pressure.some, null);
assert.equal(watch.summaries(frames.slice(0,20))[0].candidate, false);
for (const overrides of [{start:8}, {boot:'another'}, {anon:-1}]) {
  const next = watch.append(frames, watch.parse(raw(21,overrides)), false);
  assert.equal(watch.summaries(next)[0].candidate, false);
}
assert.equal(watch.summaries(watch.append(frames,watch.parse(raw(21)),true))[0].candidate,false);
for (const mutate of [f=>f.mono+=100, f=>f.time+=30, f=>f.uptime+=100, f=>f.mono=1]) {
  const frame=watch.parse(raw(21)); mutate(frame);
  assert.equal(watch.append(frames,frame,false).at(-1).breakBefore,true);
}
let stable=[];
for(let i=0;i<=20;i++) stable=watch.append(stable,watch.parse(raw(i,{anon:100000})),false);
assert.equal(watch.summaries(stable)[0].candidate,false);
for(let i=21;i<150;i++)frames=watch.append(frames,watch.parse(raw(i)),false);
assert.equal(frames.length,121);
assert.equal(watch.parse('garbage'),null);
assert.equal(watch.parse(raw(1,{pid:0})),null);
assert.equal(watch.parse(raw(1)+'\n'+Array(256).fill('process\t1\t1\t1\tS\t1\t1\t0\t-1\t-1\tx').join('\n')),null);
const missing=watch.parse(raw(150,{anon:-1}));
const restored=watch.parse(raw(151));
const series=watch.series(watch.append(watch.append(frames,missing,false),restored,false),'anon','fixture:42:7');
assert.equal(series.at(-1).breakBefore,true);
const reverse=watch.parse(raw(152)); reverse.time=10;
assert.equal(watch.series(watch.append(frames,reverse,false),'used','').length,1);
const event={time:1600,process:row,system:frames[0].system};
const report=JSON.parse(watch.report([],[],'',[event]));
assert.equal(report.events[0].process.key,'fixture:42:7');
assert.equal(report.processes.length,0);
assert.match(report.scope,/not proven leaks/);
console.log('PASS memory watch: growth controls, missing data, PID/boot identity, gaps/clocks, bounds, series and retained event report');
