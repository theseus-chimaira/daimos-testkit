#!/usr/bin/env python3
"""Check genuine owner-tagged F07 MM occupancy and exact cleanup."""

from pathlib import Path
import re
import runpy
import sys

COUNT = 1
WORDS = 0o2000
OWNER = 0o75
HALF = 0o777777


def verify(snapshot, final):
    original = runpy.run_path(str(Path(__file__).with_name(
        'daimos-f07-mm-peak-verify-v1203.py')))
    report = original['decode_snapshot'](snapshot)
    if any(final.get(key) != value for key, value in (
            ('prepared', COUNT), ('freed', COUNT),
            ('count', 0), ('error', 0))):
        raise ValueError('test-owner MM extent not exactly released')
    found = []
    for i in range(report['extent_count']):
        span = snapshot['extent%d' % (i * 2)]
        meta = snapshot['extent%d' % (i * 2 + 1)]
        if (meta >> 18) & 7 != 3 or (meta & HALF) != OWNER:
            continue
        words = (span >> 18) & HALF
        base = span & HALF
        if words != WORDS or base % 0o2000:
            raise ValueError('incorrect size/alignment of test-owner extent')
        found.append(base)
    if len(found) != COUNT or len(set(found)) != COUNT:
        raise ValueError('single owner extent missing at BRK OOM')
    if report['process_extents'] < 2:
        raise ValueError('no independent resident process extents')
    return report


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1323 ADDRESSES SIMH-OUTPUT')
    original = runpy.run_path(str(Path(__file__).with_name(
        'daimos-f07-mm-peak-verify-v1203.py')))
    snapshot = original['load_observation'](sys.argv[1], sys.argv[2])
    text = Path(sys.argv[2]).read_text(errors='replace')
    addresses = dict(line.split() for line in
                     Path(sys.argv[1]).read_text().splitlines())
    final = {}
    for key in ('prepared', 'freed', 'count', 'error'):
        addr = addresses['f07h_' + key]
        match = re.findall(r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)' %
                           int(addr, 8), text)
        if len(match) != 1:
            raise ValueError('missing or duplicate owner counter ' + key)
        final[key] = int(match[0], 8)
    report = verify(snapshot, final)
    for name, other in (('wrong-owner-count', dict(final, freed=0)),
                        ('retained-extent', dict(final, count=1))):
        try:
            verify(snapshot, other)
        except ValueError:
            continue
        raise AssertionError('unsafe control escaped: ' + name)
    print('v1323: one real 1K MM owner extent exists at physical BRK '
          'OOM; exact typed owner cleanup and negatives PASS')
    print('v1323: managed=%d allocated=%d free=%d process_extents=%d' %
          (report['managed_words'], report['allocated_words'],
           report['free_words'], report['process_extents']))


if __name__ == '__main__':
    main()
