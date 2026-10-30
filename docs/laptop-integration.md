# Laptop corrections integrated into the diagnostics audit

Date: 2026-10-30. This is a source checkpoint, not a release or installation.

## Provenance

- Audit snapshot: `c3ee256010c8f5ac8c7c1df37561e1a66c070b12`.
- Imported branch: `fix/loadlet-laptop-review-20261030`, exact remote tip
  `d52254712da51579e6bb6628a24603fa9d337885`.
- Implementation: `4f00ec8`; review parent:
  `9ea5b5ec068554f1425f758e11f20d63f6996161`.
- Shared product ancestor: `be82a42af002144366fc20d0c2ffccf0a3429ccb` (2.17.2).
- Historical reports retained under [reviews](reviews/laptop-2026-10-30.md),
  including the [laptop delivery limits](reviews/laptop-fixes-2026-10-30.md).
  Those reports describe another machine and earlier source, not this acceptance.

Reviewed three-way integration preserves high-resolution diagnostics, the
bytecode-write fix, agent discovery/handoff, live language selection and the
single PowerProfiles owner used by Overview shortcuts. The source worktree's
active branch, HEAD and index are preserved. Existing local work is not replaced.

## Imported and reconciled

- GPU records and previous-snapshot lookup use PID/start/GPU identity maps.
  Missing sensor history is retained within age/key/point bounds and returns
  with explicit discontinuities.
- Journal pressure flushes before accepting a legal record; sensor admission
  uses monotonic time. CPU-policy context truncates explicitly rather than
  discarding ordinary many-policy context. Fast diagnostics retains its own
  16000-byte context budget; the legacy path uses 10000 bytes.
- CPU thermal discovery filters before dynamic reads, checks runtime power
  state and backs off failed discovery. GPU metadata reads reuse per-pass
  start ticks. Physical wake/energy effects remain unmeasured.
- Fan Restore shares the mutation lock; failed Save restores prior intent.
  Manual fan requests cancel automation through the installed owner.
  Profile rollback attempts independent resources, records unresolved recovery
  and requires successful GPU stop before replacement.
- Profile status requires valid output and successful exit, in either callback
  order. Failure/expiry invalidates readiness and active-profile attribution.
  Accepted profile/fan changes and reopening clear obsolete fan drafts.
- Compact metric content uses actual implicit heights and scrolls within its
  budget. The imported formula omitted process spacing: three current geometry
  cases initially failed. Reserving that spacing restored the existing row
  and footer invariant without changing the assertions.
- Retained the audit's finite 90-second UI deadline with partial timeout logs
  instead of replacing it with the laptop's 120-second-only adjustment.
- Rebuilt the current sampler and refreshed provenance. The old 2.17.2 laptop
  binary and its build-input hashes were deliberately not imported.
- Kept manifest version 2.18.3 for this unreleased audit checkpoint; status adds
  `implementationRevision: "audit-laptop-integration-20261030"`.

## Current evidence

| Scope | Result | Boundary |
|---|---|---|
| Native build | PASS, 313464 bytes | Compilation, not deployment |
| Model regressions | PASS | Mixed GPU identities, maxima, transient sensor gaps, bounded retained keys |
| Journal/report checks | PASS | Pressure flush, monotonic admission, 64-policy truncation with PSI retained, existing export/storage cases |
| Fast capture/report/controller | PASS | Existing synthetic lifecycle, private storage, export and cold-import cases |
| Power/fan checks | PASS | Mocked failed GPU stop, independent rollback, recovery identity, failed fan-save rollback and locked restore; no hardware writes |
| Inert actual-consumer UI | PASS, 91 panel results, 4 raster results at each DPR 1/2 | No warnings; includes callback order, failed/malformed/late status and shared Overview apply |
| Full CI/package reproduction | Pending exact checkpoint run | No prior CI result reused |
| Installed behavior / visual inspection | NOT RUN for this integration | No deployment, root-helper installation or new image acceptance |
| Performance / long-session stability | NOT RUN for this integration | No new CPU, memory, latency or energy conclusion |

Local evidence: `~/.cache/agent-tmp/loadlet-validation-20261030/laptop-integration/`.
The initial three UI failures remain in `ui.log`; the corrected run is `ui2.log`.
QML checks use inert I/O with the accessibility bridge disabled. They do not
establish physical input, real systemd recovery, provider response or screen
reader acceptance. The laptop's original reproductions were reviewed, not all
re-executed here; new regressions cover the specific cases listed above.

Native build and focused checks ran locally as ordinary requested integration
work. Full suite and independent package reproduction use existing GitHub CI.
No extra model review occurred.

## Continuing audit

The installed runtime and privileged helpers have not changed in this batch.
No settings, recording history, exports or physical profiles were rewritten.
The 50-locale migration, actual agent-button/reload correlation, terminal/provider
acceptance, current media and formal performance/soak campaign remain open.
The earlier approximately 2.9% one-core recording result still exceeds the 1%
target; these source improvements alone do not establish a performance pass.
Main, releases and Marketplace are not promoted by this checkpoint.
