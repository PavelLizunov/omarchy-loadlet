# Loadlet verification

## 2.11.3 fan authorization and icon follow-up — 2026-10-26

The user reported invisible icons and required a single password entry rather
than a prompt per fan action. The previous 2.11.2 loaded identity was confirmed,
but did not prove icon pixels. Existing-shell logs did not establish a rendering
error. The candidate increases outline size/weight and heading contrast, emits
explicit RGB stroke colors and anchors button SVG inside the native glyph slot
instead of estimating its position from the unfitted label. The original cause
of the reported invisible icons remains unconfirmed without pixel evidence.

Fan requests now enter the fixed root-owned adapter unprivileged. It tries sudo
noninteractively first, reusing existing Omarchy authorization. Only an explicit
password-required failure opens a Polkit unlock. Unlock records the actual caller
UID and creates a validated root-owned 24-hour sudoers grant with an absolute
NOTAFTER deadline, limited to boost/restore and permitted channel/speed/duration
arguments. No permission to run worker/recover/unlock or arbitrary commands is
granted by that rule. Early revocation removes the UID-specific file.

Installed the root-owned adapter and successfully applied the caller's 24-hour
grant through existing sudo authorization; visudo accepted the actual rule.
No fan duty was changed. Installed 16 runtime files in a fresh 2.11.3 directory
and requested existing-shell rescan. Saved preferences and sensor history remain.
No tests, preview, hardware/authentication replay or independent review was run.
Actual icon visibility, first interactive unlock and expiry behavior are unverified.

## 2.11.2 SVG icon update — 2026-10-26

Added original theme-colored SVG symbols to navigation, header controls, metric
headings, process actions, restore/done, export and copy. Native host buttons
still own sizing, focus, tooltips and interaction; labels are retained. The bar
character and telemetry are unchanged. SVG raster size follows logical size and
DPR without decoded-size feedback. SvgIcon.qml ships in local installs and inert
fixture preparation. Existing icon-selection tests were adapted, not executed.

This implementation-only request did not include tests or visual verification.
No preview, test suite, lint or runtime diagnostic probe was run. Existing PNGs
remain explicitly 2.11.1 and are source-pinned, not current-icon evidence. The
previous audit results below do not establish acceptance of this update.

Installed 16 runtime files in runtime-2.11.2-svg-20261026, updated the installed
manifest entry point and requested rescanPlugins in the existing shared shell.
Saved settings and the privileged fan adapter were not changed. Loaded identity
and actual icon appearance were not probed for this implementation-only request.

## 2.11.1 page audit — 2026-10-26

The user explicitly requested visual inspection of every page and comprehensive
bug checks after noticing expansion was restricted to Overview. Expand and E now
resize Overview, Cooling, Fans and Settings without changing page. This is the
existing fitted expanded panel, not compositor full-screen.

Corrected Cooling's nearly hidden compact chart by scrolling the whole page;
fixed stale Fans selection after Escape and the details IPC destination. Compact
GPU samples survive collapse when their tile still needs them. Expanded summaries
reserve four process rows. Chart selection follows timestamps as history rolls;
isolated points paint, empty navigation stays unselected, duplicate timestamps
are merged and missing current sensors cannot display historical values as live.
Malformed/oversized history and deadline failures retain an error state.
The unsupported Fans glyph was replaced with an available refresh glyph.

Baseline make check failed on obsolete 2.8.1 media provenance. The isolated
controller gate also lacked new sensor properties. Both were corrected. Five
fresh current-source screenshots were inspected inline; the archived film is
explicitly labeled 2.8.1 and checked against its pinned historical source, not
relabeled as current. Additional inspected states include expansion, scroll,
empty/loading/error, languages en/ru/de/zh, font16, narrow Fans and DPR2.
Popup overlays lie outside the rendered subtree; dropdown pixels are not proven.
AT-SPI desktop-bridge warnings remain in renderer logs; no QML diagnostics.

Full local make check passed: package/core gates, 59 actual-panel QtTest results,
four native-bar results at each DPR1/2, isolated native add/enable/update and
manifest validation. This includes page geometry at fonts12/16/24, button/E,
Escape, chart selection, dropdown keys, malformed history, GPU persistence and
inert fan argv/failure handling. A real bounded JSONL history fixture passed.
Fan helper expiry, exception rollback and unit recovery were simulated with
temporary files only. A discovered mode0 issue now preserves full speed instead
of lowering it to a requested percentage. No real fan duty was changed during
this audit. The local native rebuild reproduced the distributed executable.

Independent review was not performed under the direct-work contract. Physical
Wayland interaction, real authentication, actual timed hardware recovery,
connector identity, every theme and multi-hour behavior remain unverified.
Applied through a fresh versioned runtime directory, preserving saved settings.
All 15 runtime files match source. Read-only existing-shell status reports
iconRevision 2.11.1, the new entry point, ready state, 13 temperatures, 5 fans,
4 control channels and no reader error. The adapter is root-owned mode755 and
matches source. No fan override unit was active at replacement. Publication
and remote CI remain distinct from these installed/loaded observations.

## 2.8.1 release candidate — 2026-10-20

This patch combines bounded HiDPI image dimensions with restoration of the
16-unit final bar canvas on Omarchy 4.5. The accepted die, gauges, palette,
slot, settings, click actions and sampling remain unchanged.

Full `make check` now passes locally: package/core gates, 40 actual-panel QtTest
cases, four focused native-bar cases at each DPR 1/2, no-compiler native
add/enable/update and manifest validation. The broad fixture now exports only
reviewed display singletons, provides inert shell/Hyprland/file adapters and
preserves already-qualified palette references. Runtime host modules are not
modified. CI uses official Omarchy 4.5.0-rc1 source at
`03ff1eff3812933f7088484533784d2f63eaf19a`; relevant installed host files match it.

Twelve fresh strict QML Preview 0.3.0 / Qt 6.12 states were rendered with empty
diagnostics and inspected inline. The current-source screenshots and DPR2 film
assets were regenerated, then the complete silent 16-second film and README
animation rebuilt. Their manifests attest these captures, not rewritten hashes
of the old assets. Native Chromium decoded every animation frame; local sanitized
README consumers at desktop/phone widths animate without overflow. See the
current media manifests and film QA for exact bytes and bounded coverage.

The shipped 239736-byte sampler is unchanged. A fresh local GCC 16.2.1 build
again reproduced it byte-for-byte. CI adds an immutable official Arch container
job that rebuilds this exact source and compares it directly with the original
shipped executable. A hash-only check is not this source-to-binary proof; the
job's remote result must be checked separately before claiming CI reproduction.

The existing installed fix was observed separately as scene16/raster32 at DPR2;
its status still reports 2.8.0 until an explicitly applied release update.
Source checks, installed bytes, loaded identity, GitHub main, exact-commit CI and
Marketplace approval are separate. Physical visual acceptance, multi-hour memory
behavior, every theme/hardware/accessibility and independent review are not
established by this release. Marketplace issue #11824 requires maintainer review;
no source commit or issue edit alone changes the listed snapshot or install flag.

## Omarchy 4.5 visible bar size follow-up

The HiDPI repair bounded source dimensions but missed the new host's additional
custom-icon normalization: the final scene canvas became12instead of16logical
pixels. The bar now centers the unchanged bounded icon directly in a native
WidgetButton. Original final-size regression fails12vs16; corrected native
DPR1/2tests pass size,centering,theme scaling,vertical layout,click behavior and
40updates. Strict actual-bar before/after renders were inspected. Installed
read-only status confirms scene16/raster32/slot27x26 over8observations35seconds,
with the same shell process and unchanged user configuration.
[Detailed scope and verification limits](docs/bar-size-compatibility.md).
At the original repair checkpoint, the media-source hash and broad current-host
fixture gates were red. The 2.8.1 release work above resolves those gates;
physical user acceptance and long-session behavior are still not inferred.

## Standard packaged installation repair

The user rejected manual compilation after Marketplace publication. The repository
already distributed a working x86_64 sampler, but the instructions and maintainer
submission required rebuilding it. Prior install tests proved a developer route,
not the intended ordinary user's no-toolchain path. This is an acceptance gap.

Normal installation is now the native `omarchy plugin add` command with `--enable`.
No compiler, make, first-run download or automatic build is required. The current
239736-byte executable is unchanged. A fresh GCC16.2.1 build of the exact current
C++ source/header/flags reproduced SHA256
`48041c660e8fbc8eaced1b312ac9baf73e2303bdcb0957dcd3e5f4c8f6a4169d`.
[Provenance](docs/binary-provenance.md) and its JSON bind the actual package bytes
to source and requirements, without assuming all compilers produce the same file.

A new package gate checks executable/source hashes, ELF64 x86_64 identity, mode,
changed-byte rejection and a real framed sample before any rebuild. Native
add/validate/catalog/enable/update scripts were exercised in a fresh temporary
HOME with make/compiler commands denied. The installed executable remained exact;
a real reader sample reached the actual Model parser. Existing-ID refusal and
an ordinary fast-forward package update passed without compilation or journal
writes. Only shell IPC was stubbed; this does not establish a fresh production
Wayland lifecycle. Full `make check` passed, including39native UI tests.

Runtime QML, catalogs, helpers, accepted icon and all current screenshots/film are
byte-unchanged; no ritual recapture or reinstallation is needed for documentation
and package checks. The existing loaded2.8.0 identity and file hashes are checked
separately. No independent review happened. Runtime support is current Linux
x86_64 Omarchy,not ARM or arbitrary distributions.

Marketplace approval for the old snapshot explicitly required a rebuild and
set Manual setup. Source publication cannot remove that separate registry flag.
The corrected exact commit and packaged-binary evidence require maintainer review
through the supported update request. Until that review and catalog publication,
the live site's automatic command remains unavailable. No maintainer action or
changed live catalog is inferred from local tests.

## Historical installation documentation follow-up

The live Marketplace catalog and its registry were inspected on 2026-10-16.
The listing for `slovn.activity-lite` has an explicit `installation.mode: manual`
override, `installAvailable: false`, and an empty `installCommand`; compatibility
is passed. The site's detail renderer deliberately suppresses the command for
that state. This is not a missing command field in the plugin manifest.

README now places a copyable native add/local-build/enable sequence before the
media. The guide distinguishes this user path from source development, and the
package check protects the command, position and guide link. Full `make check`
passed, including all 39 inert native UI cases and manifest validation.

The exact README sequence was executed with a fresh isolated HOME: real installed
CLI add/validate/catalog/enable scripts, a real public repository clone and local
C++ build. The rebuilt sampler matched the source binary hash and a real resource
sample succeeded. Existing-ID refusal preserved the binary and did not enable
again; a deliberately failing compiler prevented enablement. Only shell IPC was
stubbed. No production installation, settings, loaded identity or QML was changed;
this is not a fresh live-shell lifecycle test. Review was direct, not independent.
The Marketplace registry override remains unchanged; documentation/checkpoint
publication does not claim a changed live catalog or default branch.

## Scope

Loadlet2.8.0 is a reviewed clean source snapshot with a new public display name,
current native screenshots and a rebuilt complete film. Stable pluginID
slovn.activity-lite,settings,IPC,journal/export paths remain compatible. The
selected symmetric icon, floor rows, threshold50,palette,sampling,heat and guarded
process behavior are retained. Right-click remains no-op; the process view is
inside the panel. No fan control,driver/service installation or Discord change.

The original private source/history is preserved, not copied as ancestors or
remote refs. Private handoffs, historical diagnostics, absolute evidence roots,
private films and unrelated user files are excluded by explicit selection.
Three byte-identical public upstream preview-*.png references retain old Activity
headings/sample owners; they were inspected and are not current Loadlet media.
License, attribution and all12upstream-owned files retain their bytes;14modified
owners and4historical deletions remain classified. Clean-history fork checks use pinned
Git blob identity instead of requiring unavailable private Git objects.

## Observed native evidence

Actual-consumer inert native QtTest39passed,zero failures/skips/warnings after
branding. Four locales retain current Loadlet headers. Pointer/key tests preserve
left-click, no-op right-click, internal processes/settings/Escape and sampled
identity guards; equal-load native raster symmetry remains protected. This is
not physical input injected into the production desktop.

Twelve final qml-preview0.3.0/Qt6.12 software/offscreen states cover compact,
expanded,preferences atDPR1/2;Russian/German/Chinese and Russianfont16; current
native icon states and actual hero. Empty diagnostics. The final images/crops were
read inline. A first fixture owner looked personal; changed demonstration owner
to demo and rerendered before publication, with runtime ownership logic unchanged.
Public manifests keep current relative source/asset/fixture hashes, not raw
private request/results or machine paths. Final diff review found a malformed
mechanical title-key replacement in the unused installed Messages.js catalog.
Restored the keys, added real legacy-catalog parsing/title assertions and parsed
all20JavaScript owners. One corrected-dependency compact rerender produced the
byte-identical PNG with empty diagnostics and was read inline. Current panels do
not import that catalog; unchanged other media is explicitly qualified by hashes.
No independent review happened.

## Film evidence

A new16second1280x720/30FPS film uses fresh current native DPR2assets and Loadlet
first/end cards. 960x540messengerMP4 and complete640x360/15FPS READMEWebP are derived
from the same newly captured footage. No video title-only relabeling or original
smooth-icon equivalence. Silent,no audio generation/service/model calls.

Thirty-time forward/backward/shuffled determinism and full480frameMP4decodes pass.
Actual atom order hasmoov beforemdat,H.264/yuv420p and no audio. Complete SSIM
master minimum0.998981/mean0.99954586875; messenger minimum0.996358/mean0.9983688875;
nonebelow0.98. Five full-size stills,beat/phone sheets,four cut strips and both
worst314frames were inspected inline. The owned capture stage took44.823seconds;
this is measured local wall time, not a general performance or energy claim.

README animatedWebP has239encodedframes/15999ms/infinite loop; the one millisecond
difference is format rounding. Native Chromium decoded all239frames and240timed
samples; SSIM minimum0.993184/mean0.9967232375,nonebelow0.98,worst134 inspected.
GitHub-sanitized HTML embedded the full film. Chromium loaded animated pixels at
640px desktop/327px phone widths without overflow; both layouts were read inline.
Actual anonymous GitHub page subsequently loaded all3current screenshot images
and the inline film. Settled viewport crops compared animated pixels at640px
desktop and309px phone widths without horizontal article overflow; images were
read inline. Initial browser checks used unsettled page coordinates and produced
invalid comparisons; those were rejected and corrected to nonzero stable viewport
bounds before the final observation.
See [QA](docs/video/qa.json),[visual identity](docs/images/manifest.json) and
[film review](docs/video/REVIEW.md) for scoped observations.

## Source and publication checks

Full make check passed: core controls,39native tests and installed manifest
validator. Six runtime QML owners linted with0errors/876existing warnings; not
warning-clean. Local sampler rebuild matched its reviewed SHA256.
The first whole-byte pass covered195current files/8845810bytes with both
UTF16alignments and0tested private path/session/store matches. Subsequent owning
catalog/provenance/doc edits receive a fresh exact-tree check before publication.
Single-thread English OCR covered16PNGpaths with0tested private-metadata matches.
An initial oversubscribed OCR attempt timed out at20s; the bounded rerun passed.
Public upstream legacy pixels were manually distinguished from current demo media.
Final checked initial snapshot:195files/8849908bytes,0excluded/ignored; all locally
available203blobs/12trees/1commit and39embedded payloads,0tested content findings.
Dedicated public metadata check passed194reachable blobs. This includes available
staged superseded blobs locally, not copied private history. Fresh-root d62971eb
has no parent; remote main/checkpoint and tree were verified exactly. Nine remote
public README/manifest/screenshot/MP4/WebP paths downloaded anonymously with exact
hashes. Original repository remained private and original branch/index/files exact.
Local installer copied18exact files and refused a second overwrite without mutation.

## Installed and loaded

Loadlet2.8.0 was applied to the existing stable ID with all14runtime file hashes
exact,6existingQtQuick6.11recovery-import adaptations and a fresh runtime URL.
User settings/config remained byte-identical. The same shared shell child91623
and wrapper91542 remained; no second Quickshell,manualrestart or manualrescan.
An initial second preflight saw TTS busy and stopped before installation; speech
was not interrupted. The later idle apply had3bounded temporary IPC failures,
then3ready/no-error observations. Loaded productName=Loadlet,iconRevision=2.8.0,
rightClickAction=none,selected symmetric shape10/threshold50 and ready16px/DPR2
raster were observed. Shared automatic reload is a shared-shell event; surviving
Discord connection/Telebar no-draft observations are not proof of every unrelated
application's transient state.

The new GitHub Actions workflow was active/enabled but the initial root push
registered0runs/checks through bounded observation. Added explicit manual workflow
dispatch without changing runtime/media, so the exact final commit can be tested.
Exact-head CI outcome is checked separately; dispatch or local tests are not a
remote-CI success claim.

## Acceptance boundaries

Source/core/native/package/privacy checks,installed hashes,loaded status,remote
GitHub commit/CI and user acceptance are separate surfaces. Public publication
requires the exact fresh-root history to pass the dedicated metadata gate, not
only token heuristics. Byte/metadata/OCR checks do not establish universal absence
of encrypted/steganographic/unindexed private content or malware.

Shown icon/name are selected by the user. Fresh media/brand physical acceptance
is not reported. Independent review,allthemes/translucency,physical Wayland focus,
assistive technology,battery and every hardware sensor remain unverified. No
Marketplace submission,maintainer approval,GitHub tag or release is claimed.
