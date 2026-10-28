"""Validate the clean public package and current native media without shell IPC."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[1]
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
m = json.loads((root / 'manifest.json').read_text())
assert m['schemaVersion'] == 1 and m['id'] == 'slovn.activity-lite'
assert m['name'] == m['barWidget']['displayName'] == 'Loadlet'
assert 'loadlet' in m['barWidget']['aliases']
assert m['kinds'] == ['bar-widget'] and m['license'] == 'MIT'
assert m['entryPoints'] == {'barWidget': 'Panel.qml'}
for value in m['entryPoints'].values():
    path = PurePosixPath(value)
    assert not path.is_absolute() and '..' not in path.parts
    assert (root / value).is_file()
for path in root.rglob('*'):
    if '.git' not in path.relative_to(root).parts:
        assert not path.is_symlink(), path
assert (root / 'activity-sampler').stat().st_mode & 0o111
for name in ['process-signal', 'activity-report']:
    compile((root / name).read_text(), name, 'exec')
for setting in m['barWidget']['schema']:
    key = setting['key']
    assert setting['defaultValue'] == m['barWidget']['defaults'][key], key
    if setting['type'] == 'integer':
        assert setting['min'] <= setting['defaultValue'] <= setting['max'], key
instructions = (root / 'AGENTS.md').read_text()
assert instructions.startswith('# Loadlet workspace entry\n')
assert 8 <= len(instructions.splitlines()) <= 25
assert (root / 'docs/agent-contract.md').is_file()
for name in ['compact.png', 'expanded.png', 'settings.png', 'manifest.json']:
    assert (root / 'docs/images' / name).is_file(), name
visuals = json.loads((root / 'docs/images/manifest.json').read_text())
assert visuals['productName'] == 'Loadlet'
for name, expected in visuals['sourceHashes'].items():
    if visuals['runtimeVersion'] == m['version']:
        actual = sha(root / name)
    else:
        actual = hashlib.sha256(subprocess.check_output(
            ['git', '-C', str(root), 'show', f'{visuals["sourceCommit"]}:{name}'])).hexdigest()
    assert actual == expected, name
for name, expected in visuals['assetHashes'].items():
    assert sha(root / 'docs/images' / name) == expected, name
release_visuals = json.loads((root / 'docs/images/release-2.16.0/manifest.json').read_text())
assert release_visuals['runtimeVersion'] == m['version']
for name, expected in release_visuals['sourceHashes'].items():
    assert sha(root / name) == expected, name
for name, expected in release_visuals['assetHashes'].items():
    assert sha(root / 'docs/images/release-2.16.0' / name) == expected, name
assert (root / 'preview.png').read_bytes() == (root / 'docs/images/release-2.16.0/overview.png').read_bytes()
video = json.loads((root / 'docs/video/qa.json').read_text())
assert video['durationSeconds'] == 16 and video['fps'] == 30 and video['frames'] == 480
assert video['silent'] and video['fullDecode'] == 'PASS' and video['fastStart'] == 'PASS'
assert video['productName'] == 'Loadlet' and video['runtimeVersion'] == '2.8.1'
# The film remains a labeled historical release, never current-source evidence.
film_revision = '84ede6bbd8354d5e718f6700f95202e73c4e85d7'
def film_sha(name):
    return hashlib.sha256(subprocess.check_output(['git', '-C', str(root), 'show', f'{film_revision}:{name}'])).hexdigest()
for name, item in video['outputs'].items():
    data = (root / 'docs/video' / name).read_bytes()
    assert len(data) == item['bytes'] and hashlib.sha256(data).hexdigest() == item['sha256'], name
for name, expected in video['sourceHashes'].items():
    assert sha(root / name) == expected, name
inline = video['readmeAnimation']
assert inline['path'] == 'docs/video/loadlet.webp' and inline['source'] == 'docs/video/loadlet.mp4'
assert inline['sourceSha256'] == video['outputs']['loadlet.mp4']['sha256']
readme = (root / 'README.md').read_text()
assert 'PavelLizunov/omarchy-loadlet' in readme
assert 'activity-lite.webp' not in readme and 'Repository remains private' not in readme
install = 'omarchy plugin add https://github.com/PavelLizunov/omarchy-loadlet.git --enable'
assert install in readme and readme.index(install) < readme.index('## Use')
assert '/releases)' in '\n'.join(readme.splitlines()[:12])
assert len(readme.splitlines()) <= 100
user_install = readme.split('## Install\n', 1)[1].split('## Use', 1)[0]
assert 'make -' not in user_install and 'no compiler, make' in user_install
assert 'docs/binary-provenance.md' in user_install
assert 'Optional system controls' in readme and '24-hour' in readme
assert 'removal procedure' in readme and 'unsandboxed' in readme
assert '[README install command](../README.md#install)' in (root / 'docs/guide.md').read_text()
animation = (root / inline['path']).read_bytes()
assert len(animation) == inline['bytes'] and hashlib.sha256(animation).hexdigest() == inline['sha256']
assert animation[:4] == b'RIFF' and animation[8:12] == b'WEBP'
assert int.from_bytes(animation[4:8], 'little') + 8 == len(animation)
offset, duration, frames, loop = 12, 0, 0, None
while offset < len(animation):
    kind = animation[offset:offset + 4]
    size = int.from_bytes(animation[offset + 4:offset + 8], 'little')
    payload = animation[offset + 8:offset + 8 + size]
    assert len(payload) == size
    if kind == b'ANIM':
        loop = int.from_bytes(payload[4:6], 'little')
    if kind == b'ANMF':
        duration += int.from_bytes(payload[12:15], 'little')
        frames += 1
    offset += 8 + size + size % 2
assert offset == len(animation) and loop == 0 and frames == inline['encodedFrames']
assert frames > 1 and duration == inline['durationMs'] and abs(duration - 16000) <= 1
assets = json.loads((root / 'docs/video/assets/manifest.json').read_text())
assert assets['runtimeVersion'] == video['runtimeVersion'] and assets['productName'] == 'Loadlet'
for name, item in assets['assets'].items():
    assert sha(root / 'docs/video/assets' / name) == item['sha256'], name
for name, expected in assets['sourceHashes'].items():
    assert film_sha(name) == expected, name
assert 'historical' in (root / 'docs/video/README.md').read_text().lower()
panel = (root / 'Panel.qml').read_text()
assert f'iconRevision: "{m["version"]}"' in panel and 'productName: "Loadlet"' in panel
assert 'rightClickAction: "none"' in panel
assert 'if (buttonCode === Qt.LeftButton) root.toggle()' in panel
print('PASS Loadlet package: stable ID, defaults, source-pinned screenshots and historical film')
