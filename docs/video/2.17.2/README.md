# Loadlet 2.17.2 walkthrough

[Watch or download the MP4](loadlet-2.17.2.mp4) · [Twitter/X draft](twitter.txt)

A silent 24-second, 1600×900, 30 fps walkthrough of the current native interface.
Six four-second scenes show the computer diagram, sensor history, profile
selection, profile editing, expanded processes and the repository address.
The panels are actual QML consumer renders with inert I/O and demonstration data.
Cuts are editorial; this is not live telemetry, a desktop recording or proof of
click-through behavior. Full expanded rows are desktop detail, not a claim
that every value is readable on a small phone.

Source commit: `eb085206ed732cd50b20db40f5bdb20c34f7f5b4`.
[Asset provenance](assets/manifest.json) pins source, fixture and host-adapter
hashes. [Composition receipt](composition.json) records the timeline and output.
All five native stills and all six encoded scene covers were inspected inline.
Qt 6.12.0 / renderer 0.3.0 / software; AT-SPI bridge warnings use report policy.
No independent review, interaction campaign or separate full-decode check.

The earlier Motion Studio capture tool was not found in the installed skill
locations. This film uses existing FFmpeg instead; no new browser, service or
package was installed. Rebuild into a new external directory:

```sh
python3 docs/video/2.17.2/render.py /absolute/new/output-directory
```

The script uses Python standard library, FFmpeg with libx264/drawtext, and
JetBrains Mono Nerd Font (override with `--font`). It reads these already rendered
assets, writes bounded four-second clips and concatenates them with fast-start
MP4 metadata. It does not execute plugin helpers or change desktop settings.

Copy review: concrete implemented features, no fabricated performance/noise
claims, no invented testimonials. Native styling takes precedence over generic
web anti-slop rules. The post is a draft; it was not published to Twitter/X.
