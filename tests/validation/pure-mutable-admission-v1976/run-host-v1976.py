#!/usr/bin/env python3
"""TX2 flag interoperability with real linker, converters and FS writers."""
import os
import struct
import subprocess
import tempfile
from pathlib import Path

prefix = Path(os.environ.get('PDP10_PREFIX', str(Path.home() / 'cross')))
base = Path(os.environ.get('TMPDIR', str(Path.home() / 'tmp')))
base.mkdir(parents=True, exist_ok=True)
work = Path(tempfile.mkdtemp(prefix='pure-mutable-host-v1976.', dir=base))
tools = Path(os.environ.get('DAIMOS_HOST_BIN', str(prefix / 'bin')))
das_tools = Path(os.environ.get('DAS_HOST_BIN', str(prefix / 'bin')))


def run(tool, *args, bad=False):
    p = subprocess.run([str(tool), *map(str, args)], capture_output=True,
                       text=True)
    if (p.returncode != 0) != bad:
        raise AssertionError((tool, args, p.returncode, p.stdout, p.stderr))
    if bad:
        assert p.stderr, (tool, args)
    return p


def words(path):
    data = path.read_bytes()
    return list(struct.unpack('<' + 'Q' * (len(data) // 8), data))


def put(path, data):
    path.write_bytes(struct.pack('<' + 'Q' * len(data), *data))


print('v1976 host evidence:', work, flush=True)
asm = work / 'minimal.s'
asm.write_text('.text\n.globl start\nstart:\n jrst .\n .block 037\n')
obj = work / 'minimal.dobj'
run(prefix / 'bin/das', '-C', '-O', obj, asm)
plain, marked = work / 'plain.dxr', work / 'marked.dxr'
run(tools / 'dlink', '-b', '020', '-o', plain, obj)
run(tools / 'dlink', '-b', '020', '--compressible-mutable', '-o', marked, obj)
a, b = words(plain), words(marked)
assert len(a) == len(b) and a[:2] == b[:2] and a[3:] == b[3:]
assert b[2] == (a[2] | (0o400000 << 18))
for extra in ('--rt-required', '--xip'):
    run(tools / 'dlink', '-b', '020', '--pure', '--compressible-mutable',
        extra, '-o', work / 'invalid.dxr', obj, bad=True)
# Converters must ignore the metadata flag when producing a raw image.
for p in (plain, marked):
    run(das_tools / 'dxrcheck', p)
    run(das_tools / 'dxrconvert', '--simh', '-b', '020', p,
        p.with_suffix('.abs'))
assert plain.with_suffix('.abs').read_bytes() == marked.with_suffix('.abs').read_bytes()
compressed = work / 'marked-compressed.dxr'
run(tools / 'd6block-v1452', '-x', marked, compressed)
c = words(compressed)
assert c[2] == b[2] and c[1] == (b[1] | 0o100000)
assert c[-1] == b[-1]
# Valid plain and compressed variants survive the real INITFS encoder.
for p in (plain, marked, compressed):
    out = p.with_suffix('.words')
    run(tools / 'mkinitfs0', '--format', 'words', '-o', out,
        '/SYSTEM/INIT:' + str(p) + ':555:dxr')
    n = len(words(p))
    assert [int(x, 8) for x in out.read_text().splitlines()[-n:]] == words(p)
# Malformed text count and marked RT are rejected, even with COMPRESSED.
for tag, mutate in [('text', lambda x: (x[1] >> 18) + 1), ('rt', None)]:
    for p in (marked, compressed):
        bad = work / (tag + '-' + p.name)
        z = words(p)
        if mutate:
            z[2] = ((0o400000 | mutate(z)) << 18) | 0o647022
        else:
            z[1] |= 0o400000
        put(bad, z)
        run(tools / 'mkinitfs0', '--format', 'words', '-o', bad.with_suffix('.words'),
            '/SYSTEM/INIT:' + str(bad) + ':555:dxr', bad=True)
        if p == marked:
            run(das_tools / 'dxrcheck', bad, bad=True)
            run(das_tools / 'dxrconvert', '--simh', '-b', '020', bad,
                bad.with_suffix('.abs'), bad=True)
            run(tools / 'd6block-v1452', '-x', bad, bad.with_suffix('.cx'), bad=True)
        # Real D6FS image writer, not a stand-in decoder.
        disk = work / (bad.stem + '-disk')
        disk.mkdir()
        boot = work / 'boot.words'
        boot.write_text('0\n')
        run(prefix / 'bin/mkdsk', '-n', '1', '-m', 'clean', '-p', boot,
            '-o', disk, '--d6fs-layout', '--logstore-blocks', '010',
            '--swap-tail-blocks', '010')
        failure = run(tools / 'mkd6fs', '-n', '1', '-d', disk, '-D', '/SYSTEM:0755',
                      '-f', '/SYSTEM/INIT:' + str(bad) + ':555:dxr', bad=True)
        assert ('invalid text metadata' in failure.stderr or
                'valid DXR2 metadata' in failure.stderr or
                'RT_REQUIRED cannot be mutable-compressible' in failure.stderr), failure.stderr
# Positive D6FS image writer accepts both payload encodings together.
disk = work / 'valid-disk'
disk.mkdir()
run(prefix / 'bin/mkdsk', '-n', '1', '-m', 'clean', '-p', work / 'boot.words',
    '-o', disk, '--d6fs-layout', '--logstore-blocks', '010', '--swap-tail-blocks', '010')
run(tools / 'mkd6fs', '-n', '1', '-d', disk, '-D', '/SYSTEM:0755',
    '-f', '/SYSTEM/INIT:' + str(marked) + ':555:dxr',
    '-f', '/SYSTEM/COMP:' + str(compressed) + ':555:dxr')
print('PASS: host TX2 marker, unchanged payload/relocation, valid and invalid FS images')
