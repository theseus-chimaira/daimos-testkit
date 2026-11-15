#!/usr/bin/env python3
"""Verify live physical D6FS cache survives torn LOGSTORE and full swap.

Original linked KCORE cache witnesses are observed after real PDP-6
HALT on two cold boots; the inherited v1588 verifier also audits
actual physical Type-236 members and independent PI6 swap rollback.
"""

import importlib.util
from pathlib import Path
import re
import sys

FIELDS = ('primed', 'nonzero', 'slab', 'key', 'physical',
          'failure_observed', 'retry_observed', 'failure_differences',
          'retry_differences', 'failure_hit', 'retry_hit',
          'failure_fetch_differences', 'retry_fetch_differences')


def imported(name, label):
    path = Path(__file__).with_name(name)
    spec = importlib.util.spec_from_file_location(label, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def extract(mapping, addresses, transcript):
    previous = imported('daimos-p1c-snapshot-swap-verify-v1584.py',
                        'base_v1590')
    symbols = previous.get_symbols(mapping)
    linked = previous.get_symbols(addresses)
    assert transcript.count('HALT instruction, PC:') == 1
    after = transcript.split('HALT instruction, PC:', 1)[1]
    result = {}
    for name in FIELDS:
        symbol = 'daimos_v1590_' + name
        assert symbol in symbols and symbol in linked
        assert symbols[symbol] == linked[symbol], 'stale symbol ' + name
        pattern = r'(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$' % linked[symbol]
        hits = re.findall(pattern, after)
        assert len(hits) == 1, 'missing genuine linked cache ' + symbol
        result[name] = int(hits[0], 8)
    return result


def check(mapping, addr4, addr5, addr8, addr0, logs, media):
    previous = imported('daimos-p1c-postread-release-verify-v1588.py',
                        'postread_v1590')
    earlier, physical = previous.check(mapping, addr4, addr5, addr8,
                                       logs, media)
    values = []
    for i, transcript in enumerate(logs):
        for marker in ('P1C-D6FS-CACHE-BEFORE-LOGFAULT-V1590',
                       'P1C-LOGSTORE-TORN-REFUSED',
                       'P1C-LOGSTORE-APPEND-READBACK'):
            assert marker in transcript, 'missing actual userland ' + marker
        value = extract(mapping, addr0, transcript)
        assert value['primed'] == 1, 'D6FS private slab not populated'
        assert 0 < value['nonzero'] <= 128, 'physical cache data absent'
        assert 0 < value['slab'] < 0o400000, 'invalid original MM slab'
        assert (value['key'] >> 24) & 0o7700 == 0o1000, \
            'cache does not have original D6FS source identity'
        assert value['physical'] == 1, \
            'no genuine physical uncommitted LOGSTORE block write'
        assert value['failure_observed'] == 1, \
            'no post-physical torn failure cache witness'
        assert value['retry_observed'] == 1, \
            'no actual same-slot committed physical LOGSTORE retry'
        for name in ('failure_differences', 'retry_differences',
                     'failure_fetch_differences', 'retry_fetch_differences'):
            assert value[name] == 0, 'corrupted complete cache at ' + name
        assert value['failure_hit'] == 1, \
            'original cache not live after physical torn record'
        assert value['retry_hit'] == 1, \
            'original cache not live after committed LOGSTORE retry'
        # The v1588 same-boot independent swap rollback remains
        # mandatory after the earlier mixed-provider transaction.
        assert earlier[i][1]['daimos_v1584_swap_reads'] == 4
        assert earlier[i][1]['daimos_v1584_swap_pi2'] == 896
        values.append(value)
    return values, physical


def negatives(mapping, addr4, addr5, addr8, addr0, logs, media):
    linked = imported('daimos-p1c-snapshot-swap-verify-v1584.py',
                      'symbols_v1590').get_symbols(addr0)
    front, after = logs[0].split('HALT instruction, PC:', 1)
    corruptions = (
        ('missing populated private D6FS cache', 'primed', 0),
        ('all cached physical data zero', 'nonzero', 0),
        ('missing original MM slab', 'slab', 0),
        ('wrong provider class', 'key', 0),
        ('missing true LOGSTORE physical write', 'physical', 0),
        ('missing failure cache inspection', 'failure_observed', 0),
        ('missing committed retry inspection', 'retry_observed', 0),
        ('data changed at torn physical failure', 'failure_differences', 1),
        ('data changed at committed retry', 'retry_differences', 1),
        ('stale miss after torn failure', 'failure_hit', 0),
        ('stale miss after committed retry', 'retry_hit', 0),
        ('changed fetch payload after failure', 'failure_fetch_differences', 1),
        ('changed fetch payload after retry', 'retry_fetch_differences', 1),
    )
    for label, key, replacement in corruptions:
        symbol = 'daimos_v1590_' + key
        address = linked[symbol]
        expr = r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$' % address
        assert len(re.findall(expr, after)) == 1
        altered = re.sub(expr,
                         lambda m: m.group(1) + '%012o' % replacement +
                         m.group(3), after, count=1)
        try:
            check(mapping, addr4, addr5, addr8, addr0,
                  [front + 'HALT instruction, PC:' + altered, logs[1]],
                  media)
        except (AssertionError, KeyError):
            print('PASS v1590: rejected ' + label)
        else:
            raise AssertionError('accepted unsafe live cache: ' + label)


def main():
    args = sys.argv[1:]
    self_test = '--self-test' in args
    if self_test:
        args.remove('--self-test')
    if len(args) != 9:
        raise SystemExit('usage: v1590 [--self-test] MAP ADDR4 ADDR5 ADDR8 '
                         'ADDR1590 BOOT1 BOOT2 DRUM_DIR REPORT')
    mapping, a4, a5, a8, a0, l1, l2 = [
        Path(p).read_text(errors='replace') for p in args[:7]]
    drum = Path(args[7])
    media = [(drum / ('dsk%d.dsk' % i)).read_bytes() for i in range(4)]
    logs = [l1, l2]
    items, physical = check(mapping, a4, a5, a8, a0, logs, media)
    lines = ['PASS v1590: physical torn/committed LOGSTORE keeps clean D6FS '
             'private cache live; later independent swap snapshot DR%d:%06o' %
             physical[:2]]
    for index, value in enumerate(items, start=1):
        lines.append('BOOT %d: private slab=%06o D6FS key=%012o, nonzero=%d, '
                     'torn/commit exact 128-word differences=0/0, real '
                     'physical torn=1, original fetch HIT/HIT, swap PI2=896' %
                     (index, value['slab'], value['key'], value['nonzero']))
    result = '\n'.join(lines) + '\n'
    Path(args[8]).write_text(result)
    print(result, end='')
    if self_test:
        imported('daimos-p1c-postread-release-verify-v1588.py',
                 'negative_postread_v1590').selftest(
                     mapping, a4, a5, a8, logs, media)
        negatives(mapping, a4, a5, a8, a0, logs, media)


if __name__ == '__main__':
    main()
