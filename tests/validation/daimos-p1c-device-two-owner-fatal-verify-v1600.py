#!/usr/bin/env python3
"""Independent root DSK270 + direct DRM0 AUXSTORE fatal swap oracle.

Reuse v1599's original PI6/PI2/owner/fatal physical tests, but require
the separate direct-device translation, real raw AUXSTORE descriptor,
and four physically independent D6FSR2 DSK270 root members. No fake
VOLUME descriptors or converted logical-only media evidence allowed.
"""

import importlib.util
from pathlib import Path
import re
import struct
import sys


def imported(name, tag):
    path = Path(__file__).with_name(name)
    spec = importlib.util.spec_from_file_location(tag, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


MASK36 = (1 << 36) - 1
DRIVE_HEADER = 0o444243000000
D6FSR2 = 0o442654636222
AUXSTORE_MAGIC = 0o416570636421


def check(mapping, a4, a5, a6, a2, log, media, layout, disks):
    old = imported('daimos-p1c-two-owner-fatal-verify-v1599.py',
                   'direct_original_fault_v1600')
    assert len(media) == 8192 * 1024, 'not a real 8192-sector DRM0 image'
    assert 'DSK270                                OK' in log
    assert 'DRM236                                OK' in log
    assert 'D6FS                              LOADED' in log
    assert 'MEMFS                             LOADED' in log
    assert not any(marker in log for marker in
                   ('SIM-ERROR', 'Sockets: bind error', 'XIP-FAIL-'))
    assert len(disks) == 4
    units = set()
    geometry = set()
    for size, words in disks:
        assert size > 8192 * 1024 and size % 1024 == 0
        assert len(words) == 128 and all(word <= MASK36 for word in words)
        assert words[0] == DRIVE_HEADER, 'not physical DSK270 unit'
        assert words[6] == D6FSR2, 'not original D6FSR2 root member'
        assert words[5] not in units, 'duplicated D6FS member identity'
        units.add(words[5])
        base = (words[7] >> 18) & 0o777777
        length = words[7] & 0o777777
        tail = words[10]
        assert base >= 1 and length >= 1 and tail >= 1
        assert base + length + tail <= size // 1024
        geometry.add((size, base, length, tail))
    assert len(geometry) == 1, 'inconsistent four-member root geometry'

    desc = struct.unpack_from('<128Q', media, 0)
    assert all(word <= MASK36 for word in desc)
    assert desc[0] == AUXSTORE_MAGIC and desc[1] == 1
    backing_base = (desc[2] >> 18) & 0o777777
    backing_count = desc[2] & 0o777777
    log_base = (desc[3] >> 18) & 0o777777
    log_count = desc[3] & 0o777777
    assert backing_base > 0 and backing_count > 40
    assert log_base > 0 and log_count > 0
    assert backing_base + backing_count <= 8192
    assert log_base + log_count <= backing_base or \
        backing_base + backing_count <= log_base
    ranges = {}
    for line in layout.splitlines():
        found = re.fullmatch(r'(BACKSTORE|LOGSTORE|CACHESTORE) '
                             r'([0-7]+)\+([0-7]+)', line.strip())
        if found:
            key, start, count = found.groups()
            assert key not in ranges, 'repeated AUXSTORE layout line'
            ranges[key] = (int(start, 8), int(count, 8))
    assert ranges['BACKSTORE'] == (backing_base, backing_count)
    assert ranges['LOGSTORE'] == (log_base, log_count)
    assert 'CACHESTORE' in ranges

    fatal, unit, block, logical, occupied, owners, values = old.check(
        mapping, a4, a5, a6, a2, log, [media], media[:1024],
        direct_device=True)
    assert unit == 0
    assert logical == block - backing_base
    assert values['volume_data_blocks'] == 0
    assert values['backing_region_count'] == backing_count
    assert (values['device_region_map'] >> 18) & 0o400000
    assert ((values['device_region_map'] >> 18) & 0o200000) == 0
    return fatal, unit, block, logical, occupied, owners, values


def negative_tests(inputs):
    mapping, a4, a5, a6, a2, log, media, layout, disks = inputs
    old = imported('daimos-p1c-two-owner-fatal-verify-v1599.py',
                   'direct_owner_mutations_v1600')
    old.negative_tests((mapping, a4, a5, a6, a2, log, [media],
                        media[:1024]), direct_device=True)
    variants = []
    invalid = [(size, list(h)) for size, h in disks]
    invalid[2][1][6] = 0
    variants.append(('invalid DSK270 root member',
                     (mapping, a4, a5, a6, a2, log, media,
                      layout, invalid)))
    invalid = [(size, list(h)) for size, h in disks]
    invalid[3][1][5] = invalid[0][1][5]
    variants.append(('duplicate DSK270 member identity',
                     (mapping, a4, a5, a6, a2, log, media,
                      layout, invalid)))
    variants.append(('invented mapped VOLUME geometry',
                     (mapping, a4, a5, a6, a2, log, media,
                      layout.replace('BACKSTORE ', 'VOLUME ', 1), disks)))
    corrupted = bytearray(media)
    struct.pack_into('<Q', corrupted, 0, 0)
    variants.append(('invalid physical AUXSTORE RBN0',
                     (mapping, a4, a5, a6, a2, log, bytes(corrupted),
                      layout, disks)))
    for label, data in variants:
        try:
            check(*data)
        except (AssertionError, KeyError):
            print('PASS v1600: rejected ' + label)
        else:
            raise AssertionError('accepted unsafe direct-DEVICE evidence: ' +
                                 label)


def main():
    args = sys.argv[1:]
    negatives = '--self-test' in args
    if negatives:
        args.remove('--self-test')
    if len(args) != 10:
        raise SystemExit('usage: v1600 [--self-test] MAP A4 A5 A6 A2 '
                         'SIMH_LOG DRM0 AUXSTORE_LAYOUT DSK_DIR REPORT')
    mapping, a4, a5, a6, a2, log = [
        Path(s).read_text(errors='replace') for s in args[:6]]
    media = Path(args[6]).read_bytes()
    layout = Path(args[7]).read_text()
    directory = Path(args[8])
    disks = []
    for unit in range(4):
        image = directory / ('dsk%d.dsk' % unit)
        with image.open('rb') as stream:
            words = struct.unpack('<128Q', stream.read(1024))
        disks.append((image.stat().st_size, words))
    inputs = (mapping, a4, a5, a6, a2, log, media, layout, disks)
    fatal, unit, block, logical, occupied, owners, values = check(*inputs)
    msg = ('PASS v1600: independent DSK270 root with four real D6FSR2 '
           'members, original two PI6 owner wakes %d/%d, selected slot %d, direct DEVICE '
           'DR%d block %06o -> BACKSTORE logical %06o, original fatal '
           '%06o, zero RESIDENT, %d nonzero independent backing sectors\n' %
           (owners['first_slot'], owners['second_slot'],
            values['daimos_v1584_last_slot'], unit,
            block, logical, fatal, occupied))
    Path(args[9]).write_text(msg)
    print(msg, end='')
    if negatives:
        negative_tests(inputs)


if __name__ == '__main__':
    main()
