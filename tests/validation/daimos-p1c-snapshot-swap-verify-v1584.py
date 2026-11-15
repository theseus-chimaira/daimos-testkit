#!/usr/bin/env python3
"""Audit real PDP-6 mapped snapshot recovery and potential swap-in PI2.

Production KCORE/MRES symbols, two independent cold-boot transcripts and
four unaltered 36-bit raw Type-236 members provide the physical evidence.
No trace is accepted based on a test counter alone; positive completed
slot-0 swap-in, matched hardware DR_DONE PI2 and durable recovery are all
required by --require-overlap; ordinary healthy persistence must never be
confused with a proven overlap. Deliberately corrupted evidence must fail.
"""

from pathlib import Path
import re
import struct
import sys

MASK = (1 << 36) - 1
D6FSR2 = 0o442654636222
SNAP = 0o55464663
FIELDS = (
    'daimos_v1584_snapshot_live', 'daimos_v1584_swap_started',
    'daimos_v1584_swap_completed', 'daimos_v1584_swap_reads',
    'daimos_v1584_swap_pi2', 'daimos_v1584_snapshot_pi2',
    'daimos_v1584_swap_target', 'daimos_v1584_swap_read_active',
    'daimos_v1584_last_slot', 'backstore_blocks_used',
    'volume_data_blocks', 'backing_region_count',
    'mfsdev_storage_errors', 'proc_swap_blocks_used',
)


def get_symbols(source):
    symbols = {}
    for name, octal in re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$', source):
        assert name not in symbols, 'duplicate label ' + name
        symbols[name] = int(octal, 8)
    return symbols


def physical_sector(raw, block):
    assert len(raw) == 8192 * 1024 and 0 <= block < 8192
    words = struct.unpack_from('<128Q', raw, block * 1024)
    assert all((word & ~MASK) == 0 for word in words), \
        'media contains invalid non-36-bit words'
    return words


def check_boot(mapping, addresses, transcript, index, require_overlap=False):
    labels = get_symbols(mapping)
    linked = get_symbols(addresses)
    for name in FIELDS:
        assert name in linked and name in labels, 'missing linked ' + name
        assert linked[name] == labels[name], 'stale linked ' + name
    halt = re.findall(r'HALT instruction, PC: ([0-7]{6})', transcript)
    assert len(halt) == 1, 'missing/duplicated actual HALT'
    assert 'MEMFS                             LOADED' in transcript
    assert 'BSET                              LOADED' in transcript
    assert 'D6FS                              LOADED' in transcript
    assert 'P1C-SWAP-HALT-REQUEST-V1580' in transcript
    assert 'P1C-SWAP-CHILDREN-SLEEP-V1580' in transcript
    assert 'P1C-LOGSTORE-APPEND-READBACK' in transcript
    assert 'XIP-FAIL-' not in transcript
    if index == 1:
        assert 'XIP-SNAPSHOT-WRITTEN' in transcript
    else:
        assert 'XIP-SNAPSHOT-RESTORED' in transcript
        assert 'P1C-LOGSTORE-PREVIOUS-BOOT' in transcript
    after = transcript.split('HALT instruction, PC:', 1)[1]
    values = {}
    for name in FIELDS:
        pattern = r'(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$' % linked[name]
        hits = re.findall(pattern, after)
        assert len(hits) == 1, 'missing actual post-HALT ' + name
        values[name] = int(hits[0], 8)

    assert values['daimos_v1584_snapshot_live'] == 0, \
        'snapshot work still in progress at normal HALT'
    assert values['daimos_v1584_snapshot_pi2'] > 0, \
        'no actual physical DR_DONE during snapshot'
    if require_overlap:
        assert values['daimos_v1584_swap_started'] > 0, \
            'no independent scheduler slot-0 swap-in during snapshot'
        assert values['daimos_v1584_swap_completed'] > 0, \
            'no completed DISK->RESIDENT publication during snapshot'
        assert values['daimos_v1584_swap_reads'] > 0, \
            'no real physical BACKSTORE swap READ during snapshot'
        assert values['daimos_v1584_swap_pi2'] > 0, \
            'no selected matching hardware PI2 DR_DONE for swap-in READ'
    assert (values['daimos_v1584_swap_pi2'] <=
            values['daimos_v1584_snapshot_pi2']), \
        'PI2 matched SWAP count exceeds all DR_DONE events'
    assert (values['daimos_v1584_swap_completed'] <=
            values['daimos_v1584_swap_started']), \
        'more completed swaps than independently started'
    assert values['daimos_v1584_swap_target'] == 0, \
        'swap descriptor not retired after PI2'
    assert values['daimos_v1584_swap_read_active'] == 0, \
        'orphaned swap-read issuance marker'
    if values['daimos_v1584_swap_started'] != 0:
        assert 0 < values['daimos_v1584_last_slot'] < 24, \
            'invalid independent restore process slot'
    else:
        assert values['daimos_v1584_last_slot'] == 0, \
            'claimed swapped slot with no independent scheduler activity'
    assert values['volume_data_blocks'] > 0
    assert values['backing_region_count'] > 0
    assert values['proc_swap_blocks_used'] > 0, \
        'no live process swap ownership at normal HALT'
    assert values['backstore_blocks_used'] >= values['proc_swap_blocks_used']
    assert values['mfsdev_storage_errors'] == 0, \
        'unexpected logical storage failure on healthy controller'
    return values


def check_media(data, values):
    assert len(data) == 4
    members = []
    occupied = 0
    for i, raw in enumerate(data):
        layout = physical_sector(raw, 0)
        assert layout[6] == D6FSR2, 'invalid root member %d' % i
        base = (layout[7] >> 18) & 0o777777
        span = layout[7] & 0o777777
        tail = layout[10]
        assert base > 0 and span > 0 and tail > 0
        assert base + span + tail <= 8192
        members.append((base, span, tail))
    assert len({m[1] for m in members}) == 1
    assert len({m[2] for m in members}) == 1
    assert sum(m[1] for m in members) == values['volume_data_blocks']
    total = sum(m[2] for m in members)
    assert total == values['backing_region_count']
    unit = (values['volume_data_blocks'] + total - 1) % 4
    block = members[unit][0] + (values['volume_data_blocks'] + total - 1) // 4
    assert block == sum(members[unit]) - 1
    header = physical_sector(data[unit], block)
    assert header[0] == SNAP and header[1] == 2, \
        'valid persistent v2 snapshot commit absent'
    start, reserved, pool = header[2:5]
    assert 0 < pool <= 4096
    assert reserved == (pool + 127) // 128 + 6
    assert start + reserved == total, \
        'snapshot reservation does not end at mapped tail boundary'
    for member, raw in enumerate(data):
        base, span, tail = members[member]
        for physical in range(base + span, base + span + tail):
            if member == unit and physical == block:
                continue
            if any(physical_sector(raw, physical)):
                occupied += 1
    assert occupied >= 2, 'no physically distinct BACKSTORE payload'
    return unit, block, pool, occupied


def check(mapping, addresses, logs, media, require_overlap=False):
    assert len(logs) == 2
    first = check_boot(mapping, addresses, logs[0], 1, require_overlap)
    second = check_boot(mapping, addresses, logs[1], 2, require_overlap)
    unit, block, pool, occupied = check_media(media, second)
    return (first, second, unit, block, pool, occupied)


def selftest(mapping, addresses, logs, media):
    linked = get_symbols(addresses)
    before, after = logs[0].split('HALT instruction, PC:', 1)

    def bad_field(name, value):
        label = linked[name]
        expr = r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$' % label
        assert len(re.findall(expr, after)) == 1
        alt = re.sub(expr, lambda m: m.group(1) + '%012o' % value +
                     m.group(3), after, count=1)
        return [before + 'HALT instruction, PC:' + alt, logs[1]]

    failures = [
        ('no original DR_DONE', bad_field('daimos_v1584_snapshot_pi2', 0), media),
        ('still inside snapshot', bad_field('daimos_v1584_snapshot_live', 1), media),
        ('unretired descriptor', bad_field('daimos_v1584_swap_target', 7), media),
        ('stale read marker', bad_field('daimos_v1584_swap_read_active', 1), media),
        ('no backing owner', bad_field('proc_swap_blocks_used', 0), media),
        ('wrong mapped span', bad_field('volume_data_blocks', 0), media),
        ('unexpected storage error', bad_field('mfsdev_storage_errors', 1), media),
        ('no root volume', bad_field('backing_region_count', 0), media),
    ]
    first, second, unit, block, _, _ = check(mapping, addresses, logs, media)
    # An ordinary healthy snapshot need not overlap swap-in. However,
    # when BOTH original boots do contain a complete physical overlap,
    # corrupted evidence must satisfy the strict overlap contract too.
    # Using the healthy-only default here previously let a mutation that
    # deleted the real completed-publication count pass undetected.
    actual_overlap = all(
        values['daimos_v1584_swap_started'] > 0 and
        values['daimos_v1584_swap_completed'] > 0 and
        values['daimos_v1584_swap_pi2'] > 0
        for values in (first, second))
    if actual_overlap:
        failures.append(('lost actual scheduler swap',
            bad_field('daimos_v1584_swap_started', 0), media))
        failures.append(('lost actual publication',
            bad_field('daimos_v1584_swap_completed', 0), media))
        failures.append(('lost matching swap PI2',
            bad_field('daimos_v1584_swap_pi2', 0), media))
    bad = list(media)
    altered = bytearray(bad[unit])
    struct.pack_into('<Q', altered, block * 1024, 0)
    bad[unit] = bytes(altered)
    failures.append(('no physical committed snapshot', logs, bad))
    bad = list(media)
    altered = bytearray(bad[unit])
    struct.pack_into('<Q', altered, 6 * 8, 0)
    bad[unit] = bytes(altered)
    failures.append(('corrupt root member layout', logs, bad))
    for name, pair, sectors in failures:
        try:
            check(mapping, addresses, pair, sectors, actual_overlap)
        except (AssertionError, KeyError):
            print('PASS v1584: rejected ' + name)
        else:
            raise AssertionError('accepted unsafe physical witness: ' + name)


def main():
    args = sys.argv[1:]
    negative = '--self-test' in args
    require_overlap = '--require-overlap' in args
    if negative:
        args.remove('--self-test')
    if require_overlap:
        args.remove('--require-overlap')
    if len(args) != 6:
        raise SystemExit('usage: verifier [--self-test] MAP ADDRS BOOT1 BOOT2 '
                         'DRUM_DIR REPORT')
    mapping, addresses, boot1, boot2 = [Path(p).read_text(errors='replace')
                                       for p in args[:4]]
    drum = Path(args[4])
    media = [(drum / ('dsk%d.dsk' % unit)).read_bytes()
             for unit in range(4)]
    first, second, unit, block, pool, occupied = check(
        mapping, addresses, [boot1, boot2], media, require_overlap)
    msg = ('PASS v1584: two PDP-6 cold boots, physical mapped snapshot '
           'DR%d:%06o pool=%d; independent swap-ins '
           '%d/%d, completed %d/%d, matching PI2 %d/%d, '
           '%d nonzero backing sectors\n' %
           (unit, block, pool,
            first['daimos_v1584_swap_started'],
            second['daimos_v1584_swap_started'],
            first['daimos_v1584_swap_completed'],
            second['daimos_v1584_swap_completed'],
            first['daimos_v1584_swap_pi2'],
            second['daimos_v1584_swap_pi2'], occupied))
    if not all(vals['daimos_v1584_swap_pi2'] > 0 and
               vals['daimos_v1584_swap_completed'] > 0 and
               vals['daimos_v1584_swap_started'] > 0
               for vals in (first, second)):
        msg += ('P1-C overlap NOT PROVED: a swapped owner is not an '
                'independently scheduled swap-in during snapshot DMA\n')
    Path(args[5]).write_text(msg)
    print(msg, end='')
    if negative:
        selftest(mapping, addresses, [boot1, boot2], media)


if __name__ == '__main__':
    main()
