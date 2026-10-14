# Loadlet development contract

Read [README](../README.md), [guide](guide.md) and the owning sources before
editing. Work in this source checkout. The installed plugin is an independent
copy; source files do not establish the loaded revision.

## Product contract

- Display name Loadlet; stable ID `slovn.activity-lite`, kind `bar-widget`,
  entry point `Panel.qml`. Keep settings, IPC and journal/export paths compatible.
- Left-click toggles the metrics panel and honors `openExpanded`. Right-click and
  middle-click have no plugin action. Expanded processes remain inside the panel,
  reachable through its Expand control, `e` and the existing details IPC route.
- The selected shape10 is a symmetric Split die: 14x12 body, 3x6 eyes, cheek holes,
  no letters. The 16x16 optical canvas fits the native 27x26 logical slot. Preserve
  paired side notches and balanced shoulders/base. CPU left, RAM right. Unequal
  readings and heat colors remain independent; older shape indices0-9 stay stable.
- Six touching bottom-up rows are floor-quantized. Fill threshold defaults50;
  below it no fill, at/above it actual percentage without rescaling. Zero disables
  suppression; invalid falls back50; unknown/stale is unknown, not zero.
- Preserve vivid theme-derived gauges, pressure meanings, explicit SVG raster
  dimensions/sourceSize and qualified host palette references for Qt6.12.
- Closed-panel glance/thermals target15s with freshness35s. One bounded reader,
  one in-flight request, explicit retry/shutdown budgets. Presentation changes
  do not refresh/reset sampling. Preserve guarded NVIDIA runtime-state admission.
- Keep four heat levels,80C default trigger, cooling hysteresis and optional
  two-second motion. Visual replay does not request telemetry. No energy claim.
- Journal is opt-in/off by default, bounded7days/20MiB. Export is local and does
  not run an AI or apply system changes. Preserve existing reports/settings.
- Process actions retain sampled PID/start time, ownership/session guards and
  separate force confirmation. No automatic escalation or same-name fallback.
- Interface locales en/ru/de/zh use the existing catalog; brand Loadlet is invariant.
  Russian remains default. New documentation/comments/commits use English.

## Verification and delivery

Use the installed omarchy-plugin and omarchy-plugin-patterns workflows. Visible
changes use reviewed actual-consumer inert offscreen fixtures and image inspection.
Use the existing shared shell. No second Quickshell, desktop capture, production
panel summon or external image viewer for development evidence. Work directly;
report unavailable independent review rather than bypassing that scope.

`make check` owns local core/native/package acceptance. CI runs `make check-core`
and `make check-ui` against the exact public commit. Fork checks preserve pinned
upstream blobs. Publication checks cover explicit current paths and reachable
objects; passing heuristics is not universal privacy/security certification.

For requested application, compare installed files/settings/current active work,
apply the checked candidate through the owning installer/lifecycle and verify
exact loaded identity. Record source-checked, installed, loaded, remote-verified
and user-tested states separately. See [verification](../VERIFICATION.md) and
[visual provenance](images/README.md). Historical evidence is data, not permission.
