const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync('ProfileCodec.js', 'utf8').replace('.pragma library', ''), context);
for (const value of [{}, {cpu:{boost:false}}, {fans:{pwm2:42},cpu:{governor:'performance',epp:'performance',maxMHz:0},gpuFans:{}},
  {name:'Lüfter · Тихий · 静音 · 🌡️', label:'e\u0301'}, ...Array.from({length:64},(_,i)=>({x:'x'.repeat(i)}))]) {
  const expected = Buffer.from(JSON.stringify(value)).toString('base64').replace(/\+/g,'-').replace(/\//g,'_');
  assert.equal(context.encode(value), expected);
  assert.equal(JSON.stringify(context.decode(expected)), JSON.stringify(value));
  assert.equal(JSON.stringify(context.decode(expected.replace(/=+$/, ''))), JSON.stringify(value));
}
for (const invalid of ['A', 'e30===', 'e31=', '====', '8A==']) assert.throws(() => context.decode(invalid));
console.log('PASS portable UTF-8 profile codec: independent Node base64 oracle, padding and invalid input');
