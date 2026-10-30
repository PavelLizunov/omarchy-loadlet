# Consolidated main: Loadlet 2.18.4

Date: 2026-10-30. The user requested one current branch and local application.

## Included work

The primary parent is `747caf533cf27343a971aecfae9d8a982bd92816`, which includes
both the diagnostics/audit checkpoint and the laptop correction branch
`d52254712da51579e6bb6628a24603fa9d337885`. Earlier profile, UI, diagnostic and
startup-fix checkpoints are already ancestors of that integration.

The separate plan-only checkpoint
`117c8d5c43e06d5a4d6abae3809021c8d6ae686f` is also included as ancestry. Its
686-line plan is superseded by the integration's expanded 707-line plan carrying
the user's 50-locale correction; that newer document is retained.

Main is the current delivery branch. Historical checkpoint branches are retained
as references, not independent current product versions. No unrelated source
worktree, active branch, staged index, settings or history is reset or deleted.
The delivery is prepared in `omarchy-loadlet-main-delivery`, separate from the
dirty development worktrees. No tag, formal GitHub release or Marketplace update
is part of this consolidation.

## Functional and deployment scope

Version 2.18.4 retains the integrated runtime, packaged sampler and helper fixes.
Only version/status identity and current delivery documentation change from the
integration. The latest integration's exact CI passed all three jobs in run
41050822463, including 91 panel results and byte-identical sampler reproduction.
No new tests or physical-control experiments are requested or executed here.
A newly triggered automatic CI is not reported as passed without its own result.

Local application uses a complete fresh runtime directory followed by an atomic
installed-manifest entry-point change and the existing shared-shell rescan.
No second shell is started. Existing settings are retained byte-for-byte; the
saved capture preference remains authoritative. A reload starts a new recording
session rather than promising seamless history continuity.

Existing optional root-owned `fan-control` and `power-profile` helpers are updated
through system authentication. Installation of their code is separate from
applying a CPU/fan profile or restarting active hardware-control workers; this
batch does not do either. Helpers are not newly enabled on machines without them.
Installation and loaded identity are recorded in the local delivery receipt,
not inferred from these source instructions.

## Still unfinished

The 50-locale JSON migration, real agent-button/reload and provider acceptance,
new visual evidence, advanced diagnostic features and formal performance/soak
campaign remain open. Historical recording cost near 2.9% of one logical core
still exceeds the 1% target. Main consolidation does not turn these gaps into
completed features or performance acceptance.

The earlier [audit checkpoint](audit-progress.md) and
[laptop integration report](laptop-integration.md) are dated evidence. Their
not-installed/not-promoted statements describe those batches, not a perpetual
restriction on the user's later deployment request.
