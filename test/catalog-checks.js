const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const root = path.join(__dirname, '..');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(root, 'I18n.js'), 'utf8').replace(/^\.pragma library\s*/, ''), context);
const keys = Object.keys(context.strings.en).sort();
for (const [locale, catalog] of Object.entries(context.strings)) {
  assert.deepEqual(Object.keys(catalog).sort(), keys, locale);
  for (const key of keys) {
    assert.ok(catalog[key].trim(), `${locale}:${key}`);
    assert.deepEqual((catalog[key].match(/%[12]/g) || []).sort(),
      (context.strings.en[key].match(/%[12]/g) || []).sort(), `${locale}:${key}`);
  }
}
for (const locale of Object.keys(context.strings)) assert.equal(context.t('title', locale), 'Loadlet');
assert.equal(context.t('cancel', 'ru'), 'Отмена');
assert.equal(context.resolveLanguage('system', 'de'), 'de');
assert.equal(context.resolveLanguage('system', 'uk'), 'en');
assert.equal(context.resolveLanguage('system', 'zh-TW'), 'en');
assert.equal(context.resolveLanguage('system', 'zh-CN'), 'zh');
assert.equal(context.resolveLanguage('ru', 'de'), 'ru');
assert.equal(context.resolveLanguage('', 'en'), 'en');
assert.match(context.t('status_sending', 'de', 'fixture'), /fixture/);
assert.match(context.t('status_sending', 'zh', 'fixture'), /fixture/);
const legacy = vm.createContext({ Qt: { locale: () => ({ name: 'en_US' }) } });
vm.runInContext(fs.readFileSync(path.join(root, 'Messages.js'), 'utf8').replace(/^\.pragma library\s*/, ''), legacy);
for (const catalog of Object.values(legacy.strings)) {
  assert.equal(catalog.title, 'Loadlet');
  assert.ok(catalog.tooltip.startsWith('Loadlet · '));
}
assert.equal(legacy.text('title'), 'Loadlet');
const installLine = fs.readFileSync(path.join(root, 'Makefile'), 'utf8').split('\n').find(line => line.includes('install -m644'));
assert.match(installLine, /\bI18n\.js\b/);
console.log(`PASS catalog/install contract: ${Object.keys(context.strings).length} locales, ${keys.length} keys, placeholder parity`);
