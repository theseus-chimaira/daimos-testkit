#!/usr/bin/env python3
"""Host positive/negative controls for F07 process/swap/stack snapshot."""

from pathlib import Path
import runpy

mod = runpy.run_path(str(Path(__file__).with_name(
    'daimos-f07-swapstack-verify-v1207.py')))
verify = mod['verify_swapstack']


def pair(base, words):
    return words << 18 | base


mm = {'samples': 1, 'error': 0, 'count': 25, 'capacity': 136,
      'core': 0o1000000, 'arena_count': 1,
      'arena0': pair(0o40000, 0o600000), 'arena1': 0, 'arena2': 0,
      'lease': 7 << 18, 'buffer_base': 0o3000, 'words': 50}
proc = {'samples': 1, 'slots': 25, 'error': 0}
for slot in range(25):
    if slot == 0:
        for name in ('meta', 'vm', 'sched', 'brk'):
            proc[name + '0'] = 0
        continue
    proc['meta%d' % slot] = (0o10000 << 18) | 0o400000
    proc['sched%d' % slot] = 3 << 33
    logical = 0o1000 if slot < 7 else 0o1000 + slot * 11 + 3
    proc['brk%d' % slot] = pair(logical, 0o1000)
    if slot <= 12:
        base = 0o40000 + (slot - 1) * 0o2000
        proc['vm%d' % slot] = pair(base, 0o2000)
        mm['extent%d' % (2 * (slot - 1))] = pair(base, 0o2000)
        mm['extent%d' % (2 * (slot - 1) + 1)] = (1 << 18) | slot
    else:
        proc['vm%d' % slot] = pair(0, 0o2000)
cursor = 0o40000 + 12 * 0o2000
for i in range(13):
    mm['extent%d' % (2 * (i + 12))] = pair(cursor + i, 1)
    mm['extent%d' % (2 * (i + 12) + 1)] = (3 << 18) | 1

counters = {'samples': 1, 'error': 0, 'slot_capacity': 64,
            'swap_blocks': 400, 'swap_active': 1,
            'stack_peak': 0o300, 'idle_peak': 0o25,
            'final_swap_blocks': 0, 'final_backstore_used': 0,
            'final_swap_active': 0}
good = verify(mm, proc, counters)
assert good['real_process_slots'] == 24
assert good['nonresident_process_slots'] == 12
assert good['swap_blocks_at_oom'] == 400

mutations = [
    ('no-swap', 'swap_blocks', 0),
    ('swap-policy-off-at-oom', 'swap_active', 0),
    ('swap-leaked', 'final_swap_blocks', 1),
    ('backstore-leaked', 'final_backstore_used', 1),
    ('policy-leaked', 'final_swap_active', 1),
    ('no-private-watermark', 'stack_peak', 0),
    ('stack-overflow', 'stack_peak', 0o317),
    ('idle-overflow', 'idle_peak', good['idle_stack_capacity_words'] + 1),
    ('incorrect-capacity', 'slot_capacity', 32),
    ('not-sampled', 'samples', 0),
    ('probe-error', 'error', 1),
]
for label, key, value in mutations:
    modified = dict(counters)
    modified[key] = value
    try:
        verify(mm, proc, modified)
    except ValueError:
        continue
    raise AssertionError('v1207 unsafe mutant accepted: ' + label)

print('v1207: 24-process real/swap/stack host fixture and '
      '%d negative controls PASS' % len(mutations))
