#!/usr/bin/env python3
"""Decode a disposable F07 scheduler snapshot after SIMH stop.

The snapshot is diagnostic evidence, not an acceptance PASS.  In particular
an interrupted guest cannot demonstrate requester-only OOM correctness.
"""

from pathlib import Path
import re
import sys


STATES = ('FREE', 'OTHER', 'RUN', 'SLEEP', 'ZOMBIE', 'OTHER5',
          'STOP', 'OTHER7')


def decode(addresses, simh):
    addresses = [line.split() for line in Path(addresses).read_text().splitlines()]
    dump = Path(simh).read_text(errors='replace')
    values = {}
    for name, location in addresses:
        if not name.startswith('f07q_'):
            continue
        target = int(location, 8)
        matches = re.findall(r'(?m)^\s*0*%o\s*:\s*([0-7]+)' % target,
                             dump)
        if len(matches) != 1:
            raise ValueError('missing/repeated SIMH observation: ' + name)
        values[name[5:]] = int(matches[0], 8)
    if len([name for name in values if name.startswith('slot')]) != 0o140:
        raise ValueError('incomplete native descriptor snapshot')
    return values, dump


def report(values, dump):
    print('Guest stage markers:', ''.join(re.findall(r'^<([^\r\n]*)',
                                                dump, flags=re.M))[:80])
    for key in ('services', 'swap_request', 'selector_swap',
                'selector_ready', 'selector_resident', 'selector_none',
                'idle', 'timer', 'cursor', 'current', 'runq', 'high_slot',
                'process_table', 'rt_owner', 'pid1_meta', 'pid1_vm',
                'pid1_sched'):
        print('%-23s %012o' % (key, values[key]))
    print('slot state  flags       uarea     vm_words  vm_base   next')
    for slot in range(32):
        base = slot * 3
        meta = values['slot%03o' % base]
        vm = values['slot%03o' % (base + 1)]
        sched = values['slot%03o' % (base + 2)]
        state = (sched >> 33) & 7
        if slot and not (meta or vm or sched):
            continue
        print('%4d %-6s %06o %06o %06o %06o %06o' % (
            slot, STATES[state], meta & 0o777777,
            (meta >> 18) & 0o777777, (vm >> 18) & 0o777777,
            vm & 0o777777, sched & 0o777777))


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1238 ADDRESSES SIMH.OUT')
    values, dump = decode(sys.argv[1], sys.argv[2])
    report(values, dump)


if __name__ == '__main__':
    main()
