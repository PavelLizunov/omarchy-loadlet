# Loadlet 2.16.0 release audit

Scope: consolidated source, optional privileged controls, Omarchy integration,
actual-consumer visual review, packaging, documentation and release preparation.
Base: `3db93da050465dcfb917102375eb4df5fb9e324d` (2.15.1).
The review was performed directly; no independent model review was available
under this workspace's no-delegation contract. Earlier 2.15.0 reviews are not
review evidence for the automatic-profile changes.

## Findings and disposition

| ID | Observed defect | Resolution and evidence |
| --- | --- | --- |
| R01 | 2.15.1 package provenance retained the old Makefile hash; both local install checks and baseline CI failed | Refreshed hashes after a byte-identical rebuild; package and fresh native install checks pass |
| R02 | Automatic status had no freshness boundary | Monotonic heartbeat, 30-second expiry, unknown gaming state on errors, service-owned runtime directory; temporary-file checks cover expiry/error |
| R03 | Proton's Wine loader could count `services.exe` as a game through its installation path | Wrapper/argument checks precede path admission; detector regression covers native games, Wine games, infrastructure, launchers, missing metadata, UID and input bounds |
| R04 | Qt6.8 and Qt6.12 disagreed on profile Base64 overload behavior; a late exit could replace timeout failure | Portable ASCII profile codec, independent Node oracle and QML payload/late-exit checks; request subprocess receives forwarded termination |
| R05 | README mixed old screenshots with current behavior and buried privileged-control lifecycle | Short current front page, six current-source images, explicit helper installation/update/removal and historical-video labeling |
| R06 | Manual fan changes could compete with automatic mode | Fan request disables automation before its explicit action; manual named-profile override skips unnecessary baseline application |
| R07 | Automatic activation could report success before application, or leave changes after failed service startup | Apply detected preset before reporting success; restore previous named profile or first-activation CPU/fan snapshot on failure; mocked startup regressions |
| R08 | Saved-profile shape and deletion controls did not protect automatic-profile references | Validate stored structure; prevent deletion of active automatic game/base presets; wait for capabilities and hide unavailable boost controls |

The worker regression runs the real loop against an advancing fake clock and
mocked process identities. A second observed game resets the exit grace; Games
is applied once, then the baseline only after 15 seconds without a game. This is
not a Steam/Proton playthrough or a physical fan trial.

## Code and host integration

The stable namespace remains `slovn.activity-lite`, kind `bar-widget`, with
`Panel.qml` as the entry point. Its panel is internal, not a separately declared
plugin. Source review covered the reader/protocol/model path, journal/export,
process identity guards, profile/fan adapters, game detection and QML ownership.
Existing bounded-reader and native host controls were retained rather than
replaced by another shell or a polling process per metric.

The monitor runs with user permissions and does not require the optional root
helpers. Those helpers deliberately add system services, persistent control state
and a time-limited fixed-command sudoers grant. They are a separately installed
capability, not an undisclosed effect of the normal plugin installer. Current
Marketplace guidance requires maintainer review of these capabilities and the
bundled executable. Local checks and a GitHub release do not provide that approval.

The product retains its existing four-language catalog and explicit Russian
default, rather than migrating every string to the host's newer translation API.
This is an intentional product-contract exception. Full host-language coverage,
right-to-left layout and screen-reader acceptance are not claimed.

## Executed local checks

`QT_ACCESSIBILITY=0 NO_AT_BRIDGE=1 make check` passed after the implementation
changes: core/native fixtures, package provenance, process actions, journal and
sensor controls, power profiles, detector and independent codec checks, 82 QML
results with no failures, native bar raster checks at DPR1/2, packaged
add/enable/update in an isolated destination, and `omarchy plugin validate .`.
The install harness uses real native CLI/source and sampler/model parsing; only
shell IPC is stubbed. It does not open another production shell.

The distributed sampler was rebuilt byte-for-byte identically:

```text
053db5d3be54c56a3ecfe9a2494fd3ea844bd9978cebf8b58b91c1525d1e507b
```

QML lint exited 0 with warnings, including unqualified accesses and host dynamic
singleton typing. This is not a warning-free lint claim. Cross-Qt CI uses Qt6.8.3;
local Qt is 6.12.0. Remote acceptance must be read from the exact commit's Check
workflow, not the failing historical run40743097393. The GitHub release records
the final public commit and corresponding workflow result separately.

## Visual review

[Image provenance](images/release-2.16.0/manifest.json) pins current QML/JavaScript,
fixture and image hashes. Six inspected actual-consumer offscreen images cover
expanded overview, automatic profiles, compact Fans, Russian profile editor at
DPR2, Cooling and Settings. Native host palette/components and inert demonstration
data were used. Compact/editor content scrolls inside the fixed frame; this is
intentional, not a claim that every editor fits without scrolling.

Warning policy is **report**. Local AT-SPI/atk-bridge host warnings mean strict
warning-policy and accessibility acceptance are not established. These images
are not desktop captures, compositor/focus evidence or hardware measurements.
The older 2.8.1 video remains explicitly historical.

## Applied installation

The matching 22 runtime files were installed under
`runtime-2.16.0-release-20261028`; the manifest points to that directory's
`Panel.qml`. Existing shared-shell rescan was used. Read-only plugin IPC reported
`iconRevision=2.16.0`, the new consumer URL, `state=ready`, an empty reader error,
and `opened=false`. The host's generic list still reported `active=false` even
when the plugin-specific endpoint responded; that list field alone is not loaded
identity evidence.

All three optional helpers were installed root-owned with exact source bytes.
Unit definitions were refreshed without restarting existing fan workers.
Persistent CPU/fan state hashes and shell settings were unchanged. Automatic mode
was already inactive/disabled and was deliberately left that way; the update did
not silently re-enable it or replace the user's current percentages/boost choices.
A Polkit attempt timed out before installation; the existing authorized sudo path
subsequently completed it successfully.

## Remaining limits

- Real game launch/exit switching, physical reboot persistence, physical NVIDIA
  RPM, acoustic/thermal/energy benefit and PSU control remain unverified.
- Steam metadata plus executable evidence is a bounded heuristic, not universal
  game identification; non-Steam launches and unknown launchers may be missed or
  misclassified. GPU load alone never enables Games.
- Partial CPU presets inherit unspecified values from the captured original
  snapshot. Editing Games while automation is enabled does not update the
  privileged stored copy until automation is re-enabled.
- QML timeout and mocked rollback tests do not prove every Polkit/systemd timeout,
  real subprocess cancellation or hardware-failure path. The legacy individual-fan request has its own shorter
  UI deadline; a very slow automatic shutdown can outlive that UI request.
- The separate remote test machine was unavailable; no new result is attributed
  to it. There was no physical reboot, production-panel summon or independent
  cross-model review in this pass.
- Marketplace exact-snapshot review and its public card/copy/install availability
  are separate maintainer-owned outcomes, not completed by this release.

Source-checked, fixture-tested, installed and loaded are distinct from real-game,
reboot or user acceptance. See the [guide](guide.md) for capability limits and
complete optional-control removal.
