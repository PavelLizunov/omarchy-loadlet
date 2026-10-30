// Production controller functions, with inert clock/process/timer fixtures.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../ActivityController.qml'), 'utf8');
const timer = () => ({started: 0, stopped: 0, interval: 0,
  start() { this.started++; }, restart() { this.started++; }, stop() { this.stopped++; }});
const context = vm.createContext({
  captureWanted:false, captureEnabled:false, captureInterval:500, captureAppliedInterval:0, captureAction:"",
  sensorRecording: false, sensorWriterEnabled: false, sensorRecordingError: "", sensorsActive: false,
  gpuEnabled: false, storageEnabled: false, sensorSummaryEnabled: false,
  sensorHistory: {}, sensorsUpdatedAt: 0,
  Heat: {}, journalEnabled: false, journalWriterEnabled: false, journalError: '', heatLevel: 0,
  Model: require('../Model.js'), locale: {t: x => x}, language: 'ru', active: true, collectionEnabled: true,
  state: 'stopped', pending: '', buffer: [], bufferSize: 0, failures: 0,
  errorText: '', expanded: false, due: {}, lastTick: 0,
  reader: {running: false, writes: [], write(x) { this.writes.push(x); }},
  watchdog: timer(), shutdown: timer(), scheduler: timer(), retry: timer(), warmup: timer(), processWarmup: timer(),
  Qt: {callLater() {}}, profile: {resources: 3000, processes: 6000, thermals: 15000},
  historySamples: 60, metrics: {}, heatThreshold: 80, thermalFresh: false
});
vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../HeatPolicy.js'),'utf8'), context.Heat);
context.root = context;
context.backgroundInterval = Number(source.match(/readonly property int backgroundInterval: (\d+)/)[1]);
vm.runInContext(source.match(/readonly property int glanceMaxAge: (.*)/)[1].replace(/^/, 'glanceMaxAge = '), context);
assert.equal(context.backgroundInterval, 15000);
assert.equal(context.glanceMaxAge, 35000);
for (const match of source.matchAll(/^  function \w+\([^]*?^  }/gm)) vm.runInContext(match[0], context);
vm.runInContext('start()', context);
assert.equal(context.state, 'starting');
// FailedToStart: no exited callback, but startup watchdog must recover.
context.reader.running = false;
vm.runInContext('fail()', context);
assert.equal(context.state, 'stopping');
const shutdownBody = source.match(/id: shutdown[^]*?onTriggered: \{([^]*?)\n    }/)[1];
context.root = context;
vm.runInContext(shutdownBody, context);
assert.equal(context.state, 'backoff');
assert.ok(context.retry.interval >= 2000);
context.state = 'ready'; context.reader.running = true;
vm.runInContext('dispatch(); dispatch()', context);
assert.equal(context.reader.writes.length, 1);
context.pending = 'resources'; context.bufferSize = 262144;
vm.runInContext('consume("overflow")', context);
assert.equal(context.state, 'stopping');
context.active = false; context.collectionEnabled = false; context.state = 'stopped'; context.reader.running = false;
vm.runInContext('stop(); dispatch()', context);
assert.equal(context.reader.running, false);
assert.equal(context.pending, '');
console.log('PASS controller: failed startup, bounded retry, single flight, overflow, background gate');
context.active = true; context.collectionEnabled = true; context.state = 'ready'; context.pending = 'processes';
context.buffer = ['schema\tactivity-processes\t1', 'sample\t100\t100'];
context.previousProcesses = context.Model.emptyProcessSnapshot(); context._processMetricsReady = false;
const before = Date.now();
vm.runInContext('consume("snapshot-end\\tprocesses")', context);
assert.ok(context.due.processes >= before + 600 && context.due.processes <= Date.now() + 600);
assert.equal(context.processWarmup.started, 1);
console.log('PASS controller: first process sample schedules a 600ms wakeup instead of the regular interval');
context.active = false; context.collectionEnabled = true;
context.state = 'ready'; context.pending = ''; context.due = {}; context.reader.writes = [];
vm.runInContext('dispatch()', context);
assert.deepEqual(context.reader.writes, ['glance\n']);
context.pending = ''; context.due.glance = Date.now() + 15000;
vm.runInContext('dispatch()', context);
assert.deepEqual(context.reader.writes, ['glance\n', 'thermals\n']);
context.pending = ''; context.due.thermals = Date.now() + 15000;
vm.runInContext('dispatch()', context);
assert.equal(context.reader.writes.length, 2);
context.glancePrevious = context.Model.emptySnapshot(); context.memoryAlert = false;
const snapshot = (sample, total, idle, used) => ({sample, cpu: {total,idle}, memory: {total:1000,available:1000-used}});
context.next = snapshot(100, 10000, 5000, 500);
vm.runInContext('updateGlance(next)', context);
assert.equal(context.glanceCpu, -1);
context.next = snapshot(115.3, 11000, 5700, 860);
vm.runInContext('updateGlance(next)', context);
assert.equal(context.glanceCpu, 30);
assert.equal(context.memoryAlert, true);
context.next = snapshot(130.6, 12000, 6500, 820);
vm.runInContext('updateGlance(next)', context);
assert.equal(context.memoryAlert, true);
context.next = snapshot(145.9, 13000, 7200, 790);
vm.runInContext('updateGlance(next)', context);
assert.equal(context.memoryAlert, false);
context.pending = ''; context.due = {}; context.lastTick = Date.now() - 16000;
const retainedBaseline = context.glancePrevious;
vm.runInContext('dispatch()', context);
assert.equal(context.glancePrevious, retainedBaseline, '15s cadence plus jitter must not reset the baseline');
context.next = snapshot(200, 14000, 7300, 700);
vm.runInContext('updateGlance(next)', context);
assert.equal(context.glanceCpu, -1, 'resume must not reuse old CPU baseline');
vm.runInContext('fail()', context);
assert.equal(context.glanceUpdatedAt, 0);
console.log('PASS icon sampling: 15s cadence, 35s limit, timer jitter, CPU delta, memory hysteresis, stale failure');
const thermal = n => `schema\tactivity-thermals\t1\nsample\t123\ntemperature\tcpu0\tcoretemp\tPackage id 0\t${n * 1000}`;
context.raw = thermal(80);
vm.runInContext('accept("thermals", raw)', context);
assert.equal(context.iconTemperature,80);
// QML thermalFresh is exercised separately by QtTest; set its equivalent here.
context.thermalFresh=true;
vm.runInContext('updateHeatAlert()',context); assert.equal(context.heatAlert,true);
context.raw=thermal(77);vm.runInContext('accept("thermals",raw)',context);assert.equal(context.heatAlert,true);
context.raw=thermal(74);vm.runInContext('accept("thermals",raw)',context);assert.equal(context.heatAlert,false);
context.raw=thermal(82);vm.runInContext('accept("thermals",raw)',context);assert.equal(context.heatAlert,true);
context.thermalFresh=false;vm.runInContext('updateHeatAlert()',context);assert.equal(context.heatAlert,false);
context.raw='schema\tactivity-thermals\t1\nsample\t124';vm.runInContext('accept("thermals",raw)',context);
assert.equal(context.iconTemperature,-1);assert.equal(context.thermalUpdatedAt,0);
vm.runInContext('resetData()',context);assert.equal(context.heatAlert,false);
console.log('PASS thermals: background admission, 80/75 hysteresis, missing sensors, stale alert reset');
context.state='ready';context.pending='';context.active=false;context.due={};context.reader.writes=[];
context.journalEnabled=true;context.journalWriterEnabled=false;
vm.runInContext('dispatch()',context);assert.deepEqual(context.reader.writes,['journal-on\n']);
context.pending='';context.journalWriterEnabled=true;
context.due={glance:Date.now()+15000,thermals:Date.now()+15000};
vm.runInContext('dispatch()',context);assert.equal(context.reader.writes[1],'processes\n');
context.pending='processes';context.buffer=['schema\tactivity-processes\t1','sample\t100\t100'];
vm.runInContext('consume("snapshot-end\\tprocesses")',context);
assert.ok(context.due.processes>=Date.now()+29900);
context.journalEnabled=false;context.pending='';context.reader.writes=[];context.due={};
vm.runInContext('resetData()',context);assert.equal(context.journalWriterEnabled,true,'panel reset must not lose native writer state');
vm.runInContext('dispatch()',context);assert.equal(context.reader.writes[0],'journal-off\n');
context.journalWriterEnabled=false;context.journalEnabled=true;context.pending='';
context.due={'journal-on':Date.now()+60000,glance:Date.now()+15000,thermals:Date.now()+15000};
context.reader.writes=[];vm.runInContext('dispatch()',context);assert.equal(context.reader.writes.length,0,'failed writer retries bounded, no detail sampling until enabled');
console.log('PASS journal admission: writer configuration first, process cadence 30s, stop and bounded failure retry');
context.journalEnabled=false;context.journalWriterEnabled=false;context.sensorRecording=true;
context.sensorWriterEnabled=false;context.pending='';context.due={};context.reader.writes=[];
vm.runInContext('dispatch()',context);assert.equal(context.reader.writes[0],'sensors-on\n');
context.pending='';context.raw='schema\tactivity-sensor-recording\t1\nenabled\t1';
vm.runInContext('accept("sensors-on",raw)',context);assert.equal(context.sensorWriterEnabled,true);
context.raw='schema\tactivity-sensors\t1\nsample\t100\ntemperature\tcpu\tk10temp\tTctl\t54000\tcpu\tAMD\tpackage0';
vm.runInContext('accept("sensors",raw)',context);assert.equal(context.sensorHistory.cpu.length,1);
assert.equal(context._sensorSnapshot.temperatures[0].value,54);
vm.runInContext('resetData()',context);assert.equal(context.sensorHistory.cpu.length,1,'Recording history survives panel close');
context.sensorRecording=false;context.pending='';context.reader.writes=[];context.due={};
vm.runInContext('dispatch()',context);assert.equal(context.reader.writes[0],'sensors-off\n');
vm.runInContext('resetData()',context);assert.equal(Object.keys(context.sensorHistory).length,0);
console.log('PASS sensor recording: configuration-first admission, units, retained background history, explicit stop');
