# Loadlet guide

[Overview](../README.md). Details below describe the current native plugin.

## Language

The header language button opens a searchable, scrollable list of Omarchy registry
languages plus System. The list uses the available height in both compact and
expanded panels, with readable start-aligned names, English descriptions and
locale codes. Search and Back remain pinned. Opening reveals the selected language;
search selects its first match. Down enters the results; Up from the first result
returns to search; Enter selects and Escape/Back dismisses without changing it.
Panel letter shortcuts are suspended while searching, including `e` and `h`.
Search accepts native names, English names and locale codes.
System follows live shell-language changes; an explicit choice affects only Loadlet.
The legacy `zh` preference still selects Simplified Chinese (`zh-CN`), not `zh-TW`.
Only English, Russian, German and Simplified Chinese have translated catalogs.
Other choices use English text and are labeled as fallback in the picker. This
layout correction does not add the other 46 translated catalogs.

Displayed metrics use the selected language’s decimal separator and digits. Dates
use its Qt locale. Process IDs and editable hardware values remain machine-form
numbers. RTL locales mirror the reading layout and Back arrow; charts and physical
diagram coordinates stay left-to-right. RTL/input acceptance remains unverified.
See [localization limits](localization.md).

## Icon indicator

The default Split die has a left CPU eye and a right RAM eye. Both fill from
bottom to top in six whole rows, rounded down. **Icon fill threshold** applies
independently to CPU and RAM in both bar and header icons. The default is 50%:
49% draws no filled rows; 50% draws three; 100% draws six. The actual percentage
scale is not rescaled above the threshold. Settings offers 0-100% in 10-point
steps (`iconLoadThreshold`); 0 disables suppression and restores the original
first row at about 16.7%. Invalid threshold input falls back to 50%.
Raw readings in the panel/tooltip, sampling, thermal markers and motion are
unchanged. Empty tracks are not proof of zero or fresh data; read the tooltip
or panel for exact values/freshness.
The selected 3x6 eyes and small cutout cheeks stay inside the 16-unit canvas.
On Omarchy 4.5, the bar uses a native WidgetButton with that canvas centered
directly in the unchanged slot. This preserves the previous character size
instead of applying the new host's additional 12-unit custom-icon normalization.
Logical icon dimensions remain fixed; HiDPI changes only the bounded raster.
Version2.7.7 adds small stepped edge chips and staggered shoulders to the default
body, retaining all gauge/temperature meanings. Version2.7.8 widens that body
from12to14 logical units within the same16-unit canvas, without stretching eyes
or changing the bar slot or12-unit body height. Version 2.7.9 replaces the
asymmetric chips with paired side notches and balanced shoulders/base. The quiet
body and face mirror left/right; unequal gauge readings and heat remain distinct.
It is stored as `iconShape: 10`; all ten older silhouettes and explicit saved
selections retain their original indices. Settings can switch between them.
Older characters retain their horizontal CPU mouth and vertical RAM eye. The
SVG follows the host palette and keeps the normal icon slot.
Version 2.6.1 declares the target pixel dimensions inside the SVG as well as in
Qt's `sourceSize`, avoiding fixed-16px data-URL rasterization on Qt 6.12 and keeping
HiDPI bar/header images sharp. The 16-unit vector geometry is unchanged.
The same character appears in the panel header. Split die fill uses the theme
accent hue below 85%, with a higher brightness ceiling from 65%; from 85% it uses
the urgent hue. Version 2.7.3 raises saturation to at least 90% and selects the
brightest bounded shade retaining 3:1 active-row/body contrast on checked opaque
palettes. Unlike 2.7.1-2.7.2, it does not mix active colors with grey background.
Near-neutral theme roles use blue/red hue fallbacks; no theme settings change.
The panel cards and legacy icon shapes retain their original gauge palette.
The tooltip shows current CPU, RAM and temperature with short click hints.
Settings explains the selected shape's gauge mapping and six-row threshold.
Legacy shapes keep their flatter CPU mouth, approximately
6 logical units between endpoints with a 2.4-unit stroke, and fitted RAM eyes.

Colored flames above the character appear at 80 degrees Celsius and clear below
75 degrees Celsius. Settings can change the trigger; the clearing threshold stays
5 degrees lower. Flames use the host urgent color. They signal a configurable
temperature threshold, not a hardware-specific critical-temperature diagnosis.
Missing sensors, stale values and reader failures clear the flames.
The Split die uses stepped flames within the existing canvas; legacy shapes
keep their curved flames. Fresh high temperature also colors the CPU-card detail.

**Brief heat animation** is enabled by default and can be disabled in Settings.
The character rotates by at most 6 degrees for 2 seconds. Four heat levels start
at the configured threshold, then +5/+10/+15 degrees Celsius. At the default
80 C threshold they begin at 80/85/90/95 C, with movement starting at most once
every 15/10/5/3 seconds respectively. Flames grow above the character, then spread
to the sides and bottom while keeping the gauge tracks clear. Cooling between levels has
a 2 C deadband; full exit stays below threshold minus 5 C. Stale thermals, hiding
the item or disabling motion stops it and resets rotation. This is a native Qt
transform; it does not regenerate SVG per frame or change sensor cadence. One
visibility-gated visual replay timer uses fresh cached thermals. Inert tests verify
these bounds, not CPU or battery consumption. At the maximum level two seconds
of movement may run every three seconds; its physical resource
cost has not been measured.

With **Background icon indicators** enabled (default), the same native reader
requests aggregate CPU/RAM and a separate CPU thermal sample every 15 seconds
while the panel is closed. Requests are serial. The thermal reader reuses its
cached sensor path; initial discovery or sensor loss can enumerate hwmon sensors.
With diagnostic history, high-resolution capture and explicit memory observation
disabled, no process inventory, topology, GPU or disk requests run in this mode.
Open-panel samples feed the icon without a second reader. Disabling background
indicators and all explicit recording/observation sessions stops closed-panel
collection, while open-panel sampling continues normally.

CPU requires two counter samples; the initial baseline is unavailable, not 0%.
CPU is an average between samples, so short peaks are smoothed. Unavailable values
leave unfilled tracks and are identified in the tooltip. Freshness/counter-gap
limits are 35 seconds. Exact CPU, used/total RAM and fresh temperature are in the
tooltip. These tiny gauges show approximate levels; background polling is not
zero-overhead, timer cadence can slip during shell stalls, and battery impact
has not been measured.

## Memory growth observation

Open Memory and choose Start observation before repeating a workload you want to
understand. Opening the page alone does not start a session. Samples target every
30 seconds for one hour in the existing native reader, including while the panel
is closed. Stop keeps the result in memory until plugin reload; starting again
replaces it. Reload disables observation and does not change saved high-resolution
capture preferences. Stop and Copy local report remain in the pinned footer.

System history separates total-minus-available (an estimate, not summed process
heaps), cache plus reclaimable slab, anonymous pages, shared memory/tmpfs,
unreclaimable slab and swap used. Memory PSI reports the kernel’s 10-second
percentage of time with some/all non-idle tasks stalled on memory. Zero sampled
pressure does not exclude earlier shortages. These categories overlap; do not add
them into a fabricated complete accounting or equate cache with guaranteed savings.

Select one of the ten largest current anonymous-memory increases for baseline,
peak, change, average change per minute and charts of anonymous RSS, PSS or USS.
PSS apportions shared resident pages; USS here is Private_Clean + Private_Dirty.
Anonymous RSS may include shared anonymous pages and is only a screening signal.
Permission gaps, process exit and eviction from the bounded set mean unknown, not
zero. Identity uses PID/start ticks within each boot. Restarted/reused PIDs do not
continue the prior trend. System and process reads are not an atomic snapshot.

A growth warning requires a continuous interval of at least 10 minutes and
12 samples, anonymous growth of at least 64 MiB and 25%, and at least 70% of steps
growing by 1 MiB or more. It is a disclosed heuristic, not a statistically validated
leak detector. Absence of a warning proves nothing about slow, bursty, privileged
or unretained consumers. Repeat comparable actions after warm-up; a plateau may
reflect useful caching or allocator reuse. Allocation profiling is needed to
attribute retained memory. No automatic kill, cache drop or profiler is added.

**Notify about memory growth** is initially enabled for the explicit observation,
not a background-on-startup monitor. The toggle affects this loaded plugin only;
reload restores it to enabled, while observation itself remains off. Every new
candidate creates a Growth event once per boot/PID/start identity, up to 20 per
session, even if notifications are disabled. Each event retains its detection
time, process growth/baseline/peak, available memory, pressure and coverage.
Events remain after process exit and are included in Copy report, but a new Start
or plugin reload clears them. They are not written to the diagnostic journal or
a persistent incident database.

The native Omarchy notification shows the process, anonymous-memory increase and
interval, explicitly without a leak verdict. Clicking opens Memory with Growth
events expanded; it never starts observation or applies a system action. At most
one notification per minute, grouping up to three process summaries and a count
of additional candidates. Stop or disabling notifications discards pending alerts;
reenabling does not replay old events. Submission failures/timeouts are displayed,
and the event stays available. No automatic retries or notification service is
installed. Delivery uses the installed `omarchy-notification-send`, ordinary
urgency and the `Loadlet` sender, respecting the desktop quiet-mode policy. A
successful send does not establish that a toast was displayed. Notification
history retention belongs to the host, not this plugin.

The sender is a short-lived owned Process, bounded by `timeout` to 5 seconds
with a 1-second kill grace. Notification text is localized; process-name markup
and directional controls are neutralized for presentation. Click argv is fixed
to the plugin Memory IPC route and never contains process names or a shell
command string. No notification was sent during this implementation.

Bounds: scan at most 4096 numeric procfs entries, retain the largest 256 readable
RSS processes, and attempt smaps_rollup for the largest 32. A 300 ms admission
deadline stops new reads; it cannot interrupt an individual kernel read. The
existing reader watchdog/retry remains in force, so a stall can interrupt other
collection too. Coverage, unreadable/changed identities, observed zombies, partial
snapshots and elapsed collection time are retained. Collection duration is not a
CPU-cost measurement. Sparse access and scan limits can omit the actual culprit.

Keep at most 121 snapshots in QML memory; no new disk journal, daemon, package,
network call or root permission. The closed-panel scheduler ticks once per second
only while observing, but memory requests remain about 30 seconds apart and do
not reset on page changes. Reader interruption, samples more than 75 seconds apart,
boot changes and wall/uptime discontinuities reset comparisons and break charts.
Wall-clock reversal starts a new chart segment. A stale snapshot remains labeled.
Observed costs and full-hour/input behavior have not been measured.

Copy local report puts JSON in the desktop clipboard, without sending it to an
agent/provider. It includes system frames, coverage and histories for the ten
current leading processes (the selected retained process replaces the tenth if
needed), with names, PID/start and boot identity; no argv or
environment. Exited or no-longer-retained processes are not in that current top
history; recorded growth events still retain their detection snapshots. The
clipboard payload is capped at 524288 characters; copy before reload
and review before sharing. This is not a complete process archive.

## Memory cleanup

Open the Memory tab, or click the RAM metric tile. Opening the page is inert.
Available memory and cache reuse the existing sampler; the cache figure is
`Cached + SReclaimable`, not an amount guaranteed to be freed. Linux normally
reclaims cache automatically as applications need memory. High cache usage alone
is not a leak or a reason to clear it.

Processes by memory opens the existing expanded process table sorted by resident
memory, without ending anything. RSS includes shared pages and must not be summed
as unique application memory. To release application memory, save work and close
the application normally; an identified stuck process can use the existing explicit
Terminate confirmation. Zombie processes have already released their address space;
their parent must reap the exit status. Killing zombies is not a RAM cleanup method.
No automatic process cleanup, swap reset or stronger cache-drop mode is added.

Clear cache is in the bottom action row, beside Processes by memory. It is
disabled while a memory observation is running to preserve the session's readings.
Clear cache opens a confirmation. Authenticate and clear invokes
Polkit for that one request, flushes pending file writes with `sync()`, then
writes `3` to `/proc/sys/vm/drop_caches`. This asks the kernel to reclaim clean
file pages, dentries and inodes system-wide. It does not terminate processes,
clear application heaps, repair leaks, disable swap or delete files. Re-reading
files can be slower afterward; no speedup or fixed reclaimed size is promised.

Before/after cache and available-memory snapshots are taken around the drop,
after the flush. Concurrent applications affect both values. A completed request
with missing measurements is reported separately, never as an invented saving.
Cancel or Escape dismisses confirmation without a request. Navigation and close
dismiss unsubmitted confirmation but do not promise to cancel authorized kernel
work. The long-lived module retains the operation and its result across pages.

No root helper installation, sudoers grant, periodic cleanup, service or setting
is added. The shipped `memory-clean --clear` uses a fixed isolated Python operation
through `/usr/bin/pkexec`, with a root-side 30-second timeout and 2-second kill grace.
A root-owned `/run/loadlet-memory-clean.lock` serializes requests. The UI waits
up to 130 seconds including authentication. A timeout or lost output means the
result is unknown; uninterruptible kernel I/O may still complete. Standard
Polkit authentication policy applies; permission denial is displayed in the UI.

The module was implemented without executing cache cleanup or authentication,
and without tests or visual acceptance in this delivery.

## High-resolution diagnostics

Settings → History also provides explicit native diagnostic sessions with
250/500/1000 ms CPU polling, 1 s process candidates, incident markers, local
window analysis, on-demand Pi answers inside Loadlet, and optional Omarchy/Pi
terminal handoff. Start/Stop and interval are saved across shell reloads; new
installations still default to off. It does not replace the legacy recording
below. Ask Pi offers a named-model dropdown and optional multiline question;
model choice is saved only for Loadlet. Recording options/export and the separate
legacy history are collapsed until needed. See [usage, storage bounds, measured
cost and evidence limitations](fast-diagnostics.md).

## Diagnostic history and agent recommendations

**Diagnostic history** is a separate opt-in setting, disabled by default. It
keeps the existing reader active even when background icon indicators are off.
It adds process enumeration every 30 seconds and a bounded diagnostic-context
read every 60 seconds. Normal CPU/RAM and CPU temperature keep their 15-second
closed-panel targets. Open-panel samples are reused; no second telemetry daemon
or privileged helper is installed.

History is private JSONL under
`$XDG_STATE_HOME/omarchy/activity-lite/journal` (normally
`~/.local/state/omarchy/activity-lite/journal`). It contains:

- UTC epoch time, uptime, boot identity, CPU percentage and its averaging window;
- RAM/swap values, CPU temperature, missing values, sample ages and collection errors;
- up to 30 process candidates across high CPU, resident memory, memory growth and
  observed D/Z states, identified by boot ID, PID and start ticks;
- CPU/memory/IO PSI, selected vmstat counters, load average, CPU policy frequencies
  and limits, scaling driver/governor/EPP, boost permission, platform profile and
  AC/battery status when available.

The writer buffers at most 128 KiB, flushing on subsequent samples after 60 seconds
or buffer pressure, and on normal shutdown/SIGTERM. Chunks rotate hourly or at
1 MiB. On writes it prunes oldest chunks to at most 7 days and 20 MiB. Shorter
history is possible when the byte limit is reached. Storage failures remain local
to history and appear in diagnostic status; metrics continue. Power loss, SIGKILL
or the host's forced teardown can lose the buffered minute. No command lines,
environment variables, window titles or document contents are captured.

Settings provides **Export for an agent** for 1/2/6/24/168 hours, followed by
**Copy analysis request**. The export directory contains `samples.jsonl`,
summary.json and AGENT-PROMPT.md, generated inside that new export directory.
Summaries include sample coverage/gaps,
thermal episodes using an explicitly labeled 80 C analysis criterion, process
candidates, PSI peaks and swap/vmstat rates. The raw records retain effective CPU
policies so an agent can recommend appropriate workload, EPP/profile/boost or
frequency-limit experiments with tradeoffs, before/after checks and rollback.

For a local CLI export, run from the installed plugin folder:

```sh
python3 -I activity-report --hours 2
```

Explicit exports are outside automatic journal rotation. The default export
parent accepts at most 10 entries; move or remove an old export before creating
another. Input is bounded to 20 MiB, 50000 records and 32 KiB per line. An empty
selected period is an error, not a fabricated report. The UI has a 10-second
owned-process deadline. Exports never overwrite an existing destination.

This legacy export prepares evidence and a recommendation prompt; it does not run an AI,
change CPU settings, or end processes. The prompt is guidance, not a permissions
sandbox. When using an agent, keep its task read-only and approve any later
system changes separately. Process names are untrusted data, not executable commands.

CPU percentage of a process uses one logical core as 100% and can exceed 100%.
RSS can count shared memory more than once; growth is not proof of a leak. A D
state means uninterruptible waiting, not a proven hang; sleep is normal; a zombie
requires investigation of its parent. Candidate lists are sampled, not an archive
of all processes or finished jobs. GPU load, fans, electrical watts and direct
throttling measurements are not recorded. The export cannot prove pointless
work, exact energy use or the physical cause of heat by itself.

## Controls

- Left-click the bar icon to toggle the panel, honoring the saved detailed-view
  preference. Right-click has no action. Expand inside the panel or press `e` for
  the built-in process view; the existing details IPC route remains available.
- The header Close button dismisses the entire panel from any page, without
  stepping through editors or collapsing its frame. Selecting a fan location
  saves it and closes that location editor. Selecting a sensor category saves it
  while keeping Category open and the same sensor selected; only the dropdown
  menu closes. Neither choice closes the whole panel. Nested dropdowns and Escape
  retain their normal local dismissal.
- Expand and `e` resize every page without leaving it, including Cooling, Fans
  and Settings. This is a fitted larger panel, not compositor full-screen.
- `h`: toggle Cooling; `/`: search, `j`/`k`: select, `s`: settings.
- Click a process to select it. Terminate sends SIGTERM to that exact PID and
  sampled start time. Force terminate sends SIGKILL only after a separate confirmation.
- Processes owned by another user (including root-owned virtual machines) require
  the [system process helper](#authenticate-process-actions) and explicit confirmation
  followed by system administrator authentication. The helper rechecks PID, start
  time and all four ownership IDs after authentication. It refuses a target that
  changed or exited. Authorization expires after two minutes, with a separate
  five-second root-operation timeout.
  Canceling authentication sends no signal. Desktop/session guards still apply.
  Terminating a virtual machine's host process can lose guest data; shut down inside
  the guest for a normal operating-system shutdown.
- No automatic escalation or promotion to a same-name parent process.
- Selection follows PID and sampled start time across updates. When that identity
  disappears from the visible list, action buttons disable until another selection.
- Expanded process updates reuse a stable list model. Metrics and sorting stay live
  without resetting the scroll to the beginning or following the selected row.
  The viewport retains its rank position, not a pinned process; sorted rows can
  change underneath it. Changing the sort or search explicitly returns to the
  beginning. Keyboard selection alone reveals its target. A shorter list may
  clamp the viewport at its new end.
- Escape cancels confirmation first, then collapses details/closes the panel.
- In Settings, Escape closes an open dropdown first, then returns to the metrics.
- The language picker blocks process actions. `?` shows or hides keyboard hints.
- Error messages distinguish unavailable data from an idle machine.

The interface uses native JSON catalogs for Russian, English, German and Simplified
Chinese, shared through `LoadletLocale.qml`. New defaults follow the live Omarchy language with `system`; explicit
saved overrides are preserved. Untranslated languages currently fall back to
English. The [50-locale migration](localization.md) remains incomplete. PID, CPU, VRAM,
and byte units remain technical identifiers. Helper failures use localized UI
messages rather than displaying untranslated stderr.

## Authenticate process actions

To end processes owned by another user, install the system helper from the
reviewed Loadlet source checkout as an administrator. Existing directories
in the destination path must be root-owned, free of symlinks and writable
only by root.

```sh
(
  set -eu
  sudo mkdir -p -m 0755 /usr/local/lib/loadlet
  staged_helper=$(sudo mktemp /usr/local/lib/loadlet/.process-signal.XXXXXX)
  trap 'sudo rm -f -- "$staged_helper"' EXIT
  sudo install -o root -g root -m 0755 process-signal "$staged_helper"
  sudo mv -fT -- "$staged_helper" /usr/local/lib/loadlet/process-signal
)
```

The rename activates the new helper once the copy completes. Polkit runs this
installed executable for Loadlet process actions. If Loadlet displays a setup
message, inspect the path with `namei -l /usr/local/lib/loadlet/process-signal`.
Monitoring and same-user actions work with the normal plugin installation.

Repeat the installation from the reviewed checkout when updating this system
helper. To remove it, run `sudo rm -- /usr/local/lib/loadlet/process-signal`.
Polkit supplies authorization for each request.

## Panel geometry

Compact mode shows up to four processes without scrolling. Its visible row count
shrinks when the host clamps the panel height. On narrow panels, PID and memory
percentage columns hide before the process name, CPU and absolute memory columns.
Expanded mode keeps the process list and action buttons reachable by scrolling
the summary cards internally when vertical space is limited.

Preferred content sizes are 480×390 and 900×650 logical pixels, multiplied by the
host spacing scale. Switching pages, opening Settings or the diagram never
changes the chosen size. Only Expand, `e`, the initial saved preference and the
explicit details route change it. Long pages scroll internally with a persistent
scroll thumb. Fan location and identification controls are separate disclosures;
ordinary boost and restore actions fit the default compact Fans view. Cooling's
compact toolbar leaves the chart and range summary visible without scrolling.
The selected page is underlined. Diagram sits at the left of the lighter Cooling
toolbar; recording sits at the right, with an empty or filled circle and explicit
off/on text. Category is beside the selected sensor, not another navigation tab.
It is hidden while the diagram is open and disabled when no sensor is selected.
Scrolling pages keep both content edges aligned with their tabs; the scroll thumb
uses the outer padding, not an asymmetric content gutter. Compact and expanded
metric grids share the footer edges, card/header heights and value alignment.
The profile form and its pinned Save/Cancel row also use the same width. Keyboard focus scrolls
controls into view. RPM history has an explicit return to the originating channel.
The host adds popup padding and borders to the height; with
default tokens the outer cards are 480×422 and 900×682. Actual theme overrides and
screen bounds can change these dimensions. Settings uses the same frame as its
parent page, with its header and bottom actions outside the settings viewport.

## Reading charts

Sensor charts retain the full selected 10-minute, 1-hour or 6-hour horizontal
window, ending at the current time. Empty earlier space means missing history,
not a zero reading. The vertical grid labels temperature, percent or RPM; RPM
uses a bounded automatic scale and temperature/percent use a zero baseline.
A single observation is a dot, not a continuous line.

Hover previews a timestamp/value. Click pins that reading while live sampling
continues; drag moves it. Arrow keys select neighboring observations; Home/End
select oldest/newest. Live or Escape clears the selection; Escape then follows
the page's normal return behavior. Selection follows its timestamp across updates
and clears if that timestamp leaves the retained history. Hovering an unrecorded
gap shows no value rather than pretending its nearest sample was measured there.

Raw recording gaps and boot boundaries remain line breaks after downsampling.
Ordinary reduced-resolution history does not become a chain of false gaps.
The range summary describes available observations, not continuous coverage.
Saved-history read failures have a separate message and retry, independent of
recording/write errors. Recording is explicitly labeled on/off and never enabled
by opening a chart or changing its time window.

## Summary tiles and sensor names

The compact view defaults to two configurable tile slots in one row. Settings
can select three slots in the same row for CPU/GPU/RAM, reserving space for
processes. Each slot can
show CPU, RAM, a GPU (including a specific discovered adapter), CPU temperature,
fans, network, disk activity or storage, or be hidden. Defaults are CPU/RAM;
the optional third slot defaults to GPU. Existing slot choices remain saved.
If none of the main slots shows RAM, an enabled-by-default narrow memory strip
appears below them with percentage, used/total capacity and a fill bar. It uses
existing resource samples, not an extra poller, and can be disabled in Settings.
GPU, storage and sensor requests are admitted in compact mode only
when their tiles need them; expanded summaries also request sensors for GPU
temperatures. Closed-panel sampling is unchanged unless background sensor
recording is explicitly enabled.

All summary tiles now share one font-aware height. Core cells use the original
Activity Monitor arrangement: values on the left, topology grid anchored on the
right. The grid is fitted to the available card body rather than overflowing
into its header/footer. Hovering a cell shows its logical CPU and sampled load.
CPU temperature is a separate value/detail, never a crowded header badge.

Cooling cards show a localized device category and available model name first,
then the reading meaning; raw driver/label/location remains secondary. Identity
comes from the driver, CPU model, NVMe model and PCI IDs, not temperature guesses.
Memory modules are distinguished by their bus addresses; no physical DIMM slot
is inferred. Unknown drivers retain an explicit unidentified-device heading.

## Cooling tab

The pinned Overview/Cooling/Fans tabs share the same fitted panel frame. The Cooling
page uses a device/sensor selector and one detailed chart, rather than a tall
stack of graphs. It reads hwmon temperature and fan inputs, plus
active NVIDIA temperatures and per-fan percentages from the existing NVML provider.
Hwmon discovery covers ITE (`it87`, `it86*`), Nuvoton (`nct67*`, `nct668*`),
Fintek (`f718*`), and laptop, AIO, storage, network and battery drivers.
The CPU temperature reader falls back to CPU-related `thermal_zone` readings
when dedicated CPU hwmon readings are unavailable.
RPM is displayed only for a sensor that actually supplies RPM. Missing fan data
is unavailable, not zero. Cooling is read-only; the separate Fans page requires
the optional authenticated adapter for timed overrides. The entire Cooling page
scrolls, including recording controls, so charts stay reachable in small frames.

Cooling uses the existing serial native reader. Without background recording,
open-page sampling targets 3 seconds and retains up to 240 volatile samples.
The separate Background recording toggle is off by default. When enabled, it
keeps collecting temperatures and fan readings with the panel closed, targeting
15 seconds, and retains up to 1440 in-memory samples per sensor. It reuses the
existing bounded journal writer in a separate sensors folder; no new daemon or
process inventory is enabled. Records are retained up to 7 days or 20 MiB,
flushed about once per minute and at graceful shutdown. The buffered minute
can be lost on forced termination. The setting persists until turned off.

The chart offers 10-minute, 1-hour and 6-hour windows with min/max and observed
duration. Opening Cooling loads recent persisted history through the existing
report helper, with a 5-second deadline and bounded output. Long histories are
reduced using min/max buckets to retain peaks; missing or reduced-resolution
intervals are labeled. The cooling chart positions samples on their actual
wall-clock timestamps. Hover/click/drag selects the nearest recorded point;
left/right keys select neighboring points. Time and value appear above the
chart. Gaps over 60 seconds break the line. Reduced-resolution saved history
can therefore appear as separate line segments. A 15-second sample can miss shorter peaks and
a hot reading is not proof of hardware throttling. Recording requires the shared
shell to remain running; it is not a system-level service. Sleeping NVIDIA
devices remain excluded. Sensor discovery stays cached for 30 seconds.
Data lives in ~/.local/state/omarchy/activity-lite/sensors, or under XDG_STATE_HOME.
The diagnostic CPU/process journal and its exports remain separate.

GPU summary cards now wrap each adapter name and show its load, clock and memory
on separate lines instead of concatenating two adapters into one clipped detail.
The CPU temperature is visible in the CPU detail and its own temperature tile. Press `h` to switch
the Cooling page; Escape returns to Overview before collapsing or closing.

## Interactive computer map

Cooling and Fans provide an optional SVG case cutaway with live labeled callouts
connected to its numbered points. Temperature, actual RPM and driver percentages
appear beside the corresponding component. Multiple readings use a min–max range;
hover for individual sensor names and values. Stale or missing data says No data,
and percentages are never converted into RPM. Existing manual assignments apply.
The map reuses current sensor samples, without extra polling or hardware writes.
Compact mode uses short component names and separate lines for temperature, RPM
and percentage, leaving more space for the drawing. Full names remain in hover
text. Below the compact width budget, the drawing uses the full width and labels
continue below it in two columns; the page scrolls instead of shrinking targets.
It is collapsed by default so data remains visible.
See the [drawing references](vector-design.md). Select CPU, GPU,
RAM, drives or the motherboard to filter existing temperature/fan sensors and
reuse their history charts. The schematic collapses after selection to leave
room for data; its heading reopens it. Show all removes the filter. Multiple
devices in one category remain selectable by model in the sensor dropdown.
Missing telemetry is explicitly unavailable, not a fabricated reading.

CPU/front/rear/top/SSD/bottom fan points open the control page. Bottom fan is
a separate floor-mounted symbol and point11; points1-10 retain their numbers.
Choose Bottom fan in a channel location or sensor category to assign it manually.
No channel is assigned to this new position automatically. A channel selector
replaces the repeated tall card list. Assign a channel location
with the dropdown on that channel card; assignments are saved in plugin settings
and do not change fan duty or require authentication. With one assigned channel,
the corresponding point focuses it; without a unique match all channels remain
accessible. RPM history opens the existing chart. Sensor cards also offer manual
map locations, keyed by driver/location/reading identity rather than hwmon index.
Choosing Driver category removes that sensor override. Reset defaults clears
assignments. No connector identity is inferred from RPM, temperature or proximity.

The diagram is symbolic, not a measured replica of the actual case. Linux exposes
IT8613 fan2-fan5 without physical header labels on DRFXI. A related-board report
identifies fan4 as CPU, but is not sufficient evidence for this machine; it is
not applied automatically. A zero tachometer reading is not proof of an unused
connector. Observe physical wiring or BIOS labels before assigning CPU_FAN.

## Motherboard fan control

The Fans tab controls motherboard, AIO and laptop fans whose hwmon drivers
expose a supported PWM channel and mode control. It retains the `pwm2`–`pwm5`
channel names on DRFXI with the IT8613E driver. Assign physical locations after
checking wiring or firmware labels. A tachometer reading alone cannot identify
a connector. Install the [optional system controls](#optional-controls-installation-and-removal)
to make changes.

Enter a whole percentage within the channel's displayed range and press
**Save %** or Enter to save a controller duty. Boosts use 60%, 80% or 100% where
supported, retain the prior-duty floor and run for 5, 10 or 30 minutes. To
identify a fan, open the five-second trial and choose an available output. A
trial can lower the duty. **Stop for 5s** requests zero duty on channels that
accept it. The fan may continue spinning even at 0% duty.

Saved outputs use a root-owned service per channel and persist across reboots.
Boosts and trials pause a saved output, restore the captured duty and mode on
exit, and resume the saved output if one exists. Closing Loadlet leaves the
systemd timer running. **Restore previous control** ends the override, removes
the saved output and disables its service. The worker's recovery hook also
attempts to restore the captured state after a failure.

Settings is split into Tiles, Icon, Sampling and History. The normal preferred
frame fits short categories; diagnostic history and constrained screens scroll internally.
Sensor assignment is under Category; choosing a category keeps the editor open
and follows that category filter instead of silently switching to all sensors.
The Category button itself hides it when finished. Manual categories update the
device heading and selector label as well as the diagram filter. Raw driver
identity remains visible in Category. Wi-Fi driver instance suffixes are excluded
from saved assignment keys; existing matching keys are retained as a fallback.

IT8613 takeover goes through full speed before setting manual duty. For
motherboard channels the thermal fallback uses CPU readings. The fallback
thresholds below also apply to GPU channels using their own temperature readings.

One driver-level check on DRFXI found IT8613E revision12 at0xa30. The in-tree
it87 module did not bind. The separately packaged frankcrawford/it87 revision
bd7a566c8a60fe0308d67e26761e16260368191a bound without force_id, resource-conflict
bypass or a global ACPI override. It exposed three temperature inputs and four
fan/PWM channels. A bounded pwm2 full-duty request changed reported RPM from
about695 to1534, then duty40/mode2 were restored. Physical connector identity,
acoustic/airflow change and automatic timed restoration remain unverified.

## GPU fan control

The Fans tab also offers direct control of NVIDIA fans through NVML and discrete
AMD fans through `amdgpu` hwmon. Only channels with driver control are available.
Saved outputs, boosts and trials honor each channel's minimum and maximum. For
example, a zero-RPM RTX 5060 Ti can report 0% in automatic mode with a 30–100%
manual range. The output field shows the permitted range until you enter a value.
A 30% request and return to automatic were verified on the observed RTX 5060 Ti.

At 80 °C or above, or when temperature readings are missing, a saved output or
boost requests the driver's maximum. The requested output resumes after three
consecutive samples below 75 °C. A five-second trial is refused or ends early
when temperature is high or unavailable. On exit, the trial restores the
captured policy and any prior manual target. For NVIDIA, **Restore automatic
control** explicitly returns fan control to the driver. AMD restoration uses the
captured PWM mode and duty.

## Named CPU and cooling profiles

The dedicated Profiles tab separates browsing, applying and editing. Select Current settings, Quiet idle,
Games or a custom preset to see its CPU/fan summary without changing hardware.
Apply activates it. Edit and New profile open a dedicated page with separate CPU
and cooling sections, an internally scrolling form and pinned Save/Cancel actions.
The icon picker offers Moon, Gamepad, Fans, CPU, GPU and Tag; the saved icon is also
used in Overview shortcuts. An icon-only or name-only edit retains active-profile
attribution because it does not change the hardware configuration.
New profile starts from the selected preset without replacing it. Save updates
only the preset and returns to Profiles with that preset selected; Apply is a separate
action there. The active preset remains distinct from the selection. Back, Cancel,
Escape, switching to another tab, opening Settings or closing Loadlet discard unsaved edits. Expansion and
language selection preserve the draft. Duplicate creates another draft (up to12
saved presets). Original control and automatic game switching are on Profiles,
outside the editor. Fans contains only individual channel controls. Tabs stay
visible during editing in one row. Tab widths follow their labels; constrained
widths scroll horizontally instead of wrapping. Keyboard focus reveals its tab.
Deletion needs a second click and remains unavailable for active presets or those
used by running automation. Existing names, values and assignments are preserved.
Changing a single fan output clears the active profile indication, since it no
longer represents the saved named configuration.

Each preset can store up to 16 motherboard outputs and 8 GPU outputs, with exact
whole percentages inside the available driver ranges. CPU settings include boost
(including per-policy boost where exposed), governor, energy preference, a
maximum frequency in MHz and the ACPI `platform_profile`. Governors can include
`powersave`, `performance`, `ondemand`, `conservative` and `schedutil` when
available across CPU policies. A zero frequency restores the original limit.
Quiet idle uses boost off and powersave/power. Games permits boost and performance.

The platform profile picker lists selectable firmware modes. ACPI can report
`custom` when platform handlers have different modes. Current settings omits
that aggregate value, and Original control restores each captured handler mode.

Automatic game profiles use SteamAppId/SteamGameId and an actual game executable,
not GPU load or merely an open Steam launcher. A root-owned systemd worker checks
every5seconds, keeps Games active through a15-second exit grace period, then
restores the selected non-game preset (Quiet idle when Games is selected).
Manual profile application or an individual fan action disables automation.
Open Automatic game profiles to choose an explicit non-game return preset and
enable the toggle with authentication. Disable automation before changing that
return preset. The toggle enables/disables it with authentication;
non-Steam games without Steam launch metadata are not detected. Editing Games
requires disabling and enabling automation to capture the updated preset.
An unavailable or stale automation status is reported rather than highlighted
as a successfully applied profile. The
worker remains active with the panel closed and after reboot. Per-game CPU/fan
settings are not inferred from load. No game-playthrough or reboot check is
implied by installation.

The profile helper snapshots CPU and fan settings, serializes applies and
attempts to restore the prior settings if a step fails. The active profile is
root-owned under `/var/lib/loadlet-power`. The profile service reapplies CPU
settings after boot and per-channel services restore saved fan outputs.
**Original control** restores the captured CPU settings and releases the fan
overrides managed by the active named profile.

## Optional controls installation and removal

The normal plugin installer does not change system files. To enable CPU/fan
controls, review this source checkout and install its fixed adapters:

```sh
sudo install -Dm755 fan-control /usr/local/lib/loadlet/fan-control
sudo install -Dm755 power-profile /usr/local/lib/loadlet/power-profile
sudo install -Dm644 GameDetection.py /usr/local/lib/loadlet/GameDetection.py
```

Keep all three files from the same release. Updating the plugin does not update
these root-owned files. Reapply a named profile to refresh unit definitions; if
automation was enabled, disable and re-enable it after updating the adapters.
Do not change saved fan percentages or CPU limits merely to update the helpers.

The optional system services are `loadlet-power-profile.service`,
`loadlet-auto-game.service` and `loadlet-fan-profile@CHANNEL.service` for saved
motherboard and GPU outputs. Timed boosts and trials use
`loadlet-fan-CHANNEL.service`. Older whole-device NVIDIA presets may use
`loadlet-gpu-fan@PCI-ID.service`. These services can outlive the desktop shell.
Polkit authentication grants 24 hours of validated requests to the root-owned
helpers through sudo. Enabled services continue when the grant expires. Revoke
it by removing the matching `/etc/sudoers.d/60-loadlet-fans-UID` file as root.

To remove optional controls, disable automatic profiles and use **Original
control** on Profiles. In Fans, use **Restore** on each separately overridden
motherboard or GPU channel. The command-line equivalents use each configured
channel ID. For example, on a system with these two channels:

```sh
/usr/local/lib/loadlet/power-profile request restore
/usr/local/lib/loadlet/fan-control request restore pwm2
/usr/local/lib/loadlet/fan-control request restore nv.0000_01_00_0.fan0
```

Only after restoration succeeds, remove the installed helper files and disabled
Loadlet unit definitions as root, remove your matching sudoers grant, and run
`sudo systemctl daemon-reload`. Do not delete recovery state or helper executables
while their workers are still active.

The plugin can then be removed with `omarchy plugin remove slovn.activity-lite`.
User history under `~/.local/state/omarchy/activity-lite` and explicit exports are
retained. Remove those directories yourself only if you no longer need the data.

## Per-process GPU usage

The compact process table includes an aggregate GPU % maximum. Expanded view
replaces it with one percentage column per GPU, sorted by stable PCI identity
and labeled with a short model name, such as RTX5060Ti or Radeon610M. Long
unrecognized models use a stable GPU number. Hover its heading for the full name and PCI ID;
identical models remain distinguishable by that ID. Click a heading to sort by
that GPU. `g` still sorts by the aggregate maximum. Missing measurements sort
below measured values in either
direction and display a dash, never a fabricated zero. PID and start ticks tie
readings to the sampled process identity. Stale readings are cleared.

The existing GPU request also collects recent NVIDIA process utilization through
the optional NVML API, admitted only for an active device. The displayed value
is the maximum of 3D/compute, encoder and decoder utilization. Unsupported
drivers, unavailable process samples or sleeping GPUs remain unavailable. There
is no NVIDIA CLI polling. For DRM drivers exposing per-client engine counters,
two samples produce a per-process percentage using the existing engine formula.
Duplicated file descriptors are deduplicated; shared DRM clients may be attributed
to multiple processes. Each GPU column shows its maximum engine class. The
compact aggregate uses the maximum GPU, not a sum across adapters. Both GPU
percentages can therefore be visible for a process using both cards. Unavailable
per-card values remain dashes even if the other GPU has a measurement.

GPU collection now runs while the process table is visible even without a GPU
summary tile. Existing closed-panel collection is unchanged. No measured battery
or physical-driver compatibility claim follows from this implementation.

## Keep the panel open on a monitor

Use the pin button in the header to keep Loadlet visible while using other
windows or monitors. The highlighted pin indicates this temporary mode. Only
the card receives pointer input; there are no dismissal overlays on other
screens and no exclusive keyboard grab. The panel remains on the monitor whose
bar icon opened it. Expand and Collapse still control its size independently.

Pinning and unpinning preserve the current page, process selection, search,
scroll position and profile draft. Sampling continues through the same reader.
Use the cross or bar icon to close explicitly; Escape keeps its existing nested
back/collapse/close behavior. Closing clears the pin, so the next opening uses
the normal popup. Unpin to restore outside-click dismissal. Pin state is not
saved in settings.

## Sampling and limits

The default Efficient profile samples resources every 3 seconds, processes every
6 seconds and temperature every 15 seconds. GPU attribution is requested while the process table is visible, including
compact view (4 seconds in Efficient mode). Volume details are requested in
expanded view or for a selected storage tile (60 seconds in Efficient mode).
Scheduling rounds to the resource timer. One request is in flight at a time. History is bounded to
20–240 points. A failed request times out after 5 seconds; restarts back off from
2 to 30 seconds. Shutdown allows 1 second before killing the owned reader.

The first process snapshot displays the rows, memory and process identity
immediately. Process CPU percentages become available on the next sample.

Frames are bounded to 256 KiB before emission. Over-capacity input is rejected,
not shown as a partial process inventory. The reader also bounds directory
enumeration and input records. The panel clears unavailable data and retries.

NVIDIA queries require `runtime_status=active`; each sample uses normal NVML
initialization and shuts down that session afterward. The driver library stays
mapped until reader destruction: unloading/reloading it per sample accumulated
eventfds on the observed driver. This retains about20MiB of additional resident
driver memory in the short local probe, mostly anonymous memory, not a measured
continuing allocation per sample. NO_ATTACH
is not used because it can make an active GPU unavailable to PCI-bus handle lookup. Unknown power state skips NVIDIA
telemetry. AMD/Intel devices reported as suspended are not queried for dynamic
sysfs readings. These gates
are not a guarantee about driver races or measured battery savings.

There is no public cross-plugin lock-state API in the installed host facade.
Background icon collection is not independently lock-gated. Disable icon
indication to stop closed-panel collection. An open panel behind a lock is not
separately gated. Suspend/clock gaps invalidate counter baselines on resume.

## Build and install

For a fresh user installation, use the [README install command](../README.md#install).
The native `omarchy plugin add ... --enable` flow clones the ready-to-run package,
validates it and enables the stable ID. No compiler, make, first-run network fetch
or manual build is required. Runtime support is Linux x86_64 with Omarchy Quattro
and Python 3. The distributed sampler requires glibc 2.34 and libstdc++ with
GLIBCXX_3.4.32 or newer, supplied by the current supported Arch-based host.
Other architectures are not provided as prebuilt packages.
[Binary provenance](binary-provenance.md) records exact source and executable hashes.

For an existing Git-managed install, run `omarchy plugin update slovn.activity-lite`.
The native updater fast-forwards the package, including its ready-to-run sampler;
local changes are refused rather than overwritten. It does not delete reports.
For an older manually copied installation, use the reviewed copy-update procedure
below instead of installing over it. Marketplace install availability is a separate
maintainer-owned setting; the source README remains usable while review is pending.

The separate source-checkout workflow below is optional development/verification.
Only that workflow requires the system C++17 compiler, make, Python 3 and the shell.
Tests also use Node.js and the installed Qt Quick Test runner. NVIDIA metrics
optionally use the driver's `libnvidia-ml.so.1`; there is no `nvidia-smi` polling.
The process view is built in; no external Task Manager is required.

Like other Omarchy shell plugins, this code runs unsandboxed with your user
permissions inside the shared shell. It reads procfs/sysfs and mount statistics;
the process helper signals validated same-user processes without privileges.
Another owner's process requires the
[optional system helper](#authenticate-process-actions) and one-shot Polkit
authentication. Monitoring requires no root privileges, extra daemon, runtime
network access or remote build.
The packaged executable was rebuilt byte-identically from this fork's current
source, rather than accepted merely because upstream shipped it. To rebuild it
for development, run:

```sh
git clone https://github.com/PavelLizunov/omarchy-loadlet.git
cd omarchy-loadlet
make -B activity-sampler
omarchy plugin validate .
make install-local
omarchy-shell shell rescanPlugins
omarchy plugin enable slovn.activity-lite left
```

`install-local` refuses to overwrite an existing installation. Build/source remain
in this repository; the installed plugin contains only runtime files and licensing.
The public repository contains the source snapshot and reproducible media.
There are no automatic upstream updates. The stable plugin ID slovn.activity-lite
and local journal/export paths are retained to preserve existing user data.

For an existing manually copied installation, copy the checked runtime files
only after the checks pass; a rebuild is optional on supported x86_64 hosts. Saving installed plugin files reloads code; if necessary use
`omarchy-shell shell rescanPlugins`. Restarting the entire desktop shell is a
fallback, not a requirement for changing settings.

During a warm-cache update the installed manifest may point to
a versioned runtime directory containing Panel.qml. That task-owned directory
contains the same checked
runtime files and helpers, not a link to the source checkout. Fresh URLs load the
candidate without restarting the shared shell; root runtime files are retained.
Check the installed `entryPoints.barWidget`, rather than assuming the root file
is the active consumer. Settings and diagnostic data remain outside this tree.

If the widget fails to load, check that `ActivityIconSvg.js`, `HeatPolicy.js`,
`LoadletLocale.qml`, `i18n/*.json`, `Model.js`, all QML files and the executable
`activity-sampler`/`process-signal`/`activity-report`/`diagnostic-report` were installed together. Read the
shell log for QML errors. The status endpoint below reports reader errors without
starting another collection cycle.

```sh
omarchy plugin disable slovn.activity-lite
omarchy plugin remove slovn.activity-lite
```

## Verification

Run `make check`. The process tests create and signal only their own child
processes. `test/ui-checks.py` loads the current QML with installed host widgets,
inert process/IPC/file adapters, and the host's screen-fitting formulas; it never
opens a desktop window or changes shell state. It checks selection identity,
constrained geometry, font scaling, keyboard transitions, and localization.
This stand-in window does not verify Wayland focus, monitor hotplug or compositor
HiDPI rendering. `test/tst_lifecycle.qml` is a separate native-controller test;
it is not executed by the inert UI harness.
The inherited upstream tests are retained as historical
coverage; tests asserting removed power/automatic-kill behaviour do not apply to
this fork and are not its acceptance gate.

Read-only live status:

```sh
omarchy-shell slovn.activity-lite.status status
```

The status endpoint reports open/sampling state, sample timestamp and process count;
it never initiates additional sampling. GPU hardware behaviour, full accessibility,
theme contrast and physical energy consumption need separate runtime measurements.

MIT; original license and attribution retained.
