#!/usr/bin/env python3
"""Source-linked two-owner PI6 + physical mapped fatal swap-READ oracle.

Original v1586 validates the complete physical failure, DMA group,
HALT, untouched D6FSR2 headers and outstanding ownership. This v1599
extension requires two *distinct* original PI6 timer-service wakeups
and a real first fatal swap READ during the same MEMFS snapshot.
"""

import importlib.util
from pathlib import Path
import re
import sys


def imported(filename, key):
    path = Path(__file__).with_name(filename)
    spec = importlib.util.spec_from_file_location(key, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(mapping, address4, address5, address6, address2,
          log, media, original, direct_device=False):
    base = imported('daimos-p1c-swap-read-fault-verify-v1586.py',
                    'v1599_original_physical')
    fatal, unit, physical, logical, occupied, values = base.check(
        mapping, address4, address5, address6, log, media, original,
        timer_arms=2, direct_device=direct_device)
    linked = base.labels(mapping)
    recorded = base.labels(address2)
    after = log.split('HALT instruction, PC:', 1)[1]
    owners = {}
    for key in ('first_slot', 'second_slot', 'first_woke',
                'second_woke'):
        symbol = 'daimos_v1592_' + key
        assert symbol in linked and symbol in recorded
        assert linked[symbol] == recorded[symbol], \
            'stale linked witness ' + symbol
        expression = (r'(?m)^(?:sim>\s*)?0*%o:\s*'
                      r'([0-7]{1,12})\s*$') % linked[symbol]
        matches = re.findall(expression, after)
        assert len(matches) == 1, 'missing physical witness ' + symbol
        owners[key] = int(matches[0], 8)
    assert 0 < owners['first_slot'] < 24
    assert 0 < owners['second_slot'] < 24
    assert owners['first_slot'] != owners['second_slot']
    assert owners['first_woke'] == owners['second_woke'] == 1, \
        'both original PI6 timer-service wakeups must precede fatal'
    assert values['daimos_v1585_slot'] == owners['second_slot']
    assert values['daimos_v1585_woke'] == 1
    assert values['daimos_v1584_last_slot'] in (
        owners['first_slot'], owners['second_slot']), \
        'physical swap READ did not belong to an independently woken owner'
    assert values['daimos_v1584_swap_started'] == 1
    assert values['daimos_v1584_swap_reads'] == 1
    assert values['daimos_v1584_swap_completed'] == 0
    return fatal, unit, physical, logical, occupied, owners, values


def negative_tests(inputs, direct_device=False):
    mapping, a4, a5, a6, a2, log, media, original = inputs
    base = imported('daimos-p1c-swap-read-fault-verify-v1586.py',
                    'v1599_negative_original')
    linked = base.labels(a2)
    linked.update(base.labels(a5))
    head, tail = log.split('HALT instruction, PC:', 1)
    owners = check(*inputs, direct_device=direct_device)[5]
    mutations = (
        ('first timer owner missing', 'daimos_v1592_first_slot', 0),
        ('second timer owner missing', 'daimos_v1592_second_slot', 0),
        ('same owner twice', 'daimos_v1592_second_slot',
         owners['first_slot']),
        ('first genuine PI6 not delivered', 'daimos_v1592_first_woke', 0),
        ('second genuine PI6 not delivered', 'daimos_v1592_second_woke', 0),
        ('duplicated second PI6', 'daimos_v1592_second_woke', 2),
        ('only one timer armed', 'daimos_v1585_armed', 1),
        ('wrong last timer owner', 'daimos_v1585_slot',
         owners['first_slot']),
    )
    for label, symbol, value in mutations:
        at = linked[symbol]
        pattern = r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$' % at
        assert len(re.findall(pattern, tail)) == 1
        changed = re.sub(pattern,
                         lambda m: m.group(1) + '%012o' % value + m.group(3),
                         tail, count=1)
        try:
            check(mapping, a4, a5, a6, a2,
                  head + 'HALT instruction, PC:' + changed,
                  media, original, direct_device=direct_device)
        except (AssertionError, KeyError):
            print('PASS v1599: rejected ' + label)
        else:
            raise AssertionError('accepted false two-owner fatal: ' + label)
    # All original deep physical, fatal-path, on-disk and ownership
    # mutations must also fail in the two-owner geometry (15 more).
    base.selftest((mapping, a4, a5, a6, log, media, original),
                  timer_arms=2, direct_device=direct_device)


def main():
    args = sys.argv[1:]
    negatives = '--self-test' in args
    if negatives:
        args.remove('--self-test')
    if len(args) != 9:
        raise SystemExit('usage: v1599 [--self-test] MAP ADDR4 ADDR5 ADDR6 '
                         'ADDR2 BOOT1 DRUM_DIR ORIGINAL_LAYOUT REPORT')
    mapping, a4, a5, a6, a2, log = [
        Path(p).read_text(errors='replace') for p in args[:6]]
    media = [(Path(args[6]) / ('dsk%d.dsk' % u)).read_bytes()
             for u in range(4)]
    original = Path(args[7]).read_bytes()
    inputs = (mapping, a4, a5, a6, a2, log, media, original)
    fatal, unit, physical, logical, occupied, owners, values = check(*inputs)
    result = ('PASS v1599: two original DISK timer owners %d/%d and PI6 '
              'wakes 1/1; selected swap owner %d; '
              'original BACKSTORE fatal %06o on mapped DR%d '
              'block %06o (logical %06o), one real swap READ/PI2, '
              'no RESIDENT publish, %d other nonzero tail sectors\n' %
              (owners['first_slot'], owners['second_slot'],
               values['daimos_v1584_last_slot'], fatal,
               unit, physical, logical, occupied))
    Path(args[8]).write_text(result)
    print(result, end='')
    if negatives:
        negative_tests(inputs)


if __name__ == '__main__':
    main()
