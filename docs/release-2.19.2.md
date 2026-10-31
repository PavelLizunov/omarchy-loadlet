# Loadlet 2.19.2 release checks

## Scope and delivery states

The owner requested a new-version film using their existing video library,
thorough Omarchy-plugin checks, and Marketplace submission. This pass starts at
`e79df373879a1c9334697b584866ca54351cef69`. It preserves the permanent plugin ID
`slovn.activity-lite`, the `bar-widget` contract and `Panel.qml` entry point.

- **Source checked:** full local `make check`, current offscreen QML and film checks.
- **Packaged installation checked:** fresh isolated native add/enable/update,
  no compiler or first-run build; shell enable IPC is stubbed, not production.
- **Installed/loaded on the owner's desktop:** unchanged 2.19.0. Read-only IPC
  reported ready, capture enabled at 500 ms, four fan controls and 117 retained
  memory snapshots. The release pass does not erase them through a reload.
- **Published/reviewed:** exact-commit GitHub CI and Marketplace request are
  separate external states; follow the repository Actions and request #13300.
  This document does not assert Marketplace approval or a changed public card.

No saved settings, CPU/GPU/fan values, root helpers or running control services
were changed. No cache cleanup, authentication, process termination, real provider
call or automatic memory observation was started by this pass.

## Findings and corrections

| Finding | Evidence and correction |
| --- | --- |
| 2.19.1 failed to load | Invalid `Keys.onPageUpPressed` and three related attached handlers. Parent 2.19.2 source switches to native `Keys.onPressed`; current QtTest exercises Home/End/PageUp/PageDown and language typing. |
| Chart test selected a hidden memory chart | Baseline UI: 108 passed, 1 failed. Memory charts now have distinct object names; child lookup is scoped to its chart. Current panel suite: 112 passed, 0 failed/skipped. |
| Bright default horizontal scrollbar | Page tabs and profile shortcuts now use a 3-logical-pixel accent thumb, without a stock background. Overflow capture inspected; measured height 3, zero deviation. Focus reveal remains covered. |
| Saved language could start with a clipped row | Initial reveal uses `ListView.Beginning`; selection and keyboard movement remain distinct. Final native screenshot inspected. |
| README exceeded its own 100-line gate | Condensed the front page without removing setup/removal or control limitations. |
| Controller test fixture predated memory observation | Added fields/callback stubs and explicit scheduling checks; 30-second due time survives presentation resets. |
| Previous Marketplace request was rejected | Existing #13300 contained an extra heading. Correct the six-heading verification form and put evidence in a separate comment, rather than duplicate the listing. |

Retained local failures include README/metadata assertions, the old chart lookup,
missing controller fixture fields, and an initial Rust temporary-lifetime build
error. Subsequent success does not erase those earlier failures.

## Executed local checks

`make check` includes the following, with results retained in task-local logs:

- Distributed ELF, executable mode/source hashes, changed-byte negative control,
  real framed synthetic sample and no unsolicited journal write.
- Fork boundary, complete current-tree/reachable-content heuristics and their
  positive/negative controls; these are not universal security certification.
- Process identity/ownership and owned-child signaling tests; bounded reader
  overflow, unreadable sensors and next-request survival.
- Controller startup/retry/single-flight, stale/icon/thermal admission, journal
  and sensor recording, and explicit memory-watch timing.
- Model mathematics, four catalogs/405-key placeholder parity, profile encoding,
  icon shapes/raster bounds and pressure/heat semantics.
- Native journals, diagnostic exports, identities/gaps, bounded retention,
  locks, private output, malformed data, SIGTERM flush and inert agent argv.
- Simulated fan/profile application, rollback, game detection, worker grace and
  recovery; no physical hardware writes.
- NVIDIA lifecycle fixture: inactive admission, retained mapping, balanced
  sessions, bounded descriptors, resume and EOF cleanup; not a new GPU trial.
- Native icon QtTests at DPR 1 and 2: 4 results per run. Panel QtTest: 112 results,
  no failures/skips. Installed Qt 6.12.0 and inert host consumer.
- Native packaged add/enable/update, existing-ID refusal and actual Model parser;
  only shell IPC is stubbed. `omarchy plugin validate .` exits successfully.

### New memory regressions

`test/memory-watch-checks.js` covers threshold/insufficient/stable controls,
missing counters, boot/PID/start identities, interruptions and clock gaps,
121-frame retention, chart gaps and retained-event reports.

`test/memory-native-checks.py` supplies 270 synthetic processes plus zombie and
kernel-thread cases. It checks RSS order/256 retained entries, 32 PSS admissions
with one unavailable rollup, unknown counters, PSI, framing, observation-only
nonpersistence and command-level capture coexistence. This is not sustained
coexistence under real load or an interruptible kernel-read deadline.

QML tests exercise event deduplication, retention after exit/Stop, reset on Start,
20-event cap, notification argv/markup neutralization, nonzero exit feedback,
cooldown queueing and disabling/Stop queue discard. They use an inert Process;
no real notification daemon, toast or click delivery was tested. A further QML
regression reorders 80 synthetic process rows during a scrolled view and confirms
that the model identity and scroll rank remain unchanged.

### Native binary reproduction

`make -B activity-sampler` reproduced the shipped 333944-byte executable with
GCC 16.2.1 20260810. Both SHA256 values were
`a08b20a36d90eb8b30c934c9f69d74fc959a9ad251dba639a9a6dda351683965`.
`readelf --version-info` reconfirmed GLIBC_2.34 and GLIBCXX_3.4.32 ceilings.
The native sources/bytes did not change in this release pass; Makefile gains
regression commands only. Hosted reproduction is a separate exact-commit result.

## Visual and film evidence

The final eight captures show Overview, Cooling map, Profiles, Memory, Languages,
narrow Russian Memory, Arabic/English-fallback language selection and dark
Russian horizontal overflow. The five film images use DPR 2; the other three
use DPR 1. Source-owned QML is transformed only for inert IO/host import adapters.
No live desktop capture, second production Quickshell or external viewer was used.

All final images were read inline. Pinned actions remain visible in constrained
Memory; the body is intentionally scrollable, so partial bottom rows are viewport
clipping, not a claim that all text fits at once. The selected language row is
fully visible. RTL fixture evidence is limited: English fallback remains English,
and native-script font information is not fluent/bidi acceptance.

The render tool reported PASS under `warningsPolicy: report`. AT-SPI/atk-bridge
warnings and OpenType font-support messages are retained, not suppressed or
called strict-clean. This is not an accessibility-consumer or compositor test.

The [film](video/2.19.2/README.md) uses the owner's fframes library workflow and
real inert native UI stills, not invented product pixels. It is silent, 30 seconds,
1920×1080/30 fps. All 900 SVG frames passed renderer inspection; the MP4 was fully
decoded and chapter-midpoint frames inspected. No continuous human playback or
neural video-generation claim is made. Assets, original/transformed source hashes,
licenses and media checks are in the film evidence record.

## Residual limits

- Production 2.19.2 discovery/loading/input and real notification submission,
  display/click behavior remain unverified. Reloading would discard the owner's
  current session-only memory results; copy the report before a later update.
- No physical fan/acoustic/airflow, CPU limit, suspend/reboot or real-game trial;
  no thermal-safety, performance or energy guarantee.
- No full-hour observation/soak, sustained PSS/CPU/energy budget, allocation trace
  or leak attribution. The historical shared-shell multi-GiB spike is unexplained.
- Memory events remain session-local, not a persistent incident database. The
  300 ms collector limit is an admission deadline, not an interruptible read bound.
- Four catalogs exist; 46 registry choices use English fallback. No fluent review,
  complete plurals, screen-reader or broad bidi/RTL certification.
- Real provider/authentication, terminal handoff, long child-lifecycle faults,
  physical ENOSPC and long retention campaigns were not executed here.
- Review was direct by the implementing assistant, not independent/cross-model.
- Marketplace registry still records manual installation for the existing
  listing. The standard-installation request #12657 remains distinct from update
  #13300. A submitted request/green CI does not create a deployed copy button,
  standard-install eligibility, maintainer approval or new listed snapshot.
