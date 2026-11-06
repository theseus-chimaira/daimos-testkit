#!/usr/bin/env python3
"""Validate exercised v1208 pressure fallback on a completed F07 guest.

This is a separate positive qualification of the optional experimental
swap service.  The clean-source F07 baseline must not use this verifier.
"""

from pathlib import Path
import re
import sys


REQUIRED = (
    'pressure', 'fallback', 'victim_search', 'reclaim_ok',
    'reclaim_fail', 'swapout_ok', 'swapout_fail', 'swapin_ok',
    'swapin_pressure', 'swapin_fail', 'cooldown', 'exchanged', 'restored',
)


def decode(addresses, simh):
    text = Path(simh).read_text(errors='replace')
    result = {}
    for line in Path(addresses).read_text().splitlines():
        name, value = line.split()
        if not name.startswith('f07s_diag_'):
            continue
        name = name[len('f07s_diag_'):]
        if name not in REQUIRED:
            continue
        pattern = r'(?m)^\s*0*%o\s*:\s*([0-7]+)' % int(value, 8)
        seen = re.findall(pattern, text)
        if len(seen) != 1:
            raise ValueError('missing/duplicate swap counter ' + name)
        if name in result:
            raise ValueError('duplicate swap symbol ' + name)
        result[name] = int(seen[0], 8)
    return result


def verify(data):
    if set(REQUIRED) - set(data):
        raise ValueError('missing swap counters')
    if data['fallback'] == 0 or data['exchanged'] == 0:
        raise ValueError('fallback or normal exchange not exercised')
    if data['pressure'] != data['fallback'] + data['exchanged']:
        raise ValueError('unaccounted swap pressure path')
    if data['swapin_pressure'] != data['pressure']:
        raise ValueError('swap-in pressure inconsistent')
    if any(data[name] != 0 for name in
           ('reclaim_fail', 'swapout_fail', 'swapin_fail', 'cooldown')):
        raise ValueError('swap failure/cooldown observed')
    if min(data[name] for name in
           ('victim_search', 'reclaim_ok', 'swapout_ok',
            'swapin_ok', 'restored')) < data['fallback']:
        raise ValueError('fallback did not complete sufficient transfers')
    if data['swapout_ok'] != data['swapin_ok'] or \
            data['swapin_ok'] != data['restored']:
        raise ValueError('unbalanced swap transfers')


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1268 addresses simh.out')
    values = decode(sys.argv[1], sys.argv[2])
    verify(values)
    mutations = (
        ('fallback', 0),
        ('pressure', values['pressure'] + 1),
        ('reclaim_fail', 1),
        ('swapout_ok', 0),
        ('restored', 0),
    )
    for name, bad in mutations:
        other = dict(values)
        other[name] = bad
        try:
            verify(other)
        except ValueError:
            continue
        raise AssertionError('v1268 mutation escaped: ' + name)
    print('v1268: physical F07 fallback and exchange paths, '
          'balanced transfers and five negative controls PASS')
    print('pressure=%d fallback=%d exchange=%d swaps=%d' %
          (values['pressure'], values['fallback'], values['exchanged'],
           values['swapin_ok']))


if __name__ == '__main__':
    main()
