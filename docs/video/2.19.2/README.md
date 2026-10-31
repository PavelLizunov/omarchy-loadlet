# Loadlet 2.19.2 walkthrough

[Play/download MP4](loadlet-2.19.2.mp4) · [Poster](poster.png) · [Evidence](evidence.json)

30 seconds, 1920×1080, 30 fps, 900 frames, H.264/yuv420p. Deliberately silent.
Five six-second chapters show Overview, Cooling, Profiles, Memory and Languages.
Native QML images use inert demonstration data. The movie is not a desktop
recording, real-time interaction, benchmark, leak verdict or cooling guarantee.
Transitions belong to the film, not to the plugin. The persistent footer says so.
Small graph/process text is desktop detail, not a mobile-readability guarantee.

## Pipeline and licenses

Built with the owner's [fframes-video-pipelines](https://github.com/PavelLizunov/fframes-video-pipelines)
workflow at `06bf109a6fabf410c6573bb4a3a19bb2a83d2d69`, using fframes 1.3.0.
This is programmatic Rust/SVG animation, not a neural video generator.
The composition is in `src/main.rs`; dependency versions are pinned in Cargo.lock.
No network service or generative model produced these frames.

Loadlet and the composition use the repository MIT license. DM Sans is bundled
unchanged under [SIL OFL 1.1](licenses/DM-Sans-OFL.txt), copyright the DM Sans
Project Authors. Native UI keeps Loadlet's existing attributions. The copied
pipeline license is retained in `licenses/pipeline-MIT.txt`.
The build enables fframes' GPL-compatible H.264/FFmpeg feature. Renderer binaries,
FFmpeg, build caches and system tools are not distributed here. Their software
licenses are separate from the rendered movie. No third-party music is included.

## Reproduce

From this directory, with Rust/Cargo, a C toolchain, make, pkg-config, CMake and
NASM available, place build output outside the repository:

```sh
export CARGO_TARGET_DIR=/tmp/loadlet-film-target
CARGO_BUILD_JOBS=4 FFMPEG_FORCE_BUILD=1 cargo build --release --locked
"$CARGO_TARGET_DIR/release/loadlet-film" inspect --all-frames --fail-on warning --json
"$CARGO_TARGET_DIR/release/loadlet-film" render -o /tmp/loadlet-2.19.2-master.mp4
ffmpeg -i /tmp/loadlet-2.19.2-master.mp4 -map 0:v:0 -c copy -an -map_metadata -1 -movflags +faststart /tmp/loadlet-2.19.2.mp4
ffmpeg -v error -i /tmp/loadlet-2.19.2.mp4 -f null -
```

Only film development needs these tools; plugin installation does not.
The release machine lacked system NASM. A package was extracted into task-local
scratch for this build; no successful system package installation occurred.

The native stills were prepared with `test/ui-checks.py`'s `prepare()` and
`test/render-release-2192.qml`, using installed host widgets and inert
process/file/IPC/window adapters. Original source hashes and transformed fixture
hashes are recorded separately in evidence.json. The QML renderer was 0.3.0,
Qt 6.12.0, software/offscreen, DPR 2 for the five film images. It did not access
the desktop. Images were read inline and inspected before rendering the film.
AT-SPI/atk-bridge warnings and language-font information occurred; warning policy
was `report`, not a claim of zero-warning or full accessibility acceptance.

All 900 SVG frames passed fframes inspection. Final MP4 dimensions, duration,
frame count, pixel format, absence of audio, fast-start layout and full decoding
were checked. The five mid-chapter decoded frames were inspected. This does not
claim continuous human playback or live production-window acceptance.
