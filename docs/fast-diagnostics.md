# High-resolution diagnostics — 2.18.1 checkpoint

## Use

Settings → History → Start diagnostics begins a separate, explicit recording.
Choose a CPU polling target of 1000, 500 (default), or 250 ms. Changing the target
starts a new recording. Problem now saves a timestamped incident marker. Stop
ends only the additional diagnostics; ordinary monitoring and legacy recording
settings are unchanged. Closing the panel does not stop recording. Unloading the
plugin or ending the shared shell ends the session. The Start/Stop preference and
interval are saved as diagnosticCapture and diagnosticCaptureInterval. Reloading
the enabled plugin resumes in a new session when that preference is on; it does
not record while the shell is absent. A reader crash can also resume into a new
session. New installations remain off by default; Stop saves the off preference.

Read history selects 1/10 minutes or 1/2/6/24 hours and an optional recording.
Choose a signal, select a point, and inspect the nearest reduced process snapshot.
Inspect 60 s around selection rereads raw history for that window; use the period
selector to leave the narrowed range. Charts retain extrema, not every observation
or exact simultaneity. Coverage, invalid records and capacity omissions remain
visible. Queries are explicit, not another periodic polling loop.

Pi inside Loadlet opens an optional question and provider/model field, initialized
from the installed Pi configuration. Analyze here reads the selected period or
60-second selection, flushes active recording, and shows the final plain-text
answer in the panel. It is a one-shot answer, not a persistent chat; previous
questions/answers are not sent again. Copy answer is available. Cancel, panel
close or component teardown stops this owned job without stopping recording.
Changing the selected range does not change an already-running request; each
answer labels its original period and requested model selector.

This path uses Pi 1.4.0 print mode and existing credentials/model definitions.
A bounded summary (up to 96 KiB) includes sensor extrema, CPU/process summaries,
events and up to 12 same-session snapshots near thermal peaks, with explicit
relative times. Raw history and full chart points are not sent. The provider may
receive this summary and question and charge usage. Local models add load to the
recording. No inference runs automatically while capturing or exporting.

The job disables Pi tools, extensions, MCP, skills, context discovery and session
saving for this invocation only. It passes explicit analysis prompts in a fresh
temporary working directory and leaves global Pi configuration unchanged. This
is not an operating-system sandbox; the installed runner and configured provider
remain trusted dependencies. The offline startup flag suppresses automatic
catalog/download work, not the explicitly requested model network call. Providers
registered only by an extension are not supported by this minimal adapter; use
Pi's models.json or the separate terminal handoff instead.

The helper drains both output streams, caps final output at 64 KiB and stderr at
16 KiB, and ends inference after 120 seconds. The panel caps total query lifetime
at 150 seconds, with TERM followed by a bounded KILL fallback. Linux parent-death
signaling also stops the direct Pi child if its helper is forcibly terminated.
No new daemon, model download, provider account UI or privileged helper is added.
The adapter locates an existing Pi launcher, but path discovery alone does not
establish a working provider/model. A failed request reports an error, not an
invented answer.

Export for an agent writes a new private directory with summary.json,
samples.jsonl and AGENT-PROMPT.md. Open agent hands that directory to the existing
Omarchy default launcher or Pi in a terminal. Copy analysis request is the fallback.
No model runs during collection or export. External agents retain their ordinary
permissions and configuration; the prompt is not a filesystem/tool sandbox.
Provider selection, credentials and billing belong to the runner. Its normal
configuration can transmit report contents to a cloud provider. A launcher exit
means handoff, not completed analysis. Closing Loadlet does not cancel a separately
launched terminal agent. OpenCode is available only through the native default-agent
route when independently installed/configured; there is no tested direct adapter.

## Collection and storage contract

One scheduler lives inside the existing native reader. Absolute monotonic CPU
slots skip overdue work rather than build a catch-up queue. Resource counters and
CPU hwmon readings use the selected target; process candidates/PSI use 1 s, full
hwmon sensors 2 s, GPU batches 2 s initially. A GPU batch taking over 20 ms lowers
its target to 5 s for that recording and writes a cadence event. Diagnostic DRM
FD/client work runs at most every 10 s. Context and rollups target 10 s. Synchronous
driver/filesystem calls can still stall the reader; this is not hard real-time.

Each record carries session/boot identity, sequence, wall time at collection start,
monotonic start, collection duration and recorder CPU since the preceding record.
CPU ticks carry lateness and counter-window duration. Clock/suspend/collection
gaps reset baselines. Separate reads are not atomic simultaneous measurements.
Sensors retain driver/location/channel identity. Exposed update_interval and
missing-read/power-state reasons are included when available; unknown conversion
cadence stays unknown. Polling at 250 ms does not promise 250 ms hardware updates.

Full process scans discover new work before ranking up to 30 candidates by CPU,
RSS, growth and observed waiting states. Identity is boot ID + PID + start ticks.
Names, not command arguments or environments, are stored. Between-scan short-lived
processes can be missed. Per-process CPU uses one logical core as 100%; system CPU
uses the whole machine. GPU source timestamps/counters remain in raw evidence;
the local summary does not yet derive a per-process GPU timeline. Sleeping NVIDIA
devices retain the existing admission guard. NVML is released after each batch;
persistent initialization was not adopted. No cooling/power settings are written.

Under `$XDG_STATE_HOME/omarchy/activity-lite` (normally `~/.local/state`):

- `diagnostics`: schema-2 raw JSONL, up to 24 hours or 224 MiB, whichever binds first.
- `diagnostics-rollup`: aggregate CPU temperature extrema with peak times and CPU
  sample means, up to 7 days or 32 MiB. Not complete process/device history.
- Existing `journal` and `sensors` remain separate and keep their old limits.

Private writer locks prevent competing writers to each folder. Chunks rotate at
1 MiB/hour. Raw writes flush after about 5 s or 48 KiB on subsequent records;
rollups flush when emitted. Buffers are bounded at 128 KiB each; records at 32 KiB.
Retention is enforced on writes. Flush is not fsync: power loss can lose OS-cached
data, SIGKILL can lose buffers. Partial write errors discard the incomplete batch.
The UI exposes writer errors, not a promise of durable or gap-free history.

The report helper streams at most 224 MiB / 1,500,000 rows / 4096 chunks. It bounds
series to 128, identities to 8192, sessions to 256, process frames to 480 and events
to 200. It rejects oversized lines/chunks rather than silently accepting partial
input. A selected interval is still scanned from retained chunks; time filtering
does not yet provide a chunk index. Local-report UI output is limited to 2 MiB
with a 30 s owned-process deadline/cancel; explicit inline analysis uses the
longer bounds above. Explicit exports are outside rotation, at most ten
entries in the shared export parent. Review or move exports as needed.

```sh
python3 -I diagnostic-report --seconds 60
python3 -I diagnostic-report --start 1800000000 --end 1800000060 --export
python3 -I diagnostic-report --hours 168 --rollups
```

These are examples, not commands to replay historical times. The legacy
`activity-report` schema-1 export remains unchanged. No migration rewrites data.

## Evidence limits and implementation scope

A sampled peak is not sustained overheating. Policy frequency is not effective
clock speed or proof of throttling. No FPS/frametime, CPU hardware throttle signal,
NVML throttle-reason query, automatic game association, watched-PID subsecond scan,
statistical causation, persistent embedded chat or MCP server is implemented here.
The embedded one-shot answer interprets only the supplied summary; it does not
add missing hardware evidence. Advanced collectors still require separate source
support and acceptance.

Initial 15 s local measurements found roughly 4.5% of one logical CPU. Avoiding
per-PID stream/token allocations and slowing expensive GPU/DRM work reduced a
later short series to roughly 3.0%, with about 10.5 MiB total reader RSS. Those
runs included around 824 proc directories and are not isolated game benchmarks.
The proposed 1% target is **not achieved** by that evidence. No energy, battery,
frametime, physical sensor-conversion or runtime-suspend guarantee follows.
See VERIFICATION.md for the delivered candidate's actual checks and limitations.

## References used for design

- Linux hwmon ABI: https://github.com/torvalds/linux/blob/master/Documentation/ABI/testing/sysfs-class-hwmon
- k10temp: https://www.kernel.org/doc/html/latest/hwmon/k10temp.html
- MangoHud: https://github.com/flightlessmango/MangoHud
- NVML event meanings: https://docs.nvidia.com/deploy/nvml-api/latest/api/group__nvmlClocksEventReasons.html

These establish API semantics, not measured hardware behavior. No source was copied
from these projects. Native Omarchy launch scripts and installed Pi 1.4.0 CLI docs
own the handoff; an agent-usage widget is not an inference API. A direct OpenCode
version probe unexpectedly entered mise's lazy installer and timed out. No
OpenCode model execution or compatible installed version was established.
