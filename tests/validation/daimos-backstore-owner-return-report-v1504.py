#!/usr/bin/env python3
"""Map-backed final counters from a real PDP-6 owner-return diagnostic.

This reader deliberately makes no claim about the recovery gate until
the owner consumption path is observed and its witnesses cross-checked.
"""

from pathlib import Path
import re
import sys


SCALARS = ('armed_fdctl', 'armed_sched', 'armed_pc',
           'owner_term_count', 'owner_slot', 'owner_fdctl_before',
           'owner_backing_before', 'owner_commit_count',
           'owner_fdctl_after', 'private_fatal_count', 'private_status',
           'finish_count', 'finish_status', 'zombie_count')
ARRAYS = ('def_count', 'def_kind', 'def_prior')


def read(addresses, transcript):
    mapping = {}
    for row in Path(addresses).read_text().splitlines():
        name, addr = row.split()
        if name in mapping:
            raise ValueError('duplicate map name: ' + name)
        mapping[name] = int(addr, 8)
    output = Path(transcript).read_text(errors='replace')
    pos = output.rfind('HALT instruction, PC:')
    if pos < 0 or 'Goodbye' not in output[pos:]:
        raise ValueError('completed SIMH HALT/EXIT required')
    output = output[pos:]
    labels = ['v1494_slot', 'v1494_faults', 'v1494_free_calls',
              'v1494_repairs', 'f07s_final_swap_blocks',
              'f07s_final_backstore_used']
    labels.extend('v1504_' + x for x in SCALARS)
    labels.extend('v1504_%s_%02o' % (name, slot)
                  for name in ARRAYS for slot in range(64))
    result = {}
    for name in labels:
        if name not in mapping:
            raise ValueError('missing linked witness: ' + name)
        pattern = (r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)'
                   % mapping[name])
        found = re.findall(pattern, output)
        if len(found) != 1:
            raise ValueError('missing/duplicate final witness: ' + name)
        result[name] = int(found[0], 8)
    return result


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1504.py ADDRESSES SIMH.OUT')
    data = read(sys.argv[1], sys.argv[2])
    slot = data['v1494_slot']
    if slot <= 0 or slot >= 64:
        raise ValueError('no selected physical process slot')
    print('v1504: physical selected slot %03o' % slot)
    for key in ('v1494_faults', 'v1494_free_calls', 'v1494_repairs',
                'f07s_final_swap_blocks', 'f07s_final_backstore_used'):
        print('v1504: %-26s %012o' % (key, data[key]))
    for name in SCALARS:
        print('v1504: %-26s %012o' % (name, data['v1504_' + name]))
    for name in ARRAYS:
        key = 'v1504_%s_%02o' % (name, slot)
        print('v1504: %-26s %012o' % (key, data[key]))
    print('v1504: physical diagnostic; not yet full failure acceptance')


if __name__ == '__main__':
    main()
