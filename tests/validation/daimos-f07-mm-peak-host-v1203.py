#!/usr/bin/env python3
"""Host-only positive and negative controls for the F07 snapshot audit."""

from pathlib import Path
import runpy

verify = runpy.run_path(str(Path(__file__).with_name(
    'daimos-f07-mm-peak-verify-v1203.py')))
decode = verify['decode_snapshot']


def packed(base, words):
    return (words << 18) | base


snapshot = {
    'samples': 1,
    'error': 0,
    'count': 2,
    'capacity': 136,
    'core': 0o1000000,
    'arena_count': 2,
    'arena0': packed(0o40000, 0o200000),
    'arena1': packed(0o400000, 0o200000),
    'arena2': 0,
    'lease': 7 << 18,
    'buffer_base': 0o3000,
    'words': 4,
    'extent0': packed(0o40000, 0o2000),
    'extent1': (1 << 18) | 3,
    'extent2': packed(0o42000, 0o201),
    'extent3': (3 << 18) | 6,
}

valid = decode(snapshot)
assert valid['extent_count'] == 2
assert valid['descriptor_headroom'] == 134
assert valid['process_extents'] == 1
assert valid['kernel_dynamic_extents'] == 1
assert valid['managed_words'] == 2 * 0o200000
assert valid['allocated_words'] == 0o2201
assert valid['shared_provider_workspace_words'] == 128
assert valid['max_low_apr_placement_slack_words'] == 1023 * valid['free_gap_count']
assert valid['process_break_rounding_upper_bound_words'] == 1023

mutants = {
    'missing-capture': ('samples', 0),
    'bad-capacity': ('capacity', 137),
    'over-capacity': ('count', 137),
    'truncated-capture': ('words', 3),
    'lease-stolen': ('lease', 0),
    'overlap': ('extent2', packed(0o40001, 0o201)),
    'unaligned-process': ('extent0', packed(0o40001, 0o2000)),
    'outside-arena': ('extent2', packed(0o700000, 0o201)),
    'workspace-overlap': ('buffer_base', 0o40000),
    'sample-error': ('error', 1),
}
for name, (key, value) in mutants.items():
    modified = dict(snapshot)
    modified[key] = value
    try:
        decode(modified)
    except ValueError:
        continue
    raise AssertionError('F07 unsafe mutant was accepted: ' + name)

print('v1203: F07 host MM accounting/arena/APR/ownership audit and '
      '%d negative mutants PASS' % len(mutants))
