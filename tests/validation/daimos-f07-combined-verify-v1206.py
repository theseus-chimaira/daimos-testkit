#!/usr/bin/env python3
"""Verify genuine 12-user BRK plus 96 real MM descriptor pressure.

The v1203 MM and v1205 process verifiers execute first; this checks
the v1204 exact typed MM allocation/release on the SAME snapshot.
"""

import json
from pathlib import Path
import re
import runpy
import sys

mm_v1203 = runpy.run_path(str(Path(__file__).with_name(
    'daimos-f07-mm-peak-verify-v1203.py')))
decode_snapshot = mm_v1203['decode_snapshot']
load_observation = mm_v1203['load_observation']
HALF = mm_v1203['HALF']

EXTRA_EXTENTS = 96
EXTRA_OWNER = 0o75


def verify_combined(snapshot, done):
    mm = decode_snapshot(snapshot)
    if any(done.get(name) != expected for name, expected in (
            ('prepared', EXTRA_EXTENTS), ('freed', EXTRA_EXTENTS),
            ('count', 0), ('error', 0))):
        raise ValueError('v1206 allocations leaked or cleanup rejected')
    if mm['process_extents'] != 12:
        raise ValueError('not twelve real resident user processes')
    if mm['extent_count'] < 125 or mm['descriptor_headroom'] > 11:
        raise ValueError('insufficient combined MM descriptor pressure')
    if mm['allocated_words'] < 225000 or mm['free_words'] > 20000:
        raise ValueError('combined physical occupancy too low')

    owned = 0
    words = 0
    for i in range(mm['extent_count']):
        span = snapshot['extent%d' % (2 * i)]
        meta = snapshot['extent%d' % (2 * i + 1)]
        kind = (meta >> 18) & 7
        owner = meta & HALF
        if kind != 3 or owner != EXTRA_OWNER:
            continue
        owned += 1
        words += (span >> 18) & HALF
        if (span >> 18) & HALF != 1:
            raise ValueError('unexpected large test-owned allocation')
    if owned != EXTRA_EXTENTS or words != EXTRA_EXTENTS:
        raise ValueError('not all 96 real descriptor extents coexist')

    result = dict(mm)
    result['pressure_extents'] = owned
    result['pressure_words'] = words
    result['exact_pressure_releases'] = done['freed']
    result['actual_process_images'] = mm['process_extents']
    return result


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: verifier addresses simh.out')
    snapshot = load_observation(sys.argv[1], sys.argv[2])
    simh = Path(sys.argv[2]).read_text(errors='replace')
    done = {}
    for line in Path(sys.argv[1]).read_text().splitlines():
        name, addr = line.split()
        if not name.startswith('f07h_'):
            continue
        match = re.findall(r'(?m)^\s*0*%o\s*:\s*([0-7]+)'
                           % int(addr, 8), simh)
        if len(match) != 1:
            raise ValueError('missing combined final counter ' + name)
        done[name[5:]] = int(match[0], 8)
    result = verify_combined(snapshot, done)
    print('v1206 F07 12 real processes plus 96 MM descriptors '
          'under original held provider and exact cleanup PASS')
    print(json.dumps(result, sort_keys=True, indent=2))


if __name__ == '__main__':
    main()
