#!/usr/bin/env python3
"""Verify a real live-MM snapshot captured during a held-provider BRK OOM.

All word quantities are PDP-6 36-bit words; physical/map addresses are
octal. This is an observational subtest, not maximum-load F07 signoff.
"""

import json
from pathlib import Path
import re
import sys

HALF = 0o777777
ALIGN = 0o2000
MAX_EXTENTS = 136
BUFFER_WORDS = 0o200


def decode_snapshot(values):
    """Return a checked, quantitative MM state for one atomic sample."""
    count = values['count']
    capacity = values['capacity']
    core = values['core']
    arena_count = values['arena_count']
    if values['samples'] != 1 or values['error'] != 0:
        raise ValueError('missing or failed atomic OOM snapshot')
    if not (0 <= count <= capacity == MAX_EXTENTS):
        raise ValueError('invalid live descriptor count/capacity')
    if core != 0o1000000 or not (1 <= arena_count <= 3):
        raise ValueError('unexpected 256K core or arena count')
    if values['lease'] != (7 << 18):
        raise ValueError('foreign filesystem provider was not leased')
    if values['words'] != 2 * count:
        raise ValueError('partial MM table capture')

    arenas = []
    for i in range(arena_count):
        span = values['arena%d' % i]
        base, words = span & HALF, (span >> 18) & HALF
        if words <= 0 or base + words > core:
            raise ValueError('invalid managed arena')
        if arenas and base < arenas[-1][0] + arenas[-1][1]:
            raise ValueError('overlapping or unordered MM arenas')
        arenas.append((base, words))

    extents = []
    processes = 0
    dynamic = 0
    by_type = {}
    for i in range(count):
        span = values['extent%d' % (2 * i)]
        meta = values['extent%d' % (2 * i + 1)]
        base, words = span & HALF, (span >> 18) & HALF
        kind = (meta >> 18) & 7
        owner = meta & HALF
        pins = (meta >> 21) & 0o377
        if words == 0 or kind not in (1, 2, 3, 4):
            raise ValueError('invalid MM extent span or type')
        if base + words > core:
            raise ValueError('extent outside physical core')
        if extents and base < extents[-1][0] + extents[-1][1]:
            raise ValueError('MM extent overlap or unsorted table')
        if sum(a <= base and base + words <= a + length
               for a, length in arenas) != 1:
            raise ValueError('extent not contained in one arena')
        if kind == 1:
            if base % ALIGN or words % ALIGN:
                raise ValueError('process extent violates APR quantum')
            processes += 1
        if kind == 3:
            dynamic += 1
        by_type[str(kind)] = by_type.get(str(kind), 0) + 1
        extents.append((base, words, kind, owner, pins))

    gaps = []
    j = 0
    for arena_base, arena_words in arenas:
        end = arena_base + arena_words
        cursor = arena_base
        while j < len(extents) and extents[j][0] < end:
            base, words, _, _, _ = extents[j]
            if base > cursor:
                gaps.append((cursor, base - cursor))
            cursor = base + words
            j += 1
        if cursor < end:
            gaps.append((cursor, end - cursor))
    if j != len(extents):
        raise ValueError('extent outside all managed arenas')

    managed = sum(words for _, words in arenas)
    allocated = sum(words for _, words, _, _, _ in extents)
    free = sum(words for _, words in gaps)
    if managed != allocated + free:
        raise ValueError('managed physical MM accounting mismatch')
    # Placement slack at the beginning of each free run, for an
    # APR-aligned LOW allocation. This is not the logical BRK rounding
    # overhead, which requires separate per-process break snapshots.
    low_alignment_slack = sum(min(words, (-base) % ALIGN)
                              for base, words in gaps)
    if low_alignment_slack > (ALIGN - 1) * len(gaps):
        raise ValueError('alignment slack bound violated')

    buf = values['buffer_base']
    if buf <= 0 or buf + BUFFER_WORDS > core:
        raise ValueError('invalid shared provider buffer address')
    for base, words, _, _, _ in extents:
        if buf < base + words and base < buf + BUFFER_WORDS:
            raise ValueError('shared provider workspace overlaps managed MM')
    return {
        'core_words': core,
        'managed_words': managed,
        'unmanaged_words': core - managed,
        'allocated_words': allocated,
        'free_words': free,
        'extent_count': count,
        'descriptor_capacity': capacity,
        'descriptor_headroom': capacity - count,
        'process_extents': processes,
        'kernel_dynamic_extents': dynamic,
        'extent_types': by_type,
        'arena_count': arena_count,
        'free_gap_count': len(gaps),
        'largest_gap_words': max((words for _, words in gaps), default=0),
        'low_apr_placement_slack_words': low_alignment_slack,
        'max_low_apr_placement_slack_words': (ALIGN - 1) * len(gaps),
        'process_break_rounding_upper_bound_words': (ALIGN - 1) * processes,
        'shared_provider_workspace_base': buf,
        'shared_provider_workspace_words': BUFFER_WORDS,
        'provider_owner_lease': values['lease'],
    }


def load_observation(address_file, simh_file):
    addresses = {}
    for line in Path(address_file).read_text().splitlines():
        name, addr = line.split()
        if name.startswith('f07_'):
            addresses[name[4:]] = int(addr, 8)
    simh = Path(simh_file).read_text(errors='replace')
    raw = {}
    for name, address in addresses.items():
        pattern = r'(?m)^\s*0*%o\s*:\s*([0-7]+)' % address
        found = re.findall(pattern, simh)
        if len(found) != 1:
            raise ValueError('expected one simulator observation for %s: %d'
                             % (name, len(found)))
        raw[name] = int(found[0], 8)
    return raw


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: verify addresses simh.out')
    values = load_observation(sys.argv[1], sys.argv[2])
    result = decode_snapshot(values)
    print('v1203 F07 genuine physical-OOM held-provider MM snapshot PASS')
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
