# Loadlet 2.20.0

Pin Loadlet with the header button beside Close to keep it open while working
in other windows or on other monitors. Unpin restores outside-click dismissal.
Expansion remains a separate size control; closing clears pinning.

The existing content tree moves between the normal host popup and a card-sized
Top/OnDemand native surface. The pinned surface has no full-screen input mask,
other-output dismissal twins or exclusive keyboard grab. The current page,
process identity, search, viewport and profile draft survive this change.
Controller activity and sampling remain owned by the existing open lifecycle.

The source package retains its stable ID and existing settings. The installer
includes PinnedWindow.qml; sampler sources and executable bytes are unchanged.
The 2.19.2 walkthrough is bound to its published source commit, preserving its
original hashes instead of presenting it as evidence of this release's UI.

## Verification scope

The added native UI cases cover pin/unpin state preservation, all six pages,
explicit close, reopening and nested Escape behavior with an unsaved profile
draft. Existing layout, process actions, sampler, package and isolated native
installation checks remain in make check.

The actual-consumer inert offscreen renders cover compact and expanded Russian,
pinned settings, German light theme and DPR 2. The native surface was instantiated
hidden with its anchors, margins, layer and focus contract checked. Offscreen
evidence does not verify physical pointer/focus behavior between monitors or
screen readers. Independent review is unavailable under the project no-delegation
rule. The release PR records exact-commit hosted CI separately from local checks.
