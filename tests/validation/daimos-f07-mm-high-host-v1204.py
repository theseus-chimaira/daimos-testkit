#!/usr/bin/env python3
"""Host positive/negative controls for the high-pressure F07 verifier."""

from pathlib import Path
import runpy

mod = runpy.run_path(str(Path(__file__).with_name(
    'daimos-f07-mm-high-verify-v1204.py')))
verify = mod['verify_high_pressure']


def span(base, words):
    return (words << 18) | base


result = {
    'samples': 1, 'count': 127, 'capacity': 136,
    'core': 0o1000000, 'arena_count': 1,
    'arena0': span(0o40000, 0o320000),
    'arena1': 0, 'arena2': 0,
    'lease': 7 << 18, 'buffer_base': 0o3000,
    'words': 254, 'error': 0,
}

# Six process extents, 12 large and 96 small test-owned extents,
# plus 13 normal kernel-dynamic owners to model the existing baseline.
offset = 0o40000
extents = []
for i in range(6):
    extents.append((offset, 0o2000, 1, i + 1))
    offset += 0o2000
for i in range(12):
    extents.append((offset, 0o20000, 3, 0o75))
    offset += 0o20000
for i in range(96):
    extents.append((offset, 1, 3, 0o75))
    offset += 1
for i in range(13):
    extents.append((offset, 1, 3, 1))
    offset += 1
for i, (base, words, kind, owner) in enumerate(extents):
    result['extent%d' % (2 * i)] = span(base, words)
    result['extent%d' % (2 * i + 1)] = (kind << 18) | owner

done = {'prepared': 108, 'freed': 108, 'count': 0, 'error': 0}
good = verify(result, done)
assert good['pressure_words'] == 12 * 8192 + 96

mutants = [
    ('partial-release', None, ('freed', 107)),
    ('pressure-still-held', None, ('count', 1)),
    ('allocator-error', None, ('error', 1)),
    ('lost-large', ('extent%d' % (2 * 6 + 1), (3 << 18) | 0o76), None),
    ('unaligned-large', ('extent%d' % (2 * 6),
                         span(0o54001, 0o20000)), None),
    ('missing-small', ('extent%d' % (2 * 18 + 1), (3 << 18) | 0o76), None),
    ('lease-stolen', ('lease', 0), None),
]
for label, snapshot_mutant, done_mutant in mutants:
    data = dict(result)
    end = dict(done)
    if snapshot_mutant:
        data[snapshot_mutant[0]] = snapshot_mutant[1]
    if done_mutant:
        end[done_mutant[0]] = done_mutant[1]
    try:
        verify(data, end)
    except ValueError:
        continue
    raise AssertionError('v1204 unsafe mutation escaped: ' + label)

print('v1204: high-pressure host snapshot and %d negative mutants PASS'
      % len(mutants))
