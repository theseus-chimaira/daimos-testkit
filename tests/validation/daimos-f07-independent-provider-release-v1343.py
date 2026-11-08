#!/usr/bin/env python3
"""Fix disposable v1150 holder-release scheduling under real swap load.

The original test-only provider release required INIT to enter sleep
AFTER genuine OOM and two fatal provider-busy failures. Under real
swap pressure INIT can already be waiting for that same child. Allow
the existing independently runnable spinner to execute the SAME
original guarded release routine when it sleeps, after the real
conditions have been satisfied. No production MM/FS/PI6 code or
provider ownership/unlock operation is changed.
"""

from pathlib import Path
import sys


def inject(root):
    path = Path(root) / 'proc/proc_pdp6.s'
    source = path.read_text()
    original = '''        skipn   daimos_test_predispatch_v1150
        jrst    daimos_test_sleep_normal_v1150
        aos     daimos_test_spinner_v1150
daimos_test_sleep_normal_v1150:'''
    replacement = '''        skipn   daimos_test_predispatch_v1150
        jrst    daimos_test_sleep_normal_v1150
        aos     daimos_test_spinner_v1150
        ; v1343 disposable fixture only: INIT can be blocked in
        ; CHILD wait by the time the genuine requester OOM and
        ; repeated provider-busy errors become visible. Slot 5 is
        ; independently scheduled, so let it trigger the ORIGINAL
        ; guarded test-only provider completion, never a fake unlock.
        skipn   daimos_test_real_oom_v1150
        jrst    daimos_test_sleep_normal_v1150
        skipn   daimos_test_release_v1150
        jrst    daimos_test_maybe_release_v1150
daimos_test_sleep_normal_v1150:'''
    if source.count(original) != 1:
        raise ValueError('v1343 original test-only spinner hook moved')
    if source.count('daimos_test_maybe_release_v1150:') != 1:
        raise ValueError('v1343 original provider completion moved')
    if source.count('caige   0,2') != 1:
        raise ValueError('v1343 real busy-failure threshold moved')
    path.write_text(source.replace(original, replacement, 1))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1343.py DISPOSABLE-KERNEL-ROOT')
    inject(sys.argv[1])
