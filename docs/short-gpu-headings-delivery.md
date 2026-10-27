# GPU heading fit and visual alignment — 2026-10-27

## Findings and corrections

The supplied user image showed `GeForce RTX 506…` and a vertically displaced
user-column heading. The live PCI identities resolve to GeForce RTX5060Ti at
0000:01:00.0 and Radeon610M at0000:06:00.0. No GPU load experiment was needed to
read those identity sources.

The process table now extracts short recognizable model labels (`RTX 5060 Ti`
and `Radeon 610M`) while retaining full model/PCI identity in the tooltip. Long
unrecognized model names fall back to stable numbered GPU headings. The user
heading is top-aligned with the other headings, and its text and values have an
additional left inset separating them from the right-aligned PID column.

## Visual evidence

The actual candidate Panel.qml was prepared through test/ui-checks.py prepare(),
not its test-running main(). The prepared consumer uses the installed host
widgets/sizing formulas and distinct inert IPC/process/file adapters. Synthetic
process/GPU values and the two actual model names were supplied by
[test/render-process-gpu.qml](../test/render-process-gpu.qml). These percentages
are demonstration data, not measured application GPU usage.

Final PNGs and exact source/renderer/image hashes are in
[the evidence manifest](images/gpu-headings-2.14.7/manifest.json).
All four final images were inspected inline:

- Expanded900x682 DPR1 and DPR2: both model names and the active sort arrow fit;
  the user heading shares the CPU/GPU heading baseline; PID/user are separated.
- Constrained780x592: names fit; optional user/time columns hide, percentage
  columns remain aligned; summary tiles use the existing internal scrolling.
- Compact480x422: aggregate GPU column and row values remain aligned.

Explicit geometry checks passed with zero measured deviation for GPU heading/
row right edges and heading top alignment. The RTX label including sort arrow
has implicit width85.71875 inside112 logical units; Radeon uses72.53125.

Renderer0.3.0 / Qt6.12.0, offscreen software, Russian, inert palette. Initial
strict-warning rendering failed on AT-SPI/atk-bridge desktop accessibility
messages. Subsequent captures deliberately used warningsPolicy=report for this
layout-only inspection. Those warnings remain recorded; this is not strict
clean-diagnostics or accessibility acceptance. No Qt/QML component diagnostic
was observed. No independent model review, general tests or physical GPU probes
were run. Native design/editorial review was direct with the bundled fallback;
no external anti-slop or translation skill was available.

## Application

Source base ea1797a1556df58f0cabf466883176f38028b27a matched the prior installed
task-owned files. Version2.14.7 was installed through a new runtime directory.
The existing shared-shell status returned ready with iconRevision2.14.7 and
runtime-2.14.7-short-gpu-headings-20261027/Panel.qml as the consumer. The shared
shell was not restarted or opened for evidence; no second Quickshell was started.
User settings and fan profiles were unchanged. Production compositor layout,
actual hover/click interactions and physical GPU readings remain unverified.
