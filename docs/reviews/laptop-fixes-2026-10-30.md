# Isolated laptop corrections after the 2.17.2 review

Branch: `fix/loadlet-laptop-review-20261030`.
Base product commit: `be82a42af002144366fc20d0c2ffccf0a3429ccb`.
Parent review checkpoint: `9ea5b5ec068554f1425f758e11f20d63f6996161`.
The original dirty development checkout, main branch and its staged index are not
this worktree. Nothing here merges or replaces the other computer's work.

## Implemented source changes

- F01/F13: process GPU ingestion and previous-snapshot lookup use identity maps
  rather than repeated full-array filters. Mixed direct/engine records share one
  PID/start/GPU identity and retain unknown/direct/max aggregation semantics.
- F09: briefly missing sensor series survive under a 288-key limit, 60-240-second
  absence budget, and the existing per-series point cap. Returning observations
  mark an explicit break, even when the missing interval was shorter than the
  ordinary gap threshold.
- F07/F10: both journal paths flush under buffer pressure before accepting a legal
  record; sensor recording uses steady time for cadence and wall time for records.
- F08: CPU policy entries have a context budget with explicit truncation, leaving
  base context/PSI/power supply fields intact on ordinary many-policy systems.
- F12: CPU thermal discovery filters/ranks before dynamic temperature reads,
  honors runtime power state on discovery and cached paths, and backs off failed
  discovery for 30 seconds. No physical GPU wake/energy outcome is claimed.
- F02/F03: GPU replacement requires a successful stop. Rollback attempts independent
  resources even if another fails. Incomplete recovery records prior/target
  identities locally and permits Original control to retry all affected resources.
  New applies refuse unresolved recovery instead of silently overwriting it.
- F04/F05/F06: fan Restore uses the existing per-channel lock; service stops fail
  honestly while absent units remain harmless. Failed Save restores persisted and
  enabled/active intent. Manual fan requests use installed adapter cancellation,
  not transient runtime-status-file existence.
- F11/F14: failed/timed-out/malformed profile status clears cached readiness;
  successful data is committed only with successful exit, in either callback
  order. Accepted fan/profile changes and panel reopen clear obsolete fan drafts.
- F15: the existing inert UI runner receives a finite 120-second budget instead
  of the 30-second wrapper that timed out on this laptop. No tests were run anew.
- F16: the guide and helper diagnostic state the CPU/fan/profile grant scope.
  Compact-view GPU sampling guidance now matches the owning current code.
- P01 partial: start ticks are read once per PID in a DRM collection pass and
  NVIDIA loop invariants are hoisted. Total descriptor traversal/cache budgets,
  PCI-name caching and game-scan optimization are not implemented in this batch.

## Screenshot-related geometry change

The supplied crop is retained as user evidence, not a substitute for exact desktop
geometry. MetricCard height previously used estimated font-token arithmetic while
its actual header/value/detail contents could wrap. Compact tiles now use actual
implicit content height and reserve room for the process header, a process row,
and pinned footer before allowing the existing metric viewport to scroll. A
scrollbar gutter is reserved only when needed. The window teardown focus callback
also guards a missing window.

The user's exact meaning of "does not fit" (card contents versus outer window)
has not yet been clarified. This change addresses the source-supported inner-card
height issue. It does not assert a confirmed explanation for every edge visible in
the crop or alter host screen fitting/global font settings.

## Build and delivery evidence

`make -B activity-sampler` completed successfully using the existing hardened
Makefile. The distributed binary and machine-readable source/header/build hashes
were updated together; provenance explicitly discloses that a new reproducibility
comparison was not executed. Optional root helpers were not installed or invoked.

No new test suite, regression tests, linter, typecheck, preview/render, performance
rerun or extra model review was executed during this implementation request.
The earlier 86-case UI pass and earlier red reproductions belong to the base
snapshot, not these modifications. Two isolated implementation workers changed
only named model/native source files; their diffs were read by the coordinator.
A successful C++ build establishes compilation only.

The branch retains the 2.17.2 manifest as an unreleased corrective branch; no main
merge, version/tag bump, Marketplace update or released-package publication is
claimed. Local installation uses a fresh task-owned runtime path only when
applied, without deleting settings/history or restarting the shared shell.
Source, built, installed, loaded and user acceptance remain separate.

## Remaining limits

All changed target behavior is untested in this batch. Physical CPU/fan/NVIDIA
recovery, concurrency under actual systemd, theme/scale geometry, long-session
resources, energy and comparison with the other computer remain unverified.
The corrective source paths are implemented, not declared acceptance-complete.
No stale audit finding is silently closed by a source edit.
