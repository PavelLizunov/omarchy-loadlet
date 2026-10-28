"""Steam evidence and bounded process fixtures; never inspect a real game."""
from pathlib import Path
import importlib.util
import os
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('games', ROOT/'GameDetection.py')
games = importlib.util.module_from_spec(spec)
spec.loader.exec_module(games)
env = {'SteamAppId': '123'}
cases = [
    ('/steam/steamapps/common/MyGame/game', ['game'], env, True),
    ('/usr/bin/wine64', ['wine64', 'C:\\game\\game.exe'], env, True),
    ('/steam/steamapps/common/Proton-GE/files/bin/wine64', ['wine64', 'services.exe'], env, False),
    ('/steam/steamapps/common/Proton 10/files/bin/wine64', ['wine64', 'explorer.exe'], env, False),
    ('/steam/steamapps/common/Proton-GE/files/bin/wine64', ['wine64', 'game.exe'], env, True),
    ('/steam/steamwebhelper', ['steamwebhelper'], env, False),
    ('/usr/bin/wine64', ['wine64', 'EpicGamesLauncher.exe'], env, False),
    ('/steam/steamapps/common/Game/game', ['game'], {}, False),
    ('/usr/bin/firefox', ['firefox'], env, False),
    ('/steam/steamapps/common/Game/game', ['game'], {'SteamAppId':'0'}, False),
]
for executable, args, environment, expected in cases:
    assert games.is_game(executable, args, environment) is expected, (executable, args)
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    pid = root/'123'; pid.mkdir()
    (pid/'exe').symlink_to('/steam/steamapps/common/Game/game')
    (pid/'environ').write_bytes(b'PRIVATE=not-retained\0SteamAppId=123\0')
    (pid/'cmdline').write_bytes(b'game\0')
    assert games.running_games(os.getuid(), root) == [123]
    assert games.running_games(os.getuid()+1, root) == []
    (pid/'environ').write_bytes(b'x'*65537)
    assert games.running_games(os.getuid(), root) == []
print('PASS game detection: native, Wine, wrapper/launcher exclusions, absent metadata, ownership and bounded input')
