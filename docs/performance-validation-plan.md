# Loadlet performance, memory and stability validation plan

Status: proposed execution plan, not a test result or a release certificate.
Prepared on 2026-10-30 for the requested comprehensive audit. Documentation is
English; the delivery explanation is Russian. This document is reference data,
not an additional agent instruction set or execution authorization.

## 1. Outcome and scope

The outcome is an evidence-backed statement about a named build, machine,
configuration, workload and duration. “Works perfectly”, “zero overhead” and
“no possible memory leaks” are not testable universal acceptance statements.
A successful conclusion must instead name measured CPU/memory/latency limits,
completed lifecycle cases, faults found, and remaining coverage gaps.

The current request covers:

1. Reproduce and repair the reported reload when opening Ask Pi, without
   assuming a native crash or blaming the provider.
2. Audit the complete shipped plugin and its optional control helpers, with
   explicit file coverage and a runtime/build/test/optional dependency inventory.
3. Replace Pi-only presentation with discovered user agents using the native
   Omarchy mechanism where possible. A usage/quota plugin is not automatically
   an execution API. Keep capability differences visible.
4. Add saved profile shortcuts to Overview through the existing apply owner.
   A selected draft, requested profile and successfully applied profile remain
   distinct. Preserve explicit edit/save behavior and automatic-mode semantics.
5. Exercise the real QML controls with mouse and keyboard, not just helper
   functions, and separate fixture evidence from installed-host behavior.
6. Measure ordinary monitoring, optional recording, history/reporting, agent
   discovery, agent jobs, and optional background control services separately.
7. Prepare inspected UI frames for the video and correct README media
   presentation. A committed MP4 link is not evidence of an inline GitHub player.

Main/release/Marketplace publication is a different delivery state from a
checkpoint branch. Video capture/encoding, builds, scanners and unrelated model
jobs are not concurrent with clean performance measurements.

## 2. Baseline, known evidence and open questions

Reference source: commit `6718bc098fee1879373d7255349438bc8e441d0f` (2.18.3).
Audit worktree: `/home/slovn/Work/omarchy-loadlet-audit`.
Preserved work branch: `checkpoint/loadlet-audit-work-20261030`.
The original and earlier delivery worktrees/indexes are separate and retained.

At planning time the read-only installed status returned version 2.18.3,
`ready`, panel closed, capture enabled at 500 ms, session
`1793349297524898-1064005`, sequence 2940, and empty reader/capture errors.
This is one status observation, not a fresh capture-growth or interaction test.
The installed consumer was the versioned 2.18.3 startup-fix directory.

Historical evidence, not current acceptance:

- 2.18.0 passed the then-current full gate and 87 UI results. Agent UI changes
  in 2.18.1–2.18.3 have not passed that full verification campaign.
- A 20-second native-reader series reported about 0.0336% of one logical CPU
  for ordinary background reads, and 2.8670/2.9028/3.0325% for
  1000/500/250 ms recording. Total reader RSS was approximately 4.4/10.3 MiB.
  Around 830 proc directories were present. These are not incremental shell
  memory, a long-run leak test, energy measurements, or game benchmarks.
- The proposed 1%-of-one-core recorder target was not met.
- The previous unsupported TextArea property prevented QML loading and was
  removed. It does not explain the newer interaction symptom by itself.

Current high-priority hypothesis, NOT yet a reproduced repair:
`Diagnostics.qml` opens the form by running `python3 -I diagnostic-report
--agent-info`. That helper imports sibling `activity-report` through
`SourceFileLoader`. The installed runtime contains an `__pycache__` file.
The host recursively watches plugin-tree create/write/delete/move events and
logs `Local plugin changed, reloading:`. Recent logs contain repeated Loadlet
reloads. A first import writing bytecode into the watched runtime is a plausible
reload trigger. Establish the actual event ordering and test cold/warm imports
before declaring this the cause; other plugin writes can reload shared content.

Agent discovery, generic runner support, profile shortcuts and README media are
still implementation work. Planning does not mark them implemented or tested.

## 3. Selected skills and actual tool availability

| Resource | Use in this task | Limit |
|---|---|---|
| `performance-autoresearch` | Profiler evidence, attributable changes, balanced before/after runs, noise-aware decisions and fresh confirmation | Not a leak detector or a benchmark itself; helper receipts do not prove execution |
| `omarchy-plugin-patterns` performance/plugin review references | QML ownership, timers, process lifecycle, bounded transport, memory and native host semantics | Static compliance is not a CPU/energy result |
| `omarchy-plugin` | Manifest/package/lifecycle and Marketplace preparation checks | Listing acceptance is separate from runtime performance |
| `codebase-audit` | Direct subsystem inspection and coverage map | File length and grep hits are cues, not defects |
| `ponytail` and `ponytail-audit` | Reuse native facilities, remove demonstrated duplication/dependencies | Fewer lines alone do not establish lower CPU or safer behavior |
| `repo-hygiene` | Evidence inventory and defect ledger | No unrelated history/worktree deletion is part of this pass |

The installed skill catalog was searched. `performance-autoresearch`,
`codebase-audit` and `ponytail-audit` were found and read. No separately named
Marketplace skill was found in that search; Marketplace guidance is present in
`omarchy-plugin`. No new skill or package was installed.

Available paths were discovered, not comprehensively validated:

- Python standard library, `/proc`, cgroups and systemd tools: primary lightweight
  sampler, process ownership, CPU/IO/fd/thread and memory accounting.
- C++ and Clang compilers, make: candidate builds and isolated sanitizer builds.
  Sanitizer runtime support still needs a build/run capability check.
- `/usr/lib/qt6/bin/qmltestrunner`, `qmllint`, `qmlprofiler`: native UI test,
  import checking and optional QML profiling. Profiler attachment requires a
  compatible debug endpoint; finding the binary does not establish one.
- `gdb`, `coredumpctl`: investigate actual native faults if present, not a
  substitute for proving the reported reload mechanism.
- `inotifywait`: correlate helper-generated files with watched-tree events.
- QML preview MCP: discovered offscreen healthcheck/render tools; no current
  candidate render has yet been run in this planning step.
- `perf`, `valgrind`, `heaptrack`, `pidstat`, `smem`, `hyperfine` were not found
  on PATH in this inspection. This is not a claim that no copy exists anywhere.

Start with stdlib accounting and isolated sanitizer builds. If allocation or
native hot-spot attribution remains unresolved, assess the missing tool and its
installation cost explicitly. A missing profiler leaves that attribution open;
it does not block the other measurements. There is no need to add runtime
profiling dependencies to Loadlet.

## 4. Measurement design and attribution

### 4.1 Snapshot identity and environment

Each run records source commit, dirty diff/hash if any, executable hash, native
build flags, helper/QML hashes, installed entry point, OS/kernel/Qt/Quickshell
versions, CPU/logical-core count, GPUs/drivers, display size/DPR/refresh rate,
power source, current governor/EPP/boost state, process count, workload, recording
settings, timestamps and observer version. Historical hardware values are not
silently copied into a new run's facts.

Freeze the tested candidate for each series. Changes to code, datasets,
thresholds or observer create a new run identity. Settings and current profiles
are recorded for comparison, not rewritten to historical values. Keep private
machine/process evidence local; public reports use synthetic data and aggregate
results, not raw histories or credentials.

### 4.2 Three measurement layers

1. **Native/helper layer:** task-owned sampler with isolated state directories;
   real read-only proc/sys sources for representative cost, fixture sources for
   reproducibility and failures. No second writer to the user's history.
2. **QML layer:** actual copied consumer and installed native controls with inert
   external IO, offscreen QtTest mouse/keyboard events and rendering. This can
   isolate QML allocations and lifecycle but not actual Wayland focus/driver cost.
3. **Installed shared-shell layer:** exact loaded candidate, existing shell,
   before/after process/session/status/filesystem evidence and the requested UI
   interactions through available host/input facilities. No second production
   Quickshell. If a live input surface is unavailable, list the exact unexecuted
   interaction rather than calling fixture clicks installed acceptance.

The shell is shared with other plugins. Its entire RSS/CPU is not Loadlet's.
Measure the reader/helper processes directly; obtain QML attribution using
matched plugin-off/plugin-on runs or a representative isolated consumer.
Record background changes and uncertainty. Native helper-only A/B results do
not certify the full desktop, and full-shell drift cannot be assigned to Loadlet
without attribution. Optional privileged workers are a separate cost subtotal.

### 4.3 Definitions and observer cost

CPU percentage of one logical core:

`100 * delta(user_cpu_seconds + system_cpu_seconds) / delta(monotonic_seconds)`.

100% means one fully occupied logical core. Do not divide this value by the
number of cores. Aggregate simultaneously live task-owned processes without
adding child CPU twice through both parent `cutime/cstime` and child counters.
Track exited/replaced PIDs by PID plus start time. Cross-check native internal
`collector_cpu_ms_since_record` against OS accounting; it is not the sole oracle.

Use RSS for residency, PSS for proportional shared-page attribution, and
private/anonymous memory for retention analysis. Virtual address space, page
cache, allocator arenas and Qt/driver caches are not automatically leaks. Do not
sum shared pages as private cost or equate allocator retention with live objects.
Read `smaps_rollup` where available; missing permissions yield unknown metrics.
Capture short-lived helper peaks through `wait4`/`ru_maxrss` (Linux KiB units) or
a task-owned cgroup's `memory.peak`; a periodic sampler alone misses brief peaks.
Cgroup memory includes different accounting than process RSS/PSS, so label each
metric and do not compare them as interchangeable numbers. Do not move the
existing shared shell into a benchmark cgroup merely to obtain clean accounting.

Default observer sampling: CPU/status counters every second for short runs,
10 seconds in soaks; PSS/private memory every 15 seconds in short runs and
60 seconds in soaks; fd/thread/child counts every 10/60 seconds. IPC status is
sampled at boundaries and at most once per minute, not every telemetry tick.
Fine-grained collector lateness comes from its own timestamped records.

Measure the observer alone. Its CPU must be below 5% of the workload budget or
an absolute 0.05% of one core, whichever is stricter for the chosen test; otherwise
reduce sampling and disclose the resulting resolution. Sampling/profiling runs
are separate from clean timing runs. Do not subtract noisy observer readings to
manufacture a pass.

### 4.4 Repeats, statistics and regressions

- Exploratory screen: three runs per mode, one-minute warm-up and five-minute
  measurement. Use this to find failures, not to certify tiny improvements.
- Formal performance comparison: at least five matched A/B pairs per core mode,
  two-minute warm-up and ten-minute measurement per member, alternating AB/BA.
  Report cold-start separately; do not hide it inside discarded warm-up.
- Report run means, median of run means, range, median absolute deviation (MAD),
  and p95 of ten-second CPU windows. Latency percentiles use per-action samples.
  Do not report p99 from five run means; collect at least 1,000 relevant events
  when making a p99 claim and report the event count/method.
- For an optimization claim require correct output, a practical improvement,
  and paired improvement greater than `max(noise_floor, 2 * paired_MAD)`.
  Default practical floors: CPU 0.05 percentage point and 5% relative; latency
  10 ms and 5%; memory 1 MiB and 5%. A smaller correctness fix can be retained
  without calling it a measured speedup.
- MAD is a noise heuristic, not a confidence interval. Thermal drift, correlated
  samples and background tasks remain visible. If using confidence intervals,
  resample whole time blocks/runs, not adjacent seconds as independent trials.
- No cherry-picking: keep failures, outliers and interrupted runs. Mark external
  disturbance and repeat a whole affected pair, retaining the original evidence.
- Fresh holdout workloads confirm changes; do not optimize to the only fixture.
  Final comparison is original baseline versus final combined candidate, not a
  sum of individual percentage improvements.

## 5. Proposed acceptance budgets: good, bad and unknown

These are product engineering targets for the reference desktop, not established
results or industry guarantees. Freeze them before formal runs. Record a revised
budget as a product decision with its reason; do not raise a threshold after a
failure merely to obtain green output. Other machines get their own named results.

### 5.1 CPU and responsiveness

| Metric / reference workload | Proposed good result | Bad or incomplete result |
|---|---|---|
| Closed, ordinary reader only, optional histories off | Steady mean <=0.10% of one core | Repeated attributable excess fails this budget |
| Same mode, total incremental Loadlet including QML | <=0.25% of one core | No reliable shell attribution means unknown, not pass |
| Open compact overview, no fast recording | <=1.0% incremental core CPU | Repeated excess is a lightweight-UI budget failure |
| Open expanded processes, two available GPUs | <=2.0% incremental core CPU | Report collector/UI/driver contributions separately |
| Fast capture at 1000, 500 and 250 ms, panel closed | Reader <=1.0% per mode; incremental total <=1.5% | Historical ~2.9–3.0% fails the reader target; a usable feature can still fail its efficiency target |
| Any steady mode | p95 ten-second CPU <=3 times its mean budget; no unexplained sustained busy loop | Single startup spikes are reported separately, not erased |
| Local control visual response | p95 <=100 ms, p99 <=250 ms, no plugin-attributable stall >1 s | Measure from input delivery to state/paint, not only handler return |
| Agent discovery, no network/inference | Median <=250 ms; p95 <=1 s; maximum <=2 s over 100 actions | Cold import/config errors are included; runtime download or model invocation fails discovery behavior |
| History query at 10/100/224 MiB retained input | p95 <=1/3/10 s respectively, all finish within existing 30 s job budget | A 60-second selection still scanning all retained data must be measured as such |
| Cancel visible feedback | <=100 ms | UI must not wait for a provider to cooperate |
| Cancel owned report/analysis processes | Terminal state and owned descendants gone within 5 s, or explicit stuck-kernel-IO failure | “Signal sent” is not exit/reaping proof |

Ordinary sampling-speed settings and fast-recording cadence are different axes.
Efficient/Balanced/Fast UI settings must be compared with the same settings on
both versions. Agent computation is separately metered: inference cannot be
hidden inside Loadlet's monitoring budget, and local models may dominate CPU/GPU.

### 5.2 Memory and retained resources

Reference workload is up to approximately 1,000 proc entries with the actual
available devices. Larger populations are separate scaling cases.

| Component | Proposed steady/peak envelope | Retention criterion |
|---|---|---|
| Native reader, ordinary mode | Total RSS <=16 MiB | Stable after warm-up |
| Native reader, fast capture | Total RSS <=32 MiB | End-minus-start private/PSS <=max(2 MiB, 5% of stabilized baseline) over 24 h; trend <=0.1 MiB/h |
| QML incremental footprint, compact/expanded | PSS <=32/64 MiB above matched host baseline | After repeated UI cycles, <=max(8 MiB, 10%) extra versus warmed equivalent state; trend <=0.25 MiB/h |
| QML with maximum admitted report/answer | Incremental PSS <=128 MiB | Return to a bounded plateau after replacement/close, not a new plateau every cycle |
| Python report helper | Peak RSS <=256 MiB typical, <=512 MiB maximum-admitted fixture | Process exits; no retained helper children or open history files |
| Agent runner | Measure startup, peak and teardown separately per adapter | No inference during discovery; owned one-shot descendants terminate; externally launched terminal is explicitly separate ownership |

A small positive slope below these tolerances is not proof of zero leakage. A
repeatable positive slope, linear per-cycle accumulation, or an identified lost
allocation remains a finding even before a coarse byte budget is exceeded.
Caches must have a named owner and finite ceiling. Results indistinguishable
from shared-shell noise are inconclusive and need isolated attribution.

For long-run trends, retain and report the first 30 minutes as warm-up, then
compare medians of the first and final 30-minute equivalent-workload windows.
Calculate a robust slope from five-minute block medians; report its spread and
all step changes, not only a fitted endpoint. Existing bounded histories may
legitimately fill for hours: distinguish prefilled fixed-capacity leak fixtures
from natural empty-to-full runs, identify the expected saturation time, and
require a stable post-saturation segment. A run ending before expected saturation
cannot settle that cache's long-term retention. Repeat a suspected positive
trend on a fixed dataset; corroborate it with allocation/object/handle evidence
where possible. Separate a one-time high-water mark from repeatable per-cycle
retention and from growth proportional to an unbounded input keyspace.

After warm-up, fd/thread/QObject/connection/timer counts must return to the same
settled envelope. Any persistent additions need a specific bounded-cache cause;
there is no allowance for one leaked handle per click. No task-owned zombies,
unbounded pending queues, duplicated sampler, or orphan analysis subprocesses.
Thread and object counts are measured only where instrumentation can actually
observe them, not inferred from RSS.

### 5.3 Recording and IO

- Quiet-desktop tick lateness: p95 <=max(20 ms, 10% of requested interval), p99
  <=50% of interval; missed scheduled slots <=0.1% after warm-up. Loaded-machine
  results have their own denominator and are not silently pooled into idle data.
- Delayed work skips overdue slots rather than building a catch-up queue. Gaps,
  resets, unavailable sources and missed slots remain observable. A continuous
  chart is not proof of complete acquisition.
- Source conversion cadence is reported separately from read cadence. No claim
  of fresh 250 ms hardware readings follows from 250 ms polling.
- Ordinary monitoring with all histories off performs no persistent telemetry
  writes. Discovery/query writes nothing into the installed plugin tree.
- Proposed capture write budget: median <=20 KiB/s and p95 <=64 KiB/s over
  60-second windows for the reference population; report logical and physical
  write counters separately. Buffered bursts are not continuous throughput.
- Retained raw/rollup payload respects published 224/32 MiB ceilings after
  maintenance, with the exact measured transient allowance documented if one
  exists. Per-chunk, buffer and row bounds are checked independently.
- Report actual retention as `retained_bytes / observed_bytes_per_second` plus
  observed coverage. “Up to 24 hours” is not a 24-hour guarantee when the byte
  cap binds first. The earlier short write rate suggests this matters.
- Legacy journal/sensors retain their own 20 MiB/7-day bounds and semantics.
  Exports are outside rotation; test the ten-entry guard separately.
- Collection/export makes zero provider calls. Disk flush is not fsync and is
  not advertised as power-loss durability.

### 5.4 Verdict vocabulary

`PASS`: executed named scenario meets correctness and its applicable budgets.
`FAIL`: reproducible contract violation or attributable threshold failure.
`INCONCLUSIVE`: noise/attribution or sample count prevents a decision.
`BLOCKED`: a required tool, runtime surface or environment is unavailable.
`NOT RUN`: planned but unexecuted. `N/A`: documented genuinely inapplicable case.
A warning or accepted budget miss is not a performance pass. An unavailable GPU
is not zero cost and does not establish GPU-path coverage.

## 6. Scenario matrix

### A. First fix: opening the agent form

Record shell PID/start time, reader PID/start time, capture session/sequence,
loaded consumer, settings hash and journal cursor. Exercise the actual
`captureInlineAgentToggle` control and correlate it with the local
`--agent-info` request, filesystem events and subsequent UI/process state.
Distinguish panel close, QML recreation, reader restart, plugin reload and native
shell crash. Inspect a core dump only if a native fault actually occurred.

Reproduce helper behavior in a task-owned writable copy with no bytecode cache,
then with a warm cache, then a read-only runtime copy. Record every generated
path and compare against the host watcher contract. Exercise history read and
export too: sibling imports may share the same cause. Opening the form must
neither run an inference nor save a new default model/profile. Verify 100 repeated
opens, including the first after installation and a subsequent source revision.

Acceptance: old behavior fails a meaningful regression case, the corrected
candidate passes it, and installed-host evidence supports the actual reported
symptom. Fixture/helper evidence alone is labeled as such if live interaction
cannot be driven. One unchanged shell PID does not rule out plugin reload.

### B. Sampling modes and scaling

Core comparison modes: closed ordinary, compact overview, expanded processes,
closed fast capture 1000 ms, 500 ms and 250 ms. Add closed with all monitoring off,
legacy sensors only, legacy journal only, combined histories, capture plus each
open page, active heat animation and animation disabled.

Use deterministic proc populations of 128, 1,024, 4,096 and the actual supported
capacity boundary, then boundary+1. Add PID churn/reuse, inaccessible proc entries,
changing names, foreign users, large task counts, sensor disappearance/renumbering,
multiple GPUs and duplicate DRM client descriptors. Do not create thousands of
real processes merely to populate a scaling fixture.

Record cost versus population and source latency. A large file or full proc scan
is not by itself an optimization finding; identify measured dominant functions.
Check process metadata parsing, repeated filesystem enumeration, thermal sensor
cache refresh, DRM fd scans, NVML initialization/close, serialization, pruning
and report reduction. No unmeasured retained-NVML optimization is assumed.

### C. UI interaction and lifecycle

Use mouse/keyboard event delivery to real QML controls, not only direct function
calls. Track outcomes and object/resource counts after each batch.

- 1,000 open/close cycles after 100 warm-up cycles; sample every 100 cycles with
  a 60-second quiescent interval. Repeat rapid close/reopen and Escape routes.
- 1,000 page/settings/expand transitions; chart range, hover, pin, drag and key
  navigation; filters, sorting, scrolling and stale-data displays.
- 100 recording start/stop/interval cycles in isolated state. Repeated Start at
  the current interval is idempotent; changing interval creates the documented
  new session. Close does not silently stop persistent capture.
- Named profile shortcuts: display actual saved names, active/requested/error
  states, no profile write on render, one apply per deliberate action, shared
  busy/authorization/rollback owner, manual apply/automation interaction.
  Apply failure must not highlight success. Extensive clicking uses inert
  hardware adapters; physical profile application is a separately labeled case.
- Agent selection/question/model controls, multiline Enter versus Ctrl+Enter,
  Copy, Cancel, empty result, error, slow result and close during every phase.
- Component create/destroy, helper failed start, failed reload and settings
  persistence. Repeated real plugin reloads affect the shared host, so distinguish
  a few installed lifecycle cases from high-count isolated churn tests.
- Layout matrix: ru/en/de/zh; compact/expanded/narrow; DPR 1/2; normal and enlarged
  font; light/dark palettes; long profile/model names and answers. Use targeted
  pairwise combinations plus full coverage of changed forms, not an unexplained
  claim that every Cartesian combination was tested.
- Frame geometry remains stable between tabs; focus and scroll reach all actions.
  Offscreen results do not establish compositor focus, real monitor hotplug or
  screen-reader acceptance. Record those as distinct host-level scenarios.

### D. Agent capability and job lifecycle

Inventory native launcher/default-selection sources and the neighboring usage
plugin's public data contract. Do not import another plugin's internals as a
mandatory dependency merely to list agents. Provider usage records are not
proof of a locally runnable command, login or compatible headless API.

Test zero/one/multiple installed agents; configured-but-missing defaults;
PATH wrappers, lazy installer shims, nonexecutables and stale settings. Discovery
must be local, bounded and non-executing: no `--version` probe that can install,
no catalog download, auth request or model call. Display discovered capabilities,
not a hardcoded Pi button or invented availability.

Distinguish (1) inline answer adapters with verified one-shot semantics and
owned cancellation, (2) explicit terminal handoff through native launch behavior,
and (3) unsupported/no agent with Copy/export fallback. Do not pretend every
installed CLI supports the same flags or embed its interactive TUI as plain text.
Review native launch permission flags and document their actual consequences;
a prompt saying “diagnose only” is not a tool/OS sandbox.

For every implemented inline adapter use a deterministic fake executable to test
success, delayed exit, empty/nonzero output, malformed UTF-8/JSON where relevant,
continuous stdout/stderr, output bounds, blocked stdin, descendants keeping pipes
open, ignored TERM, cancellation and parent teardown. Exercise helper forced
exit separately: a parent-death signal on the direct child alone does not prove
that all grandchildren stop. Verify cleanup by identity, not process name.

Use 100 mock request/cancel cycles and at most one live provider smoke request
per implemented adapter for end-to-end acceptance, with a small synthetic report.
Report authentication/provider/model and output success separately from discovery.
No repeated paid requests in load tests. Provider latency has no universal pass
threshold; the UI and owned job still obey their deadline/cleanup contracts.

### E. Reports, retention and malformed inputs

Deterministically generate empty, 10 MiB, 100 MiB and 224 MiB histories with seeds,
expected extrema/gaps and multiple sessions. Boundary datasets cover 4,096 chunks,
1,500,000 rows, 32 KiB lines, 128 series, 8,192 process identities, 256 sessions,
480 retained process frames and 200 events, plus each admitted boundary+1.
Keep file count, byte and row ceilings independent; a dataset need not hit all
limits simultaneously. Check exact behavior against owning source first.

Test short selection in a large retained history, seven-day rollups, session
filtering, CPU baseline reset, PID reuse, invalid JSON/field shapes, non-finite
numbers, very long names, sparse/dense events and Unicode. Verify extrema,
chronology and gap preservation, not merely successful JSON parsing. Separate
CPU policy frequency, effective clock, throttling and FPS; absent evidence is
not fabricated by reporting or agent output.

Read while writing/rotating; truncated tail; writer lock contention; permission
failure; symlink/hardlink/nonregular input; missing directory; partial writes and
out-of-space fault injection in isolated fixtures. Validate recovery, bounded
error logging, UI responsiveness and continued ordinary monitoring. Simulate
ENOSPC in a task-owned fixture/filesystem rather than filling the user's disk.

Retention boundary tests use synthetic timestamps/isolated clock abstractions,
not system-clock changes. Accelerated tests establish logic, not seven real days
of stability. Preserve existing exports and histories. No test deletes user data.

### F. Native and QML memory diagnostics

Build an isolated native binary with debug symbols, AddressSanitizer,
UndefinedBehaviorSanitizer and leak detection where supported. Use deterministic
proc/sys fixtures and owned lifecycle tests; the shipped binary is not replaced
by an instrumented executable. Check startup/EOF/TERM/error cleanup, allocation
failures if injectable, buffers, overflow edges, FD ownership and NVML handle
cleanup. Sanitizer timing is not used for production CPU acceptance.

Fail on a reproducible plugin-owned invalid access, use-after-free, double-free,
undefined behavior or definitely lost allocation. Review third-party reachable
allocations rather than suppressing the entire library. Any suppression has an
exact stack/version/reason and remains visible. If sanitizer/NVML integration
is unsupported, record the uncovered native-driver path explicitly.

For QML, observe actual-consumer object lifetimes, signal connections, delegates,
image/provider caches, JS arrays/maps, repeating timers and late callbacks. Use
QML profiler/engine allocation support only if available in the chosen isolated
harness; otherwise counts and long-run private/PSS trends give weaker evidence.
A single stable RSS graph cannot prove QML heap cleanliness. Do not require
manual garbage collection to make ordinary-user acceptance pass.

Python `tracemalloc` and `cProfile` can attribute helper allocations/work in
instrumented runs. They do not see C++/Qt memory or all Python native allocations.
Short-lived helper peak memory and child cleanup matter even if interpreter exit
reclaims all Python objects.

### G. Failure, recovery and optional services

Exercise slow/failed helper startup; EOF mid-frame; oversized producer output
before parser accumulation; response truncation; timeout then immediate new
request; cancellation before/after flush; stale results after close/reopen; crash
backoff; disable during backoff; unavailable/malformed configuration. Confirm
single flight, finite pending work and no stale escalation killing a later job.

Test scheduler stalls via SIGSTOP/SIGCONT only on task-owned fixture readers,
wall/monotonic discontinuities through fixtures, and actual suspend/resume as a
separate recorded live case when available. Do not confuse simulated suspend
with real GPU/driver resume. A stuck uninterruptible kernel read can defeat
userspace deadlines; report this limitation, not a false kill guarantee.

For optional CPU/fan/game workers, separately inspect and measure enabled idle,
mock game enter/leave, retries, locks, authentication failure and rollback. Test
UI dispatch extensively against inert adapters, preserving the user's saved
profiles. Real CPU/fan control, reboot persistence, physical fan/RPM mapping,
energy and acoustics are separate outcomes, not inferred from process tests.
No synthetic thermal torture, fan-stop or power-limit change is required to
validate plugin memory and UI lifecycle.

### H. Long runs and user-visible interference

After blocking defects are repaired:

1. 24 h ordinary user workload with 500 ms capture and normal panel use.
2. 12 h 250 ms capture with bounded scripted helper/UI churn and large retained
   history; no repeated real model calls or physical control switching.
3. 8 h ordinary monitoring with fast/legacy recording off, or the equivalent
   isolated representative setup if changing the user's recording would lose
   desired evidence. Label isolation explicitly.
4. 4 h focused QML interaction soak with periodic returns to a common idle state.

These run serially on a target for attributable performance. An instrumented
soak can expose correctness faults but requires separate clean cost confirmation.
A completed 12 h mode is not advertised as a 24 h test. The 24 h recording soak
also cannot prove 7-day retention; add a seven-day real observation if that
specific reliability claim is wanted.

For a repeatable real game or desktop workload, use at least five matched runs
with Loadlet off/on, unchanged profiles/settings and the same scene/replay.
Suggested practical no-regression targets: median frame time +<=1%, p99 frame
time +<=3%, if measurements can resolve that effect. Report raw paired results,
scene, GPU state and confounders. No game/FPS claim if no representative workload
or frame-time measurement source is available. Package power/battery evidence
requires a separate suitable counter/meter and scope; temperature is not watts.

## 7. Audit and optimization procedure

Maintain a coverage list for all shipped sources and scripts. Review these slices
fully: native resource/process/thermal/GPU collectors; native scheduling/storage;
QML controller/model/chart/icon lifecycles; panel/profile/agent UI; Python
report/export/agent/process helpers; privileged control/game adapters; packaging,
installer, defaults and tests. Mark unread/excluded files, generated tables and
vendored boundaries. Large-file counts prioritize reading, not forced rewrites.

Dependency inventory distinguishes:

- required runtime: native Omarchy/Qt/Quickshell, packaged sampler and Python
  helpers, linked standard libraries;
- optional runtime: GPU driver/NVML, installed agents, systemd/Polkit/sudo control
  adapters and their enabled workers;
- development/test: compiler, make, Node and QtTest/profiling tools;
- media-only: render/encoding tools and video assets, not monitoring dependencies.

Confirm actual consumers before deleting a dependency, function or file. A CLI,
QML signal handler, manifest entry or IPC/export consumer can be externally
reachable without a textual call site. No blanket docstring expansion, file
splitting or framework introduction merely to satisfy generic audit heuristics.

Record each finding before repair: ID, severity, source/hash/line, reproduction,
expected/observed result, consequence, counterevidence, minimal fix and regression
case. Fix correctness first, then optimize only measured hotspots. One attributable
change per experiment; preserve telemetry correctness, cadence, source coverage
and missing-data semantics. Sampling less or removing a feature is a product
tradeoff, not a free algorithmic improvement.

Use the selected performance skill's balanced comparisons and fresh confirmation.
Its campaign helper may be useful for a focused latency optimization after the
measurement harness exists; do not force all CPU, memory, lifecycle and correctness
results into its single wall-time score. No autonomous campaign is initialized by
this plan, and no arbitrary count of optimization attempts is a success target.
Independent model review has not happened; the current workspace specifies direct
work. Neither a self-review nor a skill's historical validation substitutes for it.

## 8. Execution order, duration and progress gates

| Phase | Work | Exit evidence | Approximate elapsed time, excluding fixes |
|---|---|---|---|
| 0 | Freeze identities, inventory, observer and criteria | Reproducible run manifest; known blockers | 1–3 h |
| 1 | Reproduce reload; fix smallest owning cause | Before/after regression and scoped installed evidence | 1–4 h, cause-dependent |
| 2 | Finish requested agent/profile UI; source audit and regression additions | Coverage/defect ledger; current functional checks | 4–12 h, findings-dependent |
| 3 | Exploratory six-mode measurements | 3 x 6 min x 6 modes =108 min plus setup | 2–3 h |
| 4 | Isolated fault/sanitizer/UI churn and render inspection | Bounds, cleanup, layout, error cases | 3–8 h |
| 5 | Clean formal six-mode comparison | 5 pairs x 2 builds x 12 min x 6 modes =12 h | >=12 h |
| 6 | Long runs | 24+12+8+4 h with raw traces | >=48 h |
| 7 | Installed acceptance, final gate, media and checkpoint | Exact tested/delivered identities, report and inspected images | 2–5 h |

Expect roughly 3–5 calendar days once the candidate and instrumentation are ready,
not a promise to complete multi-day evidence inside one chat turn. Faults and
repeated long runs can extend it. Running two benchmark modes simultaneously
cannot shorten the elapsed-time requirements without changing the workload.
Video design/documentation can progress between runs; rendering/encoding must be
scheduled outside clean measurement windows on the same machine.

Long runs use an owned managed user unit with recorded exact name, start time,
absolute deadline, evidence location, resource budget and completion status, or
bounded foreground execution. A planned unit is not a running job. Report
started/running/failed/completed separately and do not claim future results.

Initial test-artifact budget is 4 GiB total, including retained synthetic data,
logs, renders and traces, with at most 2 GiB of simultaneously active history
fixtures. Stop only the task-owned run on reaching its recorded cap, leaving
ordinary user recording untouched; preserve the failure receipt. Cap continuous
logs per run and mark truncation explicitly. Short helper/fault tests get an
outer deadline above their product timeout; each soak has its exact duration
plus a five-minute shutdown grace. Any external timeout, OOM kill or resource
limit hit is a failed/interrupted run, never a successful bounded-memory result.
Resource ceilings on instrumented test children must allow sanitizer overhead
and remain distinct from production acceptance budgets. No benchmark is accepted
while an observer or cgroup is silently throttling it.

A reproducible crash, reload loop, data-loss path, unbounded growth, orphan job,
incorrect hardware apply or corrupted evidence blocks acceptance of the affected
path. Other independent investigations continue. Performance-budget misses are
reported even if correctness passes. Re-run affected scenarios after fixes;
final assertions bind to the final code, not a previously tested revision.

## 9. Test-harness quality and evidence layout

Reuse `make check`, `test/ui-checks.py`, `test/tst_panel.qml`, controller checks,
fast-diagnostics and report tests. The native lifecycle fixture is not currently
part of the inert UI gate; decide and record its separate execution method.
Add only missing targeted test coverage and a small stdlib measurement driver,
not a monitoring service or another frontend framework.

Test the observers/checkers themselves using isolated negative controls:
known CPU burn, bounded deliberate memory retention, leaked fixture FD, stalled
fixture child, altered expected peak, malformed report, extra plugin-tree write
and a changed session on a fake form-open action. The appropriate checker must
fail. A checker that only prints PASS or reads source strings cannot certify the
runtime behavior. Negative controls never modify the user's history/hardware.

Local evidence root, to be created when execution begins:
`~/.cache/agent-tmp/loadlet-validation-20261030/`.
Suggested structure:

```text
manifest.json                 exact build/host/settings/workload identities
criteria.json                 frozen budgets and statistical rules
coverage.csv                  source/scenario coverage, exclusions
findings.md                   evidence-backed defect ledger
runs/<run-id>/metadata.json    command, parent/child identities, exit and times
runs/<run-id>/samples.jsonl    raw CPU/memory/IO/resource measurements
runs/<run-id>/events.jsonl     interactions, reloads, timeouts and state changes
runs/<run-id>/stdout.log       bounded logs; truncation explicitly recorded
runs/<run-id>/stderr.log
renders/                      inspected actual-consumer PNGs and provenance
summary.json                  raw-to-summary calculation outputs
report.md                     findings, budgets, comparisons and limitations
```

Private raw evidence stays outside the repository. Publish a sanitized aggregate
report, reproducible scripts, synthetic fixtures and selected inert images with
hashes. Checkpoint the task batch without replacing the active source branch or
index. Verify the remote checkpoint's exact commit. Update binary provenance if
native source/binary changes; copied files, loaded identity, UI acceptance, CI,
remote publication and user acceptance remain distinct states.

For the README: choose a GitHub-supported presentation after checking the actual
rendered page. A bounded GIF/image preview can link to the MP4; an uploaded media
attachment/player is a different delivery mechanism. Test repository-relative
paths on the checkpoint and the eventual public page separately. Media success
is not performance acceptance. Frames must identify actual consumer revision,
locale/theme/size and inert data; do not imply synthetic scenes are live gameplay.

## 10. Final acceptance report template

The final report contains:

1. Exact source, installed and loaded identities, binary provenance and host.
2. Original symptom, established cause, minimal repair and before/after evidence.
3. Full scenario ledger with PASS/FAIL/INCONCLUSIVE/BLOCKED/NOT RUN/N/A states.
4. CPU by mode with units/denominators, memory plateaus/slopes/peaks, IO/retention,
   latency distributions, missed samples, resource counts and observer cost.
5. Sanitizer/allocation findings and which heaps/driver paths were actually seen.
6. Changes/dependencies removed and measured benefit, including failed hypotheses.
7. Agent discovery versus configured versus authenticated/output-tested status.
8. Profile UI dispatch versus physical apply/reboot/hardware acceptance.
9. Installed lifecycle, capture continuity/settings preservation and actual UI
   interaction evidence, separate from inert render/test results.
10. Game/energy/accessibility/long-retention limits and unavailable environments.
11. CI/checkpoint/media status, duration and exact artifacts for reproduction.

Acceptable conclusion example, with real values substituted only after execution:

> Build X on machine Y completed the named 24-hour workload and N interaction
> cycles with no observed unexpected reloads, surviving owned jobs or attributable
> unbounded memory trend. Reader CPU was A% of one core, peak memory B MiB, and
> action p95 C ms. Cases D remain untested or failed. These results do not prove
> universal absence of leaks or fault-free operation on other hardware.

## Planning-step outcome

Completed: installed skill discovery/read, relevant source/contract review,
read-only current status/log inspection, tool-path discovery and this plan.
Not completed: full audit, new regression suite, fresh renders, performance or
leak campaign, reload repair, generic agents, profile shortcuts, video changes,
current CI or installed acceptance. No multi-day job has been started by writing
this document. Earlier requested implementation work remains active.
