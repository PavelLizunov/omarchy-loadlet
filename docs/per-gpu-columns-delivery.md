# Expanded per-GPU process columns — 2026-10-27

## Implementation

The 2.14.5 sampler already transported PCI GPU identity with process readings,
but Model.nextProcessGpus discarded it when computing the aggregate maximum.
The model now preserves a per-GPU map alongside that unchanged maximum.

Expanded process headers and rows share the discovered GPU list sorted by PCI ID.
Each column shows a compact model name and GPU %, with the full model and PCI ID
in the heading tooltip. Clicking sorts by that GPU; unavailable values remain
last in either direction. Compact view retains its aggregate column and `g`
retains aggregate sorting. Missing or stale per-GPU readings remain dashes.

Shared header/row width calculations account for every GPU column. Optional PID,
RAM percentage, user and elapsed-time columns yield space before the process name.
The two-line GPU headings use existing catalog strings and model-derived names.
No telemetry cadence, native sampler, fan profiles or user settings were changed.

## Application

Implementation is based on 09d13e9737a5544df418d699208b62e8c9af14c3 in a separate
checkpoint/loadlet-per-gpu-columns-20261027 worktree, preserving the original
branch and index. The prior installed runtime files matched that source before
replacement.

The existing shell loaded runtime-2.14.6-per-gpu-columns-20261027/Panel.qml after
rescanPlugins. The read-only status returned state=ready, iconRevision=2.14.6 and
the exact new iconConsumer. No shared-shell restart or second Quickshell occurred.

## Limits

Tests, lint, typechecks, QML renders, additional review and physical GPU probes
were not requested or executed. Loaded identity does not establish visual fit,
per-card percentage accuracy or successful column-click sorting. No production
panel was opened for development evidence. The unchanged native executable did
not need rebuilding. Driver-specific missing readings and shared DRM-client
attribution retain the limitations documented in the guide.
