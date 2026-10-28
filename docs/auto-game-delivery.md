# Automatic game profiles — 2.15.1

The previous release required manual preset selection. Automatic switching now
belongs to the root-owned power-profile adapter, not an open-panel QML timer.

## Behavior

- SteamAppId/SteamGameId plus game executable evidence admits native Steam and
  Proton/Wine games. Steam, browser helpers, Wine services and known launchers
  are excluded. GPU utilization alone never selects Games.
- The system-owned loadlet-auto-game.service checks the selected desktop user's
  processes every five seconds. It waits fifteen seconds after the last observed
  game before returning to the saved non-game preset. Multiple games retain Games
  until the last game exits. No per-game password prompt or manual click is needed.
- CPU and motherboard/GPU fan settings use the existing serialized profile apply
  and rollback path. The existing thermal fallback remains in force.
- Enabling from Games chooses Quiet idle as the non-game preset. Enabling from
  another named profile retains that profile. Saved presets are not rewritten.
- Manual named-profile application disables automation. The Fans toggle can also
  disable it and restore the non-game preset. Game-preset edits require disabling
  and re-enabling automation to update the system-owned configuration.
- Configuration is root-owned under /var/lib/loadlet-power/auto.json. Public
  enabled/gaming/error status is under /run/loadlet-auto-game/status.json.
  Process command lines and environment contents are not logged or persisted.

## Delivery and limits

Installed through Polkit: power-profile, fan-control and GameDetection.py in
/usr/local/lib/loadlet. Automatic mode was enabled using the existing saved Games
and Quiet idle presets, including the user's latest percentages and boost choices.
No historical fan percentages or default boost preference replaced those values.
Plugin runtime 2.15.1 was installed at runtime-2.15.1-auto-game-20261028 and the
existing shared shell received rescanPlugins. Settings and the original source
branch/index were preserved; implementation uses its own checkpoint worktree.

No tests, UI rendering, live status probes, game launch/exit trial, physical
cooling/noise measurement or reboot verification were requested or run for this
change. Source review and successful install/enable/reload commands are not
end-to-end game detection acceptance or proof of the loaded runtime identity.
Non-Steam games without Steam metadata are outside this detector. Some launchers
and protected processes can require follow-up support based on an actual example.
