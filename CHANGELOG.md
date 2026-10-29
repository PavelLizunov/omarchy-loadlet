# Changelog

## Unreleased

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
