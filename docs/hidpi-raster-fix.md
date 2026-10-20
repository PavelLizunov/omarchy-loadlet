# HiDPI bar raster feedback — 2026-10-20

## Mechanism

The native Omarchy 4.5.0rc1 BarIconContent preserves Image dimensions rather
than imposing the source canvas. ActivityIcon inherited its logical width from
the decoded SVG implicitWidth, while sourceSize was width times screen DPR.
At DPR2, changing CPU/RAM regenerated an SVG with doubled dimensions. Repeated
updates grew the logical image to4096x4096 and sourceSize to8192x8192; the SVG
serializer's4096 cap stopped further size growth, not expensive raster updates.

Set the shared ActivityIcon's logical width to Style.bar.iconCanvas and its
height to width. Explicit header/preview dimensions still override these defaults.
No sampling, gauge, palette, settings or animation semantics change.

## Evidence and qualification

The kernel killed the shared shell at17:51:57 MSK after global memory exhaustion.
Its process had10.82GiB resident anonymous memory and27.62GiB swap. The session
then ended with oom-kill and SDDM appeared; this was not a system reboot.
A later live instance reproduced the4096logical/8192requested/4096decoded icon
state. Its RSS increased during observation. These facts and the exact native
loader reproduction strongly implicate raster feedback; they do not attribute
every byte of the historical38.43GiB or rule out other shell/plugin leaks.

The focused native-loader QtTest reproduced the old doubling atDPR2 and failed.
The fixed component passed40updates at each ofDPR1andDPR2, remaining16logical
pixels and16/32raster pixels. Run:

```sh
python3 test/icon-raster-checks.py
```

The existing UI entry point runs this test before the broader suite. At the
original repair checkpoint, the broader suite failed to compile against this host: its inert fixture does not
provide the newly imported Commons AudioNodes/Singleton contract. No broad UI
PASS is claimed. Core checks reached the existing exact-media source-hash gate,
which rejects the changed ActivityIcon.qml. Published screenshots/video remain
historical, not re-attested current-source media; no hashes were rewritten to
manufacture a pass. Standalone icon/controller/math/catalog/diagnostic/NVIDIA
checks passed. The later 2.8.1 release resolves those fixture/media gates with
reviewed inert dependencies, fresh actual-consumer assets and a complete local
`make check` pass. See VERIFICATION.md; the historical failure above is not a
current release blocker.

A reviewed MCP0.3.0/Qt6.12offscreen actual-icon/native-loader render atDPR2 had
empty diagnostics and passed16px/inside-slot geometry; its PNG was inspected.
The small glyph and enlarged header retained silhouette, independent gauges and
native palette. No new style or copy was introduced. This is direct inspection,
not independent review, physical input or accessibility acceptance.

## Applied runtime

Only the installed versioned runtime's ActivityIcon.qml changed. A fresh runtime
URL was selected by its manifest, preserving plugin ID, placement and settings.
Live IPC confirmed the new consumer and16x16logical/32x32requested/32x32decoded
geometry atDPR2. The shell PID stayed unchanged. Over19samples spanning182seconds,
the icon stayed bounded through13distinct telemetry timestamps; shell RSS ranged
from1.63to1.68GiB and ended below its first sample. Memory retained from earlier
raster activity was not forcibly reclaimed. This finite observation is not a
multi-hour leak-free guarantee.

Private raw evidence is outside the repository. Source fix, installed bytes,
loaded geometry, bounded observation and checkpoint publication are separate
claims. Mainline merge/release and human acceptance remain separate.
