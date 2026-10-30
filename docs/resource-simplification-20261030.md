# Resource lifetime and simplification — 2.18.9

Baseline: `50738ae99827d5bce7e07d699b96e6946ff6b6df` (2.18.8).
Scope: the requested complexity/dependency review and reported shared-shell
memory spike. Direct source/diff review only; no independent reviewer.
Private raw process data and logs remain local; only aggregates are published.

## Two different resource observations

The existing shared Quickshell had a lifetime RSS high-water mark of9.83GiB.
That confirms a large historical allocation, not its time, source or permanence.
During13observations10seconds apart, RSS went from1253956to1253372KiB,
PSS from1088521to1087937KiB, with170FDs and47threads unchanged. No growing
shell footprint was observed in that120-second window. A separate application
also used Quickshell; it was not a duplicate Loadlet shell.

The Loadlet reader stayed at10668KiB RSS but its eventfds grew1172->1200.
That is a repeatable resource leak independent of the shell's large peak.
The reader repeatedly initialized NVML, sampled, shut it down and unloaded the
library. An isolated read-only driver probe distinguished these lifetimes:

|16cycles in separate short-lived processes|eventfds before/after|
|---|---:|
|Map/unmap only|0/0|
|Init/query/shutdown/unmap each cycle|0/17|
|One mapping; init/query/shutdown each cycle|0/2|

The fix retains the library mapping until provider destruction. It does **not**
retain an initialized NVML session: shutdown still follows every sample. The
existing active-device admission gate remains. No power-state or fan writes were
used for diagnosis. Physical suspend/race behavior is not established by a mock.

A separate32-query real-driver comparison of the actual sampler gave:

|Reader|eventfds first/last|FDs first/last|RSS first/last,KiB|
|---|---:|---:|---:|
|Baseline|2/33|9/40|9976/10248|
|Candidate|2/2|9/9|30564/30776|

These are the final-source rerun values; the earlier run also had2->33and2->2
eventfds. Candidate anonymous RSS was21136->21348KiB and file RSS9428KiB;
this is predominantly retained driver anonymous memory, not simply a file cache.
Retaining the library costs about20MiB of resident memory in this short
probe. This is a bounded-resource fix, **not** a reduction of sampler RSS and not
a proven fix for the shell's9.83GiB peak. No CPU/energy improvement or long-session
memory plateau is claimed. A previous experiment retaining an initialized NVML
session was different; this change retains only the mapping.

The retained shell log also contains large historical plugin-reload bursts,
including1027notifications within one second. Multiple plugins were involved.
These are an investigation lead, not a measured association with the peak:
there is no simultaneous allocation trace. No host watcher or unrelated plugin
was changed, and the shared shell was not restarted for diagnosis.

## Demonstrated simplification

- Delete the465-line unimported `Messages.js` catalog and its installer/UI-fixture/
  legacy-catalog assertions. The active323-key `I18n.js` catalogs are unchanged.
- Delete167lines comprising nine obsolete power-model functions and their exports
  from `Model.js`. Their removed native power reader has no current production
  caller. All83remaining function bodies are byte-equivalent to baseline.
- Preserve the upstream-pinned historical tests as reference data. Their old
  power-model assertions were already excluded from this fork's acceptance gate;
  they do not establish a supported public power API. Keep preview/topology helpers
  used by the retained rendering scripts.

This removes632production JavaScript lines without replacing them with another
framework. It does not by itself improve live shell memory: the old catalog and
power helpers were not used by the active consumer.

## Dependency and native-contract decisions

|Area|Decision|
|---|---|
|Collector|Existing C++17/POSIX and platform libraries; optional driver NVML. No new dependency or daemon.|
|Reporting/control helpers|Python standard library; existing systemd and authenticated host controls. No pip dependency.|
|UI|Existing Qt/Quickshell/Omarchy controls, local QML/JS. No npm runtime dependency.|
|Agent analysis|Explicit external CLI integration, not needed for recording. Provider/authentication acceptance remains separate.|
|Development|Existing Node, compiler and Qt Quick Test; not runtime installation requirements.|
|ChoiceDropdown|Keep compatibility snapshot: native selection mutates the controlled value and selection relies on the hover index rather than the clicked row. Do not trade a small fork for a behavior regression.|
|ProfileCodec|Keep the small ASCII payload adapter for the documented Qt6.8/6.12 behavior; it is used, not speculative infrastructure.|
|Large owners|Do not split Panel/Model/collector merely to reduce per-file line counts. No new abstractions were justified by this task.|
|Recovery/guards|Keep identity checks, bounds, rollback, explicit Apply and unknown-value handling; these are required behavior, not removable complexity.|

The inventory found no application package-manager dependency manifests. This is
scoped source evidence, not a claim that every transitive host dependency is
necessary or that overengineering has been universally eliminated.

## Checks and limits

- Hardened native build succeeded.
- New inert lifecycle regression fails baseline on per-sample FD growth and passes
  the candidate. It covers one mapping, balanced26NVML sessions, inactive/unknown
  admission, resume and unloading on EOF destruction.
- Focused model mathematics and active catalog/install checks passed.
- Byte comparison confirms83retained Model functions are unchanged.
- The real-driver32-query comparison above passed without hardware configuration.
- Full hosted core/UI/package/reproduction results and installed/loaded identity
  are separate delivery receipts for the exact checkpoint, not implied here.

The existing17-module assessment does not become5/5 because of these fixes.
Native collection gains a demonstrated lifetime regression; maintainability gains
concrete dead-code removal. Fifty-locale translation, physical control acceptance,
real provider acceptance, long-running memory/cost evidence, accessibility and
live compositor/input acceptance remain open. No new visual layout was changed.
