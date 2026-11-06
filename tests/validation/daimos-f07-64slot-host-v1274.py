#!/usr/bin/env python3
"""Fail-closed mutation check of a real 64-slot F07 physical-OOM guest.

The snapshot must come from a completed PDP-6 release-media guest.
Mutations affect host copies only, never the original evidence files.
"""

import os
from pathlib import Path
import runpy
import sys


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1274 addresses simh.out')
    os.environ['V1271_TEST_FULL_SLOTS'] = '1'
    os.environ['V1207_TEST_SWAPSLOTS'] = '1'
    here = Path(__file__).parent
    mod = runpy.run_path(str(here / 'daimos-f07-swapstack-verify-v1207.py'))
    mm_mod = runpy.run_path(str(here / 'daimos-f07-mm-peak-verify-v1203.py'))
    snapshot = mm_mod['load_observation'](sys.argv[1], sys.argv[2])
    proc = mod['read_values'](sys.argv[1], sys.argv[2], 'f07p_')
    counters = mod['read_values'](sys.argv[1], sys.argv[2], 'f07s_')
    verify = mod['verify_swapstack']
    baseline = verify(snapshot, proc, counters)
    if baseline['real_process_slots'] != 63 or \
            baseline['mm_descriptor_count'] < 125:
        raise AssertionError('v1274: actual full-slot evidence absent')

    mutations = (
        ('slots', 'proc', 'slots', 63),
        ('last-user-not-live', 'proc', 'sched63', 0),
        ('last-user-wrong-brk', 'proc', 'brk63', proc['brk63'] ^ 1),
        ('last-user-no-uarea', 'proc', 'meta63', 0),
        ('MM-descriptors', 'snapshot', 'count', 124),
        ('provider-workspace', 'snapshot', 'words', 0),
        ('wrong-lease', 'snapshot', 'lease', 0),
        ('swap-disabled', 'counters', 'swap_active', 0),
        ('swap-absent', 'counters', 'swap_blocks', 0),
        ('swap-leak', 'counters', 'final_swap_blocks', 1),
        ('wrong-slot-capacity', 'counters', 'slot_capacity', 63),
        ('private-stack-overrun', 'counters', 'stack_peak', 0o317),
        ('idle-stack-overrun', 'counters', 'idle_peak', 0o401),
    )
    for label, target, key, value in mutations:
        a = dict(snapshot)
        b = dict(proc)
        c = dict(counters)
        {'snapshot': a, 'proc': b, 'counters': c}[target][key] = value
        try:
            verify(a, b, c)
        except ValueError:
            continue
        raise AssertionError('v1274: unsafe mutation passed: ' + label)
    print('v1274: real 64-slot / 127-descriptor / physical-OOM guest and '
          '%d negative mutations PASS' % len(mutations))


if __name__ == '__main__':
    main()
