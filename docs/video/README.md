# Loadlet video

[Master MP4](loadlet.mp4) · [Messenger MP4](loadlet-web.mp4)

A newly rendered silent16-second1280x720/30fps walkthrough of Loadlet2.8.1.
Every product surface is the actual native QML consumer rendered offscreen with
inert demonstration data. The selected symmetric Split die and new Loadlet headers
are current. Cuts and camera moves are presentation, not native transitions or a
live desktop recording. The complete640x360/15fps animatedWebP plays in the root
README; both MP4 versions are downloadable.

## Direction

Film in one line: a small Loadlet character shows approximate CPU/RAM, then opens
into exact readings, sampled processes and preferences.

Read from: the user selected Loadlet and requested a new public repository plus
new screenshots/video. The existing native Omarchy UI, accepted wider symmetric
icon and current source own the look. Refresh the film, not only its title card.

Concept: a precise camera over current native surfaces, with Loadlet named on the
first and final shots. The independent eyes are the signature. Rejected: a
terminal-only film would hide the interface; an invented animated dashboard would
misrepresent the native product. The former film stays in private source history,
not in this clean public snapshot.

Look: native Nord background#2e3440,foreground#d8dee9,accent#81a1c1 and existing
monospace typography. Terminal-release/data-story vocabulary is adapted to a
README walkthrough, without glow, generic HUD, fake cursor events or new theme.

Energy: precise/mid for the icon, readings, processes and preferences; low for the
attribution hold. Small landing motion begins on frame1. Sound: deliberately
silent for documentation and muted viewing. No narration, music, synthesis,
service request or artificial audio stream.

| Seconds | Actual source surface | Presentation |
| --- | --- | --- |
| 0–3.5 | Current icon, demoCPU85/RAM55 | Loadlet name and independent eye meaning |
| 3.5–7 | Compact panel, demoCPU24/RAM44 | Exact readings remain visible |
| 7–10.5 | Expanded native panel | GPU/storage and full sampled process list |
| 10.5–13 | Native preferences | Threshold50, no rescaling |
| 13–16 | Current icon and attribution | Public name/repository and retained MIT credit |

Sample values are illustrative, not measurements of a machine or a continuous
telemetry sequence. All process owners are the generic demo account. Phone-size
review covers captions/hero/composition; tiny full process rows are desktop detail,
not certified readable on a narrow phone.

## Rebuild

Use the already-installed Motion Studio capture tool. Copy this directory to an
external scratch project; caches, profiles and pristine intermediate files do
not belong in Git. `render.py` owns bounded process groups and stage deadlines.
It emits master/messenger MP4s, covers, deterministic replay and full decode logs.

```sh
python3 render.py /absolute/path/to/motion-graphics/skill/assets/template/tools/capture.mjs /absolute/new-output-directory
ffmpeg -v error -i loadlet.mp4 -vf 'fps=15,scale=640:360:flags=lanczos' -an -c:v libwebp_anim -quality 90 -compression_level 4 -loop 0 -map_metadata -1 /absolute/new-output.webp
```

[index.html](index.html) owns copy/composition; [timeline](js/timeline.mjs) owns
pure-time scene selection. Native source/asset identities are in
[assets manifest](assets/manifest.json); encoding/timing/quality receipts are in
[qa.json](qa.json). Original native pixels are cropped only outside the panel.
No desktop capture, external image viewer or independent review happened.
