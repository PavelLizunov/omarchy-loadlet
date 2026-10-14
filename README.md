# Loadlet

A small native Omarchy system monitor with a load-indicating character. CPU,
memory, temperature and sampled processes are one click away.

[Install and build](docs/guide.md#build-and-install) · [Controls and limits](docs/guide.md)

![Loadlet compact native metrics panel with demonstration data](docs/images/compact.png)

Actual native QML, rendered offscreen with inert demonstration data. These images
are not desktop captures or measurements of a machine.

## One icon, exact readings

The left eye shows CPU and the right eye shows RAM. Six bottom-up rows indicate
approximate load. The fill threshold defaults to50%: below it tracks stay empty;
at or above it the original percentage scale is preserved. Exact readings and
freshness remain in the tooltip and panel. Fresh temperature can add flames and
brief optional motion without changing sampling cadence.

Left-click toggles the panel. Right-click has no action. Expand inside the panel
for GPU, storage, search and the full sampled process list. No separate Task
Manager application is launched or required.

![Loadlet expanded native panel with GPU, storage and processes](docs/images/expanded.png)

Process actions use sampled PID/start time and ownership guards. Force kill needs
separate confirmation. There is no automatic escalation or privileged helper.
Diagnostic history is local, opt-in and off by default; exports prepare evidence
without running an AI or changing system settings.

![Loadlet icon and sampling preferences](docs/images/settings.png)

<p align="center">
  <img src="docs/video/loadlet.webp" width="640" alt="Complete16-second Loadlet tour: current icon, metrics, processes and preferences"/>
</p>

A newly rendered silent16-second walkthrough of the current Loadlet interface.
The complete animated film plays here. Cuts/camera moves are presentation, not
native transitions or a live recording.

[Master MP4](docs/video/loadlet.mp4) · [Messenger MP4](docs/video/loadlet-web.mp4) ·
[Video source and QA](docs/video/README.md)

## Build and install

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
Marketplace listing and maintainer approval are separate, not claimed here.

Russian is the default interface language; English, German and Simplified Chinese
are supported. The Loadlet name is unchanged across locales.

The plugin runs with your user permissions inside the shared Omarchy shell.
Offscreen/native tests do not certify every theme, physical pointer/focus,
screen-reader support, hardware telemetry or battery cost.
