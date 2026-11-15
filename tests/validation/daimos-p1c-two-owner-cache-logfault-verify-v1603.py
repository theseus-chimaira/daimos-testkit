#!/usr/bin/env python3
"""Source-linked original two-owner PI6 and torn LOGSTORE/cache guest.

Combine independently accepted physical v1592 and v1590 witnesses,
without assuming that their source overlays create fake wakeups or
without trusting only userland CTY markers.  Both boots must agree.
"""

import importlib.util
from pathlib import Path
import re
import sys


def imported(name, label):
    path = Path(__file__).with_name(name)
    spec = importlib.util.spec_from_file_location(label, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(mapping, a4, a5, a8, a2, a0, logs, media):
    two = imported('daimos-p1c-two-owner-verify-v1592.py', 'two_v1603')
    cache = imported('daimos-p1c-live-cache-logfault-verify-v1590.py',
                     'cache_v1603')
    owners, physical = two.check(mapping, a4, a5, a8, a2, logs, media)
    assert len(owners) == len(logs) == 2
    observations = []
    for i, transcript in enumerate(logs):
        for marker in ('P1C-D6FS-CACHE-BEFORE-LOGFAULT-V1590',
                       'P1C-LOGSTORE-TORN-REFUSED',
                       'P1C-LOGSTORE-APPEND-READBACK'):
            assert marker in transcript, 'missing original userland: ' + marker
        value = cache.extract(mapping, a0, transcript)
        assert value['primed'] == 1
        assert value['nonzero'] > 0
        assert 0 < value['slab'] < 0o400000
        assert ((value['key'] >> 24) & 0o7700) == 0o1000
        assert value['physical'] == 1, 'no actual torn physical LOGSTORE WRITE'
        assert value['failure_observed'] == 1
        assert value['retry_observed'] == 1
        assert value['failure_hit'] == 1 and value['retry_hit'] == 1
        for name in ('failure_differences', 'retry_differences',
                     'failure_fetch_differences',
                     'retry_fetch_differences'):
            assert value[name] == 0, 'clean cache data changed: ' + name
        two_slots, rollback, swap = owners[i]
        assert two_slots['first_slot'] != two_slots['second_slot']
        assert two_slots['first_woke'] == two_slots['second_woke'] == 1
        assert rollback['rollback_count'] == 1
        assert swap['daimos_v1584_swap_reads'] == 5
        assert swap['daimos_v1584_swap_pi2'] >= 1120
        observations.append((two_slots, rollback, swap, value))
    return observations, physical


def negatives(mapping, a4, a5, a8, a2, a0, logs, media):
    two = imported('daimos-p1c-two-owner-verify-v1592.py',
                   'two_neg_v1603')
    cache = imported('daimos-p1c-live-cache-logfault-verify-v1590.py',
                     'cache_neg_v1603')
    base = imported('daimos-p1c-snapshot-swap-verify-v1584.py',
                    'symbols_v1603')
    linked = base.get_symbols(a0)
    oldhead, oldtail = logs[0].split('HALT instruction, PC:', 1)
    mutation_count = 0
    for name, replacement in (
        ('primed', 0), ('nonzero', 0), ('slab', 0), ('key', 0),
        ('physical', 0), ('failure_observed', 0), ('retry_observed', 0),
        ('failure_differences', 1), ('retry_differences', 1),
        ('failure_hit', 0), ('retry_hit', 0),
        ('failure_fetch_differences', 1),
        ('retry_fetch_differences', 1),
    ):
        symbol = 'daimos_v1590_' + name
        assert symbol in linked and name in cache.FIELDS
        expr = r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$' % \
            linked[symbol]
        assert len(re.findall(expr, oldtail)) == 1, symbol
        changed = re.sub(expr, lambda m: m.group(1) +
                         '%012o' % replacement + m.group(3),
                         oldtail, count=1)
        try:
            check(mapping, a4, a5, a8, a2, a0,
                  [oldhead + 'HALT instruction, PC:' + changed, logs[1]],
                  media)
        except (AssertionError, KeyError):
            print('PASS v1603: rejected corrupt physical cache ' + name)
            mutation_count += 1
        else:
            raise AssertionError('accepted false cached data: ' + name)
    for label, marker in (
        ('unobserved first LOGSTORE failure', 'P1C-LOGSTORE-TORN-REFUSED'),
        ('unobserved original retry', 'P1C-LOGSTORE-APPEND-READBACK'),
    ):
        altered = logs[0].replace(marker, 'P1C-MISSING', 1)
        assert altered != logs[0]
        try:
            check(mapping, a4, a5, a8, a2, a0,
                  [altered, logs[1]], media)
        except (AssertionError, KeyError):
            print('PASS v1603: rejected ' + label)
            mutation_count += 1
        else:
            raise AssertionError('accepted false LOGSTORE stage: ' + label)
    assert mutation_count == 15
    # Re-run all 16 first-owner/second-owner/PI6/rollback mutants PLUS
    # the established source-linked v1584 false physical media oracles.
    two.negative_tests(mapping, a4, a5, a8, a2, logs, media)


def main():
    args = sys.argv[1:]
    selftest = '--self-test' in args
    if selftest:
        args.remove('--self-test')
    if len(args) != 10:
        raise SystemExit('usage: v1603 [--self-test] MAP ADDR4 ADDR5 '
                         'ADDR8 ADDR2 ADDR0 BOOT1 BOOT2 DRUM_DIR REPORT')
    mapping, a4, a5, a8, a2, a0, l1, l2 = [
        Path(p).read_text(errors='replace') for p in args[:8]]
    drum = Path(args[8])
    media = [(drum / ('dsk%d.dsk' % i)).read_bytes() for i in range(4)]
    logs = [l1, l2]
    observations, physical = check(mapping, a4, a5, a8, a2, a0,
                                   logs, media)
    lines = [
        'PASS v1603: same full physical two-boot PDP-6 guest, two original '
        'PI6 DISK owners, original logged torn/committed Type-236 WRITE '
        'and complete clean D6FS private cache, independent original '
        'post-DMA swap rollback; physical DR%d:%06o' % physical[:2]
    ]
    for index, (owners, failed, swap, value) in enumerate(observations, 1):
        lines.append(
            'BOOT %d: PI6 owners %d/%d wake %d/%d, swap READs %d PI2 %d, '
            'one rollback %d, torn and retry physical=1, cache 128-word '
            'differences 0/0, original HIT/HIT, MM slab %06o' %
            (index, owners['first_slot'], owners['second_slot'],
             owners['first_woke'], owners['second_woke'],
             swap['daimos_v1584_swap_reads'], swap['daimos_v1584_swap_pi2'],
             failed['rollback_count'], value['slab']))
    message = '\n'.join(lines) + '\n'
    Path(args[9]).write_text(message)
    print(message, end='')
    if selftest:
        negatives(mapping, a4, a5, a8, a2, a0, logs, media)


if __name__ == '__main__':
    main()
