"""Bounded Steam/Proton game detection without GPU-load guesses."""
from pathlib import Path
import os
import re

IGNORED = {'steam', 'steamwebhelper', 'pressure-vessel', 'pressure-vessel-wrap',
           'pv-bwrap', 'bwrap', 'wineserver', 'services.exe', 'explorer.exe',
           'winedevice.exe', 'plugplay.exe', 'rpcss.exe', 'steamservice.exe',
           'steam.exe', 'crashhandler', 'crashhandler64', 'reaper', 'proton',
           'launcher.exe', 'redlauncher.exe', 'epicgameslauncher.exe', 'uplay.exe',
           'ubisoftconnect.exe', 'battle.net.exe'}


def is_game(executable, arguments, environment):
    name = Path(executable).name.lower()
    if name in IGNORED or name.startswith(('steamwebhelper', 'crashpad_handler')):
        return False
    app = environment.get('SteamAppId') or environment.get('SteamGameId')
    if not app or not re.fullmatch(r'[1-9][0-9]{0,19}', app):
        return False
    if name.startswith(('wine', 'python')) or name in ('bash', 'sh', 'dash'):
        game_exes = [Path(arg.replace('\\', '/')).name.lower() for arg in arguments
                     if arg.lower().endswith('.exe')]
        return any(exe not in IGNORED for exe in game_exes)
    path = str(executable).lower()
    if '/steamapps/common/' in path and not any(part in path for part in
            ('/proton', '/steamlinuxruntime', '/steamworks shared/', '/steamworks_shared/')):
        return True
    return name.endswith('.exe') and name not in IGNORED


def running_games(uid, proc=Path('/proc')):
    found = []
    for index, entry in enumerate(proc.iterdir()):
        if index >= 32768:
            raise ValueError('Process enumeration budget exceeded')
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid != uid:
                continue
            executable = os.readlink(entry/'exe')
            with (entry/'environ').open('rb') as stream:
                raw = stream.read(65537)
            if len(raw) > 65536:
                continue
            env = {}
            for item in raw.split(b'\0'):
                key, _, value = item.partition(b'=')
                if key in (b'SteamAppId', b'SteamGameId'):
                    env[key.decode()] = value.decode('ascii', errors='ignore')
            with (entry/'cmdline').open('rb') as stream:
                raw = stream.read(16385)
            if len(raw) > 16384:
                continue
            arguments = [arg.decode('utf-8', errors='replace') for arg in raw.split(b'\0') if arg]
            if is_game(executable, arguments, env):
                found.append(int(entry.name))
        except (FileNotFoundError, ProcessLookupError):
            continue
        except PermissionError:
            continue
    return found
