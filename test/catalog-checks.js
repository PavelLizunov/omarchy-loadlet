const fs = require('node:fs');
const assert = require('node:assert/strict');
const path = require('node:path');
const root = path.join(__dirname, '..');
const files = fs.readdirSync(path.join(root, 'i18n')).filter(name => name.endsWith('.json'));
const catalogs = Object.fromEntries(files.map(name => [name.slice(0, -5),
  JSON.parse(fs.readFileSync(path.join(root, 'i18n', name), 'utf8'))]));
const keys = Object.keys(catalogs.en).sort();
for (const [locale, catalog] of Object.entries(catalogs)) {
  assert.deepEqual(Object.keys(catalog).sort(), keys, locale);
  for (const key of keys) {
    assert.ok(catalog[key].trim(), `${locale}:${key}`);
    assert.deepEqual((catalog[key].match(/%[1-3]/g) || []).sort(),
      (catalogs.en[key].match(/%[1-3]/g) || []).sort(), `${locale}:${key}`);
  }
}
for (const catalog of Object.values(catalogs)) assert.equal(catalog.title, 'Loadlet');
assert.equal(catalogs.ru.cancel, 'Отмена');
assert.match(catalogs.de.status_sending, /%1/);
assert.match(catalogs['zh-CN'].status_sending, /%1/);
const makefile = fs.readFileSync(path.join(root, 'Makefile'), 'utf8');
assert.match(makefile, /\bLoadletLocale\.qml\b/);
assert.match(makefile, /install -m644 i18n\/\*\.json/);
console.log(`PASS catalog/install contract: ${files.length} locales, ${keys.length} keys, placeholder parity`);
