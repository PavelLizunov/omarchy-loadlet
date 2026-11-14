# Loadlet 2.20.1

Root-owned virtual machines were visible in Processes, but both termination
buttons stopped at the same-user guard before administrator authentication was
possible. Another owner's process now opens a confirmation that identifies the
owner and explains authentication and possible virtual-machine data loss.

## Process-action contract

- Same-user actions keep their unprivileged path. Another owner requires an
  explicit confirmation and the desktop's system administrator authentication.
- Both paths target the sampled PID and start time. The authenticated path also
  captures all four live ownership IDs before authentication and checks them
  again immediately before signaling through a fresh pidfd.
- PID reuse, ownership changes, kernel threads, dead processes, protected desktop
  names and the helper's ancestor chain remain rejected. There is no same-name
  fallback, automatic privilege retry or TERM-to-KILL escalation.
- Force termination keeps its own confirmation. Canceling or denying system
  authentication sends no signal. Closing the panel cancels pending confirmation;
  an already confirmed action retains its existing lifecycle.
- Authorization expires after 120 seconds. The user-side operation is bounded at
  125 seconds with a two-second kill grace; the privileged operation has a
  five-second timeout and one-second kill grace. The UI deadline is 130 seconds.
  Expired authorization is checked again immediately before sending the signal.
- The helper captures its Python implementation before crossing Polkit and passes
  it directly to the isolated interpreter. Root does not reopen mutable plugin
  code or obtain a PID from a shared temporary file. No helper installation,
  persistent privileged grant, service or sudoers rule is added by this change.

Host-process termination is not a guest operating-system shutdown. Use the guest's
shutdown control for a normal Windows shutdown; host termination can lose data.

## Packaging and verification scope

The stable ID remains `slovn.activity-lite`, with a root manifest and Panel.qml
entry point. Settings and diagnostic storage remain compatible. The sampler,
its sources/build flags and optional CPU/fan helpers are unchanged. README
installation/removal, Python/Polkit dependencies, licensing and binary provenance
remain explicit. Existing 2.19.2 media stays labeled and source-pinned.

Release acceptance uses `make check`: helper protection and owned-child signaling,
bounded native sampling, catalog parity, actual native UI, binary provenance and
isolated native add/enable/update without compiler calls. The UI suite includes
authentication selection, cancellation, force confirmation and the ordinary-user
path. Local inert renders cover both actions in four translated locales and the
expanded Russian layout; they do not summon the production panel.

A separate user/PID/mount namespace check executes the real authenticated Python
`-c` bootstrap and pidfd signaling against owned child fixtures, including wrong
start time, changed owner, missing authorization, expiry and ignored TERM. It
does not exercise a real administrator password or terminate a host VM.

Source acceptance, exact-commit hosted CI, installed bytes, loaded identity and
user-tested termination are distinct. The GitHub release and marketplace update
request record their exact commit and outcomes. Independent review is unavailable
under the project's no-delegation rule. Real Polkit interaction and guest shutdown
acceptance remain unverified.

The official marketplace baseline determines findings and capabilities. Privilege,
the bundled executable and existing optional service/sudoers control surfaces
require maintainer review. A push does not itself approve a new marketplace
snapshot or remove its manual-installation override; use the exact-commit
[update workflow](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md#update-an-existing-listing).
