#!/usr/bin/env python3
"""Reject incorrect high-pressure MM/lease snapshots and cleanup.

The 108 test-only extents must coexist with live PDP-6 process images,
the foreign filesystem provider lease and genuine BRK physical OOM.
"""

import json
from pathlib import Path
import re
import runpy
import sys

verify = runpy.run_path(str(Path(__file__).with_name(
    'daimos-f07-mm-peak-verify-v1203.py')))
HALF = verify['HALF']
decode_snapshot = verify['decode_snapshot']
load_observation = verify['load_observation']

LARGE_COUNT = 12
SMALL_COUNT = 96
LARGE_WORDS = 0o20000
TEST_OWNER = 0o75
TEST_TYPE = 3


def verify_high_pressure(snapshot, done):
    result = decode_snapshot(snapshot)
    if any(done.get(name) != expected for name, expected in (
            ('prepared', LARGE_COUNT + SMALL_COUNT),
            ('freed', LARGE_COUNT + SMALL_COUNT),
            ('count', 0), ('error', 0))):
        raise ValueError('test pressure not completely released: %r' % done)

    large = 0
    small = 0
    pressure_words = 0
    for index in range(result['extent_count']):
        span = snapshot['extent%d' % (2 * index)]
        meta = snapshot['extent%d' % (2 * index + 1)]
        kind = (meta >> 18) & 7
        owner = meta & HALF
        if kind != TEST_TYPE or owner != TEST_OWNER:
            continue
        words = (span >> 18) & HALF
        base = span & HALF
        if words == LARGE_WORDS and base % 0o2000 == 0:
            large += 1
        elif words == 1:
            small += 1
        else:
            raise ValueError('unexpected pressure extent or APR alignment')
        pressure_words += words

    expected_words = LARGE_COUNT * LARGE_WORDS + SMALL_COUNT
    if (large != LARGE_COUNT or small != SMALL_COUNT or
            pressure_words != expected_words):
        raise ValueError('missing test pressure allocations: %d/%d, %d/%d'
                         % (large, LARGE_COUNT, small, SMALL_COUNT))
    if result['process_extents'] < 6:
        raise ValueError('live process images missing under pressure')
    if result['extent_count'] < 120 or result['descriptor_headroom'] > 16:
        raise ValueError('test did not reach high descriptor occupancy')
    if result['free_words'] > 50000:
        raise ValueError('test did not reach high physical occupancy')
    if result['allocated_words'] <= result['managed_words'] * 4 // 5:
        raise ValueError('less than 80 percent of managed core allocated')

    result['pressure_large_extents'] = large
    result['pressure_small_extents'] = small
    result['pressure_words'] = pressure_words
    result['verified_pressure_releases'] = done['freed']
    return result


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: verify addresses simh.out')
    addresses = Path(sys.argv[1]).read_text().splitlines()
    simh = Path(sys.argv[2]).read_text(errors='replace')
    snapshot = load_observation(sys.argv[1], sys.argv[2])
    done = {}
    for line in addresses:
        name, addr = line.split()
        if not name.startswith('f07h_'):
            continue
        matches = re.findall(r'(?m)^\s*0*%o\s*:\s*([0-7]+)' % int(addr, 8),
                             simh)
        if len(matches) != 1:
            raise ValueError('missing/duplicate final high-pressure counter')
        done[name[5:]] = int(matches[0], 8)
    result = verify_high_pressure(snapshot, done)
    print('v1204 F07 high physical/MM descriptor pressure plus held '
          'filesystem owner and exact cleanup PASS')
    print(json.dumps(result, sort_keys=True, indent=2))


if __name__ == '__main__':
    main()
