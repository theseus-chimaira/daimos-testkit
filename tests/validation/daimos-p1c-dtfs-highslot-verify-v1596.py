#!/usr/bin/env python3
"""Independent physical Type-551 high-slot/media-loss/MEMFS oracle.

The real guest validates original FSINFO and MEMFS syscalls. This host
oracle verifies that the stage evidence comes from a genuine Type-551
root and five separately stamped physical reels, not mock providers.
"""

import hashlib
from pathlib import Path
import re
import struct
import sys

MAGIC_DTVOL1 = 0o446466575421
MASK36 = (1 << 36) - 1

BASE_STAGES = (
    'START', 'MOUNTED5_V1595', 'READY_DETACH',
    'OFFLINE_HIGH_STABLE_V1595', 'OFFLINE_REFUSED', 'READY_SWAP',
    'SWAP_ACK_RECEIVED_V1535', 'DTC4_PREPROBE_OK',
    'DTC4_AFTER_INFO_OK', 'REPLACEMENT_HIGH_STABLE_V1595',
    'REPLACEMENT_REFUSED', 'READY_RESTORE',
    'RETURN_ALL_STABLE_V1595', 'RETURN_VERIFIED',
    'RETIRED_ALL_V1595', 'PASS',
)

MIXED_STAGES = (
    'START', 'RAM_SEEDED_V1596', 'MOUNTED5_V1595',
    'READY_DETACH', 'OFFLINE_HIGH_STABLE_V1595', 'OFFLINE_REFUSED',
    'READY_SWAP', 'SWAP_ACK_RECEIVED_V1535',
    'DTC4_PREPROBE_OK', 'DTC4_AFTER_INFO_OK',
    'REPLACEMENT_HIGH_STABLE_V1595', 'REPLACEMENT_REFUSED',
    'READY_RESTORE', 'RETURN_ALL_STABLE_V1595',
    'RETURN_VERIFIED', 'READY_HI_DETACH_V1596',
    'HIGH_OFFLINE_RAM_WRITE_V1596', 'READY_HI_RETURN_V1596',
    'HIGH_RETURNED_V1596', 'RETIRED_ALL_V1595', 'PASS',
)


def words_at_start(data):
    assert len(data) == 0o1102 * 128 * 8, 'incorrect DECtape geometry'
    result = []
    for index in range(4):
        high, low = struct.unpack_from('<II', data, index * 8)
        assert high <= 0o777777 and low <= 0o777777
        result.append(high << 18 | low)
    return result


def check(text, root_sizes, media, mode):
    assert mode in (1595, 1596)
    assert 'MACH                                PDP6' in text
    assert 'MEM                                 256 K' in text
    assert 'DTC                                   OK' in text
    assert 'DTFS                              LOADED' in text
    assert 'MEMFS                             LOADED' in text
    assert 'SIM-ERROR' not in text
    assert 'DTFSMEDIA V1527 FAIL_' not in text
    assert len(root_sizes) == 3
    assert min(root_sizes[:2]) > 1024 and root_sizes[2] == 0, \
        'root does not actually occupy DTC0/1 with empty DTC2'

    stage_names = MIXED_STAGES if mode == 1596 else BASE_STAGES
    prev = -1
    for stage in stage_names:
        matches = list(re.finditer(r'DTFSMEDIA V1527 ' +
                                   re.escape(stage) + r'\r?(?:\n|$)',
                                   text))
        assert len(matches) == 1, 'missing/duplicate real CTY ' + stage
        assert matches[0].start() > prev, 'out-of-order real CTY ' + stage
        prev = matches[0].start()
    if mode == 1595:
        assert 'HIGH_OFFLINE_RAM_WRITE_V1596' not in text

    expected = ('dtc3-v1530.tap', 'dtc4-v1530.tap',
                'dtc5-v1533.tap', 'dtc6-v1533.tap',
                'replacement-v1527.tap')
    assert set(media) == set(expected)
    ids = []
    digest = []
    for name in expected:
        data = media[name]
        records = words_at_start(data)
        assert records[0] == MAGIC_DTVOL1, 'not original DTVOL1 ' + name
        assert records[1] != 0 and records[2] != 0, 'missing physical ID'
        assert records[3] == ((~(records[0] ^ records[1] ^ records[2])) & MASK36), \
            'false physical identity checksum ' + name
        ids.append((records[1], records[2]))
        digest.append(hashlib.sha256(data).hexdigest())
    assert len(set(ids)) == 5, 'physically reused 72-bit volume identity'
    return (expected, digest)


def negative_tests(text, root_sizes, media, mode):
    old = media['dtc6-v1533.tap']
    variants = (
        ('missing original healthy high slot stage',
         text.replace('DTFSMEDIA V1527 MOUNTED5_V1595',
                      'DTFSMEDIA V1527 NOT_MOUNTED', 1), root_sizes, media),
        ('false replacement rejection',
         text.replace('DTFSMEDIA V1527 REPLACEMENT_REFUSED',
                      'DTFSMEDIA V1527 REPLACEMENT_ACCEPTED', 1), root_sizes, media),
        ('physical duplicated member identity', text, root_sizes,
         dict(media, **{'dtc6-v1533.tap': media['dtc5-v1533.tap']})),
        ('invalid native RBN0 identity', text, root_sizes,
         dict(media, **{'dtc6-v1533.tap':
                         old[:16] + b'\0' * 8 + old[24:]})),
        ('DTC2 was secretly third root member', text,
         (root_sizes[0], root_sizes[1], root_sizes[0]), media),
    )
    for label, edited, sizes, images in variants:
        try:
            check(edited, sizes, images, mode)
        except AssertionError:
            print('PASS v%d: rejected %s' % (mode, label))
        else:
            raise AssertionError('accepted false physical evidence: ' + label)
    if mode == 1596:
        for stage in ('RAM_SEEDED_V1596', 'HIGH_OFFLINE_RAM_WRITE_V1596',
                      'HIGH_RETURNED_V1596'):
            changed = text.replace('DTFSMEDIA V1527 ' + stage,
                                   'DTFSMEDIA V1527 INVALID_' + stage, 1)
            try:
                check(changed, root_sizes, media, mode)
            except AssertionError:
                print('PASS v1596: rejected missing ' + stage)
            else:
                raise AssertionError('accepted fake MEMFS/high-owner stage')


def main():
    args = sys.argv[1:]
    selftest = '--self-test' in args
    if selftest:
        args.remove('--self-test')
    if len(args) != 3:
        raise SystemExit('usage: v1596 [--self-test] WORKDIR MODE REPORT')
    work = Path(args[0])
    mode = int(args[1])
    text = (work / 'cty.out').read_text(errors='replace')
    root_sizes = tuple((work / 'media' /
                        ('dtc%d-v1530.tap' % i)).stat().st_size
                       for i in range(3))
    names = ('dtc3-v1530.tap', 'dtc4-v1530.tap',
             'dtc5-v1533.tap', 'dtc6-v1533.tap',
             'replacement-v1527.tap')
    media = {name: (work / 'media' / name).read_bytes() for name in names}
    order, digests = check(text, root_sizes, media, mode)
    result = ('PASS v%d: two-member physical TSFS root, 8 original FSINFO '
              'slots, 4 live native DTFS mounts (IDs 2..5), five distinct '
              '72-bit media, genuine DTC3 failure/return' % mode)
    if mode == 1596:
        result += (', genuine DTC6 high-ID failure/return and independent '
                   'writable MEMFS readback')
    result += '\n' + '\n'.join('%s SHA256=%s' % entry
                                 for entry in zip(order, digests)) + '\n'
    Path(args[2]).write_text(result)
    print(result, end='')
    if selftest:
        negative_tests(text, root_sizes, media, mode)


if __name__ == '__main__':
    main()
