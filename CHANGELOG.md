# Changelog

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
