#!/usr/bin/env python3
"""Report frozen per-PID F07 dispatch and swap request counts.

This is a diagnostic report, NOT an F07 acceptance verifier. An
interrupted guest can show starvation candidates but not lifecycle PASS.
"""

from pathlib import Path
import re
import sys


SLOTS = 64


def load(address_text, simulator_text):
    addresses = {}
    for line in address_text.splitlines():
        parts = line.split()
        if len(parts) != 2 or not parts[0].startswith('f07u_'):
            continue
        if parts[0] in addresses:
            raise ValueError('duplicate v1253 observation ' + parts[0])
        addresses[parts[0]] = int(parts[1], 8)
    expected = {'f07u_idle'}
    for label in ('dispatch', 'swapreq'):
        expected.update('f07u_%s%02o' % (label, slot)
                        for slot in range(SLOTS))
    if set(addresses) != expected:
        raise ValueError('incomplete v1253 per-slot observation')
    values = {}
    for label, address in addresses.items():
        pattern = r'(?m)^\s*0*%o\s*:\s*([0-7]+)' % address
        matches = re.findall(pattern, simulator_text)
        if len(matches) != 1:
            raise ValueError('missing or repeated SIMH sample ' + label)
        values[label] = int(matches[0], 8)
    return values


def summary(values):
    rows = []
    for slot in range(SLOTS):
        dispatched = values['f07u_dispatch%02o' % slot]
        requested = values['f07u_swapreq%02o' % slot]
        if dispatched or requested:
            rows.append((slot, dispatched, requested))
    return rows


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1253 ADDRESSES SIMH.OUT')
    values = load(Path(sys.argv[1]).read_text(),
                  Path(sys.argv[2]).read_text(errors='replace'))
    print('v1253: diagnostic-only per-slot scheduler/swap provenance')
    print('slot-0 idle dispatches: %d' % values['f07u_idle'])
    print('slot  dispatched  swap_requests')
    for slot, dispatched, requested in summary(values):
        print('%4d %11d %14d' % (slot, dispatched, requested))
    print('NOTE: a stopped guest is not a completed F07 acceptance')


if __name__ == '__main__':
    main()
