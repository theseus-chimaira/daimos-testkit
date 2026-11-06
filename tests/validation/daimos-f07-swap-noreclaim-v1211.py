#!/usr/bin/env python3
"""F07 source-linked guard against nested swap-in MM reclamation.

The full PDP-6 guest remains the authority for progress and cleanup.
This guard prevents an old, recursive allocator call from silently
reappearing inside a TRANSITION-held swap-in transaction.
"""

from pathlib import Path
import re
import sys


def verify(source, mm_source):
    if source.count('proc_swap_in:\n') != 1:
        raise ValueError('missing/duplicate native swap-in')
    region = source.split('proc_swap_in:\n', 1)[1].split(
        '\nproc_swap_mres_service_v481:', 1)[0]
    calls = re.findall(r'^\s*pushj\s+17,(mm_alloc_aligned(?:_noreclaim)?)\s*$',
                       region, re.M)
    if calls != ['mm_alloc_aligned_noreclaim']:
        raise ValueError('swap-in can recursively reclaim during TRANSITION')
    if '.globl  mm_alloc_aligned_noreclaim' not in source:
        raise ValueError('no resolved native no-reclaim MM entry')
    fallback = source.split('proc_swap_service_reclaim_v1208:\n', 1)
    if len(fallback) != 2:
        raise ValueError('no explicit slot-0 swap-pressure service')
    fallback = fallback[1].split('\nproc_swap_service_cooldown_v833:', 1)[0]
    if not re.search(r'pushj\s+17,proc_swap_mres_reclaim_v481', fallback):
        raise ValueError('pressure fallback does not reclaim a victim')
    if not re.search(r'pushj\s+17,proc_swap_in', fallback):
        raise ValueError('pressure fallback does not retry original owner')
    nr = mm_source.split('mm_alloc_aligned_noreclaim:\n', 1)
    if len(nr) != 2:
        raise ValueError('missing authoritative native MM allocator')
    nr = nr[1].split('\n; int mm_alloc', 1)[0]
    if re.search(r'pushj\s+17,(?:proc_swap_reclaim|mm_alloc_aligned)\b', nr):
        raise ValueError('supposed no-reclaim MM leaf recursively reclaims')


def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1211 source-linked-check DAIMOS_REPO')
    root = Path(sys.argv[1]) / 'system/kernel'
    source = (root / 'proc/proc_swap_pdp6.s').read_text()
    mm = (root / 'mm/mm_pdp6.s').read_text()
    verify(source, mm)
    bad = [
        ('recursive-wrapper', source.replace(
            'pushj   17,mm_alloc_aligned_noreclaim',
            'pushj   17,mm_alloc_aligned', 1), mm),
        ('missing-pressure-reclaim', source.replace(
            'pushj   17,proc_swap_mres_reclaim_v481',
            'pushj   17,proc_swap_in', 1), mm),
        ('missing-retry', source.replace(
            'proc_swap_service_reclaim_v1208:\n',
            'proc_swap_service_reclaim_unsafe:\n', 1), mm),
    ]
    for label, other, other_mm in bad:
        try:
            verify(other, other_mm)
        except ValueError:
            continue
        raise AssertionError('v1211 source mutant escaped: ' + label)
    print('v1211: non-recursive native swap-in with sequential reclaim '
          'and 3 negative mutants PASS (source guard only)')


if __name__ == '__main__':
    main()
