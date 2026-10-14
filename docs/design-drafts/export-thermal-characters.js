// Run: node docs/design-drafts/export-thermal-characters.js
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const shapes = {}, vector = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'SimpleVariants.js'), 'utf8'), shapes);
vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'ThermalVariants.js'), 'utf8'), vector);
for (let i = 0; i < 10; ++i) {
    const render = (cpu, ram, fresh, hot, temperatureFresh, style) => vector.svg(shapes.bodies[i].path, i, cpu, ram, fresh, hot, temperatureFresh, style);
    const normal = render(30, 44, true, false, true, 0);
    assert.notEqual(normal, render(85, 44, true, false, true, 0));
    assert.notEqual(normal, render(30, 92, true, false, true, 0));
    assert.equal(normal, render(30, 44, true, true, false, 0));
    assert.equal(render(NaN, -1, true, false, true, 0), render(0, 0, true, false, true, 0));
    assert.equal(render(200, 200, true, false, true, 0), render(100, 100, true, false, true, 0));
    assert.equal(render(85, 92, false, false, true, 0), render(0, 0, false, false, true, 0));
    assert.notEqual(normal, render(30, 44, true, true, true, 0));
    for (const state of ['normal', 'hot']) {
        const svg = state === 'normal' ? normal : render(85, 92, true, true, true, 0);
        const dest = path.join(__dirname, `thermal-character-${String(i+1).padStart(2, '0')}-${state}.svg`);
        if (fs.existsSync(dest)) assert.equal(fs.readFileSync(dest, 'utf8'), svg);
        else fs.writeFileSync(dest, svg, {flag: 'wx'});
    }
}
assert.equal(new Set([0, 1, 2].map(style => vector.svg(shapes.bodies[0].path, 0, 85, 92, true, true, true, style))).size, 3);
console.log('PASS: ten forms, independent gauges, separate temperature freshness, three heat treatments; twenty SVGs exported');
