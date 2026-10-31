# Native localization: implementation and remaining work

Version2.18.10 migrates the runtime, not all translations. Four catalogs are
present; 46 target languages still use English text fallback. No new test run,
visual inspection, fluent-language review or installed-input acceptance is claimed.

## Target

The host registry `$OMARCHY_PATH/default/i18n/locales.json` owns language names,
number formatting and direction. The 50 target codes are:

```text
ar bg bn ca cs da de el en es-MX et fa fi fil fr ga he hi hr hu
id is it ja ko lt lv ms nl no pl pt pt-BR ro ru si sk sl sr sv
sw ta th tr uk ur uz vi zh-CN zh-TW
```

Arabic, Hebrew, Persian and Urdu are RTL. Norwegian uses catalog `no` and Qt
formatting locale `nb-NO`. Regional catalogs remain distinct. English fallback
is availability behavior, never translated-locale completion.

## Runtime ownership

`Panel.qml` owns one `LoadletLocale` instance and passes it to profiles, maps,
charts, telemetry error messages, diagnostics and process actions. It uses native
`Commons.Translations` for the host-selected language. That loader's `language`
is read-only: the adapter never assigns to it or changes Omarchy configuration.
Explicit plugin overrides use two optional watched FileViews for exact/base
catalogs and the native loader's English catalog. They follow exact → base →
English → key fallback. No per-label catalog owner, process, network call or
translation service is added.

The old active `I18n.js` is replaced with `i18n/en.json`, `ru.json`, `de.json` and
`zh-CN.json`. Each contains the 323 inherited messages plus six strings for
language search, fallback disclosure and abbreviated durations. Version 2.18.11
adds 18 Memory-cleanup messages to each catalog using direct local translation;
fluent review and runtime acceptance are still unverified. The unrelated
legacy `Messages.js` was already removed in2.18.9. It never counts toward coverage.

System tracks live host language changes. Saved `zh` maps to `zh-CN`; `zh-TW`,
Hong Kong and Hant choices never use Simplified Chinese. Registry codes remain
selected even without a translated catalog. Unknown codes fall back to English.
The picker offers System plus registry entries, filters native/English names and
codes. Version2.19.1 uses the remaining panel height rather than a 160-pixel
viewport: native body-size names, English descriptions, locale codes and explicit
fallback labels. It reveals the saved selection on open, restores search focus,
and suppresses panel letter shortcuts during language entry. Search and Back
stay pinned. No new rendered/input acceptance is claimed. Choosing a language only saves
that preference; it does not apply a hardware profile or restart the reader.

## Presentation

Numbers use the host formatter in System mode. Overrides use the same registry
separator/digit rules without modifying the host singleton. Byte and temperature
formatters accept a display formatter; sampling, comparisons and saved hardware
payloads stay numeric. Process IDs, model IDs and editable hardware fields stay
machine-form text. Date labels use `Qt.locale(formatLocale)` and preserve
millisecond precision where required. Abbreviated elapsed times use whole catalog
messages instead of English suffix concatenation.

The panel content and reparented profile/editor owners inherit the selected
reading direction. The Back icon mirrors. Chart time and physical diagram
coordinates deliberately do not mirror. No claim is made that all explicit-x
layouts, popups, mixed-script identifiers or screen-reader flows are accepted.

The diagnostic helper accepts the 50 answer-language codes plus legacy `zh`.
This only affects an explicitly requested agent answer; it adds no inference
on discovery, capture or export and proves no provider-language capability.

## Remaining work and evidence limits

- Translate the other46catalogs as whole contextual messages, preserving control
  warnings, uncertainty, provider-cost notices and placeholders. Do not fill
  target files with English and report them as translations.
- Complete plural-category conversion through the host plural API, including
  layer-owned rules for explicit overrides. Current catalogs remain flat strings.
- Complete fluent review, source-string coverage and bidi/identifier presentation.
  The six added messages use direct local translation; no translation skill or
  independent reviewer was invoked.
- Exercise live switching, override fallback, all four RTL layouts, narrow/large
  text, keyboard search and unchanged draft/sampling/session behavior.
- Adapted existing catalog/UI fixtures are not evidence of execution. No tests,
  linters, previews, soaks or new measurement campaign were requested or run in
  this continuation. Earlier109panel results belong to2.18.9, not this revision.

Version2.19.1 retains the2.19.0sampler (including the2.18.9NVML fix and its
documented memory trade-off). The language/notification change does not rebuild it.
The separate shell-memory incident is not a localization finding. Its cause
remains unknown; development does not wait for that attribution.
