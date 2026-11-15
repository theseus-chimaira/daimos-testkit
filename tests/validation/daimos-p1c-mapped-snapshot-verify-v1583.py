#!/usr/bin/env python3
"""Independent physical four-member VOLUME snapshot PI2 fail-stop oracle.

Actual KCORE, PI2 driver, map and four Type-236 36-bit sector images are
necessary. Reject fake success, a direct AUXSTORE path, a wrong physical
member/sector, missing swap owner, unretired PI2 descriptor and fake commit.
No source or on-media data is rewritten by the normal verification path.
"""

from pathlib import Path
import re
import struct
import sys

MASK = (1 << 36) - 1
MAGIC = 0o442654636222  # BLOCKSET_LAYOUT_MAGIC_D6FSR2
SNAPSHOT_MAGIC = 0o55464663
NAMES = (
    'daimos_v1581_pi2_errors', 'daimos_v1581_relative',
    'daimos_v1581_target_group', 'daimos_v1581_target_descriptor',
    'daimos_v1581_arm', 'backstore_blocks_used', 'backstore_enabled',
    'mfsdev_storage_errors', 'daimos_v1581_drm_errors',
    'volume_data_blocks', 'backing_region_count', 'device_region_map',
    'backstore_blocks', 'mfsdev_d6set_members', 'vfs_namespace_root',
)


def symbols(source):
    found = {}
    for name, address in re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$',
                                    source):
        assert name not in found, 'duplicate linked symbol ' + name
        found[name] = int(address, 8)
    return found


def sector(raw, number):
    assert 0 <= number < len(raw) // 1024, 'physical block out of bounds'
    words = struct.unpack_from('<128Q', raw, number * 1024)
    assert all((word & ~MASK) == 0 for word in words), \
        'invalid non-36-bit physical media word'
    return words


def check(mapping, addresses, transcript, media):
    real = symbols(mapping)
    linked = symbols(addresses)
    for name in NAMES:
        assert name in linked, 'missing linked witness ' + name
        target = (real['mfsdev_storage_errors'] + 5
                  if name == 'daimos_v1581_drm_errors' else real[name])
        assert linked[name] == target, 'stale KCORE address ' + name

    leaf = real['kcore_critical_device_lost_v1515'] + 7
    halts = re.findall(r'HALT instruction, PC: ([0-7]{6})', transcript)
    assert [int(pc, 8) for pc in halts] == [leaf], \
        'no exact original BACKSTORE reason-2 fatal HALT'
    assert 'P1C-SWAP-HALT-REQUEST-V1580' in transcript
    assert 'P1C-SWAP-CHILDREN-SLEEP-V1580' in transcript
    assert 'P1C-LOGSTORE-APPEND-READBACK' in transcript
    assert 'XIP-FAIL-' not in transcript
    after = transcript.split('HALT instruction, PC:', 1)[1]
    values = {}
    for name in NAMES:
        address = linked[name]
        pattern = r'(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$' % address
        hits = re.findall(pattern, after)
        assert len(hits) == 1, 'missing physical post-HALT witness ' + name
        values[name] = int(hits[0], 8)

    assert values['daimos_v1581_pi2_errors'] == 1
    assert values['daimos_v1581_drm_errors'] == 1
    assert values['daimos_v1581_target_descriptor'] == 0
    assert values['daimos_v1581_arm'] == 0
    assert values['backstore_enabled'] == 1
    assert values['backstore_blocks_used'] > 0
    assert (values['device_region_map'] >> 18) & 0o400000, \
        'mapped BACKSTORE not using original DRM controller'
    assert values['volume_data_blocks'] != 0, \
        'BACKSTORE incorrectly configured as a direct DEVICE'
    assert (values['vfs_namespace_root'] >> 24) == 0o601, \
        'actual D6FS root not mounted'
    packed_members = values['mfsdev_d6set_members']
    assert packed_members & 7 == 4, 'not four real D6FS members'
    assert [(packed_members >> (3 + 3 * i)) & 7
            for i in range(4)] == [0, 1, 2, 3], \
        'root physical member selectors differ from attached media'

    assert len(media) == 4, 'four physical images required'
    starts = []
    usables = []
    tails = []
    for unit, raw in enumerate(media):
        assert len(raw) == 8192 * 1024, 'not Type-236 full unit %d' % unit
        layout = sector(raw, 0)
        assert layout[6] == MAGIC, 'invalid D6FSR2 layout unit %d' % unit
        base = (layout[7] >> 18) & 0o777777
        usable = layout[7] & 0o777777
        tail = layout[10]
        assert base >= 1 and usable > 0 and tail > 40
        assert base + usable + tail <= 8192
        assert layout[14] == 0 or layout[14] <= usable
        starts.append(base)
        usables.append(usable)
        tails.append(tail)
    assert len(set(usables)) == len(set(tails)) == 1, \
        'inhomogeneous INTERLEAVE layout'
    assert values['volume_data_blocks'] == sum(usables), \
        'runtime VOLUME data span disagrees with four physical descriptors'
    total = len(media) * tails[0]
    assert values['backing_region_count'] == total
    assert values['backstore_blocks'] == total
    assert values['daimos_v1581_relative'] == total - 1, \
        'selected write is not at actual mapped BACKSTORE boundary'

    data_index = values['volume_data_blocks'] + total - 1
    physical_member = data_index % len(media)
    physical_sector = starts[physical_member] + \
        data_index // len(media)
    assert physical_sector == starts[physical_member] + \
        usables[physical_member] + tails[physical_member] - 1
    hardware_group = (physical_member << 16) | (physical_sector << 3)
    assert values['daimos_v1581_target_group'] == hardware_group, \
        'selected PI2 group does not match computed physical member/sector'
    header = sector(media[physical_member], physical_sector)
    assert header[0] == 0 and header[0] != SNAPSHOT_MAGIC, \
        'failed snapshot invalidation incorrectly committed the header'

    occupied = 0
    for unit, raw in enumerate(media):
        base = starts[unit] + usables[unit]
        for physical in range(base, base + tails[unit]):
            if unit == physical_member and physical == physical_sector:
                continue
            if any(sector(raw, physical)):
                occupied += 1
    assert occupied >= 2, 'real swapped-process physical payload absent'
    return leaf, physical_member, physical_sector, occupied, values


def selftest(inputs):
    mapping, addresses, transcript, media = inputs
    linked = symbols(addresses)
    before, after = transcript.split('HALT instruction, PC:', 1)

    def altered_word(name, value):
        addr = linked[name]
        pat = r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$' % addr
        assert len(re.findall(pat, after)) == 1
        fragment = re.sub(pat, lambda m: m.group(1) +
                          '%012o' % value + m.group(3), after, count=1)
        return before + 'HALT instruction, PC:' + fragment

    bad = [
        ('no PI2', (mapping, addresses,
                    altered_word('daimos_v1581_pi2_errors', 0), media)),
        ('no driver accounting', (mapping, addresses,
                    altered_word('daimos_v1581_drm_errors', 0), media)),
        ('lost swap owner', (mapping, addresses,
                    altered_word('backstore_blocks_used', 0), media)),
        ('direct instead of VOLUME', (mapping, addresses,
                    altered_word('volume_data_blocks', 0), media)),
        ('wrong volume capacity', (mapping, addresses,
                    altered_word('backing_region_count', 1), media)),
        ('wrong PI2 physical group', (mapping, addresses,
                    altered_word('daimos_v1581_target_group', 1), media)),
        ('unretired descriptor', (mapping, addresses,
                    altered_word('daimos_v1581_target_descriptor', 7), media)),
        ('wrong BACKSTORE HALT', (mapping, addresses,
                    transcript.replace('HALT instruction, PC: ',
                                       'HALT instruction, PC: 000', 1), media)),
        ('wrong root member map', (mapping, addresses,
                    altered_word('mfsdev_d6set_members', 0), media)),
        ('wrong root mount', (mapping, addresses,
                    altered_word('vfs_namespace_root', 0), media)),
    ]
    _, unit, block, _, _ = check(*inputs)
    fake_commit = list(media)
    wrong = bytearray(fake_commit[unit])
    struct.pack_into('<Q', wrong, block * 1024, SNAPSHOT_MAGIC)
    fake_commit[unit] = bytes(wrong)
    bad.append(('false committed header', (mapping, addresses,
                  transcript, fake_commit)))
    wrong_image = list(media)
    wrong_layout = bytearray(wrong_image[unit])
    struct.pack_into('<Q', wrong_layout, 6 * 8, 0)
    wrong_image[unit] = bytes(wrong_layout)
    bad.append(('corrupt member descriptor', (mapping, addresses,
                transcript, wrong_image)))
    for name, evidence in bad:
        try:
            check(*evidence)
        except (AssertionError, KeyError):
            print('PASS v1583: rejected ' + name)
        else:
            raise AssertionError('accepted invalid physical evidence ' + name)


def main():
    args = sys.argv[1:]
    test = '--self-test' in args
    if test:
        args.remove('--self-test')
    if len(args) != 5:
        raise SystemExit('usage: verifier [--self-test] MAP ADDRS LOG '
                         'DRUM_DIR REPORT')
    mapping, addresses, transcript = [Path(p).read_text(errors='replace')
                                      for p in args[:3]]
    drum = Path(args[3])
    media = [(drum / ('dsk%d.dsk' % unit)).read_bytes()
             for unit in range(4)]
    inputs = (mapping, addresses, transcript, media)
    leaf, unit, physical, occupied, values = check(*inputs)
    msg = ('PASS v1583: real 4-member PDP-6 mapped BACKSTORE PI2 fatal '
           'PC %06o; physical DR%d block %06o group %06o, '
           'owned %o, %d other nonzero swap sectors; invalid snapshot '
           'header and original DRM error accounted\n' %
           (leaf, unit, physical,
            values['daimos_v1581_target_group'],
            values['backstore_blocks_used'], occupied))
    Path(args[4]).write_text(msg)
    print(msg, end='')
    if test:
        selftest(inputs)


if __name__ == '__main__':
    main()
