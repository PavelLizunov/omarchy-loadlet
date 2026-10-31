# Changelog

## 2.19.1

- Replace the five-row language viewport with a full-height list, readable
  start-aligned names, descriptions, locale codes and explicit fallback labels.
  Reveal the saved selection on opening; keep search/Back pinned and suppress
  panel letter shortcuts while typing. Preserve all registry choices and drafts.
- Add optional native memory-growth notifications during explicit observation,
  deduplicated by process instance and grouped at most once a minute. Clicking
  opens Memory, never starts collection or applies system changes.
- Retain up to 20 growth-event snapshots per session, including after process
  exit, and include them in Copy report. No persistent incident database or
  leak-proof claim; Stop keeps events, new Start/reload clears them.
- No tests, renders, real notification or observation was run in this delivery.
  The native sampler binary is unchanged.

## 2.19.0

- Make Memory an explicit one-hour growth observation, using the existing native
  reader at approximately 30-second intervals, including with the panel closed.
- Separate system/cache/anonymous/shared/slab/swap and memory-stall readings.
  Track PID/start identity, anonymous trends and optional PSS/private-page history.
  Missing samples break comparisons rather than becoming zero.
- Show bounded growth candidates with disclosed thresholds, not leak verdicts.
  Keep Stop and Copy report reachable; retain at most 121 local snapshots, no
  automatic persistence, application termination or provider call.
- Keep authenticated cache cleanup secondary and unavailable during observation.
  Preserve existing saved capture settings, process actions and hardware controls.
- Rebuild the sampler. Tests, renders, live observation and independent review
  were not run for this delivery.

## 2.18.12

- Keep a stable native process-list model instead of replacing the JavaScript
  array on every CPU/GPU update. Update sorted row data in place, preserving the
  scroll rank and PID/start-time selection. Only explicit sort/search resets the
  viewport; keyboard movement reveals its selected row.
- Add Processes by memory to the Memory page, reusing the existing sorted table
  and guarded termination flow. Explain why zombies and application heaps cannot
  be reclaimed with cache cleanup. No automatic kill or extra reclaim operation.
- No tests, renders or live scrolling acceptance were run for this delivery.

## 2.18.11

- Add a Memory tab and a RAM-tile shortcut for explicit cache cleanup. Keep the
  operation alive across page changes and preserve the existing panel dimensions.
- Confirm and authenticate each request through Polkit, then sync and drop clean
  caches. Add no automatic cleanup, persistent grant or application termination.
- Show actual before/after cache and available-memory snapshots, denial, failure
  and unknown outcomes. Cache size is not guaranteed reclaimable memory.
- Preserve the sampler binary and saved profiles/settings. Cleanup, tests and
  visual acceptance were not executed during implementation.

## 2.18.10

- Move the four existing catalogs into plugin-owned JSON, using native
  Commons.Translations with one shared adapter for saved language overrides.
- Add a bounded searchable picker for the host registry. Preserve legacy zh as
  zh-CN; untranslated choices use English, not another language.
- Localize displayed metric numbers, dates and abbreviated durations; inherit
  RTL reading layout while preserving chart and physical diagram coordinates.
- Accept all 50 registry codes for an explicitly requested inline agent answer.
  The other 46 UI catalogs, fluent review, plural conversion and complete RTL
  acceptance remain unfinished. Tests and visual checks were not run for this batch.

## 2.18.9

- Stop repeated NVIDIA library unload/reload from accumulating eventfds in the
  reader. Retain the mapping, not the NVML session; each sample still shuts down
  NVML and inactive/unknown GPUs remain excluded.
- Remove the unimported legacy Messages catalog and nine obsolete power-model
  functions. Active translations, telemetry and control behavior are unchanged.
- Add a failing-baseline/passing-candidate lifecycle regression. Document the
  separate shared-shell memory spike, dependency review and evidence limits in
  [the resource and simplification report](docs/resource-simplification-20261030.md).

## 2.18.8

- Align compact and expanded cards with the memory strip and pinned actions.
  Share card/header heights and top-align values despite different detail lines.
- Put scroll thumbs in the existing outside padding rather than reserving a
  right-only content gutter, including the profile editor.
- Migrate UI checks to single-row tabs and the dedicated Profiles editor. Cover
  inert Save, explicit Apply, icon persistence, draft routes and narrow layouts.
- Record the requested module audit, evidence and remaining gaps in
  [the UI audit](docs/ui-audit-20261030.md).

## 2.18.7

- Keep the four navigation tabs in one row. Use label-sized widths with shared
  spare space rather than sizing every tab for the longest label.
- Scroll horizontally on constrained widths and reveal focused/selected tabs.
  Preserve profile icons, editing and explicit Apply behavior.

## 2.18.6

- Add the missing top-level Profiles tab for selection, creation, editing, Apply,
  automatic switching and Original control. Keep individual fan controls on Fans.
- Add a labeled six-icon picker to the profile editor using existing glyphs and
  the existing saved icon field. Overview shortcuts use the selected icon.
- Keep tabs visible during editing and wrap them when labels do not fit one row.
  Preserve active attribution for name/icon-only edits; Save never applies hardware.

## 2.18.5

- Move profile creation and editing to a dedicated page with CPU and cooling
  sections, a scrolling form, a Back route and pinned Save/Cancel actions.
- Expose New profile directly on Fans. Saving selects the saved preset but never
  applies it; Apply and Original control stay outside the editor.
- Preserve the single profile/status owner, existing settings and hardware-control
  recovery. Cancel/Back/close discard drafts; expansion preserves them.

## 2.18.4

- Consolidate desktop diagnostics and laptop corrections on main. Preserve native
  high-resolution capture, existing settings, histories and saved profiles.
- Prevent agent metadata discovery from writing bytecode into the watched plugin
  tree. Discover installed agents without running them; keep Pi inline analysis
  and explicit terminal handoff for other agents.
- Share saved-profile shortcuts with the existing apply owner. Invalidate failed
  status, clear obsolete fan drafts and preserve compact process-row space.
- Merge bounded sensor-history retention, GPU identity-map processing, monotonic
  journal admission and pressure flushing, policy-context budgeting and thermal
  discovery admission. Rebuild the packaged sampler from the combined source.
- Restore independent resources after control failures and retain unresolved
  recovery identities. Optional root-owned helpers require a separate update.
- Follow the live shell language by default while preserving saved overrides.
  The 50-locale migration and performance/soak campaign remain incomplete.

## 2.18.3 (checkpoint)

- Remove the unsupported tabChangesFocus assignment from the Qt Quick question
  editor. It prevented the entire 2.18.2 plugin from loading, including recording.
- Keep the named-model picker, multiline question and existing saved settings.

## 2.18.2 (checkpoint)

- Replace the primary provider/model text field with named choices from local Pi
  configuration, a Pi-default option and a secondary manual-model fallback.
  Remember explicit model selection for Loadlet without changing Pi defaults.
- Add a multiline optional question, Ctrl+Enter, adjacent Analyze/Cancel actions
  and a visible provider-usage notice. Separate local charts from the agent form.
- Collapse recording options, exports, long explanations and legacy diagnostics
  instead of stacking them all into the primary interaction.

## 2.18.1 (checkpoint)

- Save diagnostic recording preference and CPU interval; resume in a new session
  after shared-shell reload. New installations remain opt-in/off by default.
- Add explicit Pi analysis inside Settings → History, with model/question fields,
  a selectable answer, Copy and Cancel. No terminal or automatic inference needed.
- Bound the supplied summary, output and job lifetime; stop the owned runner on
  cancellation or panel teardown. Pi credentials/provider settings stay external.
- Preserve the native sampler, legacy histories, saved profiles and system controls.

## 2.18.0 (checkpoint)

- Add explicit native 250/500/1000 ms diagnostic sessions, incident markers and
  monotonic skip-ahead scheduling in the existing reader. Additional recording is opt-in.
- Correlate temperatures, CPU/process candidates, GPU batches and pressure in
  bounded schema-2 raw/aggregate storage; preserve legacy history and settings.
- Add bounded local window reports, extrema-preserving charts, 60-second drilldown,
  private exports and explicit Omarchy/Pi terminal handoff. No models during capture.
- Reduce measured collection overhead, but do not claim the proposed 1% CPU target.
  See docs/fast-diagnostics.md for implemented scope and unverified behavior.

## 2.17.2

- Separate underlined page navigation from the lighter Cooling toolbar. Keep
  Diagram at the left and recording state at the right.
- Put Category beside the selected sensor; hide it with the chart when the map
  is open and disable it without a selected sensor.
- Give diagram, recording, category, edit, save, delete and history distinct
  outline icons. Keep labels, native controls, settings and hardware behavior.
- Publish the accepted 2.17.x interface to main, with a new 24-second native-QML
  walkthrough, current README/Marketplace preview and a Twitter/X draft.

## 2.17.1 (checkpoint)

- Correct the cramped compact computer map: short localized names, multiline
  measurements and more drawing space. Avoid overlapping CPU/fan hit targets.
- Stack the full-width diagram above its labels on narrower or large-font panels.
  Keep expanded layout, telemetry, assignments and physical controls unchanged.

## 2.17.0 (checkpoint)

- Separate profile selection from Apply and Edit; show the selected configuration
  and active preset separately. Add Save and apply, Cancel/Escape and deletion
  confirmation. Editing hides unrelated channel controls.
- Expose the automatic non-game return preset explicitly; retain saved profiles
  and all privileged helper behavior.
- Show fresh temperature, RPM and GPU-percent callouts on the computer map, with
  per-sensor hover details and min–max ranges. No new sampler or physical mapping.

- Integrate nyaadesu's PR1: skip unreadable hwmon sensors instead of treating a
  read error as frame overflow. Overlong lines still fail the capacity guard.
  The maintainer rebuilt the packaged sampler and refreshed its provenance.

## 2.16.0

Consolidated release of sensor categories, process GPU telemetry, persistent fan
outputs and named CPU/cooling profiles, with automatic Steam/Proton switching.

- Fix profile payload encoding across Qt6.8 and Qt6.12. A local-only green UI run
  previously hid the older-Qt failure seen in CI.
- Exclude Proton/Wine infrastructure processes before installation-path game
  detection; keep Steam metadata required and GPU load irrelevant.
- Expire stale automatic status, report unknown game state on errors, remove
  runtime status with the owned service, and roll back failed activation.
- Manual fan actions leave automatic mode before applying their explicit request.
- Preserve timeout failure against late process completion and forward request
  cancellation to the owned authentication/application child.
- Validate saved profile structure; retain profiles used by active automation.
- Refresh package provenance, reproducible-build evidence, documentation and
  actual-consumer screenshots. Optional root-owned controls have explicit setup,
  update, service lifetime and removal instructions.

Physical reboot, acoustic/energy improvement, every game launcher, and universal
hardware support are not established by the automated checks. See the release
report for exact acceptance and unresolved coverage.

## 2.15.1

Added optional automatic profile switching for Steam/Proton games. This checkpoint
was installed before a dedicated test pass; the2.16.0 audit found package and
cross-Qt regression failures. It was not a clean release baseline.

## 2.15.0

Corrected clicked-row dropdown selection and category filtering. Added named
profiles combining CPU policy, motherboard percentages and optional NVIDIA fans.

## 2.14.4–2.14.7

Persistent exact motherboard fan outputs, per-process GPU telemetry, separate
per-adapter expanded columns and shorter GPU headings.
