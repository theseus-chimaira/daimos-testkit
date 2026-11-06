#!/usr/bin/env python3
"""Cross-check 24 actual processes, swapped VMs and kernel stacks."""

import json
import os
from pathlib import Path
import re
import runpy
import sys

root = Path(__file__).parent
mm_mod = runpy.run_path(str(root / 'daimos-f07-mm-peak-verify-v1203.py'))
proc_mod = runpy.run_path(str(root / 'daimos-f07-real-proc-verify-v1205.py'))


def read_values(addresses, simh, prefix):
    raw = Path(simh).read_text(errors='replace')
    result = {}
    for line in Path(addresses).read_text().splitlines():
        name, addr = line.split()
        if not name.startswith(prefix):
            continue
        hits = re.findall(r'(?m)^\s*0*%o\s*:\s*([0-7]+)'
                          % int(addr, 8), raw)
        if len(hits) != 1:
            raise ValueError('missing or repeated observation: ' + name)
        result[name[len(prefix):]] = int(hits[0], 8)
    return result


def verify_swapstack(snapshot, proc, counters):
    # v1239 production idle stack (the original 0100 words overflowed).
    idle_capacity = 0o400
    if os.environ.get('V1225_IDLE_STACK_EXPERIMENT') == '1':
        diagnostic_size = os.environ.get('V1225_IDLE_STACK_WORDS', '0140')
        if diagnostic_size not in ('0140', '0200', '0300', '0400'):
            raise ValueError('invalid diagnostic idle-stack capacity')
        idle_capacity = int(diagnostic_size, 8)
    mm = proc_mod['verify_slots'](snapshot, proc)
    if counters['samples'] != 1 or counters['error'] != 0:
        raise ValueError('swap-state snapshot missing or invalid')
    if counters['slot_capacity'] != 64:
        raise ValueError('incorrect 256K process-slot capacity')
    if counters['swap_active'] != 1:
        raise ValueError('swap service not active during OOM')
    full_slots = os.environ.get('V1271_TEST_FULL_SLOTS') == '1'
    expected_slots = 63 if full_slots else 24
    if mm['live_process_slots'] != expected_slots:
        raise ValueError('expected exactly %d live process slots' %
                         expected_slots)
    if full_slots:
        # Real process/u-area allocation must nearly saturate both the
        # 136-entry MM extent table and physical RAM while the foreign
        # provider still owns its 128-word serialized workspace. This
        # guards F07 against a nominally full PID table with no actual
        # descriptor, APR or provider pressure.
        physical = mm['mm']
        if physical['extent_count'] < 125 or \
                physical['descriptor_headroom'] > 11:
            raise ValueError('full-slot descriptor pressure too low')
        if physical['allocated_words'] < 235000 or \
                physical['free_words'] > 4096:
            raise ValueError('full-slot physical MM pressure too low')
        if physical['shared_provider_workspace_words'] != 128 or \
                physical['provider_owner_lease'] != 7 << 18:
            raise ValueError('full-slot provider workspace not owned')
        if mm['resident_process_extents'] < 50:
            raise ValueError('too few real resident process extents')
    if mm['nonresident_or_swap_processes'] < 1:
        raise ValueError('no nonresident user process observed')
    if counters['swap_blocks'] < 1:
        raise ValueError('no real swap backing blocks observed')
    if any(counters[name] != 0 for name in
           ('final_swap_blocks', 'final_backstore_used',
            'final_swap_active')):
        raise ValueError('swap backing or activation leaked after WAIT')
    private = counters['stack_peak']
    idle = counters['idle_peak']
    if not 0 < private <= 0o316:
        raise ValueError('private kernel stack highwater outside capacity')
    if not 0 < idle <= idle_capacity:
        raise ValueError('idle kernel stack highwater outside capacity')
    return {
        'real_process_slots': mm['live_process_slots'],
        'resident_process_extents': mm['resident_process_extents'],
        'nonresident_process_slots': mm['nonresident_or_swap_processes'],
        'swap_blocks_at_oom': counters['swap_blocks'],
        'slot_capacity': counters['slot_capacity'],
        'private_stack_highwater_words': private,
        'idle_stack_highwater_words': idle,
        'private_stack_capacity_words': 0o316,
        'idle_stack_capacity_words': idle_capacity,
        'exact_resident_brk_rounding_words':
            mm['exact_total_apr_rounding_words'],
        'mm_allocated_words': mm['mm']['allocated_words'],
        'mm_descriptor_count': mm['mm']['extent_count'],
        'foreign_provider_lease': mm['mm']['provider_owner_lease'],
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: verifier addresses simh.out')
    mm = mm_mod['load_observation'](sys.argv[1], sys.argv[2])
    proc = read_values(sys.argv[1], sys.argv[2], 'f07p_')
    counters = read_values(sys.argv[1], sys.argv[2], 'f07s_')
    result = verify_swapstack(mm, proc, counters)
    print('v1207: %d real user processes, live disk swap, exact VM/BRK '
          'and private/idle stack watermarks PASS' %
          result['real_process_slots'])
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
