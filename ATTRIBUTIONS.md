# Source provenance

[Loadlet](https://github.com/PavelLizunov/omarchy-loadlet) is derived from
Kristoffer Haugland's MIT-licensed
[Activity Monitor](https://github.com/stappmus/omarchy-activity-monitor),
based on commit `b25a98c7ff2a688ab74d86d2be42249e2db2f9cf`.
The original LICENSE is retained, including the fork copyright line.

Selected ideas and code adaptations:

- Omarchy Quattro Ui/Dropdown.qml (installed4.5.0rc2, MIT): ChoiceDropdown.qml
  retains the native control and corrects clicked-row selection and controlled
  value ownership. The host installation is not modified.

- [sum117](https://github.com/sum117/omarchy-activity-monitor), commits
  `500ced953a4a8d622d4fe221ce14e482683971ee` and
  `e559afc2b32a11e096c22774d824726011cb8035`: separate TERM/KILL actions,
  honest signal-result messages, and scrolling inside the fitted panel.
- [bzillins](https://github.com/bzillins/omarchy-activity-monitor), commit
  `6fc1591c390b6dffb1547de098c54be9e58c270e`: gate NVIDIA queries on PCI
  runtime state, initialize NVML with NO_ATTACH, query by PCI address, release
  NVML after a sample. Physical power behavior still requires hardware checks.

Fork work by slovn includes economy defaults, serial bounded reader lifecycle,
bounded transport, Unicode process inspection, guarded same-user process actions,
opt-in local diagnostic history and the load-indicating Split die character.
Right-click has no action; processes are available inside the panel.

The display name is Loadlet. The stable plugin ID `slovn.activity-lite` and local
state-directory names remain compatible with earlier installations, preserving
settings and reports. The sampler's protocol/reported version is independent of
the plugin display version.

This public repository begins with a reviewed source snapshot, not imported
private development history. `docs/fork-boundary.json` pins byte-identical upstream
owners. `make check` compares those Git blob identities directly, so validation
works in this clean history without private ancestor objects.
