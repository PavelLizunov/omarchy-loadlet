// Build the fifty SVG artifacts, validating their geometry/state identities.
// Run from the repository: node docs/design-drafts/export-simple-characters.js
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const vector = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'SimpleVariants.js'), 'utf8'), vector);
const options = vector.variants();
assert.equal(options.length, 50);
const unique = new Set();
for (const option of options) {
    const svg = vector.svg(option.number, 30, 44, true);
    unique.add(svg);
    assert.notEqual(svg, vector.svg(option.number, 85, 92, true));
    assert.notEqual(vector.svg(option.number, 30, 44, true), vector.svg(option.number, 85, 44, true));
    assert.notEqual(vector.svg(option.number, 30, 44, true), vector.svg(option.number, 30, 92, true));
    assert.equal(vector.svg(option.number, 30, 44, false), vector.svg(option.number, -1, -1, false));
    assert.equal(vector.svg(option.number, 200, 200, true), vector.svg(option.number, 100, 100, true));
    assert.ok(!svg.includes('clip-path') && !svg.includes('NaN'));
}
assert.equal(unique.size, 50);
for (const option of options) {
    const target = path.join(__dirname, `simple-character-${String(option.number).padStart(2, '0')}.svg`);
    const svg = vector.svg(option.number, 30, 44, true);
    if (fs.existsSync(target) && process.argv.includes('--refresh-owned')) fs.writeFileSync(target, svg);
    else if (fs.existsSync(target)) assert.equal(fs.readFileSync(target, 'utf8'), svg, 'Preserve existing artifact: ' + target);
    else fs.writeFileSync(target, svg, {flag: 'wx'});
}
console.log('PASS: 50 unique SVG geometries; independent CPU/RAM values, stale handling and clamping; 50 snapshots exported');
