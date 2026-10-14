// Run: node docs/design-drafts/check-character-face.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const vector = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'CharacterSvg.js'), 'utf8'), vector);
const svg = (cpu, ram, fresh = true) => vector.iconSvg(cpu, ram, fresh, '#d8dee9', '#2e3440');
assert.equal(fs.readFileSync(path.join(__dirname, 'activity-character-face.svg'), 'utf8'), svg(30, 44));
assert.equal(svg(-1, -1, false), svg(85, 92, false));
assert.equal(svg(NaN, NaN), svg(-1, -1));
assert.equal(svg(200, 200), svg(100, 100));
assert.notEqual(svg(0, 44), svg(85, 44));
assert.notEqual(svg(30, 0), svg(30, 92));
assert.ok(!svg(0, 0).includes('clip-path'));
assert.ok(!vector.iconSvg(0, 0, true, '"><script/>', 'bad').includes('<script'));
console.log('PASS: SVG snapshot parity, CPU/RAM state distinction, stale/invalid values, bounds, color validation');
