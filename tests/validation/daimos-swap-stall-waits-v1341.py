#!/usr/bin/env python3
"""Decode source-linked process wait dependencies from SIMH raw samples.

Only reads the original production process table, kernel symbol map
and existing raw SIMH transcript. Does not infer a defect from a wait.
"""

from pathlib import Path
import argparse
import re

WORD = re.compile(r'(?m)^sim>\s*([0-7]+):\s*([0-7]{1,12})\s*$')
STOP = re.compile(r'(?m)^Simulation stopped, PC:')
HALF = 0o777777
TAG = 0o400000
CLOCK = 0o377777


def symbols(path):
    found = {}
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if len(fields) == 2 and re.fullmatch(r'[0-7]{1,7}', fields[1]):
            found[fields[0]] = int(fields[1], 8)
    return found


def decode(sym, raw):
    sections = STOP.split(Path(raw).read_text(errors='replace'))[1:]
    if not sections:
        raise ValueError('no real SIMH stop samples')
    snapshots = []
    for section in sections:
        words = {int(a, 8): int(v, 8) for a, v in WORD.findall(section)}
        base_addr = sym['proc_table']
        high_addr = sym['proc_high_slot']
        clock_addr = sym['proc_timer_clock']
        if not all(addr in words for addr in
                   (base_addr, high_addr, clock_addr)):
            continue
        base = words[base_addr] & HALF
        high = words[high_addr]
        if not (0 < high <= 64 and base + 3 * high < 0o1000000):
            raise ValueError('invalid linked process table')
        if not all(base + i in words for i in range(3 * high)):
            continue
        clock = words[clock_addr] & CLOCK
        states = []
        for slot in range(1, high):
            meta, vm, sched = (words[base + 3 * slot + i]
                               for i in range(3))
            state = (sched >> 33) & 7
            if state == 0:
                continue
            wait = sched & HALF
            wait_mode = (sched >> 18) & 0o60000
            kind = ('TIMER' if wait & TAG else
                    'CHILD' if wait_mode == 0o40000 else
                    'INTR' if wait_mode == 0o60000 else
                    'EVENT' if wait else 'NONE')
            remaining = ((wait & CLOCK) - clock) & CLOCK if kind == 'TIMER' else None
            named = sorted(name for name, addr in sym.items()
                           if addr == wait) if kind == 'EVENT' else []
            states.append(dict(slot=slot, state=state,
                               resident=bool(vm & HALF), wait=wait,
                               kind=kind, remaining=remaining,
                               symbol=named))
        snapshots.append((clock, states))
    if not snapshots:
        raise ValueError('no complete source-linked process snapshots')
    return snapshots


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('map')
    p.add_argument('raw')
    args = p.parse_args()
    snapshots = decode(symbols(args.map), args.raw)
    first, last = snapshots[0], snapshots[-1]
    print('v1341: complete samples=%d clock_first=%06o clock_last=%06o' %
          (len(snapshots), first[0], last[0]))
    for state in last[1]:
        if state['slot'] > 6:
            continue
        print('slot=%02o state=%d resident=%s wait=%s:%06o%s' %
              (state['slot'], state['state'], state['resident'],
               state['kind'], state['wait'],
               (' remaining=%d' % state['remaining']
                if state['remaining'] is not None else
                (' symbols=' + ','.join(state['symbol'])
                 if state['symbol'] else ''))))
    print('v1341: diagnostic only; no guest HALT or cleanup acceptance')


if __name__ == '__main__':
    main()
