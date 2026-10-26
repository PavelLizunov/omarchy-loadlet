# Technical line drawing

The previous map was a stack of boxed labels over a rough outline. It hid all
sensor data in the compact frame and was rejected by the user.

Available local wireframe/OpenDesign skills were inspected. Wireframe is a
low-fidelity HTML ideation workflow, not technical vector illustration. No
specialized vector-drawing skill was available in the active catalog. The
implementation uses native SVG/QML and these actual public reference guides:

- Tabler icon design guide: https://docs.tabler.io/icons/design-guide
- Lucide icon selection: https://github.com/lucide-icons/lucide/blob/main/docs/how-to/icon-guide.md
- Repository: https://github.com/tabler/tabler-icons

Applied principles: consistent centered line weight, round caps/joins, clear
spacing and recognizable silhouettes. The case side cutaway is an original
illustration, not copied Tabler/Lucide artwork or a reconstruction of the actual
machine. CPU heatsink, RAM, expansion card, drive, rear/front fans and case frame
use a common coordinate system. Numbered hotspots have a separate labeled legend;
labels are not painted over hardware. The schematic is an optional destination,
not a permanently expanded illustration ahead of every control.

Host palette, native buttons, retained labels and keyboard routes remain primary.
Normal data views automatically use the existing expanded fitted frame, now
900x650 content units at default scale; the compact glance remains 480x390.
Settings uses four categories, fan controls show one selected channel, and rare
sensor-assignment controls live under More options. Smaller screens and enlarged
fonts retain internal scrolling rather than clipping or shrinking all text.

The 2.13.0 actual-consumer renders were inspected inline, including all primary
pages, four settings categories, map, CPU/GPU selection, empty/error, narrow fan
view, font16, German/Chinese and DPR2. The recorded diagram and screenshots are
inert fixtures. This is direct design inspection, not independent signoff or
physical desktop acceptance.
