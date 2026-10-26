# Current Loadlet visuals

The five PNGs show Loadlet 2.11.1 through its actual native Panel consumer with
inert demonstration data. Compact, expanded, settings, Cooling and Fans were
read inline after rendering. No desktop capture or production input was used.

Compact/settings/Fans are 480x422; expanded/Cooling are 780x592 logical pixels.
Only empty outer fixture space was cropped. No resizing or reconstruction.
The preview.png file equals expanded.png. The manifest records current source
and asset hashes, Nord palette, font12 and Qt6.12 software/offscreen renderer.

Additional inspected states cover page expansion, scrolling, language selection,
empty/loading/error states, three tiles, German Cooling, Chinese Settings,
Russian font16, narrow Fans and English DPR2. Host Popup overlays are outside
the captured subtree; their pixels are not verified by these images. QtTest
exercises dropdown opening, selection and Escape independently. The renderer
reports local AT-SPI desktop-bridge warnings; no QML diagnostics were observed.

The film and DPR2 film assets remain explicitly historical 2.8.1 media, pinned
to that release source rather than relabeled as current. No independent review
happened. Physical Wayland focus, real authentication, every theme and long-run
behavior remain unverified.
