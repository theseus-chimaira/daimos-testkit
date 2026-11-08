#!/usr/bin/env python3
"""Regression for v1303's distinction between refusal and fatal I/O.

The production proc_swap_out_fail label rejects invalid/ineligible
victims before beginning a swap-out transaction as well as later
failures. Its call count cannot establish a fatal published swap.
Original final HALT, no-partner, restore and zero-backing checks stay.
"""

from pathlib import Path
import runpy


def main():
    here = Path(__file__).resolve().parent
    module = runpy.run_path(str(here / 'daimos-swap-no-partner-physical-v1303.py'))
    verify = module['verify']
    counts = dict.fromkeys(module['FIELDS'], 0)
    counts.update(pressure=1, swapin_pressure=1, cooldown=1,
                  swapout_ok=34, swapin_ok=18, restored=18,
                  reclaim_fail=1, swapout_fail=1)
    alloc = dict.fromkeys(module['ALLOC'], 0)
    alloc.update(calls=1, error=(1 << 36) - 1, requested=26624,
                 owner=5, low_fit=0, high_fit=0)
    final = dict(f07s_final_swap_blocks=0, f07s_final_backstore_used=0)
    if verify(counts, alloc, final) is not True:
        raise AssertionError('legitimate no-partner preflight refusal rejected')
    cases = (
        ('actual-fatal-swapin', {'swapin_fail': 1}, {}, {}),
        ('wrong-restore', {'restored': 17}, {}, {}),
        ('missing-cooldown', {'cooldown': 0}, {}, {}),
        ('missing-allocator-evidence', {}, {'calls': 0}, {}),
        ('fake-fallback', {'fallback': 1}, {}, {}),
        ('backing-leak', {}, {}, {'f07s_final_backstore_used': 1}),
        ('swap-block-leak', {}, {}, {'f07s_final_swap_blocks': 1}),
    )
    for name, c_delta, a_delta, f_delta in cases:
        c = dict(counts, **c_delta)
        a = dict(alloc, **a_delta)
        f = dict(final, **f_delta)
        try:
            verify(c, a, f)
        except ValueError:
            continue
        raise AssertionError('unsafe v1303 classification: ' + name)
    print('v1346: real refused victim is nonfatal; seven strict '
          'no-partner/fatal/restore/zero-leak controls PASS')


if __name__ == '__main__':
    main()
