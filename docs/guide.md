# Loadlet guide

[Overview](../README.md). Details below describe the current native plugin.

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
With diagnostic history disabled, no process inventory, topology, GPU or disk
requests run in this mode. Open-panel samples feed the icon without a second
reader. Disabling both background icon indicators and diagnostic history stops
closed-panel collection, while open-panel sampling continues normally.

CPU requires two counter samples; the initial baseline is unavailable, not 0%.
CPU is an average between samples, so short peaks are smoothed. Unavailable values
leave unfilled tracks and are identified in the tooltip. Freshness/counter-gap
limits are 35 seconds. Exact CPU, used/total RAM and fresh temperature are in the
tooltip. These tiny gauges show approximate levels; background polling is not
zero-overhead, timer cadence can slip during shell stalls, and battery impact
has not been measured.

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

The plugin prepares evidence and a recommendation prompt; it does not run an AI,
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
- No automatic escalation or promotion to a same-name parent process.
- Selection follows PID and sampled start time across updates. When that identity
  disappears from the visible list, action buttons disable until another selection.
- Escape cancels confirmation first, then collapses details/closes the panel.
- In Settings, Escape closes an open dropdown first, then returns to the metrics.
- The language picker blocks process actions. `?` shows or hides keyboard hints.
- Error messages distinguish unavailable data from an idle machine.

The interface uses `I18n.js` catalogs for Russian, English, German and Simplified
Chinese. Russian is the default; `system` follows the Qt locale. PID, CPU, VRAM,
and byte units remain technical identifiers. Helper failures use localized UI
messages rather than displaying untranslated stderr.

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
Scrolling pages keep both content edges aligned with their tabs; the scroll thumb
uses the outer padding, not an asymmetric content gutter. Keyboard focus scrolls
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

Cooling and Fans provide an optional SVG case cutaway with numbered hotspots
and a separate legend. It is collapsed by default so data remains visible.
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

The Fans tab supports the DRFXI board with the actual IT8613E hwmon driver.
Generic channel numbers pwm2-pwm5 are retained until their physical CPU/case/SSD
connectors have been identified. A nonzero RPM does not establish that identity.
The driver also exposes temp1-temp3; these are motherboard-controller inputs,
not guessed CPU/VRM/chipset temperatures. Other controllers remain unsupported
by this adapter instead of being operated through fabricated register mappings.

The system adapter is the root-owned /usr/local/lib/loadlet/fan-control. Install
it separately after reviewing the source and a driver that genuinely supports
IT8613E; the normal plugin installer does not deploy privileged executables:

~~~sh
sudo install -Dm755 fan-control /usr/local/lib/loadlet/fan-control
~~~

The UI invokes this fixed root-owned helper as an ordinary user. It first uses
noninteractive sudo, honoring Omarchy's existing day grant. If authentication is
needed, one Polkit pkexec unlock grants the authenticated caller 24 hours of
passwordless fan requests only. The helper validates and atomically installs
/etc/sudoers.d/60-loadlet-fans-UID with an absolute NOTAFTER deadline and exact
save/boost/restore/identification argument patterns; no general sudo or pkexec permission is added.
Remove that file as root to revoke early. Expired files grant nothing; a new
unlock replaces the deadline. Passwords never enter plugin code. Requests allow
only the four exposed channels. Saved profiles accept any integer from0to100%;
separate boosts use60/80/100% and a5/10/30-minute hold.
A separate identification trial accepts 0/5/10/20/30/40/50/60/80/100% for exactly
5 seconds, then restores the saved state. Unlike a boost, this intentionally
allows a lower duty, including zero. One identification worker holds an exclusive
lock; CPU temperature at/above 80 C or missing CPU telemetry rejects/cancels the
trial. It uses a 10-second systemd watchdog and the same recovery hook. These
are application limits, not a hardware cooling guarantee. Some fans do not stop
at 0% PWM; observe the physical fan rather than inferring identity from RPM alone.
No actual fan-stop trial was executed during development.

To request zero duty, select the intended channel, open the five-second fan
trial, choose0% and press Stop for5s. The button requests a stop for exactly five
seconds, then restores the saved duty and mode; the physical fan may continue
spinning if its controller does not support stopping. Selecting a percentage
alone does not apply it. Closing the trial editor or the entire Loadlet panel
does not cancel an already-started service timer. Restore ends the override early.

Enter an exact integer percentage in Fans and press **Save %** or Enter. This
is controller duty, not an exact-RPM setpoint. Unlike boosts, a saved output can
reduce the current duty. Zero requests zero duty, not a guaranteed physical stop.
At80C or without CPU temperature, the existing fallback requests100%; the saved
output resumes when readings recover below80C. This is not a cooling guarantee.

Profiles are root-owned JSON under /var/lib/loadlet-fans. The adapter installs
and enables loadlet-fan-profile@pwmN.service, one instance per saved channel,
so output is restored after reboot without the desktop shell. Missing drivers
cause a five-second retry. Ordinary stop restores the captured prior duty/mode;
ExecStopPost attempts recovery after a worker failure. **Restore previous control**
deletes the saved profile and disables its service. The optional adapter remains
a separate system installation; updating QML alone cannot add these operations.

Timed boosts retain their prior-duty floor. Trials and boosts temporarily pause
a saved profile, then resume it when the timer ends. They do not replace the
saved output or get replayed after reboot. Assigned locations persist in shell.json.
Reboot persistence is implemented by the enabled service; actual post-reboot and
physical fan behavior still require user observation.

Settings is split into Tiles, Icon, Sampling and History. The normal preferred
frame fits each category without scrolling; constrained screens retain scrolling.
Sensor assignment is under Category; choosing a category keeps the editor open
and follows that category filter instead of silently switching to all sensors.
The Category button itself hides it when finished. Manual categories update the
device heading and selector label as well as the diagram filter. Raw driver
identity remains visible in Category. Wi-Fi driver instance suffixes are excluded
from saved assignment keys; existing matching keys are retained as a fallback.

A channel boost snapshots its original duty/mode,
starts one owned transient system service, and restores the snapshot on expiry,
stop, or worker exit. Root-only state lives in /run/loadlet-fans. ExecStopPost
attempts restoration if the worker is killed. The override can outlive the UI
so closing the panel does not cancel a timed cooldown. Automatic game detection
is separate from these timed boosts; channel-to-connector assignment stays manual.

IT8613 rejects duty writes in automatic mode. Takeover goes through full speed
before setting manual duty, without a fan-stop calibration. Requests never
reduce an already-higher sampled duty. While held, missing CPU temperatures or
any observed CPU reading at/above 80 C requests full duty. This is an application
fallback, not a hardware-critical limit, thermal guarantee, or replacement for
firmware protection. No voltage, PWM polarity or hardware temperature offsets
are changed. The Restore button restores the actual prior mode, including a
prior manual setting; it does not invent a firmware default.

One driver-level check on DRFXI found IT8613E revision12 at0xa30. The in-tree
it87 module did not bind. The separately packaged frankcrawford/it87 revision
bd7a566c8a60fe0308d67e26761e16260368191a bound without force_id, resource-conflict
bypass or a global ACPI override. It exposed three temperature inputs and four
fan/PWM channels. A bounded pwm2 full-duty request changed reported RPM from
about695 to1534, then duty40/mode2 were restored. Physical connector identity,
acoustic/airflow change and automatic timed restoration remain unverified.
This observation is not generic board compatibility or a driver safety audit.

## Named CPU and cooling profiles

Fans provides Current settings, Quiet idle and Games with distinct icons. Click
one to apply it; the settings icon opens its editor. Profiles can be named,
duplicated, saved and deleted (up to12). An active profile cannot be deleted.
Saving edits does not apply them. Changing a single fan output clears the active
profile highlight, since it no longer represents the saved named configuration.

Each preset stores exact motherboard percentages, optional NVIDIA percentages,
CPU boost, powersave/performance mode with its corresponding energy preference,
and a maximum CPU frequency in MHz. Zero frequency means the original limit,
not zero processor speed. The driver validates every frequency and preference;
unsupported choices fail rather than silently succeeding. Quiet idle uses boost
off and powersave/power. Games permits boost and performance. Default fan values
come from the current saved outputs, never invented quiet or gaming speeds.

Automatic game profiles use SteamAppId/SteamGameId and an actual game executable,
not GPU load or merely an open Steam launcher. A root-owned systemd worker checks
every5seconds, keeps Games active through a15-second exit grace period, then
restores the selected non-game preset (Quiet idle when Games is selected).
Manual profile selection or an individual fan action disables automation.
The toggle enables/disables it with authentication;
non-Steam games without Steam launch metadata are not detected. Editing Games
requires disabling and enabling automation to capture the updated preset.
An unavailable or stale automation status is reported rather than highlighted
as a successfully applied profile. The
worker remains active with the panel closed and after reboot. Per-game CPU/fan
settings are not inferred from load. No game-playthrough or reboot check is
implied by installation.

The optional root-owned helper is installed separately:

```sh
sudo install -Dm755 power-profile /usr/local/lib/loadlet/power-profile
sudo install -Dm644 GameDetection.py /usr/local/lib/loadlet/GameDetection.py
```

The existing authenticated fan unlock grants exact validated profile apply and
restore requests for24hours. The helper snapshots CPU values, serializes applies,
checks service readiness, and restores prior CPU/fan settings if an application
step fails. The active profile is root-owned under /var/lib/loadlet-power;
loadlet-power-profile.service replays its CPU policy after boot. Motherboard
fan instances retain their existing boot persistence. Original control restores
the captured CPU settings, removes the named active configuration and returns
GPU fans to automatic control. A successful systemd enable is not an observed
successful physical reboot.

NVIDIA support uses the driver's NVML interface, not X11/Coolbits. On the observed
RTX5060Ti one fan is exposed, with a reported manual range30–100%. A bounded30%
request and readback succeeded, then automatic policy was restored. Below-minimum
requests fail. A missing GPU percentage means automatic control; no fake manual
control is provided for the integrated Radeon610M. Manual NVIDIA mode runs an
owned per-device service, requests100% at80C/missing GPU temperature and restores
automatic control on exit or recovery. Physical RPM and acoustic effects remain
unmeasured.

No digital PSU controller was found in the observed USB/hwmon inventory. The
physical PSU model and control/data connection are not established. Its internal
fan is not equated with an IT8613 channel. No register guessing, firmware flashing
or physical connector reassignment was performed. Those limits do not block the
CPU, motherboard and observed NVIDIA controls.

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

The optional services are `loadlet-power-profile.service`,
`loadlet-auto-game.service`, `loadlet-fan-profile@pwmN.service` and
`loadlet-gpu-fan@PCI-ID.service`. Timed fan trials use `loadlet-fan-pwmN.service`.
They are system services and can outlive the desktop shell. Authentication grants
only validated operations on root-owned helpers for24hours; already-enabled
services continue when that grant expires. Revoke a grant by removing only the
matching `/etc/sudoers.d/60-loadlet-fans-UID` file as root.

To remove optional controls, first disable automatic profiles and use Original
control in the profile editor. Restore each separately saved motherboard channel
as well. The equivalent commands for channels you actually configured are:

```sh
/usr/local/lib/loadlet/power-profile request restore
/usr/local/lib/loadlet/fan-control request restore pwm2
# Repeat for your other configured channels: pwm3, pwm4 or pwm5.
```

Only after restoration succeeds, remove the installed helper files and disabled
Loadlet unit definitions as root, remove your matching sudoers grant, and run
`sudo systemctl daemon-reload`. Do not delete recovery state or helper executables
while their workers are still active. Original-control restoration restores the
captured CPU snapshot and GPU automatic control; it is not a firmware reset.

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

## Sampling and limits

The default Efficient profile samples resources every 3 seconds, processes every
6 seconds and temperature every 15 seconds. GPU and volume details are only
requested in expanded view (4 and 60 seconds respectively; scheduling rounds to
the resource timer). One request is in flight at a time. History is bounded to
20–240 points. A failed request times out after 5 seconds; restarts back off from
2 to 30 seconds. Shutdown allows 1 second before killing the owned reader.

Frames are bounded to 256 KiB before emission. Over-capacity input is rejected,
not shown as a partial process inventory. The reader also bounds directory
enumeration and input records. The panel clears unavailable data and retries.

NVIDIA queries require `runtime_status=active`; NVML uses normal initialization
and is released after a sample. NO_ATTACH is not used because it can make an
active GPU unavailable to PCI-bus handle lookup. Unknown power state skips NVIDIA
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
the process helper signals only validated same-user processes. No root privileges,
extra daemon, runtime network access or remote build is required.
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
`I18n.js`, `Model.js`, all QML files and the executable
`activity-sampler`/`process-signal`/`activity-report` were installed together. Read the
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
