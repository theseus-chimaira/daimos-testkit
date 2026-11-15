#!/usr/bin/env python3
"""Physical DRM-root / absent DSK service and exact KCORE FSINFO oracle.

The supplied data is collected from an actual completed PDP-6 guest:
original preboot member descriptors, four postboot DRM image RBN0s,
the simulator's private controller configuration and post-HALT linked
KCORE mount words.  Never substitute a synthetic capacity for a guest
FSINFO syscall result.
"""

from pathlib import Path
import re
import struct
import sys

MASK36 = (1 << 36) - 1
DRIVE_HEADER = 0o444243000000
D6FSR2 = 0o442654636222
MARKER = 'P1D-D6FS-NODSK-CAPACITY2-V1601'
WITNESSES = (
    'vfs_mount_limit', 'vfs_mount_root_base',
    'vfs_mount_target_base', 'vfs_namespace_root',
)


def symbols(source):
    parsed = {}
    for key, address in re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$',
                                   source):
        assert key not in parsed, 'duplicated KCORE label ' + key
        parsed[key] = int(address, 8)
    return parsed


def check(console, ini, mapping, addresses, headers, original, sizes):
    assert 'MACH                                PDP6' in console
    assert 'MEM                                 128 K' in console
    assert 'DRM236                                OK' in console
    assert 'DSK270                                OK' not in console, \
        'unavailable controller unexpectedly installed'
    assert 'BSET                              LOADED' in console
    assert 'D6FS                              LOADED' in console
    assert 'MEMFS                             LOADED' in console
    assert MARKER in console
    assert 'XIP-RUN-PASS' in console and 'STATUS:0' in console
    assert 'XIP-FAIL-' not in console
    assert 'SIM-ERROR' not in console
    assert 'Sockets: bind error' not in console
    assert console.count('HALT instruction, PC:') == 1

    lines = ini.splitlines()
    assert lines.count('deposit SW 3') == 1, 'not real DRM-selected boot'
    assert lines.count('set dsk disabled') == 1
    assert lines.count('set dp enabled') == 1
    assert lines.count('set dr enabled') == 1
    assert not any(re.match(r'attach -q dsk[0-3] ', line, re.I)
                   for line in lines), 'DSK images accidentally attached'
    assert len([line for line in lines if re.match(
        r'attach -q dr[0-3] ', line, re.I)]) == 4

    linked = symbols(mapping)
    captured = symbols(addresses)
    posthalt = console.split('HALT instruction, PC:', 1)[1]
    values = {}
    for key in WITNESSES:
        assert key in linked and captured.get(key) == linked[key], \
            'stale or absent linked KCORE word ' + key
        expression = r'(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$' % linked[key]
        found = re.findall(expression, posthalt)
        assert len(found) == 1, 'missing actual post-HALT KCORE ' + key
        values[key] = int(found[0], 8)
    assert values['vfs_mount_limit'] == 2, 'phantom mount slots'
    for key in ('vfs_mount_root_base', 'vfs_mount_target_base'):
        assert 0 < values[key] < 0o400000, \
            'unpublished/out-of-range real MM VFS slab ' + key
    assert values['vfs_mount_root_base'] != \
        values['vfs_mount_target_base'], 'two mount arrays overlap'
    assert values['vfs_namespace_root'] >> 24 == 0o601, \
        'selected root is not the original D6FS namespace'

    assert len(headers) == len(sizes) == 4
    assert len(original) == 4 * 1024
    units = set()
    geometry = set()
    for unit, (header, size) in enumerate(zip(headers, sizes)):
        assert size == 8192 * 1024, 'not genuine Type-236 member size'
        assert len(header) == 128
        assert all(0 <= word <= MASK36 for word in header)
        assert struct.pack('<128Q', *header) == \
            original[unit * 1024:(unit + 1) * 1024], \
            'original root member RBN0 was overwritten'
        assert header[0] == DRIVE_HEADER
        assert header[6] == D6FSR2, 'not authentic D6FSR2 root'
        assert header[5] not in units, 'reused original root member ID'
        units.add(header[5])
        base = (header[7] >> 18) & 0o777777
        data = header[7] & 0o777777
        tail = header[10]
        assert base >= 1 and data > 0 and tail > 0
        assert base + data + tail <= size // 1024
        geometry.add((base, data, tail))
    assert len(geometry) == 1, 'inconsistent physical root geometry'
    return values, next(iter(geometry))


def reject_mutants(inputs):
    console, ini, mapping, addresses, headers, original, sizes = inputs
    data = [list(h) for h in headers]
    data[2][6] = 0
    bad_id = [list(h) for h in headers]
    bad_id[3][5] = bad_id[0][5]
    linked = symbols(addresses)
    address = linked['vfs_mount_limit']
    pattern = (r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$') % address
    assert len(re.findall(pattern, console)) == 1
    bad_capacity = re.sub(pattern,
                          lambda m: m.group(1) + '000000000006' + m.group(3),
                          console, count=1)
    no_ptr_addr = linked['vfs_mount_root_base']
    patptr = (r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$') % no_ptr_addr
    assert len(re.findall(patptr, console)) == 1
    bad_ptr = re.sub(patptr,
                     lambda m: m.group(1) + '000000000000' + m.group(3),
                     console, count=1)
    variants = (
        ('invalid real DRM root marker',
         (console, ini, mapping, addresses, data, original, sizes)),
        ('duplicate DRM physical member identity',
         (console, ini, mapping, addresses, bad_id, original, sizes)),
        ('missing real FSINFO guest result',
         (console.replace(MARKER, 'P1D-NODSK-ABSENT', 1), ini,
          mapping, addresses, headers, original, sizes)),
        ('invented DSK MINIT success',
         (console.replace('DRM236                                OK',
                          'DSK270                                OK\n'
                          'DRM236                                OK', 1), ini,
          mapping, addresses, headers, original, sizes)),
        ('DSK controller still enabled',
         (console, ini.replace('set dsk disabled', 'set dsk enabled', 1),
          mapping, addresses, headers, original, sizes)),
        ('selected wrong root class',
         (console, ini.replace('deposit SW 3', 'deposit SW 1', 1),
          mapping, addresses, headers, original, sizes)),
        ('false linked capacity six',
         (bad_capacity, ini, mapping, addresses, headers, original, sizes)),
        ('missing actual MM mount slab',
         (bad_ptr, ini, mapping, addresses, headers, original, sizes)),
        ('wrong physical DRM root RBN0',
         (console, ini, mapping, addresses, headers,
          b'\0' * 1024 + original[1024:], sizes)),
        ('no original guest XIP completion',
         (console.replace('XIP-RUN-PASS', 'XIP-RUN-FAIL', 1), ini,
          mapping, addresses, headers, original, sizes)),
    )
    for name, data in variants:
        try:
            check(*data)
        except (AssertionError, KeyError):
            print('PASS v1601: rejected ' + name)
        else:
            raise AssertionError('accepted corrupted physical service: ' + name)


def main():
    args = sys.argv[1:]
    negatives = '--self-test' in args
    if negatives:
        args.remove('--self-test')
    if len(args) != 4:
        raise SystemExit('usage: v1601 [--self-test] LOG BOOT_INI DRUM_DIR REPORT')
    log, ini, disk, report = (Path(s) for s in args)
    root = ini.parent
    mapping = (root / 'kcore.map').read_text()
    addresses = (root / 'v1601-linked-addresses.txt').read_text()
    original = (root / 'v1601-original-drm-descriptors.bin').read_bytes()
    headers = []
    sizes = []
    for unit in range(4):
        image = disk / ('dsk%d.dsk' % unit)
        with image.open('rb') as stream:
            words = struct.unpack('<128Q', stream.read(1024))
        headers.append(words)
        sizes.append(image.stat().st_size)
    inputs = (log.read_text(errors='replace'), ini.read_text(),
              mapping, addresses, headers, original, sizes)
    values, geometry = check(*inputs)
    message = ('PASS v1601: genuine DRM236 four-member root, Type-136 '
               'DSK270 absent, original linked FSINFO capacity %d, '
               'two separate MM mount arrays, each physical root size '
               '%d sectors, base %06o data %06o tail %06o; '
               'original XIP lifecycle PASS\n' %
               (values['vfs_mount_limit'], sizes[0] // 1024, *geometry))
    report.write_text(message)
    print(message, end='')
    if negatives:
        reject_mutants(inputs)


if __name__ == '__main__':
    main()
