# Audit checkpoint: work in progress

Date: 2026-10-30. Baseline: `6718bc098fee1879373d7255349438bc8e441d0f`
(2.18.3). This is a source checkpoint, not a release or deployment candidate.
The original audit checkpoint left the distributed sampler and optional helpers
unchanged. The subsequent [laptop integration](laptop-integration.md) updates their
sources and rebuilds the sampler; installed copies remain unchanged.

## Observed and changed

- A cold `python3 -I diagnostic-report --agent-info` writes sibling-import
  bytecode into the runtime directory. The host watches that directory for
  changes. The helper now sets `sys.dont_write_bytecode` before that import.
  The focused immutable-runtime regression passes. Actual installed-button
  click/reload correlation remains unexecuted.
- The original full gate reached the UI runner's 30-second deadline; the
  complete baseline gate did not pass. A separate original UI run passed 87
  panel results in approximately 28.7 seconds. The harness now allows 90
  seconds and emits captured partial logs on timeout. This is not a product
  performance improvement.
- Agent discovery reads the native menu and installed executable locations,
  excludes known mise lazy wrappers, and makes no inference request. Pi is
  the only inline adapter; other discovered agents use terminal handoff.
  This implementation still needs its focused discovery/handoff/lifecycle
  regressions and real provider acceptance. Configuration is not authentication.
- Overview profile shortcuts share the existing PowerProfiles apply owner.
  Two compact/clamped geometry failures and a binding-loop warning from the
  initial change were fixed; the existing UI gate subsequently passed.
  Dedicated shortcut dispatch/failure and active-profile attribution checks
  remain open. No physical profile changes were performed.
- The user corrected the localization scope to all 50 Omarchy registry codes.
  The contract and plan now carry that target. System language follows the
  live shell language in source, new defaults use System, saved overrides are
  preserved, and unavailable languages fall back to English rather than Russian.
  The native JSON migration and 46 additional target translations remain open.
  See [localization scope](localization.md); four catalogs are not 50-language
  support, and English fallback is not translated coverage.

## Executed checks on audit checkpoint c3ee256

The later laptop integration has separate evidence: 91 panel results plus four
raster results at each DPR 1/2, focused native/model/control regressions, and a
rebuilt sampler. See [integration evidence](laptop-integration.md) for exact
scope, initial geometry failures and unresolved acceptance.

| Scope | Observed result | Limit |
|---|---|---|
| Current inert actual-consumer UI gate | 88 panel results; 4 icon results at each DPR 1/2; no QML warnings | Not physical desktop input, all 50 layouts, screen-reader or provider acceptance |
| Live-language fixture | Shell language change, saved override, English fallback, Chinese script distinction, preserved sampling state/session | Uses copied native I18n with inert FileView input, not changing the user's shell language |
| Catalog checks | Four active catalogs, 315 keys each, placeholder parity | No fluent-human approval or new target translations |
| Report checks | Existing evidence/export cases and cold-runtime import immutability pass | No complete new agent adapter regression suite |
| Controller checks | Existing startup/retry/sampling/history admission cases pass | Not a long-running leak or performance test |

No full `make check`, CI, independent review or current-render
inspection was claimed by the original audit checkpoint. The previous baseline timeout and
intermediate UI failures are retained in private campaign evidence.

## Delivery and continuing scope

Not installed or loaded: the audit candidate. Installed code remains the earlier
2.18.3 consumer; this document does not establish its current runtime state.
No user language, profile, capture or history settings were rewritten here.

The comprehensive source/dependency audit, actual agent interaction, native
translation migration, target catalogs/RTL/formatting, current media, measurement
harness, clean comparisons and multi-day soaks remain unfinished. No long-run
unit is running. Historical recording CPU near 2.9% of one logical core remains
above the 1% target; this checkpoint establishes no new efficiency/leak result.
Main, releases and Marketplace have not been promoted by this work.
