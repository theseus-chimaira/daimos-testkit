#!/usr/bin/env python3
"""Physical four-member PDP-6 independent swap READ/PI2 fatal fault oracle.

Every original post-HALT value is read through its linked KCORE address.
Derive physical swap-READ member/block independently from D6FSR2 sector
zero descriptors and the captured original DMA hardware-group address.
Require a true original BACKSTORE fatal HALT, one real PI2/driver error,
genuine original PI6 timer wakeup, and no committed MEMFS snapshot.
"""

from pathlib import Path
import re
import struct
import sys

MASK36 = (1 << 36) - 1
LAYOUT_MAGIC = 0o442654636222
SNAPSHOT_MAGIC = 0o55464663
AUXSTORE_MAGIC = 0o416570636421
V1584 = (
    'daimos_v1584_snapshot_live', 'daimos_v1584_swap_started',
    'daimos_v1584_swap_completed', 'daimos_v1584_swap_reads',
    'daimos_v1584_swap_pi2', 'daimos_v1584_snapshot_pi2',
    'daimos_v1584_swap_target', 'daimos_v1584_swap_read_active',
    'daimos_v1584_last_slot', 'backstore_blocks_used',
    'volume_data_blocks', 'backing_region_count',
    'mfsdev_storage_errors', 'proc_swap_blocks_used',
)
V1585 = (
    'daimos_v1585_slot', 'daimos_v1585_armed', 'daimos_v1585_woke',
    'daimos_v1585_start_tick', 'daimos_v1585_end_tick',
)
V1586 = (
    'daimos_v1586_fault_armed', 'daimos_v1586_fault_count',
    'daimos_v1586_target_group', 'backstore_enabled',
    'mfsdev_d6set_members', 'device_region_map',
    'vfs_namespace_root', 'daimos_v1586_original_drm_errors',
)


def labels(source):
    symbols = {}
    for name, address in re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$',
                                    source):
        assert name not in symbols, 'duplicate KCORE label: ' + name
        symbols[name] = int(address, 8)
    return symbols


def sector(raw, number):
    assert len(raw) == 8192 * 1024 and 0 <= number < 8192
    words = struct.unpack_from('<128Q', raw, number * 1024)
    assert all(word <= MASK36 for word in words), 'non-36-bit media word'
    return words


def check(mapping, addr4, addr5, addr6, transcript, media, original,
          timer_arms=1, direct_device=False):
    linked = labels(mapping)
    addressing = [labels(s) for s in (addr4, addr5, addr6)]
    for group, names in zip(addressing, (V1584, V1585, V1586)):
        for name in names:
            assert name in group, 'missing original witness: ' + name
            expected = (linked['mfsdev_storage_errors'] + 5
                        if name == 'daimos_v1586_original_drm_errors'
                        else linked[name])
            assert group[name] == expected, 'stale KCORE address: ' + name

    fatal = linked['kcore_critical_device_lost_v1515'] + 7
    halts = re.findall(r'HALT instruction, PC: ([0-7]{6})', transcript)
    assert [int(s, 8) for s in halts] == [fatal], \
        'not the original reason-2 BACKSTORE fatal HALT'
    assert 'P1C-SWAP-HALT-REQUEST-V1580' in transcript
    assert 'P1C-SWAP-CHILDREN-SLEEP-V1580' in transcript
    assert 'P1C-LOGSTORE-APPEND-READBACK' in transcript
    assert 'XIP-SNAPSHOT-WRITTEN' in transcript
    assert 'XIP-FAIL-' not in transcript
    assert 'XIP-SNAPSHOT-RESTORED' not in transcript
    after = transcript.split('HALT instruction, PC:', 1)[1]
    values = {}
    for group, names in zip(addressing, (V1584, V1585, V1586)):
        for name in names:
            at = group[name]
            expression = (r'(?m)^(?:sim>\s*)?0*%o:\s*'
                          r'([0-7]{1,12})\s*$') % at
            hits = re.findall(expression, after)
            assert len(hits) == 1, 'missing original post-HALT ' + name
            values[name] = int(hits[0], 8)

    assert values['daimos_v1586_fault_armed'] == 0
    assert values['daimos_v1586_fault_count'] == 1
    assert values['daimos_v1586_original_drm_errors'] == 1
    assert values['mfsdev_storage_errors'] == 0
    assert values['daimos_v1584_snapshot_live'] == MASK36, \
        'snapshot already exited before selected swap READ fault'
    assert values['daimos_v1585_armed'] == timer_arms
    assert values['daimos_v1585_woke'] == 1
    assert 0 < values['daimos_v1585_slot'] < 24
    assert values['daimos_v1585_start_tick'] > 0
    assert values['daimos_v1585_end_tick'] == 0
    assert values['daimos_v1584_swap_started'] >= 1
    assert values['daimos_v1584_swap_reads'] >= 1
    assert values['daimos_v1584_swap_pi2'] == 1
    assert values['daimos_v1584_snapshot_pi2'] >= 1
    assert values['daimos_v1584_swap_completed'] == 0, \
        'failed first swap READ incorrectly published resident process'
    assert values['daimos_v1584_swap_target'] == 0
    assert values['daimos_v1584_swap_read_active'] == MASK36, \
        'original synchronous swap READ should still be on call stack'
    assert values['backstore_enabled'] == 1
    assert values['proc_swap_blocks_used'] > 0
    assert (values['backstore_blocks_used'] >=
            values['proc_swap_blocks_used'])
    if direct_device:
        assert values['volume_data_blocks'] == 0, \
            'DEVICE-backed test accidentally used a VOLUME mapper'
    else:
        assert values['volume_data_blocks'] > 0
    assert values['backing_region_count'] > 0
    assert (values['device_region_map'] >> 18) & 0o400000, \
        'original BACKSTORE is not using the Type-236 controller'
    assert values['vfs_namespace_root'] >> 24 == 0o601
    packed_members = values['mfsdev_d6set_members']
    assert packed_members & 7 == 4
    assert [(packed_members >> (3 + 3 * index)) & 7
            for index in range(4)] == [0, 1, 2, 3]

    assert len(media) == (1 if direct_device else 4)
    assert len(original) == (1024 if direct_device else 4 * 1024)
    layouts = []
    occupied = 0
    if direct_device:
        raw = media[0]
        assert raw[:1024] == original, \
            'original AUXSTORE physical unit-zero descriptor changed'
        header = sector(raw, 0)
        assert header[0] == AUXSTORE_MAGIC
        assert header[1] == 1, 'AUXSTORE version mismatch'
        start = (header[2] >> 18) & 0o777777
        tail = header[2] & 0o777777
        log_start = (header[3] >> 18) & 0o777777
        log_len = header[3] & 0o777777
        assert start >= 1 and tail >= 40
        assert start + tail <= 8192
        assert log_start > 0 and log_len > 0
        assert log_start + log_len <= start or \
            start + tail <= log_start, 'LOGSTORE overwrites BACKSTORE'
        assert tail == values['backing_region_count']
    else:
        for unit, raw in enumerate(media):
            words = sector(raw, 0)
            assert raw[:1024] == original[unit * 1024:(unit + 1) * 1024], \
                'original D6FSR2 member descriptor modified'
            assert words[6] == LAYOUT_MAGIC
            start = (words[7] >> 18) & 0o777777
            usable = words[7] & 0o777777
            tail = words[10]
            assert start >= 1 and usable > 0 and tail > 0
            assert start + usable + tail <= 8192
            layouts.append((start, usable, tail))
        assert len({data[1] for data in layouts}) == 1
        assert len({data[2] for data in layouts}) == 1
        assert sum(data[1] for data in layouts) == values['volume_data_blocks']
        assert sum(data[2] for data in layouts) == values['backing_region_count']

    group = values['daimos_v1586_target_group']
    unit = group >> 16
    physical = (group & 0o177777) >> 3
    assert 0 <= unit < (1 if direct_device else 4)
    assert group == ((unit << 16) | (physical << 3)), \
        'not a real Type-236 hardware DR group'
    if direct_device:
        assert start <= physical < start + tail, \
            'selected READ is outside real independent AUXSTORE range'
        logical = physical - start
        assert ((values['device_region_map'] >> 18) & 0o200000) == 0, \
            'direct DEVICE test has a set selector'
        assert (values['device_region_map'] & 0o777777) == start, \
            'physical DEVICE base does not equal AUXSTORE RBN0'
    else:
        start, usable, tail = layouts[unit]
        assert start + usable <= physical < start + usable + tail, \
            'injected request does not lie inside real BACKSTORE tail'
        first = physical - (start + usable)
        logical = first * 4 + unit
    assert logical < values['backing_region_count']
    assert any(sector(media[unit], physical)), \
        'selected physical swap READ had no on-media payload'

    if direct_device:
        header_unit = 0
        header_phys = start + tail - 1
    else:
        header_index = values['volume_data_blocks'] + \
            values['backing_region_count'] - 1
        header_unit = header_index % 4
        header_phys = layouts[header_unit][0] + header_index // 4
        assert header_phys == sum(layouts[header_unit]) - 1
    header = sector(media[header_unit], header_phys)
    assert header[0] == 0 and header[0] != SNAPSHOT_MAGIC, \
        'snapshot incorrectly committed despite fatal swap READ fault'
    for u, raw in enumerate(media):
        if direct_device:
            first_phys, limit_phys = start, start + tail
        else:
            base, data_span, tail_count = layouts[u]
            first_phys = base + data_span
            limit_phys = first_phys + tail_count
        for index in range(first_phys, limit_phys):
            if index == header_phys and u == header_unit:
                continue
            if any(sector(raw, index)):
                occupied += 1
    assert occupied >= 2, 'independent physical backing payload absent'
    return fatal, unit, physical, logical, occupied, values


def selftest(inputs, timer_arms=1, direct_device=False):
    mapping, addr4, addr5, addr6, transcript, media, original = inputs
    linked = labels(addr6)
    all_links = {}
    all_links.update(labels(addr4))
    all_links.update(labels(addr5))
    all_links.update(linked)
    prefix, suffix = transcript.split('HALT instruction, PC:', 1)
    mutations = (
        ('no physical PI2 injection', 'daimos_v1586_fault_count', 0),
        ('missing original DRM error', 'daimos_v1586_original_drm_errors', 0),
        ('injected fault still armed', 'daimos_v1586_fault_armed', 1),
        ('no PI6 wakeup', 'daimos_v1585_woke', 0),
        ('no independent swap entry', 'daimos_v1584_swap_started', 0),
        ('no swap READ', 'daimos_v1584_swap_reads', 0),
        ('no physical matching PI2', 'daimos_v1584_swap_pi2', 0),
        ('false resident publication', 'daimos_v1584_swap_completed', 1),
        ('lost backing ownership', 'proc_swap_blocks_used', 0),
        ('wrong physical hardware group', 'daimos_v1586_target_group', 1),
        ('unexpected backing mode', 'volume_data_blocks',
         1 if direct_device else 0),
        ('snapshot unexpectedly inactive', 'daimos_v1584_snapshot_live', 0),
    )
    for name, key, value in mutations:
        address = all_links[key]
        pattern = r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$' % address
        assert len(re.findall(pattern, suffix)) == 1
        changed = re.sub(pattern,
                         lambda m: m.group(1) + '%012o' % value + m.group(3),
                         suffix, count=1)
        try:
            check(mapping, addr4, addr5, addr6,
                  prefix + 'HALT instruction, PC:' + changed,
                  media, original, timer_arms=timer_arms,
                  direct_device=direct_device)
        except (AssertionError, KeyError):
            print('PASS v1586: rejected ' + name)
        else:
            raise AssertionError('accepted corrupted physical witness ' + name)

    fatal, unit, block, _, _, _ = check(
        *inputs, timer_arms=timer_arms, direct_device=direct_device)
    bad = list(media)
    changed = bytearray(bad[unit])
    changed[block * 1024:(block + 1) * 1024] = b'\0' * 1024
    bad[unit] = bytes(changed)
    try:
        check(mapping, addr4, addr5, addr6, transcript, bad, original,
              timer_arms=timer_arms, direct_device=direct_device)
    except (AssertionError, KeyError):
        print('PASS v1586: rejected missing selected physical swap payload')
    else:
        raise AssertionError('accepted absent physical swap payload')

    bad = list(media)
    if direct_device:
        orig_layout = sector(bad[0], 0)
        start = (orig_layout[2] >> 18) & 0o777777
        end = start + (orig_layout[2] & 0o777777) - 1
        header_unit = 0
    else:
        orig_layout = struct.unpack_from('<128Q', bad[3], 0)
        start = (orig_layout[7] >> 18) & 0o777777
        end = start + (orig_layout[7] & 0o777777) + orig_layout[10] - 1
        header_unit = 3
    changed = bytearray(bad[header_unit])
    struct.pack_into('<Q', changed, end * 1024, SNAPSHOT_MAGIC)
    bad[header_unit] = bytes(changed)
    try:
        check(mapping, addr4, addr5, addr6, transcript, bad, original,
              timer_arms=timer_arms, direct_device=direct_device)
    except (AssertionError, KeyError):
        print('PASS v1586: rejected falsely committed snapshot header')
    else:
        raise AssertionError('accepted false snapshot header')

    bad = list(media)
    changed = bytearray(bad[0])
    struct.pack_into('<Q', changed, (0 if direct_device else 6) * 8, 0)
    bad[0] = bytes(changed)
    try:
        check(mapping, addr4, addr5, addr6, transcript, bad, original,
              timer_arms=timer_arms, direct_device=direct_device)
    except (AssertionError, KeyError):
        print('PASS v1586: rejected corrupt physical ' +
              ('AUXSTORE descriptor' if direct_device else
               'D6FSR2 member'))
    else:
        raise AssertionError('accepted corrupt D6FSR2 member')


def main():
    args = sys.argv[1:]
    negatives = '--self-test' in args
    if negatives:
        args.remove('--self-test')
    if len(args) != 8:
        raise SystemExit('usage: verifier [--self-test] MAP ADDR4 ADDR5 '
                         'ADDR6 LOG DRUM_DIR LAYOUT_BASELINE REPORT')
    mapping, addr4, addr5, addr6, log = [
        Path(path).read_text(errors='replace') for path in args[:5]]
    drum = Path(args[5])
    media = [(drum / ('dsk%d.dsk' % unit)).read_bytes()
             for unit in range(4)]
    original = Path(args[6]).read_bytes()
    inputs = (mapping, addr4, addr5, addr6, log, media, original)
    fatal, unit, physical, logical, occupied, values = check(*inputs)
    message = ('PASS v1586: original BACKSTORE fatal PC %06o; authentic '
               'slot-0 swap READ DR%d physical block %06o logical tail '
               '%06o; one actual injected PI2 and original DRM error, '
               'PI6 wake %d, independent starts %d, uncommitted snapshot, '
               '%d other nonzero physical BACKSTORE sectors\n' %
               (fatal, unit, physical, logical,
                values['daimos_v1585_woke'],
                values['daimos_v1584_swap_started'], occupied))
    Path(args[7]).write_text(message)
    print(message, end='')
    if negatives:
        selftest(inputs)


if __name__ == '__main__':
    main()
