# Loadlet

A small native Omarchy system monitor with a load-indicating character. CPU,
memory, temperature and sampled processes are one click away.

[Install](#install) · [Build from source](docs/guide.md#build-and-install) · [Controls and limits](docs/guide.md)

## Install

Requires Omarchy Quattro on Linux x86_64, Git and Python 3, normally supplied
by Omarchy. No compiler, make, extra package or manual build is needed.

```sh
omarchy plugin add https://github.com/PavelLizunov/omarchy-loadlet.git --enable
```

Review the source, accept Omarchy's add prompt and choose the bar position.
The ready-to-run sampler is included; its source and build provenance are
[documented](docs/binary-provenance.md). The plugin runs with your user permissions
inside the shared shell. No root access, second shell, first-run download or
background compilation is used. An existing installation is not overwritten.

Update an installation added this way with `omarchy plugin update slovn.activity-lite`.
See [the guide](docs/guide.md#build-and-install) for updates and optional source builds.
The Marketplace's current **Manual setup** flag is a separate listing setting;
removing it requires a maintainer to review the packaged-binary evidence. Until
that change appears, use the command above from the source link.

![Loadlet compact native metrics panel with demonstration data](docs/images/compact.png)

Historical 2.14.0 native QML screenshots use inert demonstration data, not desktop
captures. The optional line-art computer map opens component sensors; manual
assignments remain explicit. Page changes never resize the chosen frame; use the
Expand button or `e` when needed. Fan location and identification are separate
optional editors. Version2.14.1 added a direct header Close button. Version2.14.2
keeps Category open after a choice, with the sensor and choice retained. Fan
location choices still close their separate editor. Version2.14.3 adds a bottom
fan point and manual assignment option. The retained screenshots predate these
controls and diagram changes. Version2.14.4 adds saved exact-percentage fan
profiles and applies manual sensor categories to their displayed names, preserving
the sensor selector binding. [Vector design references](docs/vector-design.md).

## One icon, exact readings

The left eye shows CPU and the right eye shows RAM. Six bottom-up rows indicate
approximate load. The fill threshold defaults to50%: below it tracks stay empty;
at or above it the original percentage scale is preserved. Exact readings and
freshness remain in the tooltip and panel. Fresh temperature can add flames and
brief optional motion without changing sampling cadence.

Left-click toggles the panel. Right-click has no action. Expand inside the panel
for GPU, storage, search and the full sampled process list. No separate Task
Manager application is launched or required. Each GPU has its own wrapping card.
The compact process table shows a sortable GPU % maximum. Expanded view shows
a separate sortable percentage column for each GPU, labeled with a short model
name such as RTX5060Ti or Radeon610M. Hover
the heading for its full name and PCI identity. Readings use NVIDIA per-process
utilization or supported DRM engine counters. A dash means unavailable data,
not zero usage.

The **Cooling** tab shows available hwmon temperatures and fan readings plus
NVIDIA temperature/fan telemetry through the existing NVML provider. It reuses
the native sampler and timestamp-based chart component, without a new service or dependency.
Choose a device and a 10-minute, 1-hour or 6-hour graph window. Live-only sampling
updates about every 3 seconds. Enable **Record temperatures in the background**
to keep collecting every 15 seconds during games with the panel closed. History
is local, bounded to 7 days / 20 MiB, and can be viewed after reopening the panel.
Missing driver sensors are
reported explicitly; NVIDIA percentages are not mislabeled as physical RPM.
Device categories/models and reading meanings replace driver-only sensor headings.
Settings offers two compact tiles by default, or three in one row, including
CPU temperature and individual GPUs. Three-tile mode omits the tiny core grid
to preserve readable values; the expanded CPU tile retains it. If RAM is not
one of the main tiles, a narrow RAM strip shows its percentage, used/total
capacity and fill below them. The strip can be disabled in Settings.

Cooling charts show labeled value scales and the entire selected time window.
Hover to inspect, click to pin a sample, drag or use the arrow/Home/End keys to
move it. **Live** or Escape clears the selection. Gaps remain empty; reduced
history resolution alone is not labeled as a recording gap. The default compact
Cooling and Fans pages fit their normal controls without extra scrolling.
Scrolling editors retain symmetric content margins and reveal keyboard focus.
Fan RPM history includes an explicit return to the same channel's controls. The Fans tab exposes timed boosts only
for the model-gated motherboard controller described in the guide; its
privileged adapter is a separate explicit system installation, not plugin code
executed as root. The normal monitor installation does not require it.

![Loadlet expanded native panel with GPU, storage and processes](docs/images/expanded.png)

![Loadlet Cooling with an interactive sensor chart](docs/images/cooling.png)

![Loadlet Fans with model-gated timed controls](docs/images/fans.png)

![Loadlet optional computer cutaway with numbered sensor hotspots](docs/images/computer-map.png)

Fans includes a separate 5-second identification trial from 0 to 100% duty, with
restoration afterward. Choose0% then **Stop for5s** to request a brief stop;
choosing the percentage alone does not apply it. Percent is controller output,
not a target RPM. Enter an exact integer output from0to100% and use **Save %** for a persistent
profile, reapplied after reboot. At80C or without CPU telemetry, it requests full
output. **Restore previous control** removes that profile. Timed boosts and
identification trials remain separate temporary actions. Exact RPM is not a
setpoint; manually assigned location labels are saved. A 0% request may not physically stop every fan. Hot or
missing CPU readings reject or cancel the trial. Ordinary timed boosts still
never reduce the previous duty. Only one identification trial runs at a time.

Named profiles now combine motherboard fan output, optional NVIDIA fan output,
CPU turbo boost, governor/energy preference and a maximum CPU frequency. Fans
provides quick icon buttons for Current settings, Quiet idle and Games; its
profile editor can save, duplicate and remove presets. Saving is separate from
applying. Automatic Steam/Proton detection can activate Games and restore the
previous configuration after exit, including with the panel closed. Quiet idle
disables boost and requests powersave/power; no acoustic or
energy reduction is guaranteed. The optional root-owned `power-profile` adapter
must be installed alongside `fan-control`. See the guide for actual supported
controls, persistence and restoration.

Process actions use sampled PID/start time and ownership guards. Force kill needs
separate confirmation. There is no automatic escalation or privileged helper.
Diagnostic history is local, opt-in and off by default; exports prepare evidence
without running an AI or changing system settings.

![Loadlet icon and sampling preferences](docs/images/settings.png)

<p align="center">
  <img src="docs/video/loadlet.webp" width="640" alt="Historical 2.8.1 Loadlet tour: icon, metrics, processes and preferences"/>
</p>

Historical 2.8.1 walkthrough: this silent 16-second film predates Cooling, Fans
and configurable tiles. The current interface is shown in the screenshots above.
The complete archived film plays here. Cuts/camera moves are presentation, not
native transitions or a live recording.

[Master MP4](docs/video/loadlet.mp4) · [Messenger MP4](docs/video/loadlet-web.mp4) ·
[Video source and QA](docs/video/README.md)

## Optional source build

This developer workflow is not required for normal installation.
Requires Linux with the Omarchy shell, make, a system C++17 compiler and Python3.
Tests also use Node.js and Qt Quick Test. NVIDIA metrics optionally use the
installed driver's NVML; no telemetry daemon or runtime network is required.

```sh
git clone https://github.com/PavelLizunov/omarchy-loadlet.git
cd omarchy-loadlet
make -B activity-sampler
make check
make install-local
omarchy-shell shell rescanPlugins
omarchy plugin enable slovn.activity-lite left
```

The stable plugin ID `slovn.activity-lite` preserves compatibility with existing
settings/reports. The installer refuses to overwrite an existing copy. Follow
[the guide](docs/guide.md#build-and-install) for reviewed updates and troubleshooting.
Remove the widget without deleting diagnostic reports:

```sh
omarchy plugin disable slovn.activity-lite
omarchy plugin remove slovn.activity-lite
```

## Development and provenance

[Guide](docs/guide.md) · [Verification](VERIFICATION.md) ·
[Visual provenance](docs/images/README.md) · [MIT attribution](ATTRIBUTIONS.md)

Maintained at [PavelLizunov/omarchy-loadlet](https://github.com/PavelLizunov/omarchy-loadlet).
Derived from Kristoffer Haugland's Activity Monitor; the original MIT license,
attribution and pinned upstream bytes are retained. This repository starts with a reviewed
public snapshot, without importing private diagnostic development history.
Loadlet is listed in Marketplace. The revised no-build installation path and
package evidence need separate maintainer review before its Manual setup flag changes.

Russian is the default interface language; English, German and Simplified Chinese
are supported. The Loadlet name is unchanged across locales.

The plugin runs with your user permissions inside the shared Omarchy shell.
Offscreen/native tests do not certify every theme, physical pointer/focus,
screen-reader support, hardware telemetry or battery cost.
