# Current film review

The 2.8.1 film was rebuilt from fresh actual-consumer native assets on
2026-10-20, using the pinned official Omarchy 4.5.0-rc1 host. Direct self-review,
not independent signoff. Five full-size scene stills, the complete beat sheet,
phone sheet, four cut strips and each MP4's worst-quality frame were read inline.
No headline overlap, clipped brand or accidental blank frames were observed.
Native screenshots, film assets and source manifests agree. The unchanged
accepted die, Loadlet headings, demo process owners and MIT attribution remain.
Camera movement is presentation, not native input or changing telemetry.

Phone-size review retains the same limit: the brand and hero are recognizable,
but fine explanatory text and full process rows are desktop detail, not certified
legible on a narrow phone. No universal theme, contrast or accessibility claim.

Thirty pure-time forward/backward/shuffled replays passed. Both silent H.264
outputs fully decode as 480 frames / 16 seconds / 30fps, yuv420p, moov before mdat.
Complete decoded-output versus pristine-film SSIM:
master minimum 0.998944, mean 0.9995452375;
messenger minimum 0.996202, mean 0.9983580354166667.
Neither output has a frame below 0.98. Worst frames are
314 and 389, inspected inline.

The new inline WebP contains 238 encoded frames / 15999ms,
with 1ms rounding. Native Chromium decoded all frames. Its 240 timed frames
have SSIM minimum 0.992752 against the current MP4.
Local GitHub-sanitized README consumers at desktop/phone widths animate without
overflow; their screenshots were inspected. This is separate from the current
public GitHub page, which still needs checking after publication. Historical
public-page evidence for 2.8.0 is not reused as a 2.8.1 claim.
No audio QA, synthesis, external inference or desktop capture.
