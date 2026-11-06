#!/usr/bin/env python3
"""Verify both F07 swap probes without modifying either kernel checkout.

The clean comparison has no v1208 reclaim leaf.  A zero fallback counter
is truthful there; normal F07 must still require and instrument the leaf.
"""

import os
from pathlib import Path
import subprocess
import sys
import tempfile


HERE = Path(__file__).parent
ROOT = Path(os.environ.get('DAIMOS_REPO',
                           str(Path.home() / 'git' / 'DAIMOS')))
# Frozen, committed pre-v1208 source. Do not depend on a local test clone.
BASELINE_REF = '9a841363'
PROBE = HERE / 'daimos-f07-swapstack-v1207.py'
PREFIX = 'daimos_f07s_fallback_v1209'


def check(original, clean, pass_expected, mutate=False):
    with tempfile.TemporaryDirectory(prefix='daimos-f07-v1266-',
                                     dir=os.environ.get('TMPDIR',
                                                        str(Path.home() / 'tmp'))) as name:
        proc = Path(name) / 'proc'
        proc.mkdir()
        swap = proc / 'proc_swap_pdp6.s'
        swap.write_text(original)
        if mutate:
            text = swap.read_text()
            anchor = 'proc_swap_service_pressure:'
            assert text.count(anchor) == 1
            swap.write_text(text.replace(anchor,
                                         'proc_swap_pressure_missing_v1266:', 1))
        dispatch = proc / 'syscall_dispatch_pdp6.s'
        dispatch.write_text('daimos_f07p_done_v1205:\n'
                            '        move    6,fs_provider_ready\n')
        env = os.environ.copy()
        env['V1266_CLEAN_BASELINE'] = '1' if clean else '0'
        result = subprocess.run([sys.executable, str(PROBE), name],
                                env=env, text=True, capture_output=True)
        if (result.returncode == 0) != pass_expected:
            raise AssertionError((clean, mutate,
                                  result.stdout, result.stderr))
        if not pass_expected:
            return
        after = swap.read_text()
        # Both variants declare the observation word; only the
        # experimental fallback must increment it on entry.
        if ('        aos     ' + PREFIX in after) == clean:
            raise AssertionError('fallback counter instrumented incorrectly')
        if '        .globl ' + PREFIX not in dispatch.read_text():
            raise AssertionError('fallback observation storage missing')


def main():
    baseline = subprocess.check_output(
        ['git', '-C', str(ROOT), 'show', BASELINE_REF +
         ':system/kernel/proc/proc_swap_pdp6.s'], text=True)
    fallback = 'proc_swap_service_reclaim_v1208:'
    cooldown = 'proc_swap_service_cooldown_v833:'
    assert fallback not in baseline and baseline.count(cooldown) == 1
    experimental = baseline.replace(cooldown,
                                    fallback + '\n        jrst    proc_swap_service_cooldown_v833\n' +
                                    cooldown, 1)
    for original, clean in ((baseline, True), (experimental, False)):
        check(original, clean, True)
        check(original, not clean, False)
        check(original, clean, False, mutate=True)
    print('v1266: clean and experimental F07 probes, four negative cases PASS')


if __name__ == '__main__':
    main()
