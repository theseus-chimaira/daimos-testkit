#!/usr/bin/env python3
"""Audit the exact physical-allocator error at a real swap-in failure.

The observation is diagnostic, not an F07 acceptance result. Both fit
queries are read-only and occur on the same failure path in the guest.
"""

import json
from pathlib import Path
import re
import sys


NAMES = ('calls', 'error', 'owner', 'requested', 'extents',
         'low_fit', 'low_base_or_free', 'high_fit',
         'high_base_or_free', 'meta')
MASK36 = (1 << 36) - 1


def read_observation(addresses, simh):
    raw = Path(simh).read_text(errors='replace')
    result = {}
    for line in Path(addresses).read_text().splitlines():
        name, address = line.split()
        if not name.startswith('f07a_'):
            continue
        hits = re.findall(r'(?m)^\s*0*%o:\s*([0-7]+)\s*$'
                          % int(address, 8), raw)
        if len(hits) != 1:
            raise ValueError('v1219 missing/repeated symbol ' + name)
        result[name[5:]] = int(hits[0], 8)
    if set(result) != set(NAMES):
        raise ValueError('v1219 missing MM observation fields')
    return result


def verify(obs):
    if obs['calls'] < 1 or obs['owner'] <= 0:
        raise ValueError('no genuine process swap-in failure')
    if obs['requested'] == 0 or obs['requested'] % 0o2000:
        raise ValueError('bad APR request size')
    if not 0 < obs['extents'] <= 136:
        raise ValueError('invalid MM extent count')
    error = obs['error'] - (1 << 36) if obs['error'] & (1 << 35) else obs['error']
    if error not in (-1, -2, -3):
        raise ValueError('non-resource allocator failure')
    if obs['low_fit'] not in (0, 1) or obs['high_fit'] not in (0, 1):
        raise ValueError('invalid MM fit result')
    if obs['low_fit'] != obs['high_fit']:
        raise ValueError('LOW/HIGH fit disagreement')
    if error == -2:
        if obs['low_fit'] or obs['high_fit']:
            raise ValueError('fragmentation reported despite a fit')
        if obs['low_base_or_free'] < obs['requested']:
            raise ValueError('fragmentation reported with insufficient RAM')
        if obs['low_base_or_free'] != obs['high_base_or_free']:
            raise ValueError('free-word count changes across read-only fits')
    return {'owner': obs['owner'], 'attempts': obs['calls'],
            'mm_error': error, 'requested_words': obs['requested'],
            'total_free_words': obs['low_base_or_free'] if not obs['low_fit'] else None,
            'low_fit': obs['low_fit'], 'high_fit': obs['high_fit'],
            'mm_extents': obs['extents']}


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1219-verifier addresses simh.out')
    print(json.dumps(verify(read_observation(sys.argv[1], sys.argv[2])),
                     sort_keys=True, indent=2))
