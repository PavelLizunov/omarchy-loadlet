# Omarchy 4.5 visible icon size — 2026-10-20

The user reported a much smaller Loadlet character after the HiDPI raster fix.
The source image was bounded correctly at16logical/32decoded pixels onDPR2,
but Omarchy4.5's new BarIconContent normalized the complete16-unit custom image
to Style.bar.iconSize,whose default is12. The Split die body therefore painted
at about10.5x9 rather than its previous14x12,inside the unchanged27x26slot.
The earlier regression checked logical source dimensions,not the final scene.

The bar now uses the existing native WidgetButton and centers ActivityIcon
directly in its slot. Its16-unit logical canvas and bounded HiDPI raster are
retained. No global icon-token override,inverse scaling,unbounded implicit image,
new shape,palette,sampling or settings change. Header size is unchanged.
Read-only status adds iconSizeRevision `native-canvas-v1` plus scene/slot bounds;
rotation can legitimately enlarge the scene-aligned bounding rectangle.

## Checks

`python3 -B test/icon-raster-checks.py` mounts the actual extracted Panel bar block
with exact installed native controls and inert data/formatting/IPC. The original
consumer fails final-scene width:12instead of16. Corrected source passes atDPR1/2:
fixed logical/raster size over40updates,scene16canvas,centering,unchanged slot,
font factors1/1.5/2,vertical layout and left-click/no-op right/middle behavior.
The broader panel test also asserts final mapped width/height.

Strict QML Preview0.3.0/Qt6.12 actual-bar fixtures atDPR2 were rendered before/after
and inspected inline. The restored character matches the previous optical size;
gauges and face remain readable. No diagnostics. These are inert fixture pixels,
not a desktop capture,physical acceptance or universal theme certification.
Independent review was not performed;this project requires direct work.

Icon/controller/model/catalog and bounded sampler checks pass;qmllint exits0
with existing warnings;manifest validation and task diff checks pass.
Full `make check` still stops at the exact-source media hash assertion,now naming
Panel.qml. Published screenshots/film have not been re-attested or their hashes
rewritten. `make check-ui` passes the focused raster/scene checks,then its existing
full fixture fails to import the new host Commons AudioNodes/Singleton contract.
No complete UI/media gate pass is claimed.

## Installed observation

A fresh runtime URL identifies the checked candidate without a shell restart.
The existing ActivityIcon raster-safety bytes and all other runtime dependencies
are unchanged;original installed code is retained externally. Loaded status reports
scene16x16,slot27x26,DPR2,requested32x32,decoded32x32,ready=true. Eight read-only
observations over35seconds retain those bounds while multiple telemetry timestamps
advance. Original shellPID and byte-identical user configuration are preserved.
This finite observation does not establish multi-hour resource behavior.

Source,installed bytes,loaded identity,remote checkpoint and user visual acceptance
are separate. No release,main merge or Marketplace change is part of this repair.
