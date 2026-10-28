const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync('ProfileCodec.js', 'utf8').replace('.pragma library', ''), context);
for (const value of [{}, {cpu:{boost:false}}, {fans:{pwm2:42},cpu:{governor:'performance',epp:'performance',maxMHz:0},gpuFans:{}}, ...Array.from({length:64},(_,i)=>({x:'x'.repeat(i)}))]) {
  const expected = Buffer.from(JSON.stringify(value)).toString('base64').replace(/\+/g,'-').replace(/\//g,'_');
  assert.equal(context.encode(value), expected);
}
console.log('PASS portable profile encoding: independent Node base64 oracle, all padding lengths');
