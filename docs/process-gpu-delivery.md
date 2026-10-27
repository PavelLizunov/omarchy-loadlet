# Process GPU column — 2026-10-27

The installed 2.14.4 table had no GPU column or per-process GPU transport.
Aggregate GPU utilization was not sufficient to attribute load to processes.

## Implemented

- A GPU % column in both process tables, with heading sorting and the `g` key.
- Recent NVIDIA process samples through optional nvmlDeviceGetProcessUtilization,
  within the existing active-device gate and serial GPU request. Samples are
  bounded to8192 and five seconds, keeping the latest per PID.
- DRM per-process engine counters reuse the existing fdinfo discovery and engine
  calculation, deduplicating file descriptors per process/client. Shared DRM
  clients can appear under multiple processes; values are not additive ownership.
- PID/start-tick identity, missing-value dashes, freshness gating and unavailable
  values sorted last in either direction. Parallel engine/GPU percentages use
  their maximum, not their sum.
- GPU requests admitted in compact process view without requiring a GPU tile.
  Closed-panel collection remains unchanged.
- Updated packaged executable and source/binary provenance.

## Delivery evidence and limits

Source baseline aa9c358 matched the installed 2.14.4 task-owned runtime files
before deployment. Work uses the separate checkpoint/loadlet-process-gpu-20261027
worktree; the original main branch and its index were not changed.

`make activity-sampler` exited0 using GCC16.2.1. The resulting272504-byte sampler
SHA256 is bdfb8c2f614d8b90333b0b75edf522dacd918cbebbe1741aa5d567a27905cb11.
No tests, lint, typechecks, hardware experiments, offscreen renders or additional
reviews were requested or executed. The change is not a physical-driver or UI
acceptance result. The four existing locales retain the invariant GPU token;
local editorial fallback was used, not independent language review.

Installed runtime: runtime-2.14.5-process-gpu-20261027/Panel.qml.
The first status call immediately after rescan returned `Target not found.`
A subsequent call resolved the endpoint and reported state=ready,
iconRevision=2.14.5 and the exact new iconConsumer. This establishes loaded
identity, not a successful measurement or visual table inspection. No production
panel was opened and the shared shell was not restarted. Existing fan profiles
and user settings were not modified by this task.

Actual per-process NVIDIA availability depends on the GPU/driver API; unsupported
processes remain dashes. No memory-based estimate or overall-GPU percentage is
substituted. DRM counters need two comparable samples. Process GPU readings and
column interactions have not been exercised locally.
