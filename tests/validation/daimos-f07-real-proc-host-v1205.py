#!/usr/bin/env python3
"""Host positive/negative fixtures for real process BRK/MM accounting."""

from pathlib import Path
import runpy

v = runpy.run_path(str(Path(__file__).with_name(
    'daimos-f07-real-proc-verify-v1205.py')))
verify_slots = v['verify_slots']


def packed(base, words):
    return (words << 18) | base


snap = {
    'samples': 1, 'error': 0, 'count': 13,
    'capacity': 136, 'core': 0o1000000,
    'arena_count': 1, 'arena0': packed(0o40000, 0o600000),
    'arena1': 0, 'arena2': 0, 'lease': 7 << 18,
    'buffer_base': 0o3000, 'words': 26,
}
proc = {'samples': 1, 'slots': 13, 'error': 0}
for i in range(13):
    if i == 0:
        proc['meta0'] = proc['vm0'] = proc['sched0'] = proc['brk0'] = 0
        continue
    base = 0o40000 + (i - 1) * 0o2000
    proc['meta%d' % i] = (0o10000 << 18) | 0o400000
    proc['vm%d' % i] = packed(base, 0o2000)
    proc['sched%d' % i] = 3 << 33
    logical = 0o1000 if i < 7 else 0o1000 + i * 11 + 3
    proc['brk%d' % i] = packed(logical, 0o1000)
    snap['extent%d' % (2 * (i - 1))] = packed(base, 0o2000)
    snap['extent%d' % (2 * (i - 1) + 1)] = (1 << 18) | i
end = 0o40000 + 12 * 0o2000
snap['extent24'] = packed(end, 1)
snap['extent25'] = (3 << 18) | 1

good = verify_slots(snap, proc)
assert good['live_process_slots'] == 12
assert good['resident_process_extents'] == 12
assert good['exact_total_apr_rounding_words'] > 0

mutants = [
    ('missing-child', 'sched10', 0),
    ('bad-brk', 'brk8', packed(0o1001, 0o1000)),
    ('wrong-APR-VM', 'vm7', packed(0o40000 + 6 * 0o2000, 0o4000)),
    ('wrong-MM-owner', 'extent15', (1 << 18) | 6),
    ('missing-UAREA', 'meta11', (0o10000 << 18)),
]
for label, key, value in mutants:
    a, b = dict(snap), dict(proc)
    if key.startswith('extent'):
        a[key] = value
    else:
        b[key] = value
    try:
        verify_slots(a, b)
    except ValueError:
        continue
    raise AssertionError('unsafe process/MM mutant escaped: ' + label)

print('v1205: real-process/BRK/MM host positive and '
      '%d negative tests PASS' % len(mutants))
