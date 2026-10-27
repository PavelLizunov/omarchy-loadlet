# Saved fan output and category repair — 2026-10-27

## Owning causes

The installed 2.14.3 helper exposed only temporary boosts and identification
trials. The active requests were pwm2=100%, pwm3=60%, pwm4=80%, each with a
10-minute timer. Their expiry deliberately restored the original controller
state. No saved speed profile existed.

Manual sensor assignments were persisted, but sensorOwner() always rendered
the original driver category. The host Dropdown also assigns its value before
emitting changed(), removing the consumer's value binding. Reused sensor and fan
selectors now restore that binding. Wi-Fi instance suffixes are normalized for
assignment identity, with fallback to existing saved keys.

## Changes

- Exact integer output from 0 to 100%, explicitly saved rather than a timed boost.
- Root-owned profiles in /var/lib/loadlet-fans and enabled per-channel systemd
  instances, independent of the shared shell and its authentication grant expiry.
- Existing thermal fallback remains: full output at 80 C or missing CPU readings.
- Restore removes the profile and restores the captured prior duty/mode.
- Temporary actions pause a profile and resume it afterward.
- Fan control delegates use channel IDs instead of changing telemetry objects,
  preserving in-progress input during periodic readings.
- Manual category headings, selector bindings and legacy assignment fallback.

## Application evidence

The source base c52a485 matched the installed 2.14.3 consumer and root helper
for the task-owned files before replacement. The main checkout remained untouched;
implementation uses checkpoint/loadlet-persistent-fans-20261027 in its own worktree.

The initial noninteractive helper installation failed with `a password is required`.
Polkit-authorized installation then succeeded. The helper installed and enabled
loadlet-fan-profile@pwm2.service, loadlet-fan-profile@pwm3.service and
loadlet-fan-profile@pwm4.service, reporting `saved` for 100%, 60% and 80% respectively.
The existing labels and other shell settings were retained.

The existing shell loaded 2.14.4 from
runtime-2.14.4-persistent-fans-20261027/Panel.qml after rescanPlugins. Its read-only
status reported state=ready and the exact new iconRevision and iconConsumer.
The shell was not restarted; no second Quickshell or production panel was opened.

## Limits

No tests, lint, typechecks, offscreen renders, additional review or hardware
experiments were requested or run. Live status establishes loaded identity only.
Physical RPM response, category clicking, arbitrary percentage input, temporary
resume, thermal fallback, failure recovery and reboot persistence have not been
exercised. Service enablement is not an observed successful reboot. No curve
editor or exact-RPM feedback controller was added. Localization used the existing
four catalogs with local editorial fallback, not independent language review.
