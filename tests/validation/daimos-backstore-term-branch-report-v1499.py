#!/usr/bin/env python3
"""Report two real mapped TERM event snapshots from full-guest F07."""

from pathlib import Path
import re
import sys

ARRAYS = ('pre_meta', 'pre_vm', 'pre_sched', 'pre_pc', 'pre_fdctl',
          'pre_finalize', 'event_result', 'post_meta', 'post_vm',
          'post_sched', 'post_fdctl', 'post_finalize')
COUNTERS = ('events', 'active', 'overflow', 'foreign', 'deferred',
            'busy', 'finish', 'prevm_refused', 'close_refused')


def read_values(addresses, simh):
    mapping = {}
    for row in Path(addresses).read_text().splitlines():
        name, octal = row.split()
        if name in mapping:
            raise ValueError('duplicate mapped witness: ' + name)
        mapping[name] = int(octal, 8)
    text = Path(simh).read_text(errors='replace')
    start = text.rfind('HALT instruction, PC:')
    if start < 0 or 'Goodbye' not in text[start:]:
        raise ValueError('complete physical SIMH HALT/EXIT not observed')
    text = text[start:]
    values = {}
    for name in tuple('v1499_' + x for x in COUNTERS) + tuple(
            'v1499_%s_%d' % (key, index)
            for key in ARRAYS for index in range(2)):
        if name not in mapping:
            raise ValueError('missing mapped witness: ' + name)
        expression = (r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)'
                      % mapping[name])
        matches = re.findall(expression, text)
        if len(matches) != 1:
            raise ValueError('expected one post-HALT value: ' + name)
        values[name] = int(matches[0], 8)
    return values


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1499.py ADDRESSES COMPLETED-SIMH.OUT')
    result = read_values(sys.argv[1], sys.argv[2])
    for name in COUNTERS:
        print('v1499 %-19s %012o' % (name, result['v1499_' + name]))
    for i in range(2):
        print('v1499 event %d:' % (i + 1))
        for name in ARRAYS:
            value = result['v1499_%s_%d' % (name, i)]
            print('  %-19s %012o' % (name, value))
    if result['v1499_events'] != 2 or result['v1499_overflow']:
        raise ValueError('exact two-event snapshot not obtained')
    print('v1499: diagnostic classification only, no acceptance')


if __name__ == '__main__':
    main()
