#!/usr/bin/env python3
"""Host positive/negative tests of combined process/descriptor accounting."""

import runpy
from pathlib import Path

verifier = runpy.run_path(str(Path(__file__).with_name(
    'daimos-f07-combined-verify-v1206.py')))
verify = verifier['verify_combined']


def packed(base, words):
    return (words << 18) | base


first = 0o40000
extent = []
at = first
for slot in range(1, 13):
    length = 0o44000 if slot <= 6 else 0o46000
    extent.append((at, length, 1, slot))
    at += length
for i in range(19):
    extent.append((at, 1, 3, 1))
    at += 1
for i in range(96):
    extent.append((at, 1, 3, 0o75))
    at += 1
assert len(extent) == 127
snap = {
    'samples': 1, 'count': 127, 'capacity': 136,
    'core': 0o1000000,
    'arena_count': 1, 'arena0': packed(first, 0o730000),
    'arena1': 0, 'arena2': 0, 'lease': 7 << 18,
    'buffer_base': 0o3000, 'words': 254, 'error': 0,
}
for i, (base, words, kind, owner) in enumerate(extent):
    snap['extent%d' % (2 * i)] = packed(base, words)
    snap['extent%d' % (2 * i + 1)] = (kind << 18) | owner

done = {'prepared': 96, 'freed': 96, 'count': 0, 'error': 0}
result = verify(snap, done)
assert result['pressure_words'] == 96
assert result['actual_process_images'] == 12

mutants = [
    ('not-all-prepared', None, ('prepared', 95)),
    ('not-all-freed', None, ('freed', 95)),
    ('retained-pressure', None, ('count', 1)),
    ('wrong-test-owner', ('extent%d' % (2 * 31 + 1),
                          (3 << 18) | 0o74), None),
    ('non-unit-extent', ('extent%d' % (2 * 31),
                         packed(extent[31][0], 2)), None),
    ('wrong-provider', ('lease', 0), None),
    ('too-few-processes', ('extent%d' % (2 * 5 + 1),
                           (3 << 18) | 6), None),
]
for label, snapshot_change, done_change in mutants:
    a = dict(snap)
    b = dict(done)
    if snapshot_change:
        a[snapshot_change[0]] = snapshot_change[1]
    if done_change:
        b[done_change[0]] = done_change[1]
    try:
        verify(a, b)
    except ValueError:
        continue
    raise AssertionError('bad combined MM case was accepted: ' + label)

print('v1206: combined real-process/MM host test and %d '
      'negative mutations PASS' % len(mutants))
