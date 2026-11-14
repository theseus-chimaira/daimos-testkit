#!/usr/bin/env python3
"""Post-HALT physical verification of the selected snapshot PI2 failure.

This tool does not inject an error or infer one from a user diagnostic.
It requires the exact original KCORE BACKSTORE HALT, the linked
post-HALT controller witness words, and independent Type-236 media.
"""

from pathlib import Path
import re
import struct
import sys

WITNESSES = (
    'daimos_v1581_pi2_errors',
    'daimos_v1581_relative',
    'daimos_v1581_target_group',
    'daimos_v1581_target_descriptor',
    'daimos_v1581_arm',
    'backstore_blocks_used',
    'backstore_enabled',
    'mfsdev_storage_errors',
    'daimos_v1581_drm_errors',
)
MASK = (1 << 36) - 1
MAGIC = int('55464663', 8)


def symbols_from_text(source):
    symbols = {}
    for name, addr in re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$', source):
        if name in symbols:
            raise AssertionError('duplicate linked KCORE symbol ' + name)
        symbols[name] = int(addr, 8)
    return symbols


def check(mapping, addresses, transcript, raw, layout):
    symbols = symbols_from_text(mapping)
    linked = symbols_from_text(addresses)
    for name in WITNESSES:
        if name == 'daimos_v1581_drm_errors':
            assert name in linked, 'missing driver error offset'
            assert linked[name] == symbols['mfsdev_storage_errors'] + 5, \
                'stale DRM driver error index'
        else:
            assert name in symbols and name in linked, 'missing address ' + name
            assert symbols[name] == linked[name], 'stale address ' + name
    assert 'kcore_critical_device_lost_v1515' in symbols
    expected_pc = symbols['kcore_critical_device_lost_v1515'] + 7
    halt = re.findall(r'HALT instruction, PC: ([0-7]{6})', transcript)
    assert len(halt) == 1 and int(halt[0], 8) == expected_pc, \
        'missing real BACKSTORE critical HALT'
    assert 'XIP-FAIL-' not in transcript, 'failed user-side precondition'
    assert 'P1C-SWAP-HALT-REQUEST-V1580' in transcript
    after_halt = transcript.split('HALT instruction, PC:', 1)[1]

    values = {}
    for name in WITNESSES:
        addr = linked[name]
        pattern = r'(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$' % addr
        found = re.findall(pattern, after_halt)
        assert len(found) == 1, 'missing post-HALT physical ' + name
        values[name] = int(found[0], 8)
    assert values['daimos_v1581_pi2_errors'] == 1, 'not exactly one PI2 error'
    assert values['daimos_v1581_drm_errors'] == 1, \
        'original DRM error accounting did not record selected PI2 error'
    assert values['daimos_v1581_target_descriptor'] == 0, \
        'failed PI2 descriptor was not retired'
    assert values['daimos_v1581_arm'] == 0, 'pending unsent error marker'
    assert values['backstore_blocks_used'] > 0, \
        'no allocated backing at fatal HALT'
    assert values['backstore_enabled'] == 1, \
        'BACKSTORE was not active at snapshot failure'

    spans = [s.split() for s in layout.splitlines()]
    backing = [s[1] for s in spans if len(s) == 2 and s[0] == 'BACKSTORE']
    logging = [s[1] for s in spans if len(s) == 2 and s[0] == 'LOGSTORE']
    assert len(backing) == len(logging) == 1, 'missing AUXSTORE range'

    def decode(text):
        x, n = text.split('+')
        return int(x, 8), int(n, 8)

    start, count = decode(backing[0])
    logstart, logcount = decode(logging[0])
    assert logstart + logcount <= start or start + count <= logstart, \
        'critical partitions physically overlap'
    assert count >= 40 and len(raw) % 1024 == 0
    assert start + count <= len(raw) // 1024
    assert logstart + logcount <= len(raw) // 1024
    assert values['daimos_v1581_relative'] == count - 1, \
        'selected wrong snapshot BACKSTORE-relative block'
    physical = start + count - 1
    assert values['daimos_v1581_target_group'] == physical << 3, \
        'PI2 selected wrong drum hardware group'

    def sector(block):
        data = struct.unpack_from('<128Q', raw, block * 1024)
        assert all(value & ~MASK == 0 for value in data), \
            'not a real 36-bit physical sector'
        return data

    header = sector(physical)
    assert header[0] == 0, \
        'commit header unexpectedly valid after invalidation PI2 failure'
    assert header[0] != MAGIC
    occupied = sum(any(sector(b)) for b in range(start, physical))
    assert occupied >= 2, 'no physical lower backing payload'
    return expected_pc, physical, occupied, values


def selftest(data):
    mapping, addresses, transcript, raw, layout = data
    linked = symbols_from_text(addresses)
    after = transcript.split('HALT instruction, PC:', 1)[1]

    def swap_word(key, new_value):
        address = linked[key]
        pattern = r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$' % address
        found = re.findall(pattern, after)
        assert len(found) == 1, 'selftest witness absent: ' + key
        new_after = re.sub(pattern,
                           lambda m: m.group(1) + '%012o' % new_value +
                           m.group(3), after, count=1)
        return transcript.split('HALT instruction, PC:', 1)[0] + \
            'HALT instruction, PC:' + new_after

    fixtures = [
        ('no-controller-error',
         (mapping, addresses, swap_word('daimos_v1581_pi2_errors', 0),
          raw, layout)),
        ('no-production-driver-error-account',
         (mapping, addresses, swap_word('daimos_v1581_drm_errors', 0),
          raw, layout)),
        ('no-swap-owner',
         (mapping, addresses, swap_word('backstore_blocks_used', 0),
          raw, layout)),
        ('wrong-physical-group',
         (mapping, addresses, swap_word('daimos_v1581_target_group', 1),
          raw, layout)),
        ('pending-target-not-retired',
         (mapping, addresses,
          swap_word('daimos_v1581_target_descriptor', 7), raw, layout)),
        ('wrong-HALT-reason',
         (mapping, addresses, transcript.replace(
             'HALT instruction, PC: ', 'HALT instruction, PC: 000', 1),
          raw, layout)),
        ('fake-committed-header',
         (mapping, addresses, transcript,
          _mutate_header(raw, layout), layout)),
    ]
    for name, fixture in fixtures:
        try:
            check(*fixture)
        except AssertionError:
            print('PASS v1581: rejected ' + name)
        else:
            raise AssertionError('accepted corrupted witness ' + name)


def _mutate_header(raw, layout):
    spans = [s.split() for s in layout.splitlines()]
    backing = [s[1] for s in spans if len(s) == 2 and s[0] == 'BACKSTORE']
    assert len(backing) == 1
    start, count = (int(x, 8) for x in backing[0].split('+'))
    new = bytearray(raw)
    struct.pack_into('<Q', new, (start + count - 1) * 1024, MAGIC)
    return bytes(new)


def main():
    args = sys.argv[1:]
    do_selftest = '--self-test' in args
    if do_selftest:
        args.remove('--self-test')
    if len(args) != 6:
        raise SystemExit('usage: verifier [--self-test] MAP ADDRS LOG '
                         'DRUM LAYOUT REPORT')
    paths = [Path(p) for p in args]
    data = (paths[0].read_text(), paths[1].read_text(),
            paths[2].read_text(errors='replace'), paths[3].read_bytes(),
            paths[4].read_text())
    pc, physical, occupied, values = check(*data)
    msg = ('PASS v1581: real PDP-6 BACKSTORE fatal PC %06o, '
           'PI2 errors %d, DRM errors %d, owned %o, selected drum block %o, '
           '%d lower nonzero sectors; invalid commit\n' %
           (pc, values['daimos_v1581_pi2_errors'],
            values['daimos_v1581_drm_errors'],
            values['backstore_blocks_used'], physical, occupied))
    paths[5].write_text(msg)
    print(msg, end='')
    if do_selftest:
        selftest(data)


if __name__ == '__main__':
    main()
