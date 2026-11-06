#!/usr/bin/env python3
"""Cross-check each resident PDP-6 process VM with real MM/BRK state."""

import json
from pathlib import Path
import re
import runpy
import sys

v1203 = runpy.run_path(str(Path(__file__).with_name(
    'daimos-f07-mm-peak-verify-v1203.py')))
decode_snapshot = v1203['decode_snapshot']
load_observation = v1203['load_observation']
HALF = v1203['HALF']
ALIGN = v1203['ALIGN']


def verify_slots(snapshot, proc):
    mm = decode_snapshot(snapshot)
    if proc['samples'] != 1 or proc['error'] != 0:
        raise ValueError('process probe absent/failed')
    high = proc['slots']
    if high < 13 or high > 64:
        raise ValueError('not enough live real process slots')

    extents = {}
    for index in range(mm['extent_count']):
        span = snapshot['extent%d' % (2 * index)]
        meta = snapshot['extent%d' % (2 * index + 1)]
        if ((meta >> 18) & 7) != 1:
            continue
        owner = meta & HALF
        if owner in extents:
            raise ValueError('more than one process MM extent per owner')
        extents[owner] = (span & HALF, (span >> 18) & HALF)

    live = 0
    resident = 0
    rounded_waste = 0
    processes = []
    for slot in range(high):
        # Slot zero is the kernel scheduler context, not a user
        # process and not an MM_TYPE_PROCESS owner. Its saved VM word
        # is not required to appear in the user-extent table.
        if slot == 0:
            continue
        meta = proc['meta%d' % slot]
        vm = proc['vm%d' % slot]
        sched = proc['sched%d' % slot]
        brk = proc['brk%d' % slot]
        state = (sched >> 33) & 7
        # Slots 1..12 must still exist, including six new user
        # processes, when the original requester hits physical OOM.
        if 1 <= slot <= 12 and (state in (0, 4) or not meta & 0o400000):
            raise ValueError('expected live process slot lost: %d' % slot)
        if state in (0, 4):
            continue
        live += 1
        words = (vm >> 18) & HALF
        base = vm & HALF
        logical = brk & HALF
        initial = (brk >> 18) & HALF
        if meta & 0o400000 and (brk == 0 or not 0 < initial <= logical):
            raise ValueError('missing or malformed live logical BRK')
        if 7 <= slot <= 12 and logical - initial != slot * 11 + 3:
            raise ValueError('extra child never published its distinct BRK')
        if base and words:
            if slot not in extents:
                raise ValueError('resident slot %d VM %o,,%o missing '
                                 'from MM owners %r' %
                                 (slot, words, base, sorted(extents)))
            if extents[slot] != (base, words):
                raise ValueError('resident VM base/length mismatches MM')
            if ((logical + ALIGN - 1) // ALIGN * ALIGN) != words:
                raise ValueError('process APR allocation != rounded BRK')
            resident += 1
            rounded_waste += words - logical
            processes.append({'slot': slot, 'state': state,
                              'vm_words': words, 'logical_brk': logical,
                              'apr_rounding_words': words - logical})
        elif slot in extents:
            raise ValueError('nonresident process retains MM extent')

    if live < 12 or resident < 6:
        raise ValueError('insufficient real process concurrency')
    if len(extents) != resident or resident != mm['process_extents']:
        raise ValueError('process/MM live owner totals disagree')
    if not all(0 <= p['apr_rounding_words'] < ALIGN for p in processes):
        raise ValueError('actual APR rounding exceeds one quantum')
    return {
        'live_process_slots': live,
        'resident_process_extents': resident,
        'nonresident_or_swap_processes': live - resident,
        'exact_total_apr_rounding_words': rounded_waste,
        'process_slots': processes,
        'mm': mm,
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: verify addresses simh.out')
    snapshot = load_observation(sys.argv[1], sys.argv[2])
    addresses = Path(sys.argv[1]).read_text().splitlines()
    simh = Path(sys.argv[2]).read_text(errors='replace')
    proc = {}
    for line in addresses:
        name, addr = line.split()
        if not name.startswith('f07p_'):
            continue
        matches = re.findall(r'(?m)^\s*0*%o\s*:\s*([0-7]+)'
                             % int(addr, 8), simh)
        if len(matches) != 1:
            raise ValueError('missing/duplicate process observation ' + name)
        proc[name[5:]] = int(matches[0], 8)
    result = verify_slots(snapshot, proc)
    print('v1205 F07 actual process-slot, MM extent and logical BRK '
          'APR rounding PASS')
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
