#!/usr/bin/env python3
"""Print independent v1495 diagnostic counters; do not claim acceptance."""

from pathlib import Path
import re
import sys


FIELDS = (
    'failed_entry', 'service_slot', 'event_returned',
    'witness_enter', 'witness_slot', 'witness_top', 'witness_below',
    'term_unlock_error', 'term_mark_error',
    'retry_unlock_error', 'retry_mark_error',
    'retry_descriptor', 'retry_marker',
)


def values(addresses, transcript):
    mapping = {}
    for row in Path(addresses).read_text().splitlines():
        name, address = row.split()
        if name in mapping:
            raise ValueError('duplicate mapped name: ' + name)
        mapping[name] = int(address, 8)
    output = Path(transcript).read_text(errors='replace')
    pos = output.rfind('HALT instruction, PC:')
    if pos < 0 or 'Goodbye' not in output[pos:]:
        raise ValueError('not a completed HALT/EXIT guest')
    output = output[pos:]
    result = {}
    for key in FIELDS:
        label = 'v1495_' + key
        if label not in mapping:
            raise ValueError('missing mapped diagnostic: ' + label)
        pattern = r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)' % mapping[label]
        hits = re.findall(pattern, output)
        if len(hits) != 1:
            raise ValueError('missing/duplicated final value: ' + label)
        result[key] = int(hits[0], 8)
    return result


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1495.py ADDRESSES SIMH.OUT')
    for key, value in values(sys.argv[1], sys.argv[2]).items():
        print('v1495: %-22s %012o' % (key, value))
    print('v1495: diagnostics only; no release-gate acceptance inferred')


if __name__ == '__main__':
    main()
