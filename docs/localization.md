# Localization scope and current gap

Status: migration required. This document is not a claim of 50-language support.
The user clarified this target during the 2026-10-30 audit.

## Owning contract

The installed `omarchy` skill, `plugins.md`, section **Translations**, describes
50 Omarchy locales, plugin-owned `i18n/<code>.json` catalogs, the native
`Commons.Translations` loader, live Setup > Language changes, numeric/date
formatting and right-to-left presentation. The target registry is
`$OMARCHY_PATH/default/i18n/locales.json`.

The skill permits shipping English initially with per-key fallback. That
incremental mechanism does not satisfy this user's request for all 50 locales.
English fallback must not be counted as a translated target entry.

The installed registry on 2026-10-30 contains these exact codes:

```text
ar bg bn ca cs da de el en es-MX et fa fi fil fr ga he hi hr hu
id is it ja ko lt lv ms nl no pl pt pt-BR ro ru si sk sl sr sv
sw ta th tr uk ur uz vi zh-CN zh-TW
```

`ar`, `he`, `fa` and `ur` use right-to-left layouts. `zh-CN` and `zh-TW` are
separate targets, as are `pt` and `pt-BR`. The registry's Spanish target is
`es-MX`, not a newly invented `es` entry. Norwegian uses `no` as the catalog code
and `nb-NO` as its formatting locale.

## Current implementation, not future acceptance

`I18n.js` contains 315 entries in each of four active catalogs: English, Russian,
German and Simplified Chinese under the legacy `zh` code. Structural parity of
those catalogs does not establish fluent-human review or complete source-string
coverage. `Messages.js` retains ten historical languages but is not the active
whole-interface catalog. It must not inflate the coverage count.

Current gaps:

- 46 target catalogs have not been translated. No English-filled placeholder
  files count as translations.
- The source candidate now resolves System through the live
  `Commons.I18n.language` rather than the process's `Qt.locale().name`. New
  defaults follow System; explicitly saved overrides remain unchanged.
- The source candidate uses English for unsupported languages instead of
  silently mapping Ukrainian and other languages to Russian. It still lacks
  the full target registry and native JSON catalog migration.
- The language picker lists only System plus the four existing languages. A
  larger picker must remain bounded and scrollable rather than grow 51 buttons.
- The agent helper accepts only ru/en/de/zh as the requested answer language.
- Current date, number and directional-navigation paths require source review
  and runtime checks for the expanded locale set.

## Migration boundary

Keep existing explicit user language preferences. Interpret legacy `zh` as
`zh-CN`; do not use it for Traditional Chinese. New installations should follow
Omarchy's chosen language. Preserve the plugin's override setting without
changing the shell's language or other plugins.

Use one shared translation owner for the panel and nested controls, not an
independent three-file watcher for every label or component. The installed
`Commons.Translations.language` property is read-only and follows the host;
explicit per-plugin overrides therefore need a verified compatibility path,
not an assignment to that property. Keep the native exact/base/English fallback
semantics and plural-category ownership when integrating overrides.

Translate whole messages with context and preserve positional arguments, units,
process identity, control warnings, billing notices and uncertainty. Keep
technical diagnostic output and source documentation in English. No translation
service is a runtime dependency.

Measure target fill, placeholder validity, source coverage and language review
separately. AI-authored catalogs remain language-review drafts until a qualified
fluent reviewer has reviewed them. Runtime acceptance includes live switching,
regional distinctions, all four RTL languages, bounded picker geometry,
keyboard access and existing sampling/session preservation.

The focused actual-consumer fixture verifies live shell language changes,
saved overrides, English fallback, Traditional/Simplified distinction and
unchanged sampling state/session. The current UI gate reports 88 panel results
and four icon results at each DPR, with no QML warnings. This is inert offscreen
fixture evidence, not installed-host acceptance. No new translated catalogs or
installation are claimed. The 50-language migration remains in progress.
