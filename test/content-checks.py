"""Finite byte/metadata heuristic over all working files and local Git objects."""
from collections import Counter
from pathlib import Path
import gzip
import hashlib
import importlib.util
import io
import json
import subprocess
import sys
import tarfile
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
MAX_ITEMS = 2000
MAX_ITEM = 64 * 1024 * 1024
MAX_TOTAL = 256 * 1024 * 1024
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('sensitive', ROOT / 'test/sensitive-checks.py')
sensitive = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sensitive)


def run(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], timeout=15)


def inspect(data, location, budget=None, depth=0):
    if budget is None:
        budget = [0, 0]
    budget[0] += len(data)
    budget[1] += 1
    assert len(data) <= MAX_ITEM and budget[0] <= MAX_TOTAL, 'Content byte budget exceeded'
    assert depth <= 2 and budget[1] <= MAX_ITEMS * 4, 'Content item/depth budget exceeded'
    matches = []
    texts = [('latin1', data.decode('latin1'))]
    for encoding in ['utf-16-le', 'utf-16-be']:
        for offset in [0, 1]:
            texts.append((encoding + ':' + str(offset), data[offset:].decode(encoding, errors='ignore')))
    for encoding, text in texts:
        matches.extend({'kind': kind, 'location': location, 'encoding': encoding, 'line': line}
                       for kind, line in sensitive.findings(text))
    embedded = []
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        offset, ended = 8, False
        while offset < len(data):
            assert offset + 12 <= len(data), 'Truncated PNG'
            size = int.from_bytes(data[offset:offset+4], 'big')
            kind = data[offset+4:offset+8]
            end = offset + 12 + size
            assert end <= len(data) and not ended, 'Invalid PNG chunk/tail'
            chunk = data[offset+8:offset+8+size]
            assert zlib.crc32(kind + chunk) == int.from_bytes(data[end-4:end], 'big'), 'PNG CRC mismatch'
            if kind in [b'zTXt', b'iTXt']:
                _, payload = chunk.split(b'\0', 1)
                if kind == b'zTXt':
                    assert payload[0] == 0
                    compressed, value = 1, payload[1:]
                else:
                    compressed, method = payload[:2]
                    assert compressed in [0, 1] and method == 0
                    _, _, value = payload[2:].split(b'\0', 2)
                if compressed:
                    decoder = zlib.decompressobj()
                    value = decoder.decompress(value, MAX_ITEM + 1)
                    assert len(value) <= MAX_ITEM and decoder.eof and not decoder.unused_data
                embedded.append((kind.decode(), value))
            elif kind in [b'tEXt', b'eXIf']:
                embedded.append((kind.decode(), chunk))
            ended = kind == b'IEND'
            offset = end
        assert ended and offset == len(data), 'Uninspected/incomplete PNG'
    if data[:4] == b'PK\x03\x04':
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            members = archive.infolist()
            assert len(members) <= MAX_ITEMS
            assert sum(member.file_size for member in members) <= MAX_TOTAL - budget[0]
            for member in members:
                assert member.file_size <= MAX_ITEM and not member.flag_bits & 1, 'Encrypted/large archive'
                if not member.is_dir():
                    embedded.append(('zip-member', archive.read(member)))
                    embedded.append(('zip-name', member.filename.encode('utf-8')))
    elif data[:2] == b'\x1f\x8b':
        with gzip.GzipFile(fileobj=io.BytesIO(data)) as archive:
            value = archive.read(MAX_ITEM + 1)
        assert len(value) <= MAX_ITEM
        embedded.append(('gzip-payload', value))
    elif len(data) > 265 and data[257:262] == b'ustar':
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as archive:
            for index, member in enumerate(archive):
                assert index < MAX_ITEMS and member.size <= MAX_ITEM
                embedded.append(('tar-name', member.name.encode('utf-8')))
                if member.isfile():
                    embedded.append(('tar-member', archive.extractfile(member).read(MAX_ITEM + 1)))
                assert sum(len(value) for _, value in embedded) <= MAX_TOTAL - budget[0]
    nested = len(embedded)
    for name, value in embedded:
        found, count = inspect(value, location + '/' + name, budget, depth + 1)
        matches.extend(found)
        nested += count
    return matches, nested


def controls():
    token = ('ghp_' + 'A' * 36).encode()
    for value in [token, b'\0' * 9000 + token, token.decode().encode('utf-16-le'),
                  token.decode().encode('utf-16-be'), b'X' + token.decode().encode('utf-16-le')]:
        assert inspect(value, 'synthetic-control')[0]
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as handle:
        handle.writestr('fixture.txt', token)
    assert inspect(archive.getvalue(), 'synthetic-archive')[0]
    assert inspect(gzip.compress(token), 'synthetic-gzip')[0]
    def chunk(kind, value):
        return len(value).to_bytes(4, 'big') + kind + value + zlib.crc32(kind + value).to_bytes(4, 'big')
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'zTXt', b'fixture\0\0' + zlib.compress(token))
           + chunk(b'IEND', b''))
    assert inspect(png, 'synthetic-png-metadata')[0]
    for malformed in [png[:-1], png + b'uninspected tail']:
        try:
            inspect(malformed, 'malformed-png')
        except AssertionError:
            pass
        else:
            raise AssertionError('Malformed PNG was accepted')
    raw_tar = io.BytesIO()
    with tarfile.open(fileobj=raw_tar, mode='w') as handle:
        member = tarfile.TarInfo('fixture.txt')
        member.size = len(token)
        handle.addfile(member, io.BytesIO(token))
    assert inspect(raw_tar.getvalue(), 'synthetic-tar')[0]
    assert not inspect(b'benign fixture', 'benign')[0]
    for data, budget in [(b'benign', [MAX_TOTAL, 0]), (b'benign', [0, MAX_ITEMS * 4])]:
        try:
            inspect(data, 'over-budget', budget)
        except AssertionError:
            pass
        else:
            raise AssertionError('Content budget was ignored')


def main():
    args = sys.argv[1:]
    root = ROOT
    if args[:1] == ['--root']:
        root = Path(args[1]).resolve(strict=True)
        args = args[2:]
    assert args == [] or len(args) == 2 and args[0] == '--report', 'Usage: content-checks.py [--root PATH] [--report NEW_EXTERNAL_PATH]'
    controls()
    listed = run(root, 'ls-files', '-c', '-o', '--exclude-standard', '-z')
    ignored = run(root, 'ls-files', '-o', '-i', '--exclude-standard', '-z')
    ignored_paths = {name for name in ignored.decode().split('\0') if name}
    paths = sorted({name for name in listed.decode().split('\0') if name} | ignored_paths)
    assert 0 < len(paths) <= MAX_ITEMS and sensitive.REQUIRED <= set(paths), 'Empty/incomplete selection'
    files, objects, matches, total, embedded, budget = [], [], [], 0, 0, [0, 0]
    for name in paths:
        assert not Path(name).is_absolute() and '..' not in Path(name).parts
        path = root / name
        assert path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(root)
        assert path.stat().st_size <= MAX_ITEM
        data = path.read_bytes()
        total += len(data)
        found, nested = inspect(data, name, budget)
        name_matches, _ = inspect(name.encode(), 'current-path-metadata', budget)
        matches.extend(found + name_matches)
        embedded += nested
        files.append({'path': name, 'bytes': len(data), 'binary': b'\0' in data[:8192],
                      'ignored': name in ignored_paths, 'sha256': hashlib.sha256(data).hexdigest()})
    metadata = run(root, 'cat-file', '--batch-all-objects', '--batch-check=%(objectname) %(objecttype) %(objectsize)').decode().splitlines()
    assert 0 < len(metadata) <= MAX_ITEMS
    object_summary, object_bytes = Counter(), 0
    for row in metadata:
        sha, kind, size = row.split()
        assert kind in ['blob', 'tree', 'commit', 'tag'] and int(size) <= MAX_ITEM
        data = run(root, 'cat-file', kind, sha)
        assert len(data) == int(size)
        object_bytes += len(data)
        found, nested = inspect(data, 'git:' + sha, budget)
        matches.extend(found)
        embedded += nested
        object_summary[kind] += 1
        objects.append({'oid': sha, 'type': kind, 'bytes': len(data)})
    refs = run(root, 'for-each-ref', '--format=%(refname) %(objectname)')
    ref_matches, _ = inspect(refs, 'git-ref-metadata', budget)
    matches.extend(ref_matches)
    shallow = run(root, 'rev-parse', '--is-shallow-repository').decode().strip() == 'true'
    assert not shallow, 'Shallow history: use a complete local checkout, not partial coverage'
    result = {'currentFiles': len(files), 'currentBytes': total,
              'binaryFiles': sum(item['binary'] for item in files), 'ignoredFiles': len(ignored_paths), 'excludedFiles': 0,
              'gitObjects': dict(object_summary), 'gitObjectBytes': object_bytes,
              'shallowRepository': shallow, 'embeddedPayloads': embedded,
              'totalInspectedBytesIncludingMetadata': budget[0],
              'files': files, 'objects': objects, 'findings': matches,
              'limits': ['pattern/format checks, not universal security or privacy proof',
                         'all locally available objects; remote-hidden/deleted objects remain unknown',
                         'ZIP/gzip/tar/PNG text payloads bounded; other compression/encryption not decoded',
                         'image pixels/ELF runtime behavior need separate consumers; Git config/reflog text not scanned']}
    if args:
        destination = Path(args[1]).resolve()
        assert not destination.is_relative_to(root)
        with destination.open('x', encoding='utf-8') as output:
            json.dump(result, output, indent=2)
            output.write('\n')
    # Location values remain in the private receipt, not in terminal reports.
    if matches:
        print('SENSITIVE categories (values/locations withheld):', dict(Counter(item['kind'] for item in matches)))
    print(f'{"FAIL" if matches else "PASS"} complete content heuristic: {len(files)} current files, '
          f'{total} bytes, {len(ignored_paths)} ignored included, 0 exclusions; '
          f'{dict(object_summary)} Git objects/{object_bytes} bytes; '
          f'{embedded} embedded payloads; shallow={shallow}; {len(matches)} findings; '
          'byte/NUL/unaligned UTF16/archive/benign/budget controls PASS')
    raise SystemExit(bool(matches))


if __name__ == '__main__':
    main()
